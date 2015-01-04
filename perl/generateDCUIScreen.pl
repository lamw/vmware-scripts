#!/usr/bin/perl
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2010/09/how-to-add-splash-of-color-to-esxi-dcui.html

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
