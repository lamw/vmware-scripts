#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-14586

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
