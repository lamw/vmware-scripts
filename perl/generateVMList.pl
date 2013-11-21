#!/usr/bin/perl -w
# William Lam
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   vm_outputfile => {
      type => "=s",
      help => "Name of the Output VM file",
      required => 1,
   },
   vm_exclusionfile => {
      type => "=s",
      help => "Name of the file with excluded VMs",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my %vmexclusionList = ();
my @vmlist = ();
my $vm_outputfile = Opts::get_option('vm_outputfile');
my $vm_exclusionfile = Opts::get_option('vm_exclusionfile');

processFile($vm_exclusionfile);

if(%vmexclusionList) {
        my $vms = Vim::find_entity_views(view_type => 'VirtualMachine');
        foreach(@$vms) {
                if(!$vmexclusionList{$_->name}) {
                        push @vmlist, $_->name;
                }
        }
        &outputFile(@vmlist);
}

Util::disconnect();

# Subroutine to process the input file
sub processFile {
        my ($conf) = @_;

        open(CONFIG, "$conf") || die "Error: Couldn't open the $conf!";
        while (<CONFIG>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;
                $vmexclusionList{$_} = "no";
        }
        close(CONFIG);
}

sub outputFile {
        my (@list) = @_;

        print "Generating output file \"$vm_outputfile\" ...\n";
        open(LOG,">$vm_outputfile");
        foreach(@list) {
                print LOG $_ . "\n";
        }
        close(LOG);
}
