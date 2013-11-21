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
# 4. Written Consent from original author prior to redistribution

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

# William Lam
# 01/24/2011
# http://www.virtuallyghetto.com/
# http://communities.vmware.com/docs/DOC-14586

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   operation => {
      type => "=s",
      help => "Operation 'query' or 'update'",
      required => 1,
   },
   input => {
      type => "=s",
      help => "Name of input file",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $input = Opts::get_option('input');
my $operation = Opts::get_option('operation');

my $content = Vim::get_service_content();
my $customFieldMgr = Vim::get_view(mo_ref => $content->customFieldsManager);
my (@customFieldKeys,@keyOrder) = ();
my %hostCustomFields = ();

# Get the field key value from the supplied custom field name
my %field_key;
if ( defined $customFieldMgr->field ) {
	foreach (@{$customFieldMgr->field}) {
        	$field_key{$_->name} = $_->key;
        }
}

open(INPUTFILE, "$input") or die "Failed to open file, '$input'";
while(<INPUTFILE>) {
	chomp;
	s/#.*//; # Remove comments
	s/^\s+//; # Remove opening whitespace
	s/\s+$//;  # Remove closing whitespace
	next unless length;
	
	if($_ !~ m/^vihost/) {
		@customFieldKeys = split(',',$_);
		foreach(@customFieldKeys) {
			if($field_key{$_}) {
				push @keyOrder, $field_key{$_};
			}
		}
		next;
	} else {
		my ($host,$values) = split(';',$_);
		my @customValues = split('@',$values);	
	
		$host =~ s/vihost\=//g;
		my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => {"name" => $host});
		unless ($host_view) {
			print "Unable to find Host: \"$host\"!\n";
			Util::disconnect();
			exit 1;
		}
		print "Updating $host custom fields ...\n";
		for my $i (0 .. $#keyOrder) {
			$customFieldMgr->SetField(entity => $host_view, key => $keyOrder[$i], value => $customValues[$i]);	
		}
	}
}

Util::disconnect();
