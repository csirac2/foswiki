# See bottom of file for license and copyright information

package Foswiki::Plugins::TinyMCEPlugin;

use strict;
use warnings;

use Assert;

our $VERSION           = '$Rev$';
our $RELEASE           = '21 May 2010';
our $SHORTDESCRIPTION  = 'Integration of the Tiny MCE WYSIWYG Editor';
our $NO_PREFS_IN_TOPIC = 1;

# Defaults for TINYMCEPLUGIN_INIT and INIT_browser. Defined as our vars to
# allow other extensions to override them.
# PLEASE ENSURE THE PLUGIN TOPIC EXAMPLES ARE KEPT IN SYNCH!
our $defaultINIT = <<'HERE';
mode: "textareas",
editor_selector : "foswikiWysiwygEdit",
save_on_tinymce_forms: true,
cleanup : true,
theme : "advanced",
convert_urls : true,
relative_urls : false,
remove_script_host : false,
dialog_type: "modal",
extended_valid_elements : "li[type]",
setupcontent_callback : FoswikiTiny.setUpContent,
urlconverter_callback : "FoswikiTiny.convertLink",
foswikipuburl_callback : "FoswikiTiny.convertPubURL",
save_callback : "FoswikiTiny.saveCallback",
%IF{"$TINYMCEPLUGIN_DEBUG" then="debug:true,"}%
plugins : "table,searchreplace,autosave,paste,legacyoutput,inlinepopups,fullscreen,foswikibuttons,foswikiimage%IF{"defined TINYMCEPLUGIN_ADDITIONAL_MCEPLUGINS" then=",%TINYMCEPLUGIN_ADDITIONAL_MCEPLUGINS%"}%",
foswiki_secret_id : "%WYSIWYG_SECRET_ID%",
foswiki_vars : { PUBURLPATH : "%PUBURLPATH%", PUBURL : "%PUBURL%", WEB : "%WEB%", TOPIC : "%TOPIC%", ATTACHURL : "%ATTACHURL%", ATTACHURLPATH : "%ATTACHURLPATH%", VIEWSCRIPTURL : "%SCRIPTURL{view}%", SCRIPTSUFFIX: "%SCRIPTSUFFIX%", SCRIPTURL : "%SCRIPTURL%", SYSTEMWEB: "%SYSTEMWEB%" },
theme_advanced_toolbar_align : "left",
foswikibuttons_formats : [
{ name: "Normal", el: "div", style: null },
{ name: "Heading 1", el: "h1", style: null },
{ name: "Heading 2", el: "h2", style: null },
{ name: "Heading 3", el: "h3", style: null },
{ name: "Heading 4", el: "h4", style: null },
{ name: "Heading 5", el: "h5", style: null },
{ name: "Heading 6", el: "h6", style: null },
{ name: "VERBATIM", el: "pre", style: "TMLverbatim" }, 
{ name: "LITERAL", el: "span", style: "WYSIWYG_LITERAL" },
{ name: "Protect on save", el: null, style: "WYSIWYG_PROTECTED" },
{ name: "Protect forever", el: null, style: "WYSIWYG_STICKY" }
],
paste_create_paragraphs : true,
paste_create_linebreaks : false,
paste_convert_middot_lists : true,
paste_convert_headers_to_strong : false,
paste_remove_spans: true,
paste_remove_styles: true,
paste_strip_class_attributes: "all",
theme_advanced_buttons1 : "%IF{"defined TINYMCEPLUGIN_BUTTONS1" then="%TINYMCEPLUGIN_BUTTONS1%" else="foswikiformat,separator,bold,italic,tt,colour,removeformat,separator,bullist,numlist,outdent,indent,blockquote,separator,link,unlink,anchor,separator,undo,redo,separator,search,replace"}%",
theme_advanced_buttons2 : "%IF{"defined TINYMCEPLUGIN_BUTTONS2" then="%TINYMCEPLUGIN_BUTTONS2%" else="tablecontrols,separator,attach,image,charmap,hr,separator,code,hide,fullscreen"}%",
theme_advanced_buttons3 : "%IF{"defined TINYMCEPLUGIN_BUTTONS3" then="%TINYMCEPLUGIN_BUTTONS3%" else=""}%",
theme_advanced_toolbar_location: "top",
theme_advanced_resize_horizontal : false,
theme_advanced_resizing : true,
theme_advanced_path: false,
theme_advanced_statusbar_location : "bottom",
keep_styles : false,
content_css : "%PUBURLPATH%/%SYSTEMWEB%/TinyMCEPlugin/wysiwyg%IF{"$TINYMCEPLUGIN_DEBUG" then="_src"}%.css,%PUBURLPATH%/%SYSTEMWEB%/SkinTemplates/base.css,%FOSWIKI_STYLE_URL%,%FOSWIKI_COLORS_URL%"
HERE
our %defaultINIT_BROWSER = (
    MSIE   => '',
    OPERA  => '',
    GECKO  => 'gecko_spellcheck : true',
    SAFARI => '',
    CHROME => '',
);

use Foswiki::Func ();

my $query;

# Info about browser type
my %browserInfo;

sub initPlugin {
    $query = Foswiki::Func::getCgiQuery();
    return 0 unless $query;
    unless ( $Foswiki::cfg{Plugins}{WysiwygPlugin}{Enabled} ) {
        Foswiki::Func::writeWarning(
"TinyMCEPlugin is enabled but WysiwygPlugin is not. Both must be installed and enabled for TinyMCE."
        );
        return 0;
    }
    unless ( $Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} ) {
        Foswiki::Func::writeWarning(
"TinyMCEPlugin is enabled but JQueryPlugin is not. Both must be installed and enabled for TinyMCE."
        );
        return 0;
    }

    # Identify the browser from the user agent string
    my $ua = $query->user_agent();
    if ($ua) {
        $browserInfo{isMSIE} = $ua =~ /MSIE/;
        $browserInfo{isMSIE5}   = $browserInfo{isMSIE} && ( $ua =~ /MSIE 5/ );
        $browserInfo{isMSIE5_0} = $browserInfo{isMSIE} && ( $ua =~ /MSIE 5.0/ );
        $browserInfo{isMSIE6} = $browserInfo{isMSIE} && $ua =~ /MSIE 6/;
        $browserInfo{isMSIE7} = $browserInfo{isMSIE} && $ua =~ /MSIE 7/;
        $browserInfo{isMSIE8} = $browserInfo{isMSIE} && $ua =~ /MSIE 8/;
        $browserInfo{isGecko}  = $ua =~ /Gecko/;   # Will also be true on Safari
        $browserInfo{isSafari} = $ua =~ /Safari/;  # Will also be true on Chrome
        $browserInfo{isOpera}  = $ua =~ /Opera/;
        $browserInfo{isChrome} = $ua =~ /Chrome/;
        $browserInfo{isMac}    = $ua =~ /Mac/;
        $browserInfo{isNS7}  = $ua =~ /Netscape\/7/;
        $browserInfo{isNS71} = $ua =~ /Netscape\/7.1/;
    }

    return 1;
}

sub _notAvailable {
    for my $c qw(TINYMCEPLUGIN_DISABLE NOWYSIWYG) {
        return "Disabled by * Set $c = "
          . Foswiki::Func::getPreferencesValue($c)
          if Foswiki::Func::getPreferencesFlag($c);
    }

    # Disable TinyMCE if we are on a specialised edit skin
    my $skin = Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_WYSIWYGSKIN');
    return "$skin is active"
      if ( $skin && Foswiki::Func::getSkin() =~ /\b$skin\b/o );

    return "No browser" unless $query;

    return "Disabled by URL parameter" if $query->param('nowysiwyg');

    # Check the client browser to see if it is blacklisted
    my $ua = Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_BAD_BROWSERS')
      || '(?i-xsm:Konqueror)';
    return 'Unsupported browser: ' . $query->user_agent()
      if $ua && $query->user_agent() && $query->user_agent() =~ /$ua/;

    # This should only ever happen on Foswiki 1.0.9 and earlier
    return 'TinyMCEPlugin requires ZonePlugin to be installed and enabled'
      unless (defined &Foswiki::Func::addToZone);

    return 0;
}

sub beforeEditHandler {

    #my ($text, $topic, $web) = @_;

    my $mess = _notAvailable();
    if ($mess) {
        if ( ( $mess !~ /^Disabled/ || DEBUG )
            && defined &Foswiki::Func::setPreferencesValue )
        {
            Foswiki::Func::setPreferencesValue( 'EDITOR_MESSAGE',
                'WYSIWYG could not be started: ' . $mess );
        }
        return;
    }
    if ( defined &Foswiki::Func::setPreferencesValue ) {
        Foswiki::Func::setPreferencesValue( 'EDITOR_HELP', 'TinyMCEQuickHelp' );
    }

    my $init = Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_INIT')
      || $defaultINIT;
    my $extras = '';

    # The order of these conditions is important, because browsers
    # spoof eachother
    if ( $browserInfo{isChrome} ) {
        $extras = 'CHROME';
    }
    elsif ( $browserInfo{isSafari} ) {
        $extras = 'SAFARI';
    }
    elsif ( $browserInfo{isOpera} ) {
        $extras = 'OPERA';
    }
    elsif ( $browserInfo{isGecko} ) {
        $extras = 'GECKO';
    }
    elsif ( $browserInfo{isMSIE} ) {
        $extras = 'MSIE';
    }
    if ($extras) {
        $extras =
          Foswiki::Func::getPreferencesValue( 'TINYMCEPLUGIN_INIT_' . $extras )
          || $defaultINIT_BROWSER{$extras};
        if ( defined $extras ) {
            $init = join( ',', ( split( ',', $init ), split( ',', $extras ) ) );
        }
    }

    require Foswiki::Plugins::WysiwygPlugin;

    $mess = Foswiki::Plugins::WysiwygPlugin::notWysiwygEditable( $_[0] );
    if ($mess) {
        if ( defined &Foswiki::Func::setPreferencesValue ) {
            Foswiki::Func::setPreferencesValue( 'EDITOR_MESSAGE',
                'WYSIWYG could not be started: ' . $mess );
        }
        return;
    }

    my $USE_SRC = '';
    if ( Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_DEBUG') ) {
        $USE_SRC = '_src';
    }

    # Add the Javascript for the editor. When it starts up the editor will
    # use a REST call to the WysiwygPlugin tml2html REST handler to convert
    # the textarea content from TML to HTML.
    my $pluginURL = '%PUBURLPATH%/%SYSTEMWEB%/TinyMCEPlugin';
    my $tmceURL   = $pluginURL . '/tinymce/jscripts/tiny_mce';

    # expand the init string
    my $metainit = Foswiki::Func::expandCommonVariables($init);

    # URL-encode the init string
    $metainit =~ s/([^0-9a-zA-Z-_.:~!*'\/%])/'%'.sprintf('%02x',ord($1))/ge;

    # <meta> tags really do have to be in the head!
    Foswiki::Func::addToHEAD( 'tinyMCE::Meta', <<META );
<meta name="foswiki.TINYMCEPLUGIN_INIT_ENCODED" content="$metainit" />
META

    my $behaving;
    eval {
        require Foswiki::Contrib::BehaviourContrib;
        if ( defined(&Foswiki::Contrib::BehaviourContrib::addHEAD) ) {
            Foswiki::Contrib::BehaviourContrib::addHEAD();
            $behaving = 1;
        }
    };
    unless ($behaving) {
        Foswiki::Func::addToHEAD( 'BEHAVIOURCONTRIB', <<SCRIPT );
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/BehaviourContrib/behaviour.js">
</script>
SCRIPT
    }

    # URL-encode the version number to include in the .js URLs, so that
    # the browser re-fetches the .js when this plugin is upgraded.
    my $encodedVersion = $VERSION;

    # SMELL: This regex (and the one applied to $metainit, above)
    # duplicates Foswiki::urlEncode(), but Foswiki::Func.pm does not
    # expose that function, so plugins may not use it
    $encodedVersion =~
      s/([^0-9a-zA-Z-_.:~!*'\/%])/'%'.sprintf('%02x',ord($1))/ge;

    my $scripts = <<SCRIPT;
<script language="javascript" type="text/javascript" src="$tmceURL/tiny_mce_jquery$USE_SRC.js?v=$encodedVersion"></script>
<script language="javascript" type="text/javascript" src="$pluginURL/foswiki_tiny$USE_SRC.js?v=$encodedVersion"></script>
<script language="javascript" type="text/javascript" src="$pluginURL/foswiki$USE_SRC.js?v=$encodedVersion"></script>
SCRIPT

    Foswiki::Func::addToZone(
        'body', 'tinyMCE', $scripts,
        'tinyMCE::Meta, JQUERYPLUGIN::FOSWIKI' );

    # See %SYSTEMWEB%.IfStatements for a description of this context id.
    Foswiki::Func::getContext()->{textareas_hijacked} = 1;
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
