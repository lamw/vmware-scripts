#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-11671

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use DateTime;
use Net::SMTP;

$SIG{__DIE__} = sub{Util::disconnect()};

#################
# EMAIL CONF
#################

my $SEND_MAIL = "no";
my $EMAIL_HOST = "emailserver";
my $EMAIL_DOMAIN = "localhost.localdomain";
my $EMAIL_TO = 'William Lam <william@primp-industries.com>';
my $EMAIL_FROM = 'vMA <vMA@primp-industries.com>';

########### NOT MODIFY PAST HERE ###########

my %opts = (
	report => {
        type => "=s",
        help => "The name of the report to output. Please at \".html\" extension",
        required => 0,
        },
        start => {
	type => "=s",
        help => "Starting date of report YYYY-MM-DD",
	required => 0,
        },
	end => {
        type => "=s",
        help => "Ending date of report YYYY-MM-DD",
        required => 0,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $report_name;

#if report name is not specified, default output
if (Opts::option_is_set ('report')) {
        $report_name = Opts::get_option('report');
}
else {
        $report_name = "vmProvisionReport.html";
}

my ($sY,$sM,$sD,$eY,$eM,$eD,$st,$et);

if (Opts::option_is_set ('start')) {
	($sY,$sM,$sD) = split('-',Opts::get_option('start'));
	$st = DateTime->new( year => $sY, month => $sM, day => $sD);
}

if (Opts::option_is_set ('end')) {
        ($eY,$eM,$eD) = split('-',Opts::get_option('end'));
	$et = DateTime->new( year => $eY, month => $eM, day => $eD);
} else {
	my $today = DateTime->now;
	$eY = $today->year;
	$eM = $today->month;
	$eD = $today->day;
	$et = DateTime->new( year => $eY, month => $eM, day => $eD);
}

my %vms_created_day = ();
my %vms_created_month = ();
my $totalDays = 0;
my $totalMonths = 0;
my $day_string = "VM Deployments Per Day";
my $month_string = "VM Deployments Per Month";

my $content = Vim::get_service_content();
my $eventMgr = Vim::get_view(mo_ref => $content->eventManager);

eval {
	my $timeSpec;
	if (!Opts::option_is_set ('end')) {
		$timeSpec = EventFilterSpecByTime->new(endTime => $et);
	} else {
		$timeSpec = EventFilterSpecByTime->new(beginTime => $st, endTime => $et);
	}
	my $filterSpec = EventFilterSpec->new(time => $timeSpec, type => ["VmCreatedEvent","VmClonedEvent","VmDeployedEvent"]);
	my $results = $eventMgr->CreateCollectorForEvents(filter => $filterSpec);
	
	my $eventCollector = Vim::get_view(mo_ref => $results);

	$eventCollector->ResetCollector();

	my $events = $eventCollector->latestPage;

	&readEvents($events);
	my $count = 0;
	while(@$events) {
		eval {
			$events = $eventCollector->ReadPreviousEvents(maxCount => 1000);			
		};
		if($@) {
			print "No more events\n";
		} else {
			$count = $count+1 ;
			&readEvents($events);
		}

	}
};	
if($@) {
	print "Error: " . $@ . "\n";
}

my $report_output = &graphVMStats();
print "Generating provision report: \"$report_name\" ...\n\n";
open(REPORT_OUTPUT, ">$report_name");
print REPORT_OUTPUT $report_output;
close(REPORT_OUTPUT);

Util::disconnect();

if($SEND_MAIL eq "yes") {
        &sendMail();
}

########################
# HELPER FUNCTIONS
########################

sub sendMail {
        my $smtp = Net::SMTP->new($EMAIL_HOST ,Hello => $EMAIL_DOMAIN, Timeout => 30,);

        unless($smtp) {
                die "Error: Unable to setup connection with email server: \"" . $EMAIL_HOST . "\"!\n";
        }

        $smtp->mail($EMAIL_FROM);
        $smtp->to($EMAIL_TO);

        $smtp->data();
        $smtp->datasend('From: '.$EMAIL_FROM."\n");
        $smtp->datasend('To: '.$EMAIL_TO."\n");
        $smtp->datasend('Subject: '.$report_name."\n");
        $smtp->datasend("\n");

        open (HANDLE, $report_name) or die("ERROR: Can not locate log \"$report_name\"!\n");
        my @lines = <HANDLE>;
        close(HANDLE);
        foreach my $line (@lines) {
                $smtp->datasend($line);
        }

        eval {
                $smtp->dataend();
                $smtp->quit;
        };
        if($@) {
                die "Error: Unable to send report \"$report_name\"!\n";
        } else {
                `/bin/rm -f $report_name`;
        }
}

sub readEvents() {
	my ($e) = @_;
	foreach( @$e) {
                my $time = $_->createdTime;
                $time =~ s/T.*//;
                if(!defined($vms_created_day{$time})) {
                        $totalDays += 1;
                }
                $vms_created_day{$time} += 1;

                my $month = substr($time,0,7);
                if(!defined($vms_created_day{$month})) {
                        $totalMonths += 1;
                }
                $vms_created_month{$month} += 1;
        }
}

sub graphVMStats() {
	my $output;

$output .= <<HTML_OUTPUT;
<html>
<title>VMware VM Provision Report</title>
<META NAME="AUTHOR" CONTENT="William Lam">
<style type="text/css">
      .graph {
        background-color: #C8C8C8;
        border: solid 1px black;
      }
      
      .graph td {
        font-family: verdana, arial, sans serif;
      }
      
      .graph thead th {
        border-bottom: double 3px black;
        font-family: verdana, arial, sans serif;
        padding: 1em;
      }
    
      .graph tfoot td {
        border-top: solid 1px #999999;
        font-size: x-small;
        text-align: center;
        padding: 0.5em;
        color: #666666;
      }

      .bar {
        background-color: white;
        text-align: right;
        border-left: solid 1px black;
        padding-right: 0.5em;
        width: 400px;
      }
      
      .bar div { 
        border-top: solid 2px #0077DD;
        background-color: #004080;
        border-bottom: solid 2px #002266;
        text-align: right;
        color: white;
        float: left;
        padding-top: 0;
        height: 1em;
      }
      
      body {
        background-color: white;
      }
</style>
HTML_OUTPUT

$output .= <<HTML_OUTPUT;
<table width="430" class="graph" cellspacing="6" cellpadding="0" align=top>
        <thead>
                <tr><th colspan="3">$month_string</th></tr>
        </thead>
HTML_OUTPUT

my $b = 0;
my $counter = 0;
for my $key ( sort keys %vms_created_month ) {
        my $value = $vms_created_month{$key};
	$output .= "<tr>\n";
        my $per = (($value/$totalMonths)*100);
	$output .= "<td width=\"50\">$key<\/td><td width=\"$per\" class=\"bar\"><div style=\"width: $value;\"><\/div><\/td><td>$value<\/td>\n";
        $output .= "<\/tr>\n";
        $counter += 1;
	$b += $value;
}

$output .= <<HTML_OUTPUT;
</table>
</body>
</html>
HTML_OUTPUT

$output .= "Entries: " . $b . "\n";
	return $output;
}

sub captureEvents {
	my ($events) = @_;
	foreach( @$events) {
                my $time = $_->createdTime;
                $time =~ s/T.*//;
                if(!defined($vms_created_day{$time})) {
                        $totalDays += 1;
                }
                $vms_created_day{$time} += 1;

                my $month = substr($time,0,7);
                if(!defined($vms_created_day{$month})) {
                        $totalMonths += 1;
                }
                $vms_created_month{$month} += 1;
        }
}
