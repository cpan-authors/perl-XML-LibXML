#!/usr/bin/perl

# Regression test for GH #245 (RT #123479):
# XML::LibXML whitespace settings can leak between parsers
#
# The xmlKeepBlanksDefault global was set by LibXML_init_parser but never
# restored in LibXML_cleanup_parser. A parse with no_blanks => 1 would
# permanently flip the global to 0, causing subsequent default parsers
# to silently strip whitespace.

use strict;
use warnings;

use Test::More tests => 13;

use XML::LibXML;

my $xml = qq{<?xml version="1.0" encoding="utf-8"?>\n<foo>\n    <bar/>\n</foo>\n};
my $expected_ws = "\n    \n";

# Baseline: default parser preserves whitespace
{
    my $p = XML::LibXML->new;
    my $doc = $p->parse_string($xml);
    # TEST
    is($doc->textContent, $expected_ws,
       'default parser preserves whitespace (baseline)');
}

# no_blanks parser strips whitespace
{
    my $p = XML::LibXML->new(no_blanks => 1);
    my $doc = $p->parse_string($xml);
    # TEST
    is($doc->textContent, '',
       'no_blanks => 1 strips whitespace');
}

# THE BUG: default parser after no_blanks parse must still preserve whitespace
{
    my $p = XML::LibXML->new;
    my $doc = $p->parse_string($xml);
    # TEST
    is($doc->textContent, $expected_ws,
       'default parser after no_blanks parse still preserves whitespace');
}

# Explicit no_blanks => 0 after no_blanks => 1 parse
{
    # First poison the global with no_blanks => 1
    my $nb = XML::LibXML->new(no_blanks => 1);
    $nb->parse_string($xml);

    my $p = XML::LibXML->new(no_blanks => 0);
    my $doc = $p->parse_string($xml);
    # TEST
    is($doc->textContent, $expected_ws,
       'explicit no_blanks => 0 preserves whitespace after no_blanks => 1 parse');
}

# Interleaved parsers: each respects its own setting
{
    my $nb_parser = XML::LibXML->new(no_blanks => 1);
    my $def_parser = XML::LibXML->new;

    my $d1 = $nb_parser->parse_string($xml);
    # TEST
    is($d1->textContent, '', 'interleaved: no_blanks parser strips');

    my $d2 = $def_parser->parse_string($xml);
    # TEST
    is($d2->textContent, $expected_ws, 'interleaved: default parser preserves');

    my $d3 = $nb_parser->parse_string($xml);
    # TEST
    is($d3->textContent, '', 'interleaved: no_blanks parser still strips');

    my $d4 = $def_parser->parse_string($xml);
    # TEST
    is($d4->textContent, $expected_ws, 'interleaved: default parser still preserves');
}

# parse_balanced_chunk: no_blanks must not leak to subsequent default parse
{
    my $chunk = "<foo>\n    <bar/>\n</foo>";
    my $chunk_ws = "\n    \n";

    my $nb_parser = XML::LibXML->new(no_blanks => 1);
    my $nb_chunk = $nb_parser->parse_balanced_chunk($chunk);
    # TEST
    is($nb_chunk->textContent, '',
       'parse_balanced_chunk with no_blanks strips whitespace');

    my $def_parser = XML::LibXML->new;
    my $doc = $def_parser->parse_string($xml);
    # TEST
    is($doc->textContent, $expected_ws,
       'default parse_string after no_blanks parse_balanced_chunk preserves whitespace');
}

# Reusing same parser multiple times: settings remain stable
{
    my $nb_parser = XML::LibXML->new(no_blanks => 1);
    my $def_parser = XML::LibXML->new;

    for my $i (1..3) {
        # TEST*3
        is($nb_parser->parse_string($xml)->textContent, '',
           "reuse: no_blanks parser strips on iteration $i");
    }
    # The implicit 3 tests here use the TEST*3 annotation above
}
