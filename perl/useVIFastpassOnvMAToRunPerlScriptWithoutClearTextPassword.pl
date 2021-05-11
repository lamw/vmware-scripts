#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10883

use strict;
use warnings;
use VMware::VIFPLib;

# define custom options for vm and target host
my %opts = (
   'esxlist' => {
      type => "=s",
      help => "List of ESX(i) host to perform operations on",
      required => 1,
   },
);

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::set_option("passthroughauth", 1);
Opts::validate();

my @hosts = ();
my $command_to_execute;
my ($username,$password);
my $esxlist = Opts::get_option('esxlist');
&processConfigurationFile($esxlist);

### PLEASE DO NOT MODIFY PAST THIS LINE ###

my $viuser = vifplib_perl::CreateVIUserInfo();
my $vifplib = vifplib_perl::CreateVIFPLib();

foreach my $server (@hosts) {
        eval { $vifplib->QueryTarget($server, $viuser); };
        if(!$@) {
                $username = $viuser->GetUsername();
                $password = $viuser->GetPassword();
		print "Executing script on \"$server\" ...\n";
	        $command_to_execute = `esxcfg-nas -l --server $server --username $username --password $password`;
        	print $command_to_execute . "\n";
        } else {
		print "Error: " . $@ . "\n";
	}
}

# Subroutine to process the input file
sub processConfigurationFile {
        my ($local_conf) = @_;
        my $CONF_HANDLE;

        open(CONF_HANDLE, "$local_conf") || die "Couldn't open file \"$local_conf\"!\n";
        while (<CONF_HANDLE>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;
                push @hosts,$_;
        }
        close(CONF_HANDLE);
}
