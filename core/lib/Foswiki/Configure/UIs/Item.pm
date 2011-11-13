package Foswiki::Configure::UIs::Item;

use strict;
use utf8;
use locale;
use locale;
use warnings;
use warnings qw( FATAL utf8 );

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

=begin TML

---++ ObjectMethod renderHtml($value, $root, ...) -> ($html, \%properties)
   * =$value= - Foswiki::Configure::Value object in the model
   * =$root= - Foswiki::Configure::UIs::Root

Generates the appropriate HTML for getting a presenting the configure the
entry.

Must be implemented by subclasses.

=cut

sub renderHtml {
    Carp::confess 'Subclasses must implement';
}

1;
