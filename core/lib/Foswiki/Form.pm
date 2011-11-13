# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Form

Object representing a single form definition.

Form definitions are mainly used to control rendering of a form for
editing, though there is some application login there that handles
transferring values between edits and saves.

A form definition consists of a Foswiki::Form object, which has a list
of field definitions. Each field definition is an object of a type
derived from Foswiki::Form::FieldDefinition. These objects are responsible
for the actual syntax and semantics of the field type. Form definitions
are parsed from Foswiki tables, and the types are mapped by name to a
class declared in Foswiki::Form::* - for example, the =text= type is mapped
to =Foswiki::Form::Text= and the =checkbox= type to =Foswiki::Form::Checkbox=.

The =Foswiki::Form::FieldDefinition= class declares default behaviours for
types that accept a single value in their definitions. The
=Foswiki::Form::ListFieldDefinition= extends this for types that have lists
of possible values.

=cut

# The bulk of this object is a parser for form definitions. All the
# intelligence is in the individual field types.

package Foswiki::Form;
use strict;
use utf8;
use warnings;
use warnings qw( FATAL utf8 );

use Foswiki::Meta ();
our @ISA = ('Foswiki::Meta');

use Assert;
use Error qw( :try );

use Foswiki::Sandbox                   ();
use Foswiki::Form::FieldDefinition     ();
use Foswiki::Form::ListFieldDefinition ();
use Foswiki::AccessControlException    ();
use Foswiki::OopsException             ();
BEGIN { if ( $Foswiki::cfg{UseLocale} ) { require locale; import locale (); } }

# The following are reserved as URL parameters to scripts and may not be
# used as field names in forms.
my %reservedFieldNames = map { $_ => 1 }
  qw( action breaklock contenttype cover dontnotify editaction
  forcenewrevision formtemplate onlynewtopic onlywikiname
  originalrev skin templatetopic text topic topicparent user );

=begin TML

---++ ClassMethod new ( $session, $web, $topic, \@def )

Looks up a form in the session object or, if it hasn't been read yet,
reads it from the form definition topic on disc.
   * =$web= - default web to recover form from, if =$form= doesn't
     specify a web
   * =$topic= - name of the topic that contains the form definition
   * =\@def= - optional. A reference to a list of field definitions.
     If present, these definitions will be used, rather than any read from
     the form definition topic.

May throw Foswiki::OopsException if the web and form are not valid for use as a
form name, or if \@def is not given and the form does not exist in the
database. May throw Foswiki::AccessControlException if the form schema
in the database is protected against view.

=cut

sub new {
    my ( $class, $session, $web, $form, $def ) = @_;

    my $this = $session->{forms}->{"$web.$form"};
    unless ($this) {

        # A form name has to be a valid topic name after normalisation
        my ( $vweb, $vtopic ) = $session->normalizeWebTopicName( $web, $form );
        $vweb = Foswiki::Sandbox::untaint( $vweb,
            \&Foswiki::Sandbox::validateWebName );
        $vtopic = Foswiki::Sandbox::untaint( $vtopic,
            \&Foswiki::Sandbox::validateTopicName );
        unless ( $vweb && $vtopic ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'invalid_form_name',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ $web, $form ]
            );
        }

        # Got to have either a def or a topic
        unless ( $def || $session->topicExists( $vweb, $vtopic ) ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'no_form_def',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ $web, $form ]
            );
        }

        $this = $class->SUPER::new( $session, $vweb, $vtopic );
        $session->{forms}->{"$web.$form"} = $this;

        unless ( $def || $this->haveAccess('VIEW') ) {
            throw Foswiki::AccessControlException( 'VIEW', $session->{user},
                $web, $form, $Foswiki::Meta::reason );
        }

        if (ref($this) ne 'Foswiki::Form') {
            #recast if we have to - allowing the cache to work its magic
            $this = bless($this, 'Foswiki::Form');
            $session->{forms}->{"$web.$form"} = $this;
        }

        unless ($def) {
            $this->{fields} = $this->_parseFormDefinition();
        }
        elsif ( ref($def) eq 'ARRAY' ) {
            $this->{fields} = $def;
        }
        else {

            # Foswiki::Meta object
            $this->{fields} = $this->_extractPseudoFieldDefs($def);
        }
    }

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    foreach ( @{ $this->{fields} } ) {
        $_->finish();
    }
    undef $this->{fields};
    $this->SUPER::finish();
}

=begin TML

---++ StaticMethod getAvailableForms( $metaObject ) -> @forms

Get a list of the names of forms that are available for use in the
given topic. $metaObject can be a topic or a web.

=cut

sub getAvailableForms {
    my $metaObject = shift;
    if ( defined $metaObject->topic ) {
        $metaObject =
          Foswiki::Meta->new( $metaObject->session, $metaObject->web );
    }
    my $legalForms = $metaObject->getPreference('WEBFORMS') || '';
    $legalForms =~ s/^\s+//;
    $legalForms =~ s/\s+$//;
    my @forms = split( /[,\s]+/, $legalForms );

    # This is where we could %SEARCH for *Form topics
    return @forms;
}

=begin TML

---++ StaticMethod fieldTitle2FieldName($title) -> $name
Chop out all except A-Za-z0-9_. from a field name to create a
valid "name" for storing in meta-data

=cut

sub fieldTitle2FieldName {
    my ($text) = @_;
    return '' unless defined($text);
    $text =~ s/!//g;
    $text =~ s/<nop>//g;             # support <nop> character in title
    $text =~ s/[^A-Za-z0-9_\.]//g;
    return $text;
}

# Get definition from supplied topic text
# Returns array of arrays
#   1st - list fields
#   2nd - name, title, type, size, vals, tooltip, attributes
#   Possible attributes are "M" (mandatory field)
sub _parseFormDefinition {
    my $this = shift;

    my @fields  = ();
    my $inBlock = 0;
    my $text    = $this->text();
    $text = '' unless defined $text;

    $text =~ s/\\\n//g;    # remove trailing '\' and join continuation lines

# | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* | *Attributes:* |
# Tooltip and attributes are optional
    foreach my $line ( split( /\n/, $text ) ) {
        if ( $line =~ /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/ ) {
            $inBlock = 1;
            next;
        }

       # Only insist on first field being present FIXME - use oops page instead?
        if ( $inBlock && $line =~ s/^\s*\|\s*// ) {
            $line =~ s/\\\|/\007/g;    # protect \| from split
            my ( $title, $type, $size, $vals, $tooltip, $attributes ) =
              map { s/\007/|/g; $_ } split( /\s*\|\s*/, $line );

            $title ||= '';

            $type ||= '';
            $type = lc($type);
            $type =~ s/^\s*//go;
            $type =~ s/\s*$//go;
            $type = 'text' if ( !$type );

            $size ||= '';

            $vals ||= '';
            $vals = $this->expandMacros($vals);
            $vals =~ s/<\/?(!|nop|noautolink)\/?>//go;
            $vals =~ s/^\s+//g;
            $vals =~ s/\s+$//g;

            $tooltip ||= '';

            $attributes ||= '';
            $attributes =~ s/\s*//go;
            $attributes = '' if ( !$attributes );

            my $definingTopic = "";
            if ( $title =~ /\[\[(.+)\]\[(.+)\]\]/ ) {

                # use common defining topics with different field titles
                $definingTopic = fieldTitle2FieldName($1);
                $title         = $2;
            }

            my $name = fieldTitle2FieldName($title);

            # Rename fields with reserved names
            if ( $reservedFieldNames{$name} ) {
                $name .= '_';
            }
            my $fieldDef = $this->createField(
                $type,
                name          => $name,
                title         => $title,
                size          => $size,
                value         => $vals,
                tooltip       => $tooltip,
                attributes    => $attributes,
                definingTopic => $definingTopic,
                web           => $this->web(),
                topic         => $this->topic()
            );
            push( @fields, $fieldDef );

            $this->{mandatoryFieldsPresent} ||= $fieldDef->isMandatory();
        }
        else {
            $inBlock = 0;
        }
    }

    return \@fields;
}

# PROTECTED
# Create a field object. Done like this so that this method can be
# overridden by subclasses to extend the range of field types.
sub createField {
    my $this = shift;
    my $type = shift;

    # The untaint is required for the validation *and* the ucfirst, which
    # retaints when use locale is in force
    my $class = Foswiki::Sandbox::untaint(
        $type,
        sub {
            my $class = shift;
            $class =~ /^(\w*)/;    # cut off +buttons etc
            return 'Foswiki::Form::' . ucfirst($1);
        }
    );
    eval 'require ' . $class;
    if ($@) {

        # Type not available; use base type
        require Foswiki::Form::FieldDefinition;
        $class = 'Foswiki::Form::FieldDefinition';
    }
    return $class->new( session => $this->session(), type => $type, @_ );
}

# Generate a link to the given topic, so we can bring up details in a
# separate window.
sub _link {
    my ( $this, $string, $tooltip, $topic ) = @_;

    $string =~ s/[\[\]]//go;

    $topic ||= $string;
    my $defaultToolTip =
      $this->session->i18n->maketext('Details in separate window');
    $tooltip ||= $defaultToolTip;

    ( my $web, $topic ) =
      $this->session->normalizeWebTopicName( $this->{web}, $topic );

    $web =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );

    $topic = Foswiki::Sandbox::untaint( $topic,
        \&Foswiki::Sandbox::validateTopicName );

    my $link;

    if ( $this->session->topicExists( $web, $topic ) ) {
        $link = CGI::a(
            {
                target => $topic,
                title  => $tooltip,
                href => $this->session->getScriptUrl( 0, 'view', $web, $topic ),
                rel  => 'nofollow'
            },
            $string
        );
    }
    else {
        my $that =
          Foswiki::Meta->new( $this->session, $web,
            $topic || $Foswiki::cfg{HomeTopicName} );
        my $expanded = $that->expandMacros($string);
        if ( $tooltip ne $defaultToolTip ) {
            $link = CGI::span( { title => $tooltip }, $expanded );
        }
        else {
            $link = $expanded;
        }
    }

    return $link;
}

sub stringify {
    my $this = shift;
    my $fs   = "| *Name* | *Type* | *Size* | *Attributes* |\n";
    foreach my $fieldDef ( @{ $this->{fields} } ) {
        $fs .= $fieldDef->stringify();
    }
    return $fs;
}

=begin TML

---++ ObjectMethod renderForEdit( $topicObject ) -> $html

   * =$topicObject= the topic being rendered

Render the form fields for entry during an edit session, using data values
from $meta

=cut

sub renderForEdit {
    my ( $this, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    require CGI;
    my $session = $this->session;

    if ( $this->{mandatoryFieldsPresent} ) {
        $session->enterContext('mandatoryfields');
    }
    my $tmpl = $session->templates->readTemplate('form');
    $tmpl = $topicObject->expandMacros($tmpl);

    $tmpl =~ s/%FORMTITLE%/$this->_link( $this->web.'.'.$this->topic )/ge;
    my ( $text, $repeatTitledText, $repeatUntitledText, $afterText ) =
      split( /%REPEAT%/, $tmpl );

    foreach my $fieldDef ( @{ $this->{fields} } ) {

        my $value;
        my $tooltip       = $fieldDef->{tooltip};
        my $definingTopic = $fieldDef->{definingTopic};
        my $title         = $fieldDef->{title};
        my $tmp           = '';
        if ( !$title && !$fieldDef->isEditable() ) {

            # Special handling for untitled labels.
            # SMELL: Assumes that uneditable fields are not multi-valued
            $tmp = $repeatUntitledText;
            $value =
              $topicObject->renderTML(
                $topicObject->expandMacros( $fieldDef->{value} ) );
        }
        else {
            $tmp = $repeatTitledText;

            if ( defined( $fieldDef->{name} ) ) {
                my $field = $topicObject->get( 'FIELD', $fieldDef->{name} );
                $value = $field->{value};
            }
            my $extra = '';    # extras on col 0

            unless ( defined($value) ) {
                my $dv = $fieldDef->getDefaultValue($value);
                if ( defined($dv) ) {
                    $dv    = $topicObject->expandMacros($dv);
                    $value = Foswiki::expandStandardEscapes($dv);    # Item2837
                }
            }

            # Give plugin field types a chance first (but no chance to add to
            # col 0 :-(
            # SMELL: assumes that the field value is a string
            my $output = $session->{plugins}->dispatch(
                'renderFormFieldForEditHandler', $fieldDef->{name},
                $fieldDef->{type},               $fieldDef->{size},
                $value,                          $fieldDef->{attributes},
                $fieldDef->{value}
            );

            if ($output) {
                $value = $output;
            }
            else {
                ( $extra, $value ) =
                  $fieldDef->renderForEdit( $topicObject, $value );
            }

            if ( $fieldDef->isMandatory() ) {
                $extra .= CGI::span( { class => 'foswikiAlert' }, ' *' );
            }

            $tmp =~ s/%ROWTITLE%/
              $this->_link( $title, $tooltip, $definingTopic )/ge;
            $tmp =~ s/%ROWEXTRA%/$extra/g;
        }
        $tmp =~ s/%ROWVALUE%/$value/g;
        $text .= $tmp;
    }

    $text .= $afterText;
    return $text;
}

=begin TML

---++ ObjectMethod renderHidden( $topicObject ) -> $html

Render form fields found in the meta as hidden inputs, so they pass
through edits untouched.

=cut

sub renderHidden {
    my ( $this, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;

    my $text = '';

    foreach my $field ( @{ $this->{fields} } ) {
        $text .= $field->renderHidden($topicObject);
    }

    return $text;
}

=begin TML

---++ ObjectMethod getFieldValuesFromQuery($query, $topicObject) -> ( $seen, \@missing )

Extract new values for form fields from a query.

   * =$query= - the query
   * =$topicObject= - the meta object that is storing the form values

For each field, if there is a value in the query, use it.
Otherwise if there is already entry for the field in the meta, keep it.

Returns the number of fields which had values provided by the query,
and a references to an array of the names of mandatory fields that were
missing from the query.

=cut

sub getFieldValuesFromQuery {
    my ( $this, $query, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    my @missing;
    my $seen = 0;

    # Remove the old defs so we apply the
    # order in the form definition, and not the
    # order in the previous meta object. See Item1982.
    my @old = $topicObject->find('FIELD');
    $topicObject->remove('FIELD');
    foreach my $fieldDef ( @{ $this->{fields} } ) {
        my ( $set, $present ) =
          $fieldDef->populateMetaFromQueryData( $query, $topicObject, \@old );
        if ($present) {
            $seen++;
        }
        if ( !$set && $fieldDef->isMandatory() ) {

            # Remember missing mandatory fields
            push( @missing, $fieldDef->{title} || "unnamed field" );
        }
    }
    return ( $seen, \@missing );
}

=begin TML

---++ ObjectMethod isTextMergeable( $name ) -> $boolean

   * =$name= - name of a form field (value of the =name= attribute)

Returns true if the type of the named field allows it to be text-merged.

If the form does not define the field, it is assumed to be mergeable.

=cut

sub isTextMergeable {
    my ( $this, $name ) = @_;

    my $fieldDef = $this->getField($name);
    if ($fieldDef) {
        return $fieldDef->isTextMergeable();
    }

    # Field not found - assume it is mergeable
    return 1;
}

=begin TML

---++ ObjectMethod getField( $name ) -> $fieldDefinition

   * =$name= - name of a form field (value of the =name= attribute)

Returns a =Foswiki::Form::FieldDefinition=, or undef if the form does not
define the field.

=cut

sub getField {
    my ( $this, $name ) = @_;
    foreach my $fieldDef ( @{ $this->{fields} } ) {
        return $fieldDef if ( $fieldDef->{name} && $fieldDef->{name} eq $name );
    }
    return;
}

=begin TML

---++ ObjectMethod getFields() -> \@fields

Return a list containing references to field name/value pairs.
Each entry in the list has a {name} field and a {value} field. It may
have other fields as well, which caller should ignore. The
returned list should be treated as *read only* (must not be written to).

=cut

sub getFields {
    my $this = shift;
    return $this->{fields};
}

sub renderForDisplay {
    my ( $this, $topicObject ) = @_;

    my $templates = $this->session->templates;
    $templates->readTemplate('formtables');

    my $text = $templates->expandTemplate('FORM:display:header');

    my $rowTemplate = $templates->expandTemplate('FORM:display:row');
    my $hasAllFieldsHidden = 1;
    foreach my $fieldDef ( @{ $this->{fields} } ) {
        my $fm = $topicObject->get( 'FIELD', $fieldDef->{name} );
        next unless $fm;
        my $fa = $fm->{attributes} || '';
        unless ( $fa =~ /H/ ) {
            $hasAllFieldsHidden = 0;
            my $row = $rowTemplate;

            # Legacy; was %A_TITLE% before it was $title
            $row =~ s/%A_TITLE%/\$title/g;
            $row =~ s/%A_VALUE%/\$value/g;    # Legacy
            $text .= $fieldDef->renderForDisplay( $row, $fm->{value} );
        }
    }
    return '' if $hasAllFieldsHidden;
    
    $text .= $templates->expandTemplate('FORM:display:footer');

    # substitute remaining placeholders in footer and header
    $text =~ s/%A_TITLE%/$this->getPath()/ge;

    return $text;
}

# extractPseudoFieldDefs( $meta ) -> $fieldDefs
# Examine the FIELDs in $meta and reverse-engineer a set of field
# definitions that can be used to construct a new "pseudo-form". This
# fake form can be used to support editing of topics that have an attached
# form that has no definition topic.
sub _extractPseudoFieldDefs {
    my ( $this, $meta ) = @_;
    my @fields = $meta->find('FIELD');
    my @fieldDefs;
    require Foswiki::Form::FieldDefinition;
    foreach my $field (@fields) {

        # Fields are name, value, title, but there is no other type
        # information so we have to treat them all as "text" :-(
        my $fieldDef = new Foswiki::Form::FieldDefinition(
            session    => $this->session,
            name       => $field->{name},
            title      => $field->{title} || $field->{name},
            attributes => $field->{attributes} || ''
        );
        push( @fieldDefs, $fieldDef );
    }
    return \@fieldDefs;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
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
