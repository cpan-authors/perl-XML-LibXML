#!/usr/bin/perl

use strict;
use warnings;

# GH #233: HTML parser errors should include line numbers in as_string output
# https://github.com/cpan-authors/XML-LibXML/issues/233

use Test::More;

if (! XML::LibXML::HAVE_STRUCT_ERRORS()) {
    plan skip_all => 'XML::LibXML does not have structured errors';
}
else {
    plan tests => 6;
}

use XML::LibXML;
use XML::LibXML::Error;

my $p = XML::LibXML->new();

my $html = "<html>\n<body>\n<p>text\n</p>\n<div><b>bad</i></div>\n</body>\n</html>";

my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    eval { $p->parse_html_string($html, { recover => 1 }) };
}

SKIP:
{
    if (! @warnings) {
        skip('No warnings captured from HTML parse - possibly old libxml2', 6);
    }

    my $err = $warnings[0];

    skip('Warning is not an XML::LibXML::Error object', 6)
        if (! ref($err) or ! $err->isa('XML::LibXML::Error'));

    # Walk the chain to find the innermost (first) error
    my $first = $err;
    while ($first->_prev && ref($first->_prev)) {
        $first = $first->_prev;
    }

    # TEST
    is($first->{domain}, XML::LibXML::Error::XML_ERR_FROM_HTML(),
        'Error domain is HTML parser');

    # TEST
    ok(defined $first->line(), 'HTML error has a line number');

    # TEST
    ok($first->line() > 0, 'HTML error line number is positive');

    my $str = $first->as_string();

    # TEST
    like($str, qr/line \d+/, 'as_string includes line number for HTML errors');

    # TEST
    like($str, qr/HTML parser/, 'as_string identifies HTML parser domain');

    # XML parser errors preserve existing "Entity: line N" format
    my @xml_warns;
    {
        local $SIG{__WARN__} = sub { push @xml_warns, $_[0] };
        eval { $p->parse_string("<root>\n<x>\n</y>\n</root>", { recover => 1 }) };
    }

    my $xml_err;
    if (@xml_warns && ref($xml_warns[0]) && $xml_warns[0]->isa('XML::LibXML::Error')) {
        $xml_err = $xml_warns[0];
        while ($xml_err->_prev && ref($xml_err->_prev)) {
            $xml_err = $xml_err->_prev;
        }
    }

    SKIP:
    {
        skip('No XML warnings to compare', 1) if (! $xml_err);

        my $xml_str = $xml_err->as_string();
        # TEST
        like($xml_str, qr/:\d+:/, 'XML parser error retains file:line format');
    }
}
