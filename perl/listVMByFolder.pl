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

# Original Author: stumpr (http://communities.vmware.com/message/1265766#1265766)
# http://communities.vmware.com/docs/DOC-10059

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
