#!/usr/local/bin/perl

use strict;

# I just love those unassailable file-scoped lexicals
my ($TRIVIA) = 'data/trivia.list';
my ($TRIVIA_IDX) = 'data/trivia.idx';

sub find_title_trivia
{
    my ($keywords) = join (' ', @_);
    my ($rec, $pos, $title, $matches, @match);

    open (IDX, $TRIVIA_IDX) || die "find_title: $!";
    # each line in the index file is of the form 
    #     <line number> <title>
    # we're looking for titles that match our query, priveleging
    # exact matches
    while (chomp ($rec = <IDX>)) {
	($pos, $title) = split (/ /, $rec, 2);
	next unless $title =~ /$keywords/i;
	if ($title =~ /^$keywords$/i) {
	    # exact match; we keep it
	    @match = ($title, $pos);
	    last;
	}

	else {
	    # we may have multiple titles that match, so we'll use
	    # the single-pass random selection trick:
	    # first we count how many matches so far...
	    $matches++;

	    # the chance that THIS match is the one we want is 1/$matches,
	    # so we pick a random number and see what happens
	    @match = ($title, $pos) if (rand () < (1 / $matches));
	}
    }

    close (IDX);
    return (@match);
}

sub pick_trivia
{
    my ($title, $pos) = @_;
    my ($line, @this_trivia, $trivia, $triviac);

    open (TRIVIA, $TRIVIA) || die "pick_trivia: $!";

    seek (TRIVIA, $pos, 0);

    # suck up the line with the movie title & year, as well as the blank
    # line after it
    $line = <TRIVIA>;

    while (chomp ($line = <TRIVIA>)) {
	# stop when we reach the next movie
	last if $line =~ /^\#/;

	# the trivias are separated by blank lines...
	push (@this_trivia, $line) unless $line =~ /^\s*$/;
	if (@this_trivia and $line =~ /^\s*$/) {
	    # let's play the single-pass random selection game to 
	    # pick a trivia...
	    $triviac++;
	    $trivia = [@this_trivia] if (rand () < (1 / $triviac));
	    undef (@this_trivia);
	}
    }

    close (TRIVIA);
    return ($title, $trivia);
}
