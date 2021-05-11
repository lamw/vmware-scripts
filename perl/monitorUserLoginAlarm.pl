#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2011/10/how-to-create-vcenter-alarm-to-monitor.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   user => {
      type => "=s",
      help => "Name of the user to alarm on",
      required => 1,
   },
   alarmname => {
      type => "=s",
      help => "Name of the alarm",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $user = Opts::get_option('user');
my $alarmname = Opts::get_option('alarmname');

my $rootFolder = Vim::get_view(mo_ref => Vim::get_service_content()->rootFolder);
my $alarmMgr = Vim::get_view(mo_ref => Vim::get_service_content()->alarmManager);

eval {
        my $eventComparisons = EventAlarmExpressionComparison->new(attributeName => 'userName', operator => 'equals', value => $user);
        my $eventAlarm = EventAlarmExpression->new(objectType => 'HostSystem', eventType => 'UserLoginSessionEvent', status => ManagedEntityStatus->new('red'), comparisons => [$eventComparisons]);
        my $alarmSpec = AlarmSpec->new(name => $alarmname, enabled => 1, description => "Alarm to track " . $user . " login", expression => $eventAlarm);
        $alarmMgr->CreateAlarm(entity => $rootFolder, spec => $alarmSpec);
};
if($@) {
        print "Error: " . $@ . "\n";
}

Util::disconnect();
