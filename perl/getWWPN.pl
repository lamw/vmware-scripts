#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author or contributors may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 4. Consent from original author prior to redistribution

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

##################################################################
# Author: William Lam
# 09/09/2009
# http://communities.vmware.com/docs/DOC-10687
# http://engineering.ucsb.edu/~duonglt/vmware/
##################################################################
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
	my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $_ });
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
