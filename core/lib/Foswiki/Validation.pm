# See bottom of file for license and copyright information
package Foswiki::Validation;

use strict;

use Assert;

use Digest::MD5 ();
use Foswiki ();

=begin TML

---+ package Foswiki::Validation

"Validation" is the process of ensuring that an incoming request came from
a page we generated. Validation keys are injected into all HTML pages
generated by Foswiki, in Foswiki::writeCompletePage. When a request is
received from the browser that requires validation, that request must
be accompanied by the validation key. The functions in this package
support the generation and checking of these validation keys.

When a request requiring validation comes in, Foswiki::UI::checkValidationKey
is called. This compares the key in the request with the set of valid keys
stored in the session. if the comparison fails, the browser is redirected
to the =login= script (even if the user is currently logged in) with the
=action= parameter set to =validate=. This generates a confirmation screen
that the user must accept before the transaction can proceed. When the screen
is confirmed, =login= is invoked again and the original transaction restored
from passthrough.

In the function descriptions below, $cgis is a reference to a CGI::Session
object.

=cut

our $digester = new Digest::MD5();

=begin TML

---++ StaticMethod addValidationKey( $cgis, $form ) -> $form

Add a new validation key to the form. The key will
time out after {LeaseLength}

=cut

sub addValidationKey {
    my ( $cgis, $form ) = @_;
    my $actions = $cgis->param('VALID_ACTIONS');
    $actions ||= {};
    $digester->add( $form, $cgis->id(), rand(time) );
    my $nonce = $digester->b64digest();
    $actions->{$nonce} = time() + $Foswiki::cfg{LeaseLength};
    #print STDERR time.": ADD $nonce ".join('; ', map { "$_=$actions->{$_}" } keys %$actions)."\n";
    $cgis->param( 'VALID_ACTIONS', $actions );
    return $form.CGI::hidden(-name => 'validation_key', -value=>$nonce);
}

=begin TML

---++ StaticMethod isValidNonce( $cgis, $key ) -> $boolean

Check that the given validation key is valid for the session.
Return false if not.

=cut

sub isValidNonce {
    my ( $cgis, $nonce ) = @_;
    my $actions = $cgis->param('VALID_ACTIONS');
    return 0 unless ref($actions) eq 'HASH';
    return $actions->{$nonce};
}

=begin TML

---++ StaticMethod expireValidationKeys($cgis)

Expire any timed-out validation keys for this session

=cut

sub expireValidationKeys {
    my $cgis = shift;
    my $actions = $cgis->param('VALID_ACTIONS');
    if ($actions) {
        my $deaths = 0;
        while (my ($nonce, $time) = each %$actions) {
            if ($time < time()) {
                #print STDERR time.": EXPIRE $nonce $time\n";
                delete $actions->{$nonce};
                $deaths++;
            }
        }
        if ($deaths) {
            $cgis->param('VALID_ACTIONS', $actions);
        }
    }
}

=begin TML

---++ StaticMethod validate($session)

Generate (or check) the "Suspicious request" verification screen for the
given session. This screen is generated when a validation fails, as a
response to a ValidationException.

=cut

sub validate {
    my ( $session ) = @_;
    my $query   = $session->{request};
    my $web     = $session->{webName};
    my $topic   = $session->{topicName};

    my $origurl = $query->param('origurl');
    $query->delete( 'origurl' );

    my $tmpl =
      $session->templates->readTemplate( 'validate', $session->getSkin() );

    if ($query->param('response')) {
        my $url;
        if ($query->param('response') eq 'OK') {
            if ( !$origurl || $origurl eq $query->url() ) {
                $url = $session->getScriptUrl( 0, 'view', $web, $topic );
            }
            else {
                $url = $origurl;
                # SMELL: do we ever need this?
                ASSERT($url !~ /#/) if DEBUG;
                # Unpack params encoded in the origurl and restore them
                # to the query. If they were left in the query string they
                # would be lost when we redirect with passthrough
                if ( $url =~ s/\?(.*)$// ) {
                    foreach my $pair ( split( /[&;]/, $1 ) ) {
                        if ( $pair =~ /(.*?)=(.*)/ ) {
                            $query->param( $1, TAINT($2) );
                        }
                    }
                }
            }

            # Redirect with passthrough (302)
            #print STDERR "CONFIRMED; redirect to POST $url\n";
            $session->redirect( $url, 1 );
        }
        else {
            #print STDERR "REJECTED; redirect to GET view\n";
            # Validation failed; redirect to view (302)
            $url = $session->getScriptUrl( 0, 'view', $web, $topic );
            $session->redirect( $url, 0 );    # no passthrough
        }
    } else {
        #print STDERR "PROMPT VALIDATE\n";
        # prompt for user verification
        $session->{response}->status(401);

        $session->{prefs}->setSessionPreferences(
            ORIGURL => Foswiki::_encode( 'entity', $origurl || '' ),
           );

        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
        $tmpl = $topicObject->expandMacros($tmpl);
        $tmpl = $topicObject->renderTML($tmpl);
        $tmpl =~ s/<nop>//g;
        $session->writeCompletePage($tmpl);
    }
}

1;
__END__
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
