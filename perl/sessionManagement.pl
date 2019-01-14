#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/12/identifying-idle-vcenter-sessions.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use HTTP::Date;

my %opts = (
        'operation' => {
        type => "=s",
        help => "Operation [list|disconnect|terminateidle]",
        required => 1,
        },
        'sessionkey' => {
        type => "=s",
        help => "Session key to disconnect",
        required => 0,
        },
        'idle_hours' =>{
            type => "=i",
            help => "Select session to terminate if they are idle for N hours. Defaults to 36.",
            required => 0,
        },
        'dry' => {
            type => "",
            help => "Enable dry run. Inspect but skip real actions.",
            required => 0,
        },
);
# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option ('operation');
my $sessionkey = Opts::get_option ('sessionkey');
my $opt_idle_hours = Opts::get_option( 'idle_hours');
my $opt_dry    = Opts::get_option('dry');

my $sc = Vim::get_service_content();
my $sessionMgr = Vim::get_view(mo_ref => $sc->sessionManager);
my $sessionList = eval {$sessionMgr->sessionList || []};
my $currentSessionkey = $sessionMgr->currentSession->key;

print 'Connected to vCenter Server: '. $sessionMgr->{vim}->{service_url}."\n";
print 'Checking #'. scalar @$sessionList . " user sessions.\n";

if($operation eq "list") {
	foreach my $session (@$sessionList) {
		if($session->key eq $currentSessionkey) {
			print "Username           : " . $session->userName . " (CURRENT SESSION)\n";
		} else {
			print "Username           : " . $session->userName . "\n";
		}
		print "Fullname           : " . $session->fullName . "\n";
		print "Login Time         : " . time2str(str2time($session->loginTime)) . "\n";
		print "Last Active Time   : " . time2str(str2time($session->lastActiveTime)) . "\n";
		print "vCenter Ext Session: " . ($session->extensionSession ? "true"  : "false") . "\n"; 
		print "Sessionkey         : " . $session->key . "\n\n";
	}
} elsif($operation eq "disconnect") {
    Opts::assert_usage( defined $sessionkey ,"Operation 'disconnect' expects option '--sessionkey <session>'." );
	print "Disconnecting sessionkey: " . $sessionkey . " ...\n";
	eval {
		unless ($opt_dry) {$sessionMgr->TerminateSession(sessionId => [$sessionkey]);}
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
} elsif ( $operation eq 'terminateidle' ){
    my $max_idletime = abs ($opt_idle_hours || 36);

    my $now = time;
    foreach my $session (@$sessionList) {
        if($session->key eq $currentSessionkey) {
            print "Username: " . $session->userName . " (CURRENT SESSION) SKIP!\n";
            next;
        }

        my $idletime = 	(time - str2time($session->lastActiveTime))/3600;
        if ( $idletime > $max_idletime) {
            print "Terminating user Session ". $session->userName;
            eval {
                unless ($opt_dry) {$sessionMgr->TerminateSession(sessionId => [$session->key]);}
            };
            if($@) {
                print "Error: " . $@ . "\n";
            }            
        } # if limit reached
    } # foreach session
} else {
	print "Invalid operation!\n";
}


Util::disconnect();
