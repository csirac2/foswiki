# See bottom of file for license and copyright information
use strict;
use warnings;

package PreferencesPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Unit::Request;
use Unit::Response;
use Foswiki;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $Foswiki::cfg{Plugins}{PreferencesPlugin}{Enabled} = 1;
}

sub test_edit_simple {
    my $this  = shift;
    my $query = new Unit::Request( { prefsaction => ['edit'], } );
    my $text  = <<HERE;
   * Set FLEEGLE = floon
%EDITPREFERENCES%
HERE
    my $twiki = new Foswiki( undef, $query );
    $Foswiki::Plugins::SESSION = $twiki;
    my $result =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web}, undef );
    $this->assert(
        $result =~ s/^.*(<form [^<]*name=[\"\']editpreferences[\"\'])/$1/si,
        $result );
    $this->assert( $result =~ s/(<\/form>).*$/$1/ );
    my $viewUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'viewauth' );
    $this->assert_html_equals( <<HTML, $result );
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <span style="font-weight:bold;" class="foswikiAlert">FLEEGLE = SHELTER\0070</span>
 <input type="submit" name="prefsaction" value="Save new settings" accesskey="s" class="foswikiSubmit" />
 &nbsp;
 <input type="submit" name="prefsaction" value="Cancel" accesskey="c" class="foswikiButtonCancel" />
</form>
HTML
    $twiki->finish();
}

# Item4816
sub test_edit_multiple_with_comments {
    my $this  = shift;
    my $query = new Unit::Request( { prefsaction => ['edit'], } );
    my $text  = <<HERE;
<!-- Comment should be outside form -->
Normal text outside form
%EDITPREFERENCES%
   * Set FLEEGLE = floon
   * Set FLEEGLE2 = floontoo
<!-- Form ends before this
   * Set HIDDENSETTING = hidden
-->
HERE
    my $twiki = new Foswiki( undef, $query );
    $Foswiki::Plugins::SESSION = $twiki;
    my $result =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web}, undef );
    my $viewUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'viewauth' );
    $this->assert_html_equals( <<HTML, $result );
<!-- Comment should be outside form -->
Normal text outside form
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <input type="submit" name="prefsaction" value="Save new settings" accesskey="s" class="foswikiSubmit" />
 &nbsp;
 <input type="submit" name="prefsaction" value="Cancel" accesskey="c" class="foswikiButtonCancel" />
   * Set <span style="font-weight:bold;" class="foswikiAlert">FLEEGLE = SHELTER\0070</span>
   * Set <span style="font-weight:bold;" class="foswikiAlert">FLEEGLE2 = SHELTER\0071</span></form>
<!-- Form ends before this
   * Set HIDDENSETTING = hidden
-->
HTML
    $twiki->finish();
}

sub test_save {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            prefsaction => ['save'],
            FLEEGLE     => ['flurb'],
        }
    );
    my $input = <<HERE;
   * Set FLEEGLE = floon
%EDITPREFERENCES%
HERE
    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );
    $query->method('POST');

    my $twiki = new Foswiki( undef, $query );
    $Foswiki::Plugins::SESSION = $twiki;

    # This will attempt to redirect, so must capture
    my ( $result, $ecode ) = $this->capture(
        sub {
            $twiki->{response}->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
            $Foswiki::engine->finalize( $twiki->{response}, $twiki->{request} );
        }
    );
    $this->assert( $result =~ /Status: 302/ );
    my $viewUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    $this->assert_matches( qr/^Location: $viewUrl\r$/m, $result );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_str_equals( <<HERE, $text );
   * Set FLEEGLE = flurb
%EDITPREFERENCES%
HERE

    $twiki->finish();
}

sub test_view {
    my $this = shift;
    my $text = <<HERE;
   * Set FLEEGLE = floon
%EDITPREFERENCES%
HERE
    my $twiki = new Foswiki();
    $Foswiki::Plugins::SESSION = $twiki;
    my $result =
      Foswiki::Func::expandCommonVariables( $text, $this->{test_topic},
        $this->{test_web}, undef );
    $this->assert(
        $result =~ s/^.*(<form [^<]*name=[\"\']editpreferences[\"\'])/$1/si,
        $result );
    $this->assert( $result =~ s/(<\/form>).*$/$1/ );
    my $viewUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'viewauth' );
    $this->assert_html_equals( <<HTML, $result );
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <input type="hidden" name="prefsaction" value="edit"  />
 <input type="submit" name="edit" value="Edit Preferences" class="foswikiButton" />
</form>
HTML
    $twiki->finish();
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
