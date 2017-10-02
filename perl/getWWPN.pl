#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10687

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use Math::BigInt;

my %opts = (
        list => {
        type => "=s",
        help => "List of ESX(i) hosts",
        required => 1,
        },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $conf = Opts::get_option('list');
my @hosts = ();
my %vmhbas = ();

&processConfigurationFile($conf);

foreach(@hosts) {
	my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $_ }
                                          , properties => [ 'name', 'config']);
	my $hbas = $host_view->config->storageDevice->hostBusAdapter;
	foreach my $hba (@$hbas) {
        	if ($hba->isa("HostFibreChannelHba")) {
                	my $nwwn = (Math::BigInt->new($hba->nodeWorldWideName))->as_hex();
                	my $pwwn = (Math::BigInt->new($hba->portWorldWideName))->as_hex();
                	$nwwn =~ s/^..//;
                	$pwwn =~ s/^..//;
                	$nwwn = join(':', unpack('A2' x 8, $nwwn));
                	$pwwn = join(':', unpack('A2' x 8, $pwwn));
			
                	print $host_view->name . "-" . $hba->device . "\t" . $pwwn . "\n";
        	}
	}

}

Util::disconnect();

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
