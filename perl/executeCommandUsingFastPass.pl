#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10730

use strict;
use warnings;
use VMware::VIFPLib;

# define custom options for vm and target host
my %opts = (
   'hostlist' => {
      type => "=s",
      help => "List of ESX(i) host to enable/disable configuration of FT",
      required => 1,
   },
);

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();

my @hosts = ();
my ($username,$password);
my $hostlist = Opts::get_option('hostlist');
&processConfigurationFile($hostlist);

### PLEASE DO NOT MODIFY PAST THIS LINE ###

my $viuser = vifplib_perl::CreateVIUserInfo();
my $vifplib = vifplib_perl::CreateVIFPLib();

foreach my $server (@hosts) {
        eval { $vifplib->QueryTarget($server, $viuser); };
        if(!$@) {
                $username = $viuser->GetUsername();
                $password = $viuser->GetPassword();
        }
	print "Executing viversion.pl on Server: " . $server . "\n";
	my $cmd_result = `/usr/lib/vmware-vcli/apps/general/viversion.pl --server "$server" --username "$username" --password "$password"`;
	print "================ RESULTS ================\n"; 
	print $cmd_result . "\n";
	print "\n";
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
