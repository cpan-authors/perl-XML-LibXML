#!/usr/bin/perl

# Regression test for https://github.com/shlomif/perl-XML-LibXML/issues/88
#
# A parser with no_blanks set a global default in libxml2 that persisted
# into later parser instances even when they explicitly requested keep_blanks.

use strict;
use warnings;

use Test::More tests => 7;

use XML::LibXML;
use File::Temp qw(tempfile);

my $xml = <<'EOF';
<?xml version="1.0"?>
<hello><bold>Line1</bold>
<bold>Line2</bold></hello>
EOF

my $expected_with_blanks = <<'EOF';
<?xml version="1.0"?>
<hello><bold>Line1</bold>
<bold>Line2</bold></hello>
EOF

my $expected_no_blanks = <<'EOF';
<?xml version="1.0"?>
<hello><bold>Line1</bold><bold>Line2</bold></hello>
EOF

# TEST
{
    my $parser = XML::LibXML->new( keep_blanks => 1 );
    my $dom = $parser->load_xml( string => $xml );
    is( $dom->serialize, $expected_with_blanks,
        'first parser: keep_blanks preserves whitespace' );
}

# TEST
{
    my $parser = XML::LibXML->new( no_blanks => 1 );
    my $dom = $parser->load_xml( string => $xml );
    is( $dom->serialize, $expected_no_blanks,
        'second parser: no_blanks strips whitespace' );
}

# TEST
{
    my $parser = XML::LibXML->new( keep_blanks => 1 );
    my $dom = $parser->load_xml( string => $xml );
    is( $dom->serialize, $expected_with_blanks,
        'third parser (load_xml): keep_blanks after no_blanks' );
}

# TEST
{
    my $parser = XML::LibXML->new();
    my $dom = $parser->parse_string( $xml );
    is( $dom->serialize, $expected_with_blanks,
        'fourth parser (parse_string): default keeps blanks' );
}

# TEST
{
    my ($fh, $tmpfile) = tempfile(SUFFIX => '.xml', UNLINK => 1);
    print $fh $xml;
    close $fh;

    my $parser = XML::LibXML->new( keep_blanks => 1 );
    my $dom = $parser->load_xml( location => $tmpfile );
    is( $dom->serialize, $expected_with_blanks,
        'fifth parser (parse_file): keep_blanks after no_blanks' );
}

# TEST
{
    my ($fh, $tmpfile) = tempfile(SUFFIX => '.xml', UNLINK => 1);
    print $fh $xml;
    close $fh;

    open(my $io, '<', $tmpfile);
    my $parser = XML::LibXML->new( keep_blanks => 1 );
    my $dom = $parser->load_xml( IO => $io );
    close $io;
    is( $dom->serialize, $expected_with_blanks,
        'sixth parser (parse_fh): keep_blanks after no_blanks' );
}

# TEST
{
    my $parser = XML::LibXML->new( no_blanks => 1 );
    my $dom = $parser->load_xml( string => $xml );
    is( $dom->serialize, $expected_no_blanks,
        'seventh parser: no_blanks still works at end' );
}
