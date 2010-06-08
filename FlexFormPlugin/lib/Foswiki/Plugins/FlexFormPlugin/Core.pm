# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2010 Michael Daum http://michaeldaumconsulting.com
#
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

package Foswiki::Plugins::FlexFormPlugin::Core;

use strict;
use Foswiki::Func ();    # The plugins API
use Foswiki::Form ();
use Foswiki::Plugins ();

our $baseWeb;
our $baseTopic;
our %topicObjs;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "- FlexFormPlugin - $_[0]\n" if DEBUG;
}

##############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;
  %topicObjs = ();
}

##############################################################################
sub finish {
  undef %topicObjs;
}

##############################################################################
# create a new topic object, reuse already created ones
sub getTopicObject {
  my ($session, $web, $topic) = @_;

  $web ||= '';
  $topic ||= '';
  
  $web =~ s/\//\./go;
  my $key = $web.'.'.$topic;
  my $topicObj = $topicObjs{$key};
  
  unless ($topicObj) {
    ($topicObj, undef) = Foswiki::Func::readTopic($web, $topic);
    $topicObjs{$key} = $topicObj;
  }

  return $topicObj;
}

##############################################################################
sub handleRENDERFORDISPLAY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleRENDERFORDISPLAY($theTopic, $theWeb)");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $theFields = $params->{field} || $params->{fields};
  my $theForm = $params->{form};
  my $theFormat = $params->{format};
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || '';
  my $theValueSep = $params->{valueseparator} || ', ';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theMap = $params->{map} || '';
  my $theLabelFormat = $params->{labelformat} || '';

  # get defaults from template
  if (!defined($theFormat) && !defined($theHeader) && !defined($theFooter)) {
    my $templates = $session->templates;
    $templates->readTemplate('formtables');
    $theHeader = $templates->expandTemplate('FORM:display:header');
    $theFooter = $templates->expandTemplate('FORM:display:footer');
    $theFormat = $templates->expandTemplate('FORM:display:row');
  }

  $theHeader ||= '';
  $theFooter ||= '';
  $theFormat ||= '';

  # make it compatible
  $theHeader =~ s/%A_TITLE%/\$title/g;
  $theFormat =~ s/%A_TITLE%/\$title/g;
  $theFormat =~ s/%A_VALUE%/\$value/g;
  $theFooter =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_VALUE%/\$value/g;

  my $thisWeb = $theWeb;
  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = getTopicObject($session, $thisWeb, $thisTopic); 

  $theForm = $topicObj->getFormName unless defined $theForm;
  return '' unless $theForm;

  my $theFormWeb = $thisWeb;
  ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($theFormWeb, $theForm);

  my $form = new Foswiki::Form($session, $theFormWeb, $theForm);
  return '' unless $form;
  my $formTitle;
  if ($form->can('getPath')) {
    $formTitle = $form->getPath;
  } else {
    $formTitle = $form->{web}.'.'.$form->{topic};
  }
  $formTitle =~ s/\//./g; # normalize web names

  $theHeader =~ s/\$title/$formTitle/g;
  $theFooter =~ s/\$title/$formTitle/g;

  my $fieldTitles;
  foreach my $map (split(/\s*,\s*/, $theMap)) {
    if ($map =~ /^(.*)=(.*)$/) {
      $fieldTitles->{$1} = $2;
    }
  }

  my @selectedFields = ();
  if ($theFields) {
    foreach my $fieldName (split(/\s*,\s*/, $theFields)) {
      my $field = $form->getField($fieldName);
      writeDebug("WARNING: no field for '$fieldName' in $theFormWeb.$theForm") unless $field;
      push @selectedFields, $field if $field;
    }
  } else {
    @selectedFields = @{$form->getFields()};
  }

  my @result = ();
  foreach my $field (@selectedFields) { 
    next unless $field;

    my $fieldName = $field->{name};
    my $fieldType = $field->{type};
    my $fieldSize = $field->{size};
    my $fieldAttrs = $field->{attributes};
    my $fieldDescription = $field->{tooltip};
    my $fieldTitle = $field->{title};
    my $fieldDefiningTopic = $field->{definingTopic};

    my $fieldAllowedValues = '';
    if ($field->can('getOptions')) {
      my $options = $field->getOptions();
      if ($options) {
        $fieldAllowedValues = join($theValueSep, @$options);
      }
    }

    my $fieldDefault = '';
    if ($field->can('getDefault')) {
      $fieldDefault = $field->getDefault() || '';
    }

    $fieldSize = $params->{$fieldName.'_size'} if defined $params->{$fieldName.'_size'};
    $fieldAttrs = $params->{$fieldName.'_attributes'} if defined $params->{$fieldName.'_attributes'};
    $fieldDescription = $params->{$fieldName.'_tooltip'} if defined $params->{$fieldName.'_tooltip'};
    $fieldDescription = $params->{$fieldName.'_description'} if defined $params->{$fieldName.'_description'};
    $fieldTitle = $params->{$fieldName.'_title'} if defined $params->{$fieldName.'_title'}; # see also map
    $fieldAllowedValues = $params->{$fieldName.'_values'} if defined $params->{$fieldName.'_values'};
    $fieldDefault = $params->{$fieldName.'_default'} if defined $params->{$fieldName.'_default'};

    # temporarily remap field to another type
    my $fieldClone;
    if (defined $params->{$fieldName.'_type'}) {
      $fieldType = $params->{$fieldName.'_type'};
      $fieldClone = $form->createField(
	$fieldType,
	name          => $fieldName,
	title         => $fieldTitle,
	size          => $fieldSize,
	value         => $fieldAllowedValues,
	tooltip       => $fieldDescription,
	attributes    => $fieldAttrs,
	definingTopic => $fieldDefiningTopic,
	web           => $topicObj->web,
	topic         => $topicObj->topic,
      );
      $field = $fieldClone;
    } 

    #writeDebug("reading fieldName=$fieldName");

    my $metaField = $topicObj->get('FIELD', $fieldName);
    unless ($metaField) {
      # Not a valid field name, maybe it's a title.
      $fieldName = Foswiki::Form::fieldTitle2FieldName($fieldName);
      $metaField = $topicObj->get('FIELD', $fieldName );
    }
    my $fieldValue = $metaField?$metaField->{value}:$fieldDefault;

    next if $theInclude && $fieldName !~ /^($theInclude)$/;
    next if $theExclude && $fieldName =~ /^($theExclude)$/;
    next if $theIncludeAttr && $fieldAttrs !~ /^($theIncludeAttr)$/;
    next if $theExcludeAttr && $fieldAttrs =~ /^($theExcludeAttr)$/;

    my $line = $theFormat;
    unless ($fieldName) { # label
      next unless $theLabelFormat;
      $line = $theLabelFormat;
    }

    # some must be expanded before renderForDisplay
    $line =~ s/\$values\b/$fieldAllowedValues/g;

    $line = $field->renderForDisplay($line, $fieldValue, {
      bar=>'|', # SMELL: keep bars
      newline=>'$n', # SMELL: keep newlines
    }); # SMELL what about the attrs param in Foswiki::Form
        # SMELL wtf is this attr anyway

    $fieldTitle = $fieldTitles->{$fieldName} if $fieldTitles && $fieldTitles->{$fieldName};

    $line =~ s/\$name\b/$fieldName/g;
    $line =~ s/\$type\b/$fieldType/g;
    $line =~ s/\$size\b/$fieldSize/g;
    $line =~ s/\$attrs\b/$fieldAttrs/g;
    $line =~ s/\$value\b/$fieldValue/g;
    $line =~ s/\$default\b/$fieldDefault/g;
    $line =~ s/\$tooltip\b/$fieldDescription/g;
    $line =~ s/\$description\b/$fieldDescription/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$form\b/$formTitle/g;
    $line =~ s/\$nop//g;
    $line =~ s/\$n/\n/g;
    $line =~ s/\$percnt/%/g;
    $line =~ s/\$dollar/\$/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;
  }

  return $theHeader.join($theSep, @result).$theFooter;
}

##############################################################################
sub handleRENDERFOREDIT {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleRENDERFOREDIT($theTopic, $theWeb)");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $theFields = $params->{field} || $params->{fields};
  my $theForm = $params->{form};
  my $theValue = $params->{value};
  my $theFormat = $params->{format};
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || '';
  my $theValueSep = $params->{valueseparator} || ', ';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theMap = $params->{map} || '';
  my $theMandatory = $params->{mandatory};
  my $theHidden = $params->{hidden};
  my $theHiddenFormat = $params->{hiddenformat};

  if (!defined($theFormat) && !defined($theHeader) && !defined($theFooter)) {
    $theHeader = '<div class=\'foswikiFormSteps\'>';
    $theFormat = '<div class=\'foswikiFormStep\'><h3>$title:$mandatory</h3>$edit</div>';
    $theFooter ='</div>';
  } else {
    $theFormat = '$edit$mandatory' unless defined $theFormat;
    $theHeader = '' unless defined $theHeader;
    $theFooter = '' unless defined $theFooter;
  }
  $theMandatory = " <span class='foswikiAlert'>**</span> " unless defined $theMandatory;
  $theHiddenFormat = '$edit' unless defined $theHiddenFormat;
  
  my $thisWeb = $theWeb;

  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = getTopicObject($session, $thisWeb, $thisTopic); 

  # give beforeEditHandlers a chance
  # SMELL: watch out for the fix of Item1965; it must be applied here as well; for now
  # we mimic the core behaviour here
  my $text = $topicObj->text();
  $session->{plugins}->dispatch('beforeEditHandler', $text, $thisTopic, $thisWeb, $topicObj);
  $topicObj->text($text);

  $theForm = $topicObj->getFormName unless defined $theForm;
  return '' unless $theForm;

  my $theFormWeb = $thisWeb;
  ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($theFormWeb, $theForm);

  writeDebug("theForm=$theForm"); 

  my $form = new Foswiki::Form($session, $theFormWeb, $theForm);
  return '' unless $form;

  my $fieldTitles;
  foreach my $map (split(/\s*,\s*/, $theMap)) {
    if ($map =~ /^(.*)=(.*)$/) {
      $fieldTitles->{$1} = $2;
    }
  }

  my @selectedFields = ();
  if ($theFields) {
    foreach my $fieldName (split(/\s*,\s*/, $theFields)) {
      my $field = $form->getField($fieldName);
      writeDebug("WARNING: no field for '$fieldName' in $theFormWeb.$theForm") unless $field;
      push @selectedFields, $field if $field;
    }
  } else {
    @selectedFields = @{$form->getFields()};
  }

  #writeDebug("theFields=$theFields");
  #writeDebug("selectedFields=@selectedFields");

  my @result = ();
  foreach my $field (@selectedFields) { 
    next unless $field;

    my $fieldExtra = '';
    my $fieldEdit = '';

    my $fieldName = $field->{name};
    my $fieldType = $field->{type};
    my $fieldSize = $field->{size};
    my $fieldAttrs = $field->{attributes};
    my $fieldDescription = $field->{tooltip};
    my $fieldTitle = $field->{title};
    my $fieldDefiningTopic = $field->{definingTopic};

    # get the list of all allowed values
    my $fieldAllowedValues = '';
    if ($field->can('getOptions')) {
      my $options = $field->getOptions();
      if ($options) {
        $fieldAllowedValues = join($theValueSep, @$options);
      }
    }

    # get the default value
    my $fieldDefault = '';
    if ($field->can('getDefault')) {
      $fieldDefault = $field->getDefault() || '';
    }

    $fieldSize = $params->{$fieldName.'_size'} if defined $params->{$fieldName.'_size'};
    $fieldAttrs = $params->{$fieldName.'_attributes'} if defined $params->{$fieldName.'_attributes'};
    $fieldDescription = $params->{$fieldName.'_tooltip'} if defined $params->{$fieldName.'_tooltip'};
    $fieldDescription = $params->{$fieldName.'_description'} if defined $params->{$fieldName.'_description'};
    $fieldTitle = $params->{$fieldName.'_title'} if defined $params->{$fieldName.'_title'}; # see also map
    $fieldAllowedValues = $params->{$fieldName.'_values'} if defined $params->{$fieldName.'_values'};
    $fieldDefault = $params->{$fieldName.'_default'} if defined $params->{$fieldName.'_default'};

    # temporarily remap field to another type
    my $fieldClone;
    if (defined $params->{$fieldName.'_type'}) {
      $fieldType = $params->{$fieldName.'_type'};
      $fieldClone = $form->createField(
	$fieldType,
	name          => $fieldName,
	title         => $fieldTitle,
	size          => $fieldSize,
	value         => $fieldAllowedValues,
	tooltip       => $fieldDescription,
	attributes    => $fieldAttrs,
	definingTopic => $fieldDefiningTopic,
	web           => $topicObj->web,
	topic         => $topicObj->topic,
      );
      $field = $fieldClone;
    } 


    #writeDebug("reading fieldName=$fieldName");

    my $fieldValue;
    if (defined $theValue) {
      $fieldValue = $theValue;
    } else {
      $fieldValue = $params->{$fieldName.'_value'};
    }

    unless (defined $fieldValue) {
      my $query = Foswiki::Func::getCgiQuery();
      $fieldValue = $query->param($fieldName);
    }

    unless (defined $fieldValue) {
      my $metaField = $topicObj->get('FIELD', $fieldName);
      unless ($metaField) {
        # Not a valid field name, maybe it's a title.
        $fieldName = Foswiki::Form::fieldTitle2FieldName($fieldName);
        $metaField = $topicObj->get('FIELD', $fieldName );
      }
      $fieldValue = $metaField->{value} if $metaField;
    }

    $fieldValue = $fieldDefault unless defined $fieldValue;

    next if $theInclude && $fieldName !~ /^($theInclude)$/;
    next if $theExclude && $fieldName =~ /^($theExclude)$/;
    next if $theIncludeAttr && $fieldAttrs !~ /^($theIncludeAttr)$/;
    next if $theExcludeAttr && $fieldAttrs =~ /^($theExcludeAttr)$/;

    $fieldValue = "\0" unless $fieldValue; # prevent dropped value attr in CGI.pm

    $fieldEdit = $session->{plugins}->dispatch(
      'renderFormFieldForEditHandler', $fieldName, $fieldType, $fieldSize,
        $fieldValue, $fieldAttrs, $fieldAllowedValues
    );

    my $isHidden = ($theHidden && $fieldName =~ /^($theHidden)$/)?1:0;
    unless ($fieldEdit) {
      if ($isHidden) {
	# sneak in the value into the topicObj
        my $metaField = $topicObj->get('FIELD', $fieldName);
        $metaField->{value} = $fieldValue if $metaField;
	$fieldEdit = $field->renderHidden($topicObj);
      } else {
	if ($Foswiki::Plugins::VERSION > 2.0) {
	  ($fieldExtra, $fieldEdit) = 
	    $field->renderForEdit($topicObj, $fieldValue);
	} else {
	  # pre-TOM
	  ($fieldExtra, $fieldEdit) = 
	    $field->renderForEdit($thisWeb, $thisTopic, $fieldValue);
	}
      }
    }

    $fieldEdit =~ s/\0//g;
    $fieldValue =~ s/\0//g;

    my $line = $isHidden?$theHiddenFormat:$theFormat;
    $fieldTitle = $fieldTitles->{$fieldName} if $fieldTitles && $fieldTitles->{$fieldName};
    my $fieldMandatory = '';
    $fieldMandatory = $theMandatory if $field->isMandatory();

    $line =~ s/\$mandatory/$fieldMandatory/g;
    $line =~ s/\$edit\b/$fieldEdit/g;
    $line =~ s/\$name\b/$fieldName/g;
    $line =~ s/\$type\b/$fieldType/g;
    $line =~ s/\$size\b/$fieldSize/g;
    $line =~ s/\$attrs\b/$fieldAttrs/g;
    $line =~ s/\$values\b/$fieldAllowedValues/g;
    $line =~ s/\$value\b/$fieldValue/g;
    $line =~ s/\$default\b/$fieldDefault/g;
    $line =~ s/\$tooltip\b/$fieldDescription/g;
    $line =~ s/\$description\b/$fieldDescription/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$extra\b/$fieldExtra/g;
    $line =~ s/\$nop//g;
    $line =~ s/\$n/\n/g;
    $line =~ s/\$percnt/%/g;
    $line =~ s/\$dollar/\$/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;
  }

  return '<noautolink>'.$theHeader.join($theSep, @result).$theFooter.'</noautolink>';
}


1;
