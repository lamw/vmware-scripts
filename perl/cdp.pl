#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com

use strict;
use warnings;
use Math::BigInt;
use Tie::File;
use POSIX qw/mktime/;
use Getopt::Long;
use VMware::VIRuntime;
use VMware::VILib;

########### DO NOT MODIFY PAST HERE ###########

################################
# VERSION
################################
my $version = "0.1";
$Util::script_version = $version;

################################
# DEMO MODE
# 0 = no, 1 = yes
################################
my $enable_demo_mode = 0;

################
#GLOBAL VARS
################
my $opt_type;
my $host_type;
my $host_view;
my $cluster_count = 0;
my $cluster_view;
my $cluster_views;
my $datacenter_view;
my $datacenter_name;
my $start_time;
my $end_time;
my $run_time;
my $my_time;
my @jump_tags = ();
my $randomHostName;
my $content;
my $report_name;

my %opts = (
        datacenter => {
        type => "=s",
        help => "The name of a vCenter datacenter",
        required => 0,
        },
	cluster => {
	type => "=s",
        help => "The name of a vCenter cluster",
	required => 0,
        },
        type => {
        type => "=s",
        help => "Type: [vcenter|datacenter|cluster|host]\n",
        required => 1,
        },
        report => {
        type => "=s",
        help => "The name of the report to output. Please add \".html\" extension",
        required => 0,
        },
);
# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

############################
# PARSE COMMANDLINE OPTIONS
#############################
if (Opts::option_is_set ('type')) {
        # get ServiceContent
        $content = Vim::get_service_content();
        $host_type = $content->about->apiType;
        $opt_type = Opts::get_option('type');

	####################
        # SINGLE ESX HOST
        ####################
        if( ($opt_type eq 'host') && (!Opts::option_is_set('cluster')) && ($host_type eq 'HostAgent') ) {
                $host_view = Vim::find_entity_views(view_type => 'HostSystem');
                if (!$host_view) {
                        die "ESX/ESXi host was not found\n";
                }
        }
        #####################
        # vCENTER + CLUSTER
        #####################
        elsif( ($opt_type eq 'cluster') && ($host_type eq 'VirtualCenter') ) {
                if ( Opts::option_is_set('cluster') ) {
                        my $cluster_name = Opts::get_option('cluster');
                        $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource',filter => { name => $cluster_name });

                        if(!$cluster_view) {
                                die "Cluster: \"$cluster_name\" was not found\n";
                        }
                }
                else {
                        Fail("\n--cluster parameter required with the name of a valid vCenter Cluster\n\n");
                }
        }
        ########################
        # vCENTER + DATACENTER
        ########################
        elsif( ($opt_type eq 'datacenter') && ($host_type eq 'VirtualCenter') ) {
                if ( Opts::option_is_set('datacenter') ) {
                        $datacenter_name = Opts::get_option('datacenter');
                        my $datacenter_view = Vim::find_entity_view(view_type => 'Datacenter',filter => { name => $datacenter_name});
                        if(!$datacenter_view) {
                                die "Datacenter: \"$datacenter_name\" was not found\n";
                        }
                        $cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource',begin_entity => $datacenter_view);

                        if(!$cluster_views) {
                                die "No clusters were found in this datacenter\n";
                        }
                }
                else {
                        Fail("\n--datacenter parameter required with the name of a valid vCenter Datacenter\n\n");
                }
        }
	##################
        # vCENTER ALL
        ##################
        elsif( ($opt_type eq 'vcenter') && (!Opts::option_is_set('cluster')) && ($host_type eq 'VirtualCenter') ) {
                $cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource');
                Fail ("No clusters found.\n") unless (@$cluster_views);
        } else { die "Invalid Input, ensure your selection is one of the supported use cases \n\n\tServer: vCenter => [vcenter|datacenter|cluster]\n\tServer: ESX/ESXi Host => [host]\n"; }

        #if report name is not specified, default output
        if (Opts::option_is_set ('report')) {
                $report_name = Opts::get_option('report');
        }
        else {
                $report_name = "cdp.html";
        }
}

### CODE START ###

#################################
# PRINT HTML HEADER/CSS
#################################
printStartHeader();

#########################################
# PRINT vCENTER or HOST BUILD/SUMMARY
#########################################
printBuildSummary();

#########################################
# PRINT vCENTER INFO
#########################################
if ($opt_type eq 'vcenter') {
        foreach my $cluster (@$cluster_views) {
                $cluster_count += 1;
                my $hosts = Vim::get_views (mo_ref_array => $cluster->host);
                if(@$hosts) {
			getVswitchInfo($hosts);
                }
        }
}
#########################################
# PRINT SPECIFIC DATACENTER INFO
#########################################
elsif ($opt_type eq 'datacenter') {
        printDatacenterName($datacenter_name);
        foreach my $cluster (@$cluster_views) {
                $cluster_count += 1;
                printClusterSummary($cluster);
                my $hosts = Vim::get_views (mo_ref_array => $cluster->host);
                if(@$hosts) {
			getVswitchInfo($hosts);
                }
        }
}
#########################################
# PRINT SPECIFIC CLUSTER INFO
#########################################
elsif ($opt_type eq 'cluster') {
        $cluster_count += 1;
        printClusterSummary($cluster_view);
	foreach my $cluster (@$cluster_views) {
                $cluster_count += 1;
                printClusterSummary($cluster);
                my $hosts = Vim::get_views (mo_ref_array => $cluster->host);
                if(@$hosts) {
                        getVswitchInfo($hosts);
                }
        }	
}
elsif ($opt_type eq 'host' ) {
	getVswitchInfo($host_view);
}

#################################
# CLOSE HTML REPORT
#################################
printCloseHeader();

Util::disconnect();

### CODE END ###

###########################
#
# HELPER FUNCTIONS
#
###########################

sub getVswitchInfo {
	my ($hosts) = @_;
	my %cdp_enabled = ();
	my %cdp_blob = ();

	foreach my $host(@$hosts) {	
        my $netMgr = Vim::get_view(mo_ref => $host->configManager->networkSystem);
        my @physicalNicHintInfo = $netMgr->QueryNetworkHint();
        foreach (@physicalNicHintInfo){
        	foreach ( @{$_} ){
                	if(defined($_->connectedSwitchPort)) {
                        	my $device = $_->device;
                                my $port = $_->connectedSwitchPort->portId;
				my $address = defined $_->connectedSwitchPort->address ? $_->connectedSwitchPort->address : "N/A";
				my $cdp_ver = defined $_->connectedSwitchPort->cdpVersion ? $_->connectedSwitchPort->cdpVersion : "N/A";
				my $devid = defined $_->connectedSwitchPort->devId ? $_->connectedSwitchPort->devId : "N/A";
				my $duplex = defined $_->connectedSwitchPort->fullDuplex ? ($_->connectedSwitchPort->fullDuplex ? "YES" : "NO") : "N/A";
				my $platform = defined $_->connectedSwitchPort->hardwarePlatform ? $_->connectedSwitchPort->hardwarePlatform : "N/A";
				my $prefix = defined $_->connectedSwitchPort->ipPrefix ? $_->connectedSwitchPort->ipPrefix : "N/A";
				my $location = defined $_->connectedSwitchPort->location ? $_->connectedSwitchPort->location : "N/A";
				my $mgmt_addr = defined $_->connectedSwitchPort->mgmtAddr ? $_->connectedSwitchPort->mgmtAddr : "N/A";
				my $d_mtu = defined $_->connectedSwitchPort->mtu ? $_->connectedSwitchPort->mtu : "N/A";
				my $samples = defined $_->connectedSwitchPort->samples ? $_->connectedSwitchPort->samples : "N/A";
				my $sys_ver = defined $_->connectedSwitchPort->softwareVersion ? $_->connectedSwitchPort->softwareVersion : "N/A";
				my $sys_name = defined $_->connectedSwitchPort->systemName ? $_->connectedSwitchPort->systemName : "N/A";
				my $sys_oid = defined $_->connectedSwitchPort->systemOID ? $_->connectedSwitchPort->systemOID : "N/A";
				my $timeout = defined $_->connectedSwitchPort->timeout ? $_->connectedSwitchPort->timeout : "N/A";
				my $ttl = defined $_->connectedSwitchPort->ttl ? $_->connectedSwitchPort->ttl : "N/A";
				my $vlan = defined $_->connectedSwitchPort->vlan ? $_->connectedSwitchPort->vlan : "N/A"; 
				my $blob .= "<tr><td>".$device."</td><td>".$mgmt_addr."</td><td>".$address."</td><td>".$prefix."</td><td>".$location."</td><td>".$sys_name."</td><td>".$sys_ver."</td><td>".$sys_oid."</td><td>".$platform."</td><td>".$devid."</td><td>".$cdp_ver."</td><td>".$duplex."</td><td>".$d_mtu."</td><td>".$timeout."</td><td>".$ttl."</td><td>".$vlan."</td><td>".$samples."</td></tr>\n";
				$cdp_blob{$device} = $blob;			
				$cdp_enabled{$device} = $port;
                        }
                }
        }

        my $vswitches = $host->config->network->vswitch;
        my $vswitch_string = "";
        foreach my $vSwitch (@$vswitches) {
        	my $pNicName = "";
                my $mtu = "";
                my $cdp_vswitch = "";
		my $found = 0;
		my $device_name = "";

                my $pNics = $vSwitch->pnic;
                my $pNicKey = "";
                foreach (@$pNics) {
                	$pNicKey = $_;
                        if ($pNicKey ne "") {
                        	$pNics = $netMgr->networkInfo->pnic;
                                foreach my $pNic (@$pNics) {
                                	if ($pNic->key eq $pNicKey) {
                                        	$pNicName = $pNicName ? ("$pNicName," . $pNic->device) : $pNic->device;
                                                if($cdp_enabled{$pNic->device}) {
                                                	$cdp_vswitch = $cdp_enabled{$pNic->device};
                                                }
                                                else {
                                                	$cdp_vswitch = "";
                                                }
                                        }
                                }
                        }
                }
                $mtu = $vSwitch->{mtu} if defined($vSwitch->{mtu});
                $vswitch_string .= "<tr><th>VSWITCH NAME</th><th>NUM OF PORTS</th><th>USED PORTS</th><th>MTU</th><th>UPLINKS</th><th>CDP ENABLED</th></tr><tr><td>".$vSwitch->name."</td><td>".$vSwitch->numPorts."</td><td>".($vSwitch->numPorts - $vSwitch->numPortsAvailable)."</td><td>".$vSwitch->{mtu}."</td><td>".$pNicName."</td><td>".$cdp_vswitch."</td></tr>";
                $vswitch_string .= "<tr><th>PORTGROUP NAME</th><th>VLAN ID</th><th>USED PORTS</th><th colspan=3>UPLINKS</th></tr>";
                my $portGroups = $vSwitch->portgroup;
                foreach my $port (@$portGroups) {
                	my $pg = FindPortGroupbyKey ($netMgr, $vSwitch->key, $port);
                        next unless (defined $pg);
                        my $usedPorts = (defined $pg->port) ? $#{$pg->port} + 1 : 0;
                        if($enable_demo_mode eq 1) {
                        	$vswitch_string .= "<tr><td>HIDE MY PG</td><td>HIDE MY VLAN ID</td><td>".$usedPorts."</td><td colspan=3>".$pNicName."</td></tr>";
                        } else {
                                $vswitch_string .= "<tr><td>".$pg->spec->name."</td><td>".$pg->spec->vlanId."</td><td>".$usedPorts."</td><td colspan=3>".$pNicName."</td></tr>";
                        }
                }	
        }
        print REPORT_OUTPUT "<br><b>VSWITCH(s)</b><table border=1>",$vswitch_string,"</table></td></tr>\n";

	my $cdp_string = "";
	for my $key ( keys %cdp_blob ) {
	        my $value = $cdp_blob{$key};
                $cdp_string .= $value;
        }
	print REPORT_OUTPUT "<br><b>CDP SUMMARY</b><table border=1><tr><th>DEVICE</th><th>MGMT ADDRESS</th><th>DEVICE ADDRESS</th><th>IP PREFIX</th><th>LOCATION</th><th>SYSTEM NAME</th><th>SYSTEM VERSION</th><th>SYSTEM OID</th><th>PLATFORM</th><th>DEVICE ID</th><th>CDP VER</th><th>FULL DUPLEX</th><th>MTU</th><th>TIMEOUT</th><th>TTL</th><th>VLAN ID</th><th>SAMPLES</th></tr>\n",$cdp_string,"</table></td></tr>\n";
	}
}

sub FindPortGroupbyKey {
   my ($network, $vSwitch, $key) = @_;
   my $portGroups = $network->networkInfo->portgroup;
   foreach my $pg (@$portGroups) {
      return $pg if (($pg->vswitch eq $vSwitch) && ($key eq $pg->key));
   }
   return undef;
}

sub printBuildSummary {
        my $print_type;
        if ($content->about->apiType eq 'VirtualCenter') {
                $print_type = "VMware vCenter";
        } else {
		$print_type = "ESX/ESXi";
	}

        print REPORT_OUTPUT "<H2>$print_type:</H2>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>BUILD</th><th>VERSION</th><th>FULL NAME</th>\n";
        print REPORT_OUTPUT "<tr>";
        print REPORT_OUTPUT "<td>",$content->about->build,"</td><td>",$content->about->version,"</td><td>",$content->about->fullName,"</td>\n";
        print REPORT_OUTPUT "</tr>";
        print REPORT_OUTPUT "</table>\n";

        #please do not touch this, else the jump tags will break
        print REPORT_OUTPUT "<br>\n";
        print REPORT_OUTPUT "\n/<!-- insert here -->/\n";
}

sub printStartHeader {
        print "Generating VMware vSwitch Report $version \"$report_name\" ...\n\n";
        print "This can take a few minutes depending on environment size. \nGet a cup of coffee/tea and check out http://www.engineering.ucsb.edu/~duonglt/vmware/\n";

        $my_time = "Date: ".giveMeDate('MDYHMS');

        $start_time = time();
        open(REPORT_OUTPUT, ">$report_name");
        print REPORT_OUTPUT "<html>\n";
        print REPORT_OUTPUT "<title>VMware vSwitch Report $version - $my_time</title>\n";
        print REPORT_OUTPUT "<META NAME=\"AUTHOR\" CONTENT=\"William Lam\">\n";
        print REPORT_OUTPUT "<style type=\"text/css\">\n";
        print REPORT_OUTPUT "body { background-color:#EEEEEE; }\n";
        print REPORT_OUTPUT "body,table,td,th { font-family:Tahoma; color:Black; Font-Size:10pt }\n";
        print REPORT_OUTPUT "th { font-weight:bold; background-color:#CCCCCC; }\n";
        print REPORT_OUTPUT "a:link { color: blue; }\n";
        print REPORT_OUTPUT "a:active { color: blue; }\n";
        print REPORT_OUTPUT "</style>\n";

        print REPORT_OUTPUT "\n<H1>VMware vSwitch Report $version</H1>\n";
        print REPORT_OUTPUT "$my_time\n";
}

sub giveMeDate {
        my ($date_format) = @_;
        my %dttime = ();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

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

        if($date_format eq 'MDYHMS') {
                $my_time = "$dttime{mon}-$dttime{mday}-$dttime{year} $dttime{hour}:$dttime{min}:$dttime{sec}";
        }
        elsif ($date_format eq 'YMD') {
                $my_time = "$dttime{year}-$dttime{mon}-$dttime{mday}";
        }
        return $my_time;
}

sub printCloseHeader {
        print REPORT_OUTPUT "<br><hr>\n";
        print REPORT_OUTPUT "<center>Author: <b><a href=\"http://engineering.ucsb.edu/~duonglt/vmware/\">William Lam</a></b></center>\n";
        print REPORT_OUTPUT "<center>Generated using: <b><a href=\"http://engineering.ucsb.edu/~duonglt/vmware/cdp.pl\">cdp.pl</a></b></center>\n";
        print REPORT_OUTPUT "<center>&#0153;Primp Industries</center>\n";
        close(REPORT_OUTPUT);

        my @lines;
        my $jump_string = "";
        tie @lines, 'Tie::File', $report_name or die;
        for (@lines) {
                if (/<!-- insert here -->/) {
                        foreach (@jump_tags) {
                                if( ($_ =~ /^CL/) ) {
                                        my $tmp_string = substr($_,2);
                                        $jump_string .= $tmp_string;
                                }
                                else {
                                        $jump_string .= $_;
                                }
                        }
                        $_ = "\n$jump_string";
                        last;
                }
        }
        untie @lines;

        $end_time = time();
        $run_time = $end_time - $start_time;
        print "\nStart Time: ",&formatTime(str => scalar localtime($start_time)),"\n";
        print "End   Time: ",&formatTime(str => scalar localtime($end_time)),"\n";

        if ($run_time < 60) {
                print "Duration  : ",$run_time," Seconds\n\n";
        }
        else {
                print "Duration  : ",&restrict_num_decimal_digits($run_time/60,2)," Minutes\n\n";
        }
}

sub Fail {
    my ($msg) = @_;
    Util::disconnect();
    die ($msg);
    exit ();
}

#http://www.infocopter.com/perl/format-time.html
sub formatTime(%) {
        my %args = @_;
        $args{'str'} ||= ''; # e.g. Mon Jul 3 12:59:28 2006

        my @elems = ();
        foreach (split / /, $args{'str'}) {
                next unless $_;
                push(@elems, $_);
        }

        my ($weekday, $month, $mday, $time, $yyyy) = split / /, join(' ', @elems);

        my %months = (  Jan => 1, Feb => 2, Mar => 3, Apr =>  4, May =>  5, Jun =>  6,
                        Jul => 7, Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12 );

        my $s  = substr($time, 6,2);
        my $m  = substr($time, 3,2);
        my $h  = substr($time, 0, 2);
        my $dd = sprintf('%02d', $mday);

        my $mm_num = sprintf('%02d', $months{$month});

        my $formatted = "$mm_num\-$dd\-$yyyy $h:$m:$s";
        #my $formatted = "$yyyy$mm_num$dd$h$m$s";

        $formatted;
}

