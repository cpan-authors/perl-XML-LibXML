
use strict;
use warnings;

=head1 DESCRIPTION

Regression test for double-free in _parse_string with libxml2 >= 2.14.

In libxml2 >= 2.14, xmlParseDocument may set doc->URL to the same pointer
as ctxt->input->filename rather than making a copy.  Without the fix,
xmlFreeParserCtxt frees input->filename, then our code xmlFree(doc->URL)
frees the same allocation again, crashing with "double free or corruption".

On older libxml2 these are independent allocations and both paths work;
this test ensures neither path leaks or crashes on any version.

See L<https://github.com/cpan-authors/XML-LibXML/issues/113>.

=cut

use Test::More tests => 6;
use XML::LibXML;

# parse_string with a base URI — the code path that triggered the
# double-free on libxml2 >= 2.14.
{
    my $parser = XML::LibXML->new();
    my $doc = eval { $parser->parse_string('<root/>', 'http://example.com/test.xml') };

    # TEST
    ok(!$@, 'parse_string with base URI does not crash');
    # TEST
    isa_ok($doc, 'XML::LibXML::Document', 'parse_string with base URI returns a document');
    # TEST
    is($doc->URI, 'http://example.com/test.xml', 'document URI set correctly');
}

# parse_string without a base URI — the other branch in the fix.
{
    my $parser = XML::LibXML->new();
    my $doc = eval { $parser->parse_string('<root/>') };

    # TEST
    ok(!$@, 'parse_string without base URI does not crash');
    # TEST
    isa_ok($doc, 'XML::LibXML::Document', 'parse_string without base URI returns a document');
    # TEST
    like($doc->URI, qr/^unknown-/, 'document URI is auto-generated unknown-* form');
}
