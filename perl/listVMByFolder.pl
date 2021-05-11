#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10059

use strict;
use warnings;

use VMware::VIRuntime;


Opts::parse();
Opts::validate();

Util::connect();

my ($datacenter_views, $vmFolder_view, $indent);

$indent = 0;

$datacenter_views = Vim::find_entity_views(
        view_type => 'Datacenter',
        properties => ["name", "vmFolder"],
);

foreach ( @{$datacenter_views} )
{
        print "Datacenter: " . $_->name . "\n";

        TraverseFolder($_->vmFolder, $indent);

}

sub TraverseFolder
{
        my ($entity_moref, $index) = @_;

        my ($num_entities, $entity_view, $child_view, $i, $mo);

        $index += 4;


        $entity_view = Vim::get_view(
                mo_ref => $entity_moref, properties => ['name', 'childEntity']
        );


        $num_entities = defined($entity_view->childEntity) ? @{$entity_view->childEntity} : 0;
        if ( $num_entities > 0 )
        {

                foreach $mo ( @{$entity_view->childEntity} )
                {
                        $child_view = Vim::get_view(
                                mo_ref => $mo, properties => ['name']
                        );

                        if ( $child_view->isa("VirtualMachine") )
                        {
                                print " " x $index . "Virtual Machine: " . $child_view->name . "\n" ;
                        }

                        if ( $child_view->isa("Folder") )
                        {
                                print " " x $index . "Folder: " . $child_view->name . "\n";
                                $child_view = Vim::get_view(
                                        mo_ref => $mo, properties => ['name', 'childEntity']
                                );

                                TraverseFolder($mo, $index);
                        }

                }
        }

}

Util::disconnect();
