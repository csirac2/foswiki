# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::BibtexFormfieldPlugin::Core

=cut

package Foswiki::Plugins::BibtexFormfieldPlugin::Core;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Assert;
use Error;
use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Foswiki::Form();
use Text::BibTeX();         # library for parsing bibtex files
use Data::Dumper;           # library for debugging
use List::MoreUtils qw(uniq);

# How to debug:
#    print STDERR "MESSAGE: SCRIPT CALLED!!!";
# writeDebug("This debug message goes to working/logs/debug.log");

sub TRACE { 1 }

sub beforeSaveHandler {
    my ( $text, $topic, $web, $topicObject ) = @_;
    my $formData = $topicObject->get('FORM');
    my %newBibtexCodeStringHash;
    my %oldBibtexCodeStringHash;
    my %bibtexFormFieldHash;
    my %finalHash;

    if ( defined $formData and $formData->{name} ) {
        my ( $formWeb, $formTopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $formData->{name} );
        my $formDef = Foswiki::Form->new( $Foswiki::Plugins::SESSION, $formWeb,
            $formTopic );
        my ( $bibtexCodeFieldName, @bibtexFieldNames ) =
          getBibtexFieldNames($formDef);

        my $bibtexCodeString;
        if ($bibtexCodeFieldName) {
            writeDebug("Found bibtexCode field!") if TRACE;

            #~ my $field = $topicObject->get( 'FIELD', $bibtexCodeFieldName );
            #~ ASSERT( exists $field->{value} and $field->{value} ) if DEBUG;
            #~ $bibtexCodeString = $field->{value};
            #~ writeDebug($bibtexCodeString) if TRACE;

            ### parse new bibtexCodeString to Hash
            %newBibtexCodeStringHash =
              parseBibtexCodeStringToHash( $topicObject, $bibtexCodeFieldName );

            ### write bibtex form fields to Hash
            %bibtexFormFieldHash =
              writeBibtexFieldsToHash( $topicObject, @bibtexFieldNames );

            ### parse old bibtexCodeString to Hash if it exists
            my ( $topicObjectOld, $textOld, $bibtexCodeStringOld );
            if ( Foswiki::Func::topicExists( $web, $topic ) ) {
                my ( $topicObjectOld, $textOld ) =
                  Foswiki::Func::readTopic( $web, $topic );
                my $formDataOld = $topicObjectOld->get('FORM');

                my ( $formWebOld, $formTopicOld ) =
                  Foswiki::Func::normalizeWebTopicName( $web,
                    $formDataOld->{name} );
                my $formDefOld =
                  Foswiki::Form->new( $Foswiki::Plugins::SESSION, $formWebOld,
                    $formTopicOld );
                my ( $bibtexCodeFieldNameOld, @bibtexFieldNames ) =
                  getBibtexFieldNames($formDefOld);

                if ($bibtexCodeFieldNameOld) {

             #~ my $bibtexCodeString =
             #~ getBibtexCodeString( $topicObjectOld, $bibtexCodeFieldNameOld );

#~ ASSERT( exists ( $topicObjectOld ) and defined( $topicObjectOld ) ) if DEBUG;
                    %oldBibtexCodeStringHash =
                      parseBibtexCodeStringToHash( $topicObjectOld,
                        $bibtexCodeFieldNameOld );

                    %finalHash = mergeHashes( \%newBibtexCodeStringHash,
                        \%oldBibtexCodeStringHash, \%bibtexFormFieldHash );
                }
            }
            else {
                ### merge hashes
                %oldBibtexCodeStringHash =
                  ();    # dummy hash because old topic didn't exist
                %finalHash = mergeHashes( \%newBibtexCodeStringHash,
                    \%oldBibtexCodeStringHash, \%bibtexFormFieldHash );
            }

            my $finalBibtexStringCode =
              createNewBibtexCodeString( \%finalHash );

            $topicObject =
              resetBibtexFormFields( $finalBibtexStringCode, $topicObject,
                @bibtexFieldNames );

            $topicObject =
              parseBibtexCodeToFields( $finalBibtexStringCode, $topicObject,
                @bibtexFieldNames );

            $topicObject->putKeyed(
                'FIELD',
                {
                    name  => $bibtexCodeFieldName,
                    value => $finalBibtexStringCode
                }
            );
        }
    }
    else {
        writeDebug("No bibtex fields detected in '$web.$topic'");
    }

    return;
}

sub mergeHashes {
    my ( $newBibtexCodeStringHash, $oldBibtexCodeStringHash,
        $bibtexFormFieldHash )
      = @_;
    my $mergedHash;
    my $field;
    my $fieldValue;
    my @allHashKeys;

    @allHashKeys = (
        ( keys %$newBibtexCodeStringHash ),
        ( keys %$oldBibtexCodeStringHash ),
        ( keys %$bibtexFormFieldHash )
    );

    @allHashKeys = uniq(@allHashKeys);

    $mergedHash = $newBibtexCodeStringHash;

    foreach my $key (@allHashKeys) {
        if ( $key ne 'key' and $key ne 'type' )
        {    # we don't want to edit the bibtex fields 'key' or 'type'
            if
              ( # if value exists and is the same in both bibtexCodeStrings overwrite with value of fields
                exists( $mergedHash->{$key} )
                and exists( $oldBibtexCodeStringHash->{$key} )
                and ( $mergedHash->{$key} eq $oldBibtexCodeStringHash->{$key} )
              )
            {

#~ if( exists($bibtexFormFieldHash->{$key}) and not ($bibtexFormFieldHash->{$key} eq "") ){
                if ( exists( $bibtexFormFieldHash->{$key} ) ) {
                    $mergedHash->{$key} = $bibtexFormFieldHash->{$key};
                }
                elsif ( not exists( $bibtexFormFieldHash->{$key} ) ) {
                    delete $mergedHash
                      ->{$key};    # remove field if the form field is empty
                }
            }

            if
              ( # if value does *not* exists in both bibtexCodeStrings and exists the field-value overwrite add value of fields
                not exists( $mergedHash->{$key} )
                and not exists( $oldBibtexCodeStringHash->{$key} )
                and exists( $bibtexFormFieldHash->{$key} )
              )
            {
                $mergedHash->{$key} = $bibtexFormFieldHash->{$key};
            }
        }
    }

    return %$mergedHash;
}

sub createNewBibtexCodeString {
    my ($mergedHash) = @_;
    my $bibtexCodeString;
    my $field;
    my $fieldValue;
    my $key;
    my $currentKey;
    writeDebug("Creating bibtexCodeString from bibtex atom fields!") if TRACE;

    my $entryType = $mergedHash->{'type'};
    my $entryKey  = $mergedHash->{'key'};

    $bibtexCodeString = "\@$entryType\{$entryKey,\n";
    foreach $key ( keys %$mergedHash ) {
        if ( ( $key ne 'type' ) and ( $key ne 'key' ) ) {
            $currentKey = $key;
            $fieldValue = $mergedHash->{$key};
            $bibtexCodeString =
              "$bibtexCodeString	$currentKey = \{$fieldValue\},\n";
        }
    }
    $bibtexCodeString = "$bibtexCodeString \}";

    writeDebug("Value of \$bibtexCodeString:\n $bibtexCodeString");

    return $bibtexCodeString;
}

sub parseBibtexCodeStringToHash {
    my ( $topicObject, $bibtexCodeFieldName ) = @_;

    #~ ASSERT( exists $topicObject and defined( $topicObject ) ) if DEBUG;
    #~ ASSERT( exists $bibtexCodeFieldName and $bibtexCodeFieldName ) if DEBUG;
    #~ ASSERT( exists $bibtexFieldNames and $bibtexFieldNames ) if DEBUG;
    my $bibtexCodeString =
      getBibtexCodeString( $topicObject, $bibtexCodeFieldName );

    #~ ASSERT( exists $bibtexCodeString and $bibtexCodeString ) if DEBUG;

    my $entry = Text::BibTeX::Entry->new();
    my @fieldList;
    my $fieldValue;
    my $fieldName;
    my $type;
    my $key;
    my %parsedFields = ();

    writeDebug("In detection loop, got code string: '$bibtexCodeString'")
      if TRACE;

    $entry->parse_s($bibtexCodeString);

    if ( $entry->parse_ok ) {
        writeDebug("bibtexCodeString parsed correctly.") if TRACE;
    }
    else {
        writeDebug("bibtexCodeString parsed *incorrectly*.") if TRACE;
    }
    @fieldList = $entry->fieldlist;
    foreach my $fieldName (@fieldList) {

        #~ writeDebug( "Processing bibtex field '$fieldName' -> "
        #~ . $entry->get($fieldName) ) if TRACE;

        #~ writeDebug("Parsed field in bibtexForm!!!") if TRACE;
        my $fieldValue = $entry->get($fieldName);

        # DOI fields often contain an annoying DOI: prefix on the
        # value. Perhaps there's a good reason for this (Eg. non-DOI
        # things going into DOI fields), so double-check that RHS
        # of this junk looks roughly as if it could be a DOI.
        if ( lc($fieldName) eq 'doi' ) {
            if ( $fieldValue =~ /^doi:\s*(\d+\..*)$/i ) {
                $fieldValue = $1;
            }
        }

        $parsedFields{$fieldName} = $fieldValue;
        writeDebug(
            "The hash field '$fieldName' of '\%parsedFields' has the value: "
              . $parsedFields{$fieldName} )
          if TRACE;
    }
    $parsedFields{'type'} = $entry->type;
    $parsedFields{'key'}  = $entry->key;

    return %parsedFields;
}

sub getBibtexCodeString {
    my ( $topicObject, $bibtexCodeFieldName ) = @_;

    my $field = $topicObject->get( 'FIELD', $bibtexCodeFieldName );
    my $bibtexCodeString = $field->{value};

    return $bibtexCodeString;
}

sub writeBibtexFieldsToHash {
    my ( $topicObject, @bibtexFieldNames ) = @_;
    my $bibtexCodeString;
    my $field;
    my $fieldValue;
    my %parsedFields = ();

    foreach my $fieldName (@bibtexFieldNames) {
        $field = $topicObject->get( 'FIELD', $fieldName );
        $fieldValue = $field->{value};

        if ($fieldValue) {
            $parsedFields{$fieldName} = $fieldValue;
            writeDebug(
"In *writeBibtexFieldsToHash* : The field $fieldName in \%parsedFields has the value: "
                  . $parsedFields{$fieldName} )
              if TRACE;
        }
    }

    return %parsedFields;
}

sub createBibtexCodeString {
    my ( $topicObject, @bibtexFieldNames ) = @_;
    my $bibtexCodeString;
    my $field;
    my $fieldValue;
    writeDebug("Creating bibtexCodeString from bibtex atom fields!") if TRACE;

    $field            = $topicObject->get( 'FIELD', "key" );
    $fieldValue       = $field->{value};
    $bibtexCodeString = "\@ARTICLE{$fieldValue,\n";
    foreach my $fieldName (@bibtexFieldNames) {
        $field = $topicObject->get( 'FIELD', $fieldName );
        $fieldValue = $field->{value};
        if ( $fieldValue =~ "" ) {
            $bibtexCodeString = "$bibtexCodeString  $fieldName=$fieldValue,\n";
        }
    }
    $bibtexCodeString = "$bibtexCodeString}";

  #    writeDebug("Created bibtexCodeString from bibtex atom fields!") if TRACE;
  #    writeDebug("bibtexCodeString:\n$bibtexCodeString") if TRACE;
    return $bibtexCodeString;
}

sub resetBibtexFormFields {
    my ( $bibtexCodeString, $topicObject, @bibtexFieldNames ) = @_;

    foreach my $fieldName (@bibtexFieldNames) {
        $topicObject->putKeyed( 'FIELD', { name => $fieldName, value => "" } );
    }
    return $topicObject;
}

sub parseBibtexCodeToFields {
    my ( $bibtexCodeString, $topicObject, @bibtexFieldNames ) = @_;
    my $entry = Text::BibTeX::Entry->new();
    my @fieldList;
    my $fieldValue;
    my $fieldName;
    my $type;
    my $key;

    writeDebug("In detection loop, got code string: '$bibtexCodeString'")
      if TRACE;

    $entry->parse_s($bibtexCodeString);
    @fieldList = $entry->fieldlist;
    foreach my $fieldName (@fieldList) {

        #~ writeDebug( "Processing bibtex field '$fieldName' -> "
        #~ . $entry->get($fieldName) )
        #~ if TRACE;

        if ( grep { $_ eq $fieldName } @bibtexFieldNames ) {

            #~ writeDebug("Parsed field in bibtexForm!!!") if TRACE;
            my $fieldValue = $entry->get($fieldName);

            # DOI fields often contain an annoying DOI: prefix on the
            # value. Perhaps there's a good reason for this (Eg. non-DOI
            # things going into DOI fields), so double-check that RHS
            # of this junk looks roughly as if it could be a DOI.
            if ( lc($fieldName) eq 'doi' ) {
                if ( $fieldValue =~ /^doi:\s*(\d+\..*)$/i ) {
                    $fieldValue = $1;
                }
            }

            #~ writeDebug("Putting '$fieldName': '$fieldValue'") if TRACE;
            $topicObject->putKeyed( 'FIELD',
                { name => $fieldName, value => $fieldValue } );
        }
    }

    return $topicObject;
}

sub getBibtexFieldNames {
    my ($formDef) = @_;
    my ( $bibtexCodeFieldName, @bibtexFieldNames );

    if ($formDef) {
        ASSERT( $formDef->can('getFields') ) if DEBUG;
        ASSERT( ref( $formDef->getFields ) eq 'ARRAY' ) if DEBUG;
        ASSERT( scalar( @{ $formDef->getFields } ) ) if DEBUG;
        ASSERT( scalar( @{ $formDef->getFields } ) ) if DEBUG;
        my $fields = $formDef->getFields();

        if ( $fields and ref($fields) eq 'ARRAY' and scalar( @{$fields} ) )
        {    # form definition found, if not the formfields aren't indexed
            writeDebug("Got form field definitions!") if TRACE;
            foreach my $fieldDef ( @{ $formDef->getFields() } ) {
                writeDebug("Start 1") if TRACE;
                if ( $fieldDef->{type} and $fieldDef->{name} ) {
                    writeDebug(
                        "Start 2: $fieldDef->{type} is $fieldDef->{name}")
                      if TRACE;
                    if ( $fieldDef->{type} =~ /^bibtex\+code\b/ ) {
                        writeDebug(
"In bibtexCode IF-clause, got type $fieldDef->{type} in $fieldDef->{name}"
                        ) if TRACE;
                        $bibtexCodeFieldName = $fieldDef->{name};
                    }
                    elsif ( $fieldDef->{type} =~ /^bibtex\b/ ) {
                        writeDebug(
"In bibtex IF-clause, got type $fieldDef->{type} in $fieldDef->{name}"
                        ) if TRACE;
                        push( @bibtexFieldNames, $fieldDef->{name} );
                    }
                }
            }
        }
    }

    return ( $bibtexCodeFieldName, @bibtexFieldNames );
}

sub writeDebug {
    my ($message) = @_;

    Foswiki::Func::writeDebug( 'BibtexFormfieldsPlugin: ' . $message );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011-2011 Foswiki Contributors. Foswiki Contributors
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
