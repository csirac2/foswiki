#!/usr/bin/perl -w

BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;
$build = new Foswiki::Contrib::Build('TWikiWorkbenchAddOn');
$build->build($build->{target});

