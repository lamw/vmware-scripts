#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11767

use strict;
use warnings;
use VMware::VIFPLib;
use VMware::VIExt;
use Net::SMTP;

######################################################
# List of ESX(i) hosts to exclude from backup
######################################################

my @exclude_hosts = (
"himalaya.primp-industries.com",
"reflex.primp-industries.com",
"mauna-loa.primp-industries.com",
"esx4-2.primp-industries.com"
);

#################
# EMAIL CONF
#################

my $SEND_MAIL = "no";
my $EMAIL_HOST = "emailserver";
my $EMAIL_DOMAIN = "localhost.localdomain";
my $EMAIL_TO = 'William Lam <william@primp-industries.com.com>';
my $EMAIL_FROM = 'ghettoVCBg2 <ghettoVCBg2@primp-industries.com.com>';

my %opts = (
	logoutput => {
	type => "=s",
        help => "UPS Log output",
        required => 0,
	default => "/tmp/ghettoHostBackup.log",
        },
	report => {
        type => "=s",
        help => "Backup Report",
        required => 0,
        default => "/tmp/ghettoHostBackupReport.html",
        },
	loglevel => {
        type => "=s",
        help => "Log level [info|debug]",
        required => 0,
        default => "debug",
        },
	rotation => {
        type => "=s",
        help => "Number of backups to keep",
	required => 0,
	default => 5,
	},
	backup_dir => {
        type => "=s",
        help => "Path to backup directory in which ESXi backups will be stored in vMA",
	required => 0,
	default => "/home/vi-admin/ghettoHostBackups",
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);
Opts::parse();
Opts::set_option("passthroughauth", 1);
Opts::validate();

my $log_output = Opts::get_option('logoutput');
my $report = Opts::get_option('report');
my $loglevel = Opts::get_option('loglevel');
my $rotation = Opts::get_option('rotation');
my $backup_dir = Opts::get_option('backup_dir');

my $dir_naming_convention = timeStamp('YMD');
my $report_name = "Ghetto ESXi Host Backup Report";

# log level
my %log_level=(
	"debug"   => 1,
        "info"    => 2,
        "warn"    => 3,
        "error"   => 4,
        "fatal"   => 5,
);

my $LOGLEVEL = $log_level{$loglevel};

my $viuser = vifplib_perl::CreateVIUserInfo();
my $vifplib = vifplib_perl::CreateVIFPLib();
my @hosts = VIFPLib::enumerate_targets();

&createBackupDirectory($backup_dir);
&processHosts();

if($SEND_MAIL eq "yes") {
        &sendMail();
}

########################
# HELPER FUNCTIONS
########################

sub sendMail {
        my $smtp = Net::SMTP->new($EMAIL_HOST ,Hello => $EMAIL_DOMAIN,Timeout => 30,);

        unless($smtp) {
                die "Error: Unable to setup connection with email server: \"" . $EMAIL_HOST . "\"!\n";
        }

        $smtp->mail($EMAIL_FROM);
        $smtp->to($EMAIL_TO);

        $smtp->data();
        $smtp->datasend('From: '.$EMAIL_FROM."\n");
        $smtp->datasend('To: '.$EMAIL_TO."\n");
        $smtp->datasend('Subject: ghettoHostBackupManagement.pl Completed'.timeStamp('MDYHMS')."\n");
        $smtp->datasend("\n");

        open (HANDLE, $report) or die(timeStamp('MDYHMS'), "ERROR: Can not locate log \"$report\" !\n");
        my @lines = <HANDLE>;
        close(HANDLE);
        foreach my $line (@lines) {
                $smtp->datasend($line);
        }

        $smtp->dataend();
        $smtp->quit;

	&removeLog();
}

sub createBackupDirectory {
	my ($dir) = @_;

	`mkdir -p $dir`
}

sub processHosts {
	&startReportCreation();
	foreach my $host (@hosts) {
		if (! grep( /^$host/,@exclude_hosts ) ) {	
			&log("info","Found host: ". "\"$host\"");
			&log("debug", "Main: Login by vi-fastpass to: " . $host);
			eval {
        			VIFPLib::login_by_fastpass($host);
				#validate ESX/ESXi host
			        my $content = Vim::get_service_content();
        			my $host_type = $content->about->apiType;
				my $build = $content->about->build;
				if($host_type eq 'HostAgent' && $content->about->productLineId eq 'embeddedEsx') {
					my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
					my $firmwareSys = Vim::get_view(mo_ref => $host_view->configManager->firmwareSystem);
			
					my $backuphost_dir = "$backup_dir/$host/$host-$dir_naming_convention";
					my $backuphost_filename = "$host.tgz";
					&createBackupDirectory($backuphost_dir);

					&backupHost($firmwareSys,"$backuphost_dir/$backuphost_filename");
					my $filesize = -s "$backuphost_dir/$backuphost_filename";
						
					&checkHostBackupRotation("$backup_dir/$host",$backuphost_dir);

					if($filesize gt 0) {
						print REPORT_OUTPUT "\t<table><tr><td><div id=\"header\" style=\"color:blue\">$backuphost_filename == ".&prettyPrintData($filesize,'B')."</div></td><td><div id=\"content-good\" style=\"color:green\">[ ALL GOOD ]</div></td></tr></table>\n";
					} else {
						print REPORT_OUTPUT "\t<table><tr><td><div id=\"header\" style=\"color:blue\">$host ($build)</div></td><td><div id=\"content-good\" style=\"color:red\">[ FAILED ]</div></td></tr></table>\n";
					}
				} else {
            				&log("info","Host: " . "\"$host\" is not an ESX(i) host and will be ignored");
        			}
				&log("debug", "Main: Disconnect from: ". $host . "\n");
				Util::disconnect();
			}; 
			if($@) {
				&log("info","Error: Unable to login to host: ". "\"$host\"! Ensure host is being managed by vMA!");
			}
		}
	}
	&endReportCreation();

	if($SEND_MAIL eq 'yes') {
		&removeLog();
	}
}

sub backupHost {
	my ($fwsys, $file) = @_;

	my $downloadUrl;
   	eval { 
		$downloadUrl = $fwsys->BackupFirmwareConfiguration(); 
	};
   	if ($@) {
      		&log("info","ESXi backup failed: " . ($@->fault_string));
   	}
   	&log("info","Backing up ESXi conf to $file");
   	if ($downloadUrl =~ m@http.*//\*//?(.*)@) {
      		my $docrootPath = $1;
      		unless (defined($file)) {
         	# strips off all the directory parts of the url
         	($file = $docrootPath) =~ s/.*\///g
      	}
      	VIExt::http_get_file("docroot", $docrootPath, undef, undef, $file);
   	} else {
      		&log("info","Unexpected download URL format: $downloadUrl");
   	}
}

sub removeLog {
	`/bin/rm -f $report`;
}

sub checkHostBackupRotation {
        my ($backup_dir,$dir_naming_convention) = @_;
        my @LIST_BACKUPS = `ls "$backup_dir" 2>&1`;

        &log("debug", "Checking rotation ...");

        chomp(@LIST_BACKUPS);

        foreach my $DIR (reverse(@LIST_BACKUPS)) {
                $DIR =~ s/\///g;
                #################################
                # VMware bug in vCLI vifs --dir
                # SR 1291801391
                #################################
                # tmp fix
                if($DIR !~ /^Parent Directory/) {
                        my $NEW;
                        my ($mv_dir,$rm_dir);
                        my $TMP_DIR="$backup_dir/$DIR";
                        my ($BAD, $TMP) = split('--', $TMP_DIR);

                        if(!defined($TMP)) {
                                $TMP = $TMP_DIR;
                        }

                        if($TMP eq $dir_naming_convention) {
                                $NEW=$TMP."--1";
                                $mv_dir = `mv "$TMP_DIR" "$NEW" 2>&1`;
                        } elsif($TMP >= $rotation) {
                                my $path = $TMP_DIR;
				$rm_dir = `rm -rf "$path" 2>&1`;
                                &log("info", "Purging ". $path ." due to rotation max");
                        } else {
                                my ($BASE, $BAD) = split('--',$TMP_DIR);
                                $NEW = $BASE."--".($TMP+1);
                                $mv_dir = `mv "$TMP_DIR" "$NEW" 2>&1`;
                        }
                }
        }
}

sub timeStamp {
        my ($date_format) = @_;
        my %dttime = ();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        my $my_time;
        my $time_string;

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
                $time_string = $my_time." -- ";
        } elsif ($date_format eq 'YMD') {
                $my_time = "$dttime{year}-$dttime{mon}-$dttime{mday}";
                $time_string = $my_time;
        }
        return $time_string;
}

#http://www.bryantmcgill.com/Shazam_Perl_Module/Subroutines/utils_convert_bytes_to_optimal_unit.html
sub prettyPrintData{
        my($bytes,$type) = @_;

        return '' if ($bytes eq '' || $type eq '');
        return 0 if ($bytes <= 0);

        my($size);

        if($type eq 'B') {
                $size = $bytes . ' Bytes' if ($bytes < 1024);
                $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'M') {
                $bytes = $bytes * (1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }

        elsif($type eq 'G') {
                $bytes = $bytes * (1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'MHZ') {
                $size = sprintf("%.2f", ($bytes/1e-06)) . ' MHz' if ($bytes >= 1e-06 && $bytes < 0.001);
                $size = sprintf("%.2f", ($bytes*0.001)) . ' GHz' if ($bytes >= 0.001);
        }

        return $size;
}

sub giveMeDate {
        my ($date_format) = @_;
        my %dttime = ();
        my $my_time;
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

sub startReportCreation {
        print "Generating $report_name \"$report\" ...\n\n";
        open(REPORT_OUTPUT, ">$report");

        my $date = " --- Date: ".giveMeDate('MDYHMS');
        my $html_start = <<HTML_START;
<html>
<title>$report_name</title>
<META NAME="AUTHOR" CONTENT="William Lam">

<style type="text/css">
        body {
                font-family:arial,helvetica,sans-serif;
                font-size:12px;
                background-color:#E0D8E0;
        }
        #title {
                margin:0px auto;
                padding:10px;
                font-size:16px;
                font-weight: bold;
                font-color: black;
                text-align: center;
        }
        #wrapper {
                margin:0px auto;
                border:1px solid #bbb;
                padding:10px;
                width: 80%;
        }
        #header {
                font-size:14px;
                font-weight: bold;
                border:1px solid #bbb;
                height:10px;
                padding:10px;
        }
        #content-good {
                font-size:13px;
                font-weight: bold;
                border:1px solid #bbb;
                height:10px;
                padding:10px;
        }
        #content {
                font-weight: bold;
                margin-top:1px;
        }
        #content-main {
                margin-left:10px;
                width:666px;
                height:10px;
        }
</style>

<div id="title">$report_name $date</div>

HTML_START

        print REPORT_OUTPUT $html_start;
}

sub endReportCreation {
        my $html_end = <<HTML_END;
</html>
HTML_END
        print REPORT_OUTPUT $html_end;
        close(REPORT_OUTPUT);
}

sub log {
        my($logLevel, $message) = @_;

        open(LOG,">>$log_output");
        if ($LOGLEVEL <= $log_level{$logLevel}) {
                print LOG "\t" . timeStamp('MDYHMS'), " ",$logLevel, ": ", $message,"\n";
        }
        close(LOG);
}
