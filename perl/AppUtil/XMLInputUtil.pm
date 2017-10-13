#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#

use 5.006001;
use strict;
use warnings;

our $VERSION = '0.1';


##################################################################################
package XMLValidation;

# This subroutine checks if the XML is well formed or not
# Input Parameters:
# ----------------
# filename		: Name of  the input XML file
#
# Output:
# ------
# If the XML is well formed, it returns 1 else 0.

sub validate_format {
   my $valid = 1;

   my ($filename) = @_;   
   if ((length($filename) == 0) || !(-e $filename && -r $filename && -T $filename)) {
      Util::trace(0, "\n'$filename' doesnt exist or is not readable:\n$@\n");
      $valid = 0;
   } else {
      my $parser = XML::LibXML->new ();
      eval {
         $parser->parse_file( $filename );
      };
      if( $@ ) {
         Util::trace(0, "\nERROR in '$filename':\n$@\n");
         $valid = 0;
      }
   }

   return $valid;
}


# This subroutine validates the input XML file  against the schema
# Input Parameters:
# ----------------
# filename		: Name of  the input XML file
# schema		: Name of the schema file (.xsd file)
#
# Output:
# ------
# If the XML is valid, it returns 1 else 0.

sub validate_schema {
   my $valid = 1;

   my ($filename, $schema_filename) = @_;

   if ((length($schema_filename) == 0) || 
       !(-e $schema_filename && -r $schema_filename && -T $schema_filename)) {
      Util::trace(0, "\n'$schema_filename' doesnt exist or is not readable:\n$@\n");
      $valid = 0;
   } else {
      my $xmlschema = XML::LibXML::Schema-> new( location => $schema_filename );
      my $parser=XML::LibXML-> new;
      my $doc=$parser-> parse_file( $filename );
      eval {
         $xmlschema-> validate( $doc );
      };
      if ($@) {
         Util::trace(0, "\nError in '$filename':\n" . $@);
         $valid = 0;
      }
   }

   return $valid;
}

1;