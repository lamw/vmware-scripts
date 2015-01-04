#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-11781

use strict;
use warnings;
use POSIX qw/mktime/;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('3.5.0','licensed','VirtualCenter');

my $operation = Opts::get_option('operation');

my $content = Vim::get_service_content();
my $vms = Vim::find_entity_views(view_type => 'VirtualMachine');
my @customFields = ("AGE","USER","CREATED");

my $customFieldMgr = Vim::get_view(mo_ref => $content->customFieldsManager);
my $eventMgr = Vim::get_view(mo_ref => $content->eventManager);

&verifyCustomFields();
&updateVMAge();

### HELPER FUNCTIONS ###

sub updateVMAge {
	foreach my $vm (@$vms) {
		my $recur = EventFilterSpecRecursionOption->new('self');
		my $entity = EventFilterSpecByEntity->new(entity => $vm, recursion => $recur);
		my $filterSpec = EventFilterSpec->new(entity => $entity, type => ["VmCreatedEvent","VmClonedEvent","VmDeployedEvent"]);
		my $events;
	
		eval {
			$events = $eventMgr->QueryEvents(filter => $filterSpec);
		};
		if($@) {
			print "Error querying for events: " . $@ . "\n";
		}

		my ($age,$user,$created) = ('N/A','N/A','N/A');
		foreach(@$events) {
			my $createdTime;
			if($_->createdTime) { 
				$created = $_->createdTime; 
				my ($vmCreateDate,$vmCreatedTime) = split('T',$created);
				my $todays_date = giveMeDate('YMD');
				chomp($todays_date);
				$age = days_between($vmCreateDate,$todays_date);
			}
			if($_->userName) {
				$user = $_->userName;
			}
		}
		my $agekey = &findKey('AGE');
		eval {
                	$customFieldMgr->SetField(entity => $vm, key => $agekey, value => $age);
		}; 
		if($@) { print "Error updating AGE: " . $@ . "\n"; }
               	my $userkey = &findKey('USER');
		eval {
	       	        $customFieldMgr->SetField(entity => $vm, key => $userkey, value => $user);
		};
		if($@) { print "Error updating USER: " . $@ . "\n"; }
	               my $createdkey = &findKey('CREATED');
		eval {
	               	$customFieldMgr->SetField(entity => $vm, key => $createdkey, value => $created);
		};
		if($@) { print "Error updating CREATED: " . $@ . "\n"; }
	}
}

sub verifyCustomFields {
	foreach(@customFields) {
		my $key = &findKey($_);
		if($key eq '-2003') {
			$customFieldMgr->AddCustomFieldDef(name => $_, moType => 'VirtualMachine');
		}
	}
}

sub findKey {
	my ($name) = @_;

	my $fields = $customFieldMgr->field;
	my $key = -2003;

	foreach(@$fields) {
	        if($_->name eq $name) {
        	        $key = $_->key;
        	}
	}
	return $key;
}

#http://www.perlmonks.org/?node_id=17057
sub days_between {
        my ($start, $end) = @_;
        my ($y1, $m1, $d1) = split ("-", $start);
        my ($y2, $m2, $d2) = split ("-", $end);
        my $diff = mktime(0,0,0, $d2-1, $m2-1, $y2 - 1900) -  mktime(0,0,0, $d1-1, $m1-1, $y1 - 1900);
        return $diff / (60*60*24);
}

sub giveMeDate {
        my ($date_format) = @_;
        my %dttime = ();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $my_time;

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

sub validateConnection {
        my ($host_version,$host_license,$host_type) = @_;
        my $service_content = Vim::get_service_content();
        my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);

        ########################
        # CHECK HOST VERSION
        ########################
        if(!$service_content->about->version ge $host_version) {
                Util::disconnect();
                print color("red") . "This script requires your ESX(i) host to be greater than $host_version\n\n" . color("reset");
                exit 1;
        }

        ########################
        # CHECK HOST LICENSE
        ########################
        my $licenses = $licMgr->licenses;
        foreach(@$licenses) {
                if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
                        Util::disconnect();
                        print color("red") . "This script requires your ESX(i) be licensed, the free version will not allow you to perform any write operations!\n\n" . color("reset");
                        exit 1;
                }
        }

        ########################
        # CHECK HOST TYPE
        ########################
        if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
                Util::disconnect();
                print color("red") . "This script needs to be executed against $host_type\n\n" . color("reset");
                exit 1
        }

        return $service_content->about->apiType;
}


Util::disconnect();
