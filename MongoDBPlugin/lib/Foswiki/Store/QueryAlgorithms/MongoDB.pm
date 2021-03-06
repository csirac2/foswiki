# See the bottom of this file for license and copyright information

=begin TML

---+ package Foswiki::Store::QueryAlgorithms::MongoDB

Default brute-force query algorithm

Has some basic optimisation: it hoists regular expressions out of the
query to use with grep, so we can narrow down the set of topics that we
have to evaluate the query on.

Not sure exactly where the breakpoint is between the
costs of hoisting and the advantages of hoisting. Benchmarks suggest
that it's around 6 topics, though this may vary depending on disk
speed and memory size. It also depends on the complexity of the query.

=cut

package Foswiki::Store::QueryAlgorithms::MongoDB;
use strict;

#@ISA = ( 'Foswiki::Query::QueryAlgorithms' ); # interface

use Foswiki::Search::Node ();

#use Foswiki::Meta         ();
use Foswiki::Plugins::MongoDBPlugin       ();
use Foswiki::Plugins::MongoDBPlugin::Meta ();
use Foswiki::Search::InfoCache;

# See Foswiki::Query::QueryAlgorithms.pm for details
sub query {
    my ( $query, $web, $inputTopicSet, $session, $options ) = @_;

#SMELL: initialise the mongoDB hack. needed if the mondoPlugin is not enabled, but the algo is selected :/
    Foswiki::Plugins::MongoDBPlugin::getMongoDB();

    require Foswiki::Query::HoistREs;
    my $hoistedREs = Foswiki::Query::HoistREs::collatedHoist($query);
    
    if ((!defined($options->{topic})) and 
        ($hoistedREs->{name})) {
            #set the 'includetopic' matcher..
            #dammit, i have to de-regex it? thats mad.
    }

    my $topicSet = $inputTopicSet;
    if ( !defined($topicSet) ) {

        #then we start with the whole web?
        #TODO: i'm sure that is a flawed assumption
        my $webObject = Foswiki::Meta->new( $session, $web );
        $topicSet =
          Foswiki::Search::InfoCache::getTopicListIterator( $webObject,
            $options );
    }

    #TODO: howto ask iterator for list length?
    #TODO: once the inputTopicSet isa ResultSet we might have an idea
    #    if ( scalar(@$topics) > 6 ) {
    if ( defined($hoistedREs->{text}) ) {
        my $searchOptions = {
            type                => 'regex',
            casesensitive       => 1,
            files_without_match => 1,
        };
        my @filter = @{$hoistedREs->{text}};
        my $searchQuery =
          new Foswiki::Search::Node( $query->toString(), \@filter,
            $searchOptions );
         $topicSet->reset();
        $topicSet =
          $session->{store}->searchInWebMetaData(
              $searchQuery, $web, $topicSet, $session, $searchOptions );
    }
    else {

#TODO: clearly _this_ can be re-written as a FilterIterator, and if we are able to use the sorting hints (ie DB Store) can propogate all the way to FORMAT

        print STDERR "WARNING: couldn't hoistREs on " . $query->toString();
    }

    #print STDERR "))))".$query->toString()."((((\n";
    use Data::Dumper;
    print STDERR "--------Query::MongoDB \n" . Dumper($query) . "\n";
    my $resultTopicSet =
      new Foswiki::Search::InfoCache( $Foswiki::Plugins::SESSION, $web );
    local $/;
    while ( $topicSet->hasNext() ) {
        my $topic = $topicSet->next();

#my $meta = Foswiki::Meta->new( $session, $web, $topic );
#GRIN: curiously quick hack to use the MongoDB topics rather than from disk - should have no positive effect on performance :)
#TODO: will make a Store backend later.
        my $meta =
          Foswiki::Plugins::MongoDBPlugin::Meta->new( $session, $web, $topic );

        # this 'lazy load' will become useful when @$topics becomes
        # an infoCache

        $meta->reload() unless ( $meta->getLoadedRev() );
        next unless ( $meta->getLoadedRev() );
        print STDERR "Processing $topic\n"
          if ( Foswiki::Query::Node::MONITOR_EVAL() );
        my $match = $query->evaluate( tom => $meta, data => $meta );
        if ($match) {
            $resultTopicSet->addTopic($meta);
        }
    }

    return $resultTopicSet;
}

# The getField function is here to allow for Store specific optimisations
# such as direct database lookups.
sub getField {
    my ( $this, $node, $data, $field ) = @_;

    my $result;
    if ( UNIVERSAL::isa( $data, 'Foswiki::Meta' ) ) {

        # The object being indexed is a Foswiki::Meta object, so
        # we have to use a different approach to treating it
        # as an associative array. The first thing to do is to
        # apply our "alias" shortcuts.
        my $realField = $field;
        if ( $Foswiki::Query::Node::aliases{$field} ) {
            $realField = $Foswiki::Query::Node::aliases{$field};
        }
        if ( $realField =~ s/^META:// ) {
            if ( $Foswiki::Query::Node::isArrayType{$realField} ) {

                # Array type, have to use find
                my @e = $data->find($realField);
                $result = \@e;
            }
            else {
                $result = $data->get($realField);
            }
        }
        elsif ( $realField eq 'name' ) {

            # Special accessor to compensate for lack of a topic
            # name anywhere in the saved fields of meta
            return $data->topic();
        }
        elsif ( $realField eq 'text' ) {

            # Special accessor to compensate for lack of the topic text
            # name anywhere in the saved fields of meta
            return $data->text();
        }
        elsif ( $realField eq 'web' ) {

            # Special accessor to compensate for lack of a web
            # name anywhere in the saved fields of meta
            return $data->web();
        }
        else {

            # The field name isn't an alias, check to see if it's
            # the form name
            my $form = $data->get('FORM');
            if ( $form && $field eq $form->{name} ) {

                # SHORTCUT;it's the form name, so give me the fields
                # as if the 'field' keyword had been used.
                # TODO: This is where multiple form support needs to reside.
                # Return the array of FIELD for further indexing.
                my @e = $data->find('FIELD');
                return \@e;
            }
            else {

                # SHORTCUT; not a predefined name; assume it's a field
                # 'name' instead.
                # SMELL: Needs to error out if there are multiple forms -
                # or perhaps have a heuristic that gives access to the
                # uniquely named field.
                $result = $data->get( 'FIELD', $field );
                $result = $result->{value} if $result;
            }
        }
    }
    elsif ( ref($data) eq 'ARRAY' ) {

        # Array objects are returned during evaluation, e.g. when
        # a subset of an array is matched for further processing.

        # Indexing an array object. The index will be one of:
        # 1. An integer, which is an implicit index='x' query
        # 2. A name, which is an implicit name='x' query
        if ( $field =~ /^\d+$/ ) {

            # Integer index
            $result = $data->[$field];
        }
        else {

            # String index
            my @res;

            # Get all array entries that match the field
            foreach my $f (@$data) {
                my $val = getField( undef, $node, $f, $field );
                push( @res, $val ) if defined($val);
            }
            if ( scalar(@res) ) {
                $result = \@res;
            }
            else {

                # The field name wasn't explicitly seen in any of the records.
                # Try again, this time matching 'name' and returning 'value'
                foreach my $f (@$data) {
                    next unless ref($f) eq 'HASH';
                    if (   $f->{name}
                        && $f->{name} eq $field
                        && defined $f->{value} )
                    {
                        push( @res, $f->{value} );
                    }
                }
                if ( scalar(@res) ) {
                    $result = \@res;
                }
            }
        }
    }
    elsif ( ref($data) eq 'HASH' ) {

        # A hash object may be returned when a sub-object of a Foswiki::Meta
        # object has been matched.
        $result = $data->{ $node->{params}[0] };
    }
    else {
        $result = $node->{params}[0];
    }
    return $result;
}

# Get a referenced topic
# See Foswiki::Store::QueryAlgorithms.pm for details
sub getRefTopic {
    my ( $this, $relativeTo, $w, $t ) = @_;
    return Foswiki::Meta->load( $relativeTo->session, $w, $t );
}

1;
__END__
This copyright information applies to the MongoDBPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright 2010 - SvenDowideit@fosiki.com
#
# MongoDBPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.
