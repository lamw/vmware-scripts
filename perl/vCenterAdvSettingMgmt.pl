#!/usr/bin/perl -w
# Copyright (c) 2009-2012 William Lam All rights reserved.

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

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   operation => {
      type => "=s",
      help => "Operation [list|update",
      required => 1,
   },
   key => {
      type => "=s",
      help => "Name of advanced setting",
      required => 0,
   },
   value => {
      type => "=s",
      help => "Value to change advanced setting",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $key = Opts::get_option('key');
my $value = Opts::get_option('value');

my $sc = Vim::get_service_content();
my $settingMgr = Vim::get_view(mo_ref => $sc->setting);

if($sc->about->productLineId ne "vpx") {
	print "This is only supported on a vCenter Server\n\n";
	Util::disconnect();
	exit 1;
}

if($operation eq "list") {
	my $settings = $settingMgr->setting;
	foreach(sort {$a->key cmp $b->key} @$settings) {
		print $_->key . " = " . $_->value . "\n";
	}
} elsif($operation eq "update") {
	unless($key && $value) {
		print "\"update\" operation requires both \"key\" and \"value\"\n\n";
		Util::disconnect();
	        exit 1;
	}
	print "Updating \"$key\" to \"$value\" ...\n";
	eval {
		my $option = OptionValue->new(key => $key, value => $value);
		$settingMgr->UpdateOptions(changedValue => [$option]);
		print "\tSuccessfully updated advanced setting\n";
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
} else  {
	print "Invalid option\n";
}

Util::disconnect();
