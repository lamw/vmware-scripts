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

# William Lam
# 01/30/2010
# http://communities.vmware.com/docs/DOC-11910
# http://engineering.ucsb.edu/~duonglt/vmware/
# http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   file => {
      type => "=s",
      help => "Message to display on the DCUI",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $key = 'Annotations.WelcomeMessage';
my $file = Opts::get_option('file');

open FILE, "<$file";
my $value = do { local $/; <FILE> };

my $host = Vim::find_entity_view(view_type => 'HostSystem');
my $advOpt = Vim::get_view(mo_ref => $host->configManager->advancedOption);

my $adv_param = OptionValue->new(key => $key, value => $value);

eval {
	print "Updating \"" . $host->name . "\" with advanced parameter configuration: \"$key\" with value:\n$value";
	$advOpt->UpdateOptions(changedValue => [$adv_param]);
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
