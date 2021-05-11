#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2013/01/monitoring-vcenter-sso-user-account.html

use strict;
use warnings;
use POSIX qw/mktime/;
use DBI;
use Data::Dumper;
use Net::SMTP;

# vpostgres or mssql
my $DB_CONNECTOR = "vpostgres";

# for mssql
my $MSSQL_DSN_NAME = 'sso';
my $MSSQL_DB_NAME = 'RSA';
my $MSSQL_USENAME = 'RSA_USER';
my $MSSQL_PASSWORD = 'mysuperdupersecurepassword';

# for vpostres
my $SSO_HOSTNAME = 'vcenter51-1.primp-industries.com';
my $SSO_DB_NAME = 'ssodb';
my $SSO_DB_PORT = 5432;
my $SSO_USERNAME = 'ssod';
my $SSO_PASSWORD = 'mysuperdupersecurepassword';

# days to notify before expiration
my $DAYS_TO_NOTIFY_IN_ADVANCE = 8;

# email results
my $SEND_EMAIL = 'yes';
my $EMAIL_HOST = 'mail.primp-industries.com';
my $EMAIL_DOMAIN = 'primp-industries.com';
my @EMAIL_TO = qw(william@primp-industries.com tuan@primp-industries.com);
my $EMAIL_FROM = 'vMA@primp-industries.com';

### DO NOT MODIFY BEYOND HERE ###

my $password_days_expiration_sql = "select max_life_sec from ims_authn_password_policy where notes = \'Password policy for SSO system users\'";
my $sso_users_sql = "select loginuid,change_password_date from ims_principal_data where exuid is null";

my ($password_change_days,$todays_date,$dbh,$rows);
$todays_date = giveMeDate();
my @output = ();
my $has_output = 0;

if($DB_CONNECTOR eq "vpostgres") {
	push @output, "SSO DB: " . $SSO_HOSTNAME . "\n\n";
	print "\nConnecting to SSO DB: " . $SSO_HOSTNAME . "\n";
	$dbh = DBI->connect("DBI:Pg:database=$SSO_DB_NAME;host=$SSO_HOSTNAME;port=$SSO_DB_PORT", $SSO_USERNAME, $SSO_PASSWORD);
} elsif($DB_CONNECTOR eq "mssql") {
	$sso_users_sql = "select loginuid,convert(VARCHAR(19),change_password_date,120) as change_password_date from ims_principal_data where exuid is null";
	push @output, "SSO DSN: " .  $MSSQL_DSN_NAME . "\n\n";
	print "\nConnecting to SSO DSN: " .  $MSSQL_DSN_NAME . "\n";
	my $dsn = "DBI:Sybase:server=$MSSQL_DSN_NAME;database=$MSSQL_DB_NAME";
	$dbh = DBI->connect($dsn, $MSSQL_USENAME, $MSSQL_PASSWORD) || die "Failed to connect\n!";
} else {
	print "Unknown \"DB_CONNECTOR\" specififed!\n";
	exit 1;
}

# query the current password policy
$rows = $dbh->selectall_arrayref($password_days_expiration_sql, { Slice =>{} });
foreach my $row (@$rows) {
	if(defined($row->{'max_life_sec'})) {
		$password_change_days = int($row->{'max_life_sec'}/86400);
		print "SSO Password Change Policy (days): " . $password_change_days . "\n";
	} else {
		print "max_life_sec property is NULL for some reason\n";
		$dbh->disconnect();
		exit 1;
	}
}

print "User accounts expring within $DAYS_TO_NOTIFY_IN_ADVANCE days ...\n\n";

# query all SSO users
$rows = $dbh->selectall_arrayref($sso_users_sql, { Slice =>{} });
foreach my $row (@$rows) {
	if(defined($row->{'change_password_date'}) && $row->{'loginuid'} ne "trustedapp") {
		my $sso_user = $row->{'loginuid'};
		my ($sso_user_last_pass_change_date,$junk) = split(' ',$row->{'change_password_date'});
		my $diff = days_between($sso_user_last_pass_change_date,$todays_date);
		my $daysleft = $password_change_days - $diff;

		if($daysleft <= $DAYS_TO_NOTIFY_IN_ADVANCE) {
			$has_output = 1;
			push @output, $sso_user . " has " . ($daysleft) . " days left\n";
			print $sso_user . " has " . ($daysleft) . " days left\n";
		}
	}
}
print "\n";

$dbh->disconnect();

if($SEND_EMAIL eq "yes" && $has_output eq 1) {
        print "Emailing results ...\n";
        &emailReport();
}

### HELPER METHODS ###

#http://www.perlmonks.org/?node_id=17057
sub days_between {
        my ($start, $end) = @_;
        my ($y1, $m1, $d1) = split ("-", $start);
        my ($y2, $m2, $d2) = split ("-", $end);
        my $diff = mktime(0,0,0, $d2-1, $m2-1, $y2 - 1900) -  mktime(0,0,0, $d1-1, $m1-1, $y1 - 1900);
        return $diff / (60*60*24);
}

sub emailReport {
	my $smtp = Net::SMTP->new($EMAIL_HOST, Hello => $EMAIL_DOMAIN, Timeout => 30,);

        unless($smtp) {
		die "Error: Unable to setup connection with email server: \"" . $EMAIL_HOST . "\"!\n";
        }

	my $boundary = 'frontier';
	$smtp->mail($EMAIL_FROM);
	$smtp->to(@EMAIL_TO);
	$smtp->data();
	$smtp->datasend("From: " . $EMAIL_FROM . "\n");
	$smtp->datasend("Subject: vCenter SSO Users Expiring in " . $DAYS_TO_NOTIFY_IN_ADVANCE . " days\n");
	$smtp->datasend("MIME-Version: 1.0\n");
	$smtp->datasend("Content-type: multipart/mixed;\n\tboundary=\"$boundary\"\n");
	$smtp->datasend("\n");
	$smtp->datasend(@output);
	$smtp->dataend();
	$smtp->quit;
}

sub giveMeDate {
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

        return "$dttime{year}-$dttime{mon}-$dttime{mday}";
}
