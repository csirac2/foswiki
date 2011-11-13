# Copyright (C) 2004 Florian Weimer
package RobustnessTests;

use strict;
use utf8;
use warnings;
use warnings qw( FATAL utf8 );
use Scalar::Util ();
use Error qw( :try );

use Assert; # for TAINT

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );
require 5.008;

use utf8;
use Foswiki;
use Foswiki::Sandbox;
use Foswiki::Time;
BEGIN { if ( $Foswiki::cfg{UseLocale} ) { require locale; import locale (); } }

my $slash;

# Unicode strings
use utf8;
# The second word in the $unicode[0] consists only of two _graphemes_
# (logical characters as humans know them) both built from single _base
# characters_ but then decorated w/additional _modifier_ characters to add
# vowel marks and other signs.
#
# vim, scite, and probably other monospace/grid-based editors have problems
# with this and may show all five unicode characters separately.
# It's the word "hindi" in devanagari script. http://translate.google.com/#auto|hi|hindi
#
# - "use utf8;" needs to be at the top of this .pm.
# - Your editor/terminal needs to be editing in utf8.
# - You might also want ttf-devanagari-fonts or ttf-indic-fonts-core
# - First word german 'übermaß' to make the failure mode more easy to follow
my @unicode = (
    'übermaß_हिंदी', # "excess" in german and 'Hindi' in hindi
    'मानक', # 'standard' in hindi
    '奶酪', # 'cheese' in Chinese
    'חזיר', # 'pork' in Hebrew
    );

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new(@args);

    $this->{test_web}   = 'Temporary' . $class . 'Test$unicode[2]Web';
    $this->{test_topic} = 'Test$unicode[3]Topic' . $class;
    die "Robustness tests must be run with -T" unless Scalar::Util::tainted($Assert::DIRTY);

    return $this;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{session} = Foswiki->new();
    $slash = ( $^O eq 'MSWin32' ) ? '\\' : '/';
    Foswiki::Sandbox::_assessPipeSupport();

    return;
}

sub tear_down {
    my $this = shift;

    # NOTE: this test pokes globals in the sandbox, so we have to be extra
    # careful about restoring state.
    Foswiki::Sandbox::_assessPipeSupport();
    $this->{session}->finish();
    $this->SUPER::tear_down();

    return;
}

sub test_untaintUnchecked {
    my $this = shift;

    foreach my $f ('', 'abc', @unicode) {
	my $h = TAINT($f);
	$this->assert(!UNTAINTED($h));
	$this->assert(defined $h);
	my $g = Foswiki::Sandbox::untaintUnchecked($h);
	$this->assert_str_equals( $f, $g );
	$this->assert(UNTAINTED($g));
    }
}

sub test_validateAttachmentName {
    my $this = shift;

    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("abc") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("./abc") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("abc/.") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("/abc") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("//abc") );

    $this->assert_str_equals( "",
        Foswiki::Sandbox::validateAttachmentName("c/..") );

    $this->assert_null( Foswiki::Sandbox::validateAttachmentName("../a") );

    $this->assert_null( Foswiki::Sandbox::validateAttachmentName("/a/../..") );
    $this->assert_str_equals( "a",
        Foswiki::Sandbox::validateAttachmentName("//a/b/c/../..") );
    $this->assert_str_equals( "..a",
        Foswiki::Sandbox::validateAttachmentName("..a/") );
    $this->assert_str_equals( "a/..b",
        Foswiki::Sandbox::validateAttachmentName("a/..b") );

    foreach my $f (@unicode) {
	$this->assert_str_equals( $f,
				  Foswiki::Sandbox::validateAttachmentName($f) );
    }
}

=begin TML
 Item11185: This is how things were before we began Operation Unicode:

$regex{filenameInvalidCharRegex} = qr/[^$regex{mixedAlphaNum}\. _-]/o;

 Then devised, using the notes above (and subsequently abandoned for NameFilter):

$regex{filenameInvalidCharRegex} = qr/[-%'";!\+=<>&{\(\)}\x00-\x1f\x7f-\x9f]/o;

Now for full unicodification, attachment name filtering has gone, so we have to make
sure a valid unicode name survives the cut intact.

=cut

sub test_sanitizeAttachmentName {
    my $this = shift;

    # Check that leading paths are stripped
    $this->assert_str_equals( "abc", (Foswiki::Sandbox::sanitizeAttachmentName("abc"))[0] );
    $this->assert_str_equals( "abc", (Foswiki::Sandbox::sanitizeAttachmentName("./abc"))[0] );
    $this->assert_str_equals( "abc", (Foswiki::Sandbox::sanitizeAttachmentName("\\abc"))[0] );
    $this->assert_str_equals( "abc", (Foswiki::Sandbox::sanitizeAttachmentName("//abc"))[0] );
    $this->assert_str_equals( "abc", (Foswiki::Sandbox::sanitizeAttachmentName("\\\\abc"))[0] );
    $this->assert_str_equals( $unicode[0], (Foswiki::Sandbox::sanitizeAttachmentName($unicode[0]))[0] );
    $this->assert_str_equals( $unicode[0], (Foswiki::Sandbox::sanitizeAttachmentName("./$unicode[0]"))[0] );
    $this->assert_str_equals( $unicode[0], (Foswiki::Sandbox::sanitizeAttachmentName("./".$unicode[0]))[0] );

    # Check that the upload filter is applied.
    $Foswiki::cfg{UploadFilter} = qr(^(
             \.htaccess
         | .*\.(?i)(?:php[0-9s]?(\..*)?
         | [sp]htm[l]?(\..*)?
         | pl
         | py
         | cgi ))$)x;
    $this->assert_str_equals( ".htaccess.txt", (Foswiki::Sandbox::sanitizeAttachmentName(".htaccess"))[0] );
    for my $i (qw(php shtm phtml pl py cgi PHP SHTM PHTML PL PY CGI)) {
        my $j = "bog.$i";
        my $y = "$j.txt";
        $this->assert_str_equals( $y, (Foswiki::Sandbox::sanitizeAttachmentName($j))[0] );
    }
    for my $i (qw(php phtm shtml PHP PHTM SHTML)) {
        my $j = "bog.$i.s";
        my $y = "$j.txt";
        $this->assert_str_equals( $y, (Foswiki::Sandbox::sanitizeAttachmentName($j))[0] );
    }

    foreach my $f (@unicode) {
	$this->assert( utf8::is_utf8($f),
		       'Our attachment name string doesn\'t have utf8 flag set' );

	my ($sanitized, $orig) = Foswiki::Func::sanitizeAttachmentName($f);

	$this->assert_str_equals( $f, $orig );
	$this->assert_str_equals( $f, $sanitized );
    }

    return;
}

sub test_buildCommandLine {
    my $this = shift;
    $this->assert_deep_equals( [ "a", "b", "c" ],
        [ Foswiki::Sandbox::_buildCommandLine( "a b c", () ) ] );
    $this->assert_deep_equals( [ "a", "b", "c" ],
        [ Foswiki::Sandbox::_buildCommandLine( " a  b  c ", () ) ] );
    $this->assert_deep_equals(
        [ 1, 2, 3 ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  %B%  %C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );
    $this->assert_deep_equals(

#unfortuanatly, buildCommandLine cleans up paths using File::Spec, which thus uses \\ on some win32's (strawberry for eg)
        [ 1, "./-..", "a${slash}b" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A|U%  %B|F%  %C|F% ",
                ( A => 1, B => "-..", C => "a/b" )
            )
        ]
    );
    $this->assert_deep_equals(
        [ 1, "2:3" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  %B%:%C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );
    $this->assert_deep_equals(
        [ 1, "-n2:3" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  -n%B%:%C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );
    $this->assert_deep_equals(
        [ 1, "-r2:HEAD", 3 ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  -r%B%:HEAD %C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );

#unfortuanatly, buildCommandLine cleans up paths using File::Spec, which thus uses \\ on some win32's (strawberry for eg)
    $this->assert_deep_equals(
        [ "a", "b", "${slash}c" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A|F%  ", ( A => [ "a", "b", "/c" ] )
            )
        ]
    );

    $this->assert_deep_equals(
        [ "1", "2.3", "4", 'str-.+_ing', "-09AZaz.+_" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A|N% %B|S% %C|S%",
                ( A => [ 1, 2.3, 4 ], B => 'str-.+_ing', C => "-09AZaz.+_" )
            )
        ]
    );

    $this->assert_deep_equals(
        ["2004/11/20 09:57:41"],
        [
            Foswiki::Sandbox::_buildCommandLine(
                "%A|D%",
                A => Foswiki::Time::formatTime( 1100944661, '$rcs', 'gmtime' )
            )
        ]
    );

    my $result;
    $result = eval { Foswiki::Sandbox::_buildCommandLine('%A|%'); 1; };
    $this->assert( !$result );
    $result = eval { Foswiki::Sandbox::_buildCommandLine('%A|X%'); 1; };
    $this->assert( !$result );
    my $caught = 0;
    try { Foswiki::Sandbox::_buildCommandLine( ' %A|N%  ', A => '2/3' ); 1; }
    otherwise {
        $caught += 1;
    };
    $this->assert_num_equals( 1, $caught );

  # SMELL: Item11185 - this was an assert_not_null that implied the following
  # invocation should fail. After re-writing it as suggested by perlcritic/PBP,
  # the invocation actually works fine. PH thinks the old test only accidentally
  # worked before because of Error.pm try/catch propagation-under-test-craziness
    $result = eval {
        Foswiki::Sandbox::_buildCommandLine( ' %A|S%  ', A => '2/3' );
        1;
    };
    $this->assert($result);

    return;
}

sub verify {
    my $this = shift;
    my ( $out, $exit ) =
      Foswiki::Sandbox->sysCommand( 'sh -c %A%', A => 'echo OK; echo BOSS' );
    $this->assert_str_equals( "OK\nBOSS\n", $out );
    $this->assert_equals( 0, $exit );
    ( $out, $exit ) =
      Foswiki::Sandbox->sysCommand( 'sh -c %A%',
        A => 'echo JUNK ON STDERR 1>&2' );
    $this->assert_equals( 0, $exit );
    $this->assert_str_equals( "", $out );
    ( $out, $exit ) = Foswiki::Sandbox->sysCommand(
        'test %A% %B% %C%',
        A => '1',
        B => '-eq',
        C => '2'
    );
    $this->assert_equals( 1, $exit, $exit . ' ' . $out );
    $this->assert_str_equals( "", $out );
    ( $out, $exit ) =
      Foswiki::Sandbox->sysCommand( 'sh -c %A%', A => 'echo urmf; exit 7' );
    $this->assert( $exit != 0 );
    $this->assert_str_equals( "urmf\n", $out );
    ( $out, $exit ) = Foswiki::Sandbox->sysCommand('echo');
    $this->assert_equals( 0, $exit );
    $this->assert_str_equals( `echo`, $out );

    return;
}

sub test_executeRSP {
    my $this = shift;
    return if ( $^O eq 'MSWin32' );
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 1;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 0;
    $this->verify();

    return;
}

sub test_executeESP {
    my $this = shift;
    return if ( $^O eq 'MSWin32' );
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 0;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 1;
    $this->verify();

    return;
}

sub test_executeNSP {
    my $this = shift;
    return if ( $^O eq 'MSWin32' );
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 0;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 0;
    $this->verify();

    return;
}

1;
