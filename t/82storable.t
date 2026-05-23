use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile);

BEGIN {
    eval { require Storable };
    if ($@) {
        plan skip_all => 'Storable not available';
    }
    else {
        plan tests => 15;
    }
}

use XML::LibXML;

# TEST
use_ok('Storable');

my $xml = '<?xml version="1.0" encoding="UTF-8"?>' . "\n" . '<root><child attr="val">text</child></root>';

{
    my $doc = XML::LibXML->load_xml(string => $xml);

    # TEST
    my $frozen = eval { Storable::freeze($doc) };
    ok(defined $frozen, 'Document can be frozen with Storable');

    # TEST
    my $thawed = eval { Storable::thaw($frozen) };
    ok(defined $thawed, 'Document can be thawed with Storable');

    # TEST
    isa_ok($thawed, 'XML::LibXML::Document');

    # TEST
    is($thawed->documentElement->nodeName, 'root', 'thawed document has correct root element');

    # TEST
    my $child = ($thawed->documentElement->childNodes)[0];
    is($child->getAttribute('attr'), 'val', 'thawed document preserves attributes');
}

{
    my $doc = XML::LibXML->load_xml(string => $xml);

    # TEST
    my $clone = eval { Storable::dclone($doc) };
    ok(defined $clone, 'Document can be dcloned with Storable');

    # TEST
    isa_ok($clone, 'XML::LibXML::Document');

    # TEST
    is($clone->documentElement->textContent, 'text', 'dcloned document preserves text content');
}

{
    my $doc = XML::LibXML->load_xml(string => $xml);
    my $elem = $doc->documentElement;

    # TEST
    eval { Storable::freeze($elem) };
    like($@, qr/cannot be serialized with Storable/, 'freezing a non-Document node croaks');
}

{
    my $doc = XML::LibXML->load_xml(string => $xml);
    my $text_node = $doc->createTextNode("hello");

    # TEST
    eval { Storable::freeze($text_node) };
    like($@, qr/cannot be serialized with Storable/, 'freezing a Text node croaks');
}

{
    my $doc = XML::LibXML->load_xml(string => $xml);
    my (undef, $tmpfile) = tempfile(UNLINK => 1);

    # TEST
    eval { Storable::store($doc, $tmpfile) };
    ok(!$@, 'Document can be stored to file') or diag($@);

    # TEST
    my $retrieved = eval { Storable::retrieve($tmpfile) };
    ok(defined $retrieved, 'Document can be retrieved from file');

    # TEST
    isa_ok($retrieved, 'XML::LibXML::Document');

    # TEST
    is($retrieved->documentElement->textContent, 'text',
       'retrieved document preserves content across store/retrieve');
}
