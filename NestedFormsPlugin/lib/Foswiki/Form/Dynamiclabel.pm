# See bottom of file for license and copyright information
package Foswiki::Form::Dynamiclabel;

use strict;
use warnings;
use Assert;

use Foswiki::Form::FieldDefinition ();
our @ISA = ('Foswiki::Form::FieldDefinition');

sub isEditable {
    return 0;
}

sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    ASSERT( !$value ) if DEBUG;
    my $_format =
      $this->SUPER::renderForDisplay( $format, $this->SUPER::getDefaultValue(),
        $attrs );

    return $_format;
}

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    ASSERT( !$value ) if DEBUG;
    my $renderedValue =
      $topicObject->renderTML(
        $topicObject->expandMacros( $this->SUPER::getDefaultValue() ) );
    return ( '',
            CGI::hidden( -name => $this->{name}, -value => '' )
          . CGI::div( {}, $renderedValue ) );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Paul.W.Harvey@csiro.au Centre for Plant Biodiversity Research
http://www.trin.org.au - http://www.anbg.gov.au/cpbr/ - http://www.csiro.au/pi

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
