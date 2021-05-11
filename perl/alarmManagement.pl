#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2010/10/how-to-ack-reset-vcenter-alarm.html

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect()};

my %opts = (
   alarm => {
      type => "=s",
      help => "Name of the alarm to ACK",
      required => 0,
   },
   entity => {
      type => "=s",
      help => "Name of the entity to ACK",
      required => 0,
   },
   operation => {
      type => "=s",
      help => "[list|ack]",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('4.0.0','licensed','VirtualCenter');

my $alarm = Opts::get_option('alarm');
my $operation = Opts::get_option('operation');
my $entity = Opts::get_option('entity');

my ($alarm_key,$alarm_state,$alarm_name,$alarm_entity) = ("Alarm Key","Alarm State", "Alarm Name", "Alarm Entity");

my $sc = Vim::get_service_content();

if($operation eq "list") {
	&listAlarms($sc);
}elsif($operation eq "ack") {
	unless($alarm && $entity) {
		Util::disconnect();
		print "Operation ack requires \"alarm\" and \"entity\" params!\n";
		exit 1;
	}
	&ackAlarm($sc,$alarm,$entity);
} else {
	print "Invalid operation selection!\n";
}

Util::disconnect();

sub ackAlarm {
	my ($sc,$a,$e) = @_;

	my $alarmMgr = Vim::get_view(mo_ref => $sc->alarmManager);
	eval {
                my $alarms = $alarmMgr->GetAlarm();
		my $found = 0;
		if($alarms) {
			print "Searching for Alarm: $alarm on Entity: $entity ...\n";
			foreach(@$alarms) {
				my $alarm_moref = Vim::get_view(mo_ref => $_);
				$alarm_key = $alarm_moref->{'mo_ref'}->value;
                                my $alarm = $alarm_moref->info;
				my $alarm_entity_moref = Vim::get_view(mo_ref => $alarm->entity);
				$alarm_entity = $alarm_entity_moref->name;

				if($alarm->enabled) {
					if($a eq $alarm_key && $e eq $alarm_entity) {
						$found = 1;
						print "\tFound Alarm: $a!\n";
						eval {
							print "\tAcknowledging Alarm ...\n";
							$alarmMgr->AcknowledgeAlarm(alarm => $alarm_moref, entity => $alarm_entity_moref);
							print "\tReseting Alarm to green ...\n";
							$alarmMgr->SetAlarmStatus(alarm => $alarm_moref, entity => $alarm_entity_moref, status => ManagedEntityStatus->new('green'));
						};
						if($@) {
							print "Error in AcknowledgeAlarm " . $@ . "\n";
						}
					}
				}
			}
			if($found eq 0) {
				print "Unable to locate Alarm: " . $alarm . " for Entity: " . $entity . "\n";
			}
		}
	};
	if($@) {
                print "Error in getAlarm: " . $@ . "\n";
        }
}

sub listAlarms {
	my ($sc) = @_;

	my $alarmMgr = Vim::get_view(mo_ref => $sc->alarmManager);
	my $alarms;

	eval {
		$alarms = $alarmMgr->GetAlarm();
		if($alarms) {
			format format1 =
@<<<<<<<<<<<<<| @<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$alarm_key,$alarm_state,$alarm_name,$alarm_entity
-------------------------------------------------------------------------------------------------------------------------------------
.
			$~ = 'format1';
			write;

			foreach(sort {$a->value cmp $b->value} @$alarms) {
				my $alarm_moref = Vim::get_view(mo_ref => $_);
				my $alarm = $alarm_moref->info;

				if($alarm->enabled) {
					$alarm_key = $alarm_moref->{'mo_ref'}->value;
                                        $alarm_name = $alarm->name;

                                        my $alarm_entity_moref = Vim::get_view(mo_ref => $alarm->entity);
                                        $alarm_entity = $alarm_entity_moref->name;
					eval {
						my $alarmStates = $alarmMgr->GetAlarmState(entity => $alarm_entity_moref);
						foreach(@$alarmStates) {
							if($_->overallStatus->val eq "red" || $_->overallStatus->val eq "yellow") {
								$alarm_state = $_->overallStatus->val;
								write;
								last;
							}
						}
					};
					if($@) {
				                print "Error in getAlarmState: " . $@ . "\n";
        				}
				}
			}
		}
	};
	if($@) { 
		print "Error in getAlarm: " . $@ . "\n";
	}		
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
		if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed' && @$licenses eq 1) {
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
