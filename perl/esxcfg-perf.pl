#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-11909

use strict;
use warnings;
use VMware::VIFPLib;
use VMware::VIRuntime;
use Data::Dumper;
use Time::Local;

# define custom options for vm and target host
my %opts = (
   'hostlist' => {
      type => "=s",
      help => "List of ESX(i) host to perform operations on",
      required => 1,
   },
   'metriclist' => {
      type => "=s",
      help => "List of ESX(i) host metrics to collect",
      required => 1,
   },
   'aggregate' => {
      type => "=s",
      help => "Only display aggregated statistics - N/A to all metrics [yes|no]",
      required => 0,
      default => "no",
   },
   'start_date' => {
      type => "=s",
      help => "Start Date YYYY-MM-DD",
      required => 0,
   },
   'end_date' => {
      type => "=s",
      help => "End Date YYYY-MM-DD",
      required => 0,
   },
);

# read and validate command-line parameters
Opts::add_options(%opts);
Opts::parse();
Opts::set_option("passthroughauth", 1);
Opts::validate();

my (@hosts,@metrics,%metricResults) = ();
my %sampleHostSamplingPeriod = ();
my ($start_date,$end_date);
my ($HOST,$METRIC,$VALUE,$OBJ,$UNIT);
my ($HOST1,$SAMPLE);
my $debug = 0;

format format1 =
@<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<| @<<<<<<<<<<<<
$HOST,                          $OBJ,		$METRIC,		$VALUE,		$UNIT
-----------------------------------------------------------------------------------------------------------------------------------
.

my $hostlist = Opts::get_option('hostlist');
my $metriclist = Opts::get_option('metriclist');
my $aggregate = Opts::get_option('aggregate');
my $start = Opts::get_option('start_date'); 
my $end = Opts::get_option('end_date');

my @vMATargets = VIFPLib::enumerate_targets();

($start_date,$end_date) = &get_date_range($start,$end);
&processFile($hostlist,1);
&processFile($metriclist,2);

print "Processing performance statistics ...\n\n";
print "Start Date: " . $start_date . "\n";
print "End   Date: " . $end_date . "\n";
print "\n";

foreach my $host (@vMATargets) {
	if(grep(/$host/,@hosts)) {
		VIFPLib::login_by_fastpass($host);

		#validate ESX/ESXi host
		my $content = Vim::get_service_content();
		my $host_type = $content->about->apiType;

		if($host_type eq 'HostAgent') {
			#get performance manager
			my $perfMgr = Vim::get_view(mo_ref => $content->perfManager);

			#get performance counters
			my $perfCounterInfo = $perfMgr->perfCounter;

			#get host view
			my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
			my $hostname = &getHostname($host_view);

			#grab all counter defs
			my %allCounterDefintions = ();
        		foreach(@$perfCounterInfo) {
        	        	$allCounterDefintions{$_->key} = $_;
	        	}

			my @metricIDs = ();
				
			#get available metrics from host
			my $availmetricid = $perfMgr->QueryAvailablePerfMetric(entity => $host_view);			
			foreach(sort {$a->counterId cmp $b->counterId} @$availmetricid) {
				if($allCounterDefintions{$_->counterId}) {
					my $metric = $allCounterDefintions{$_->counterId};
					my $groupInfo = $metric->groupInfo->key;
	                        	my $nameInfo = $metric->nameInfo->key;
        	                	my $instance = $_->instance;
                	        	my $key = $metric->key;
					my $rolluptype = $metric->rollupType->val;
					my $statstype = $metric->statsType->val;
					my $unitInfo = $metric->unitInfo->key;

					#e.g. cpu.usage.average
					my $vmwInternalName = $groupInfo . "." . $nameInfo . "." . $rolluptype;				

					foreach(@metrics) {
						if($_ eq $vmwInternalName) {
							#print $groupInfo . "\t" . $nameInfo . "\t" . $rolluptype . "\t" . $statstype . "\t" . $unitInfo . "\n";
							my $metricId = PerfMetricId->new(counterId => $key, instance => '*');
							if(! grep(/^$key/,@metricIDs)) {
								push @metricIDs,$metricId;
							}
						}
					}
				}	
			}

			my $intervalIds = &get_available_intervals(perfmgr_view => $perfMgr, host => $host_view);

			$sampleHostSamplingPeriod{$hostname} = shift(@$intervalIds);

			my $perfQuerySpec;
			if($start_date ne 'realtime' && $end_date ne 'realtime') {
				$perfQuerySpec = PerfQuerySpec->new(entity => $host_view, maxSample => 10, metricId => \@metricIDs, startTime => $start_date, endTime => $end_date);
			} else {
				$perfQuerySpec = PerfQuerySpec->new(entity => $host_view, maxSample => 10, intervalId => shift(@$intervalIds), metricId => \@metricIDs);
			}

			my $metrics;	
			eval {
				$metrics = $perfMgr->QueryPerf(querySpec => [$perfQuerySpec]);
			};
			if(!$@) {
				my %uniqueInstances = ();
				foreach(@$metrics) {
					if($debug eq 1) {
						my $samples = $_->sampleInfo;
						foreach(@$samples) {
							print $_->interval . "\t" . $_->timestamp . "\n";
						}
					}

					my $perfValues = $_->value;
					foreach(@$perfValues) {
						my $object = $_->id->instance ? $_->id->instance :"TOTAL";
						my $uniqueKey = $hostname . "--ID--" . $_->id->counterId . "--INS--" . $object;
						if(!$uniqueInstances{$uniqueKey}) {
							if($aggregate eq "no" || $object eq "TOTAL") {
								my ($numOfCounters,$sumOfCounters,$res) = (0,0,0);

								my $values = $_->value;
								my $metricRef = $allCounterDefintions{$_->id->counterId};
								my $unitString = $metricRef->unitInfo->label;
								my $unitInfo = $metricRef->unitInfo->key;
								my $groupInfo = $metricRef->groupInfo->key;
								my $nameInfo = $metricRef->nameInfo->key;
								my $rollupType = $metricRef->rollupType->val;
								my $factor = 1;
								
								if($unitInfo eq 'percent') { $factor = 100; }

								foreach(@$values) {
									if($rollupType eq 'average') {
										$res = &average($_)/$factor;
									}elsif($rollupType eq 'maximum') {
										$res = &maximum($_)/$factor;
									}elsif($rollupType eq 'minimum') {
										$res = &minimum($_)/$factor;
									}elsif($rollupType eq 'latest') {
										$res = &latest($_)/$factor;
									}
									$res = &restrict_num_decimal_digits($res,3);
								}

								my $internalID = $groupInfo . "." . $nameInfo . "." . $rollupType;
								$metricResults{$uniqueKey} = $internalID . "\t" . $hostname . "\t" . $object . "\t" . $res . "\t" . $unitString . "\n";
							}
						}
					}
				}
			} else {
				$metricResults{$hostname} = "NO DATA" . "\t" . $hostname . "\t" . "NO DATA" . "\t" . "NO DATA" . "\t" . "NO DATA" . "\n";
			}
			@metricIDs = ();
		}
		Util::disconnect();
	}
}

if(%metricResults) {
($HOST,$OBJ,$METRIC,$VALUE,$UNIT) = ('HOSTNAME','OBJECT','METRIC','VALUE','UNITS');
$~ = 'format1';
write;

for my $key ( sort { $metricResults {$a} cmp $metricResults {$b}} keys %metricResults ) {
	my $value = $metricResults{$key};
	($METRIC,$HOST,$OBJ,$VALUE,$UNIT) = split(' ',$value,5);
	$~ = 'format1';
	write;
}
} else {
	print "No results for time period for hosts\n";
}

print "\n";

my $showSample = 0;
if($showSample eq 1) {
format format2 =
@<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<
$HOST1,         $SAMPLE
--------------------------------------------------
.

($HOST1,$SAMPLE) = ('HOSTNAME','SAMPLE PERIOD (secs)');
$~ = 'format2';
write;

for my $key ( sort keys %sampleHostSamplingPeriod ) {
	($HOST1,$SAMPLE) = ($key,$sampleHostSamplingPeriod{$key});
	$~ = 'format2';
	write;
}
}

####################################
# 	HELPER FUNCTIONS
####################################

#VMware's viperformance.pl function
sub get_available_intervals {
   my %args = @_;
   my $perfmgr_view = $args{perfmgr_view};
   my $entity = $args{host};

   my $historical_intervals = $perfmgr_view->historicalInterval;
   my $provider_summary = $perfmgr_view->QueryPerfProviderSummary(entity => $entity);
   my @intervals;
   if ($provider_summary->refreshRate) {
      push @intervals, $provider_summary->refreshRate;
   }
   foreach (@$historical_intervals) {
      push @intervals, $_->samplingPeriod;
   }
   return \@intervals;
}

sub getHostname {
        my ($host) = @_;
        my $shortname = $host->name;

        my $networkSys = Vim::get_view(mo_ref => $host->configManager->networkSystem);

        if($networkSys->dnsConfig->hostName) {
                $shortname = $networkSys->dnsConfig->hostName;
        }

        return $shortname;
}

# Subroutine to process the input file
sub processFile {
        my ($list,$type) =  @_;
	my $CONF_HANDLE;

	open(CONF_HANDLE, "$list") || die "Couldn't open file \"$list\" input file!\n";
	while (<CONF_HANDLE>) {
        	chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;

		if($type eq 1) {
	                push @hosts,$_;
                } else {
                        push @metrics,$_;
                }
        }
        close(CONF_HANDLE);
}

sub minimum {
   my @arr = @_;
   my $n = @arr;

   my $i = 0;
   my $min;

   for ($i = 0; $i < $n; $i++)
   {
      if ($arr[$i] != -1)
      {
         $min = $arr[$i];
         last;
      }
   }

   for (; $i < $n; $i++)
   {
      if (($arr[$i] < $min) && ($arr[$i] != -1))
      {
         $min = $arr[$i];
      }
   }

   return $min;
}

sub maximum {
   my @arr = @_;
   my $n= @arr;

   my $i=0;
   my $max;

   for ($i = 0; $i < $n; $i++)
   {
      if ($arr[$i] != -1)
      {
         $max = $arr[$i];
         last;
      }
   }

   for (; $i < $n; $i++)
   {
      if ($arr[$i] > $max)
      {
         $max = $arr[$i];
      }
   }

   return $max;
}

sub latest {
	my @arr = @_;
	return shift(@arr);
}

sub average {
   my @arr = @_;
   my $n = 0;
   my $avg = 0;

   foreach(@arr) {
   	$avg += $_;
   	$n += 1;
   }
   return $avg ? $avg/$n : 0;
}


# restrict the number of digits after the decimal point
#http://guymal.com/mycode/perl_restrict_digits.shtml
sub restrict_num_decimal_digits {
        my $num=shift;#the number to work on
        my $digs_to_cut=shift;# the number of digits after

        if ($num=~/\d+\.(\d){$digs_to_cut,}/) {
                $num=sprintf("%.".($digs_to_cut-1)."f", $num);
        }
        return $num;
}

sub get_date_range {
	my ($sd,$ed) = @_;
	my ($st_date,$ed_date,$year,$month,$day);
	my $start_string = "T00:00:00";
	my $end_string = "T00:00:00";
	
	if($sd && $ed) {
		$st_date = $sd . $start_string;
		$ed_date = $ed . $end_string;
	} else {
		($st_date,$ed_date) = ('realtime','realtime')
	}
   	return ($st_date,$ed_date);
}

sub giveMeDate {
	my ($time) = @_;
        my %dttime = ();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);

        ### begin_: initialize DateTime number formats
        $dttime{year }  = sprintf "%04d",($year + 1900);  ## four digits to specify the year
        $dttime{mon  }  = sprintf "%02d",($mon + 1);      ## zeropad months
        $dttime{mday }  = sprintf "%02d",$mday;           ## zeropad day of the month
        $dttime{wday }  = sprintf "%02d",$wday + 1;       ## zeropad day of week; sunday = 1;
        $dttime{yday }  = sprintf "%02d",$yday;           ## zeropad nth day of the year
        $dttime{hour }  = sprintf "%02d",$hour;           ## zeropad hour
        $dttime{min  }  = sprintf "%02d",$min;            ## zeropad minutes
        $dttime{sec  }  = sprintf "%02d",$sec;            ## zeropad seconds
        $dttime{isdst}  = $isdst;

        return $dttime{year},$dttime{mon},$dttime{mday};
}
