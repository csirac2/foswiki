# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2010 Foswiki Contributors
#
# For licensing info read LICENSE file in the Foswiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html


package Foswiki::Contrib::StringifierContrib;
use strict;
use Foswiki::Contrib::StringifierContrib::Base;
our @ISA = qw( Foswiki::Contrib::StringifierContrib::Base );
use Carp;
use File::MMagic;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use File::stat;

use vars qw($VERSION $RELEASE $magic);

$VERSION = '$Rev: 4426 (2009-07-03) $';
$RELEASE = '1.10';
$magic = File::MMagic->new();

sub stringFor {
  my ($class, $filename, $encoding) = @_;
  return unless -r $filename;
  my $mime = $magic->checktype_filename($filename);

  #print STDERR "filename=$filename, mime=$mime\n";
  my $self = $class->handler_for($filename, $mime)->new();

  return $self->stringForFile($filename);
}

1;
