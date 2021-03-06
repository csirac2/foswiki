# See bottom of file for license and copyright information
package Foswiki::Store::SearchAlgorithms::Native;

use Assert;
use FoswikiNativeSearch ();
use Foswiki::Search::InfoCache ();
use Foswiki::Search::ResultSet ();

=pod

---+ package Foswiki::Store::SearchAlgorithms::Native

Native implementation of the RCS cache search. Requires tools/native_search
to be built and installed.

---++ query($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $string. See RcsFile::searchInWebContent
for details.

Rude and crude, this makes no attempt to handle UTF-8.

SMELL: 'query' and '_webQuery' are duplicated from
Foswiki::Store::SearchAlgorithms::Forking - doesn't seem to be any
sensible way to enable re-use.

=cut

sub query {
    my ( $query, $inputTopicSet, $session, $options ) = @_;

    if (( @{ $query->{tokens} } ) == 0) {
        return new Foswiki::Search::InfoCache($session, '');
    }

    my $webNames = $options->{web}       || '';
    my $recurse = $options->{'recurse'} || '';
    my $isAdmin = $session->{users}->isAdmin( $session->{user} );

    my $searchAllFlag = ( $webNames =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );
    my @webs = Foswiki::Search::InfoCache::_getListOfWebs( $webNames, $recurse, $searchAllFlag );

    my @resultCacheList;
    foreach my $web (@webs) {
        # can't process what ain't thar
        next unless $session->webExists($web);

        my $webObject = Foswiki::Meta->new( $session, $web );
        my $thisWebNoSearchAll = $webObject->getPreference('NOSEARCHALL') || '';

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        next
          if ( $searchAllFlag
            && !$isAdmin
            && ( $thisWebNoSearchAll =~ /on/i || $web =~ /^[\.\_]/ )
            && $web ne $session->{webName} );
        
        my $infoCache = _webQuery($query, $web, $inputTopicSet, $session, $options);
        $infoCache->sortResults( $options );
        push(@resultCacheList, $infoCache);
    }
    my $resultset = new Foswiki::Search::ResultSet(\@resultCacheList, $options->{groupby}, $options->{order}, Foswiki::isTrue( $options->{reverse} ));
    #TODO: $options should become redundant
    $resultset->sortResults( $options );
    return $resultset;
}


#ok, for initial validation, naively call the code with a web.
sub _webQuery {
    my ( $query, $web, $inputTopicSet, $session, $options ) = @_;
    ASSERT( scalar( @{ $query->{tokens} } ) > 0 ) if DEBUG;
#print STDERR "ForkingSEARCH(".join(', ', @{ $query->{tokens} }).")\n";
    # default scope is 'text'
    $options->{'scope'} = 'text'
      unless ( defined( $options->{'scope'} )
        && $options->{'scope'} =~ /^(topic|all)$/ );

    my $topicSet = $inputTopicSet;
    if (!defined($topicSet)) {
        #then we start with the whole web
        #TODO: i'm sure that is a flawed assumption
        my $webObject = Foswiki::Meta->new( $session, $web );
        $topicSet = Foswiki::Search::InfoCache::getTopicListIterator( $webObject, $options );
    }
    ASSERT( UNIVERSAL::isa( $topicSet, 'Foswiki::Iterator' ) ) if DEBUG;

#print STDERR "######## Forking search ($web) tokens ".scalar(@{$query->{tokens}})." : ".join(',', @{$query->{tokens}})."\n";
# AND search - search once for each token, ANDing result together
    foreach my $token ( @{ $query->{tokens} } ) {

        my $tokenCopy = $token;
        
        # flag for AND NOT search
        my $invertSearch = 0;
        $invertSearch = ( $tokenCopy =~ s/^\!//o );

        # scope can be 'topic' (default), 'text' or "all"
        # scope='topic', e.g. Perl search on topic name:
        my %topicMatches;
        unless ( $options->{'scope'} eq 'text' ) {
            my $qtoken = $tokenCopy;

# FIXME I18N
# http://foswiki.org/Tasks/Item1646 this causes us to use/leak huge amounts of memory if called too often
            $qtoken = quotemeta($qtoken) if ( $options->{'type'} ne 'regex' );

            my @topicList;
            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $topic = $topicSet->next();

                if ( $options->{'casesensitive'} ) {

                    # fix for Codev.SearchWithNoPipe
                    #push(@scopeTopicList, $topic) if ( $topic =~ /$qtoken/ );
                    $topicMatches{$topic} = 1 if ( $topic =~ /$qtoken/ );
                }
                else {

                    #push(@scopeTopicList, $topic) if ( $topic =~ /$qtoken/i );
                    $topicMatches{$topic} = 1 if ( $topic =~ /$qtoken/i );
                }
            }
        }

        # scope='text', e.g. grep search on topic text:
        my $textMatches;
        unless ( $options->{'scope'} eq 'topic' ) {
            $textMatches = search(
                $tokenCopy, $web, $topicSet, $session, $options );
        }

        #bring the text matches into the topicMatch hash
        if ($textMatches) {
            @topicMatches{ keys %$textMatches } = values %$textMatches;
        }

        my @scopeTextList = ();
        if ($invertSearch) {
            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $webtopic = $topicSet->next();
                my ($Iweb, $topic) = Foswiki::Func::normalizeWebTopicName($web, $webtopic);

                if ( $topicMatches{$topic} ) {
                } else {
                    push( @scopeTextList, $topic );            
                }
            }
        }
        else {
            #TODO: the sad thing about this is we lose info
            @scopeTextList = keys(%topicMatches);
        }

        # reduced topic list for next token
        $topicSet =
          new Foswiki::Search::InfoCache( $Foswiki::Plugins::SESSION, $web,
            \@scopeTextList );
    }

    return $topicSet;
}

=pod

---++ search($searchString, $web, $topics, $session, $options) -> \%seen

=cut

sub search {
    my ( $searchString, $web, $topics, $session, $options ) = @_;
    my $sDir;

    if (ref($web)) {
        # 1.0.9 and earlier had ($searchString, $topics, $options, $sDir)
        # remap                 ($searchString, $web,    $topics,  $session
        $sDir = $session;
        $options = $topics;
        $topics = $web;
    } else {
        $sDir = "$Foswiki::cfg{DataDir}/$web";
        # Flatten the iterator
        my $it = $topics;
        $topics = [];
        # SMELL: why does the iterator have to be reset? There's nothing
        # in the POD docs to say why, but the unit tests (Fn_SEARCH) fail if
        # you don't reset it.
        $it->reset();
        while ($it->hasNext()) {
            my $wt = $it->next();
            my ($Iweb, $tn) = Foswiki::Func::normalizeWebTopicName(
                $web, $wt);
            push(@$topics, "$sDir/$tn.txt");
        }
    }
    $searchString ||= '';
    if ( !$options->{type} || $options->{type} ne 'regex' ) {

        # Escape non-word chars in search string for plain text search
        $searchString =~ s/(\W)/\\$1/g;
    }
    $searchString =~ s/^(.*)$/\\b$1\\b/go if $options->{'wordboundaries'};
    my @fs;
    push( @fs, '-i' ) unless $options->{casesensitive};
    push( @fs, '-l' ) if $options->{files_without_match};
    push( @fs, $searchString );
    push( @fs, @$topics );
    my $matches = FoswikiNativeSearch::cgrep( \@fs );
    my %seen;

    if ( defined($matches) ) {
        for (@$matches) {

            # Note use of / and \ as dir separators, to support
            # Winblows
            if (/([^\/\\]*)\.txt(:(.*))?$/) {

                # Implicit untaint OK; data from search
                push( @{ $seen{$1} }, $3 );
            }
        }
    }
    return \%seen;
}

1;
__END__
Authors: Crawford Currie http://c-dot.co.uk, Sven Dowideit

Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
module, as follows:
Copyright (C) 2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

