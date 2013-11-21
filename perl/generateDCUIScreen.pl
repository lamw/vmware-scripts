#!/usr/bin/perl
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

##################################################################
# Author: William Lam
# 09/08/2010
# http://www.virtuallyghetto.com
##################################################################

#example inputfile
#
#bgcolor:yellow
#color:black
#        {esxproduct} {esxversion}
#        =space=
#        Hostname: {hostname}
#        Service Tag: {servicetag}
#        =space=
#bgcolor:dark-grey
#color:white
#        Primp Industries
#        www.virtuallyghetto.com
#        =space=
#color:end

use strict;
use warnings;

my @lines = ();
my $output="welcome";

@ARGV == 1 or
        die("Script requires DCUI variable input file\n");

&processConfigurationFile($ARGV[0]);

open(WELCOME_OUTPUT, ">$output");

foreach(@lines) {
        if($_ =~ m/=space=/) {
                print WELCOME_OUTPUT "\t"x9 . "\n";
        } elsif($_ =~ m/color:/) {
                my ($colortype,$color) = split(':',$_,2);
                if($color ne "end") {
                        print WELCOME_OUTPUT "{" . $colortype . ":" . $color . "}" .  "\t"x9 . "\n";
                } else {
                        print WELCOME_OUTPUT "{/color}" .  "\t"x9 . "\n";
                }
        } else {
                print WELCOME_OUTPUT "\t" . $_ . "\t"x9 . "\n";
        }
}

close(WELCOME_OUTPUT);

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

                push @lines,$_;
        }
        close(CONF_HANDLE);
}
