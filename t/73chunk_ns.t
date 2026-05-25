use strict;
use warnings;

use Test::More tests => 10;

use XML::LibXML;

# GH #254: parse_balanced_chunk with namespaces leaked memory because
# xmlParseBalancedChunkMemory was called with a NULL document.

my $parser = XML::LibXML->new();

{
    my $chunk = '<foo:bar xmlns:foo="http://example.com">content</foo:bar>';
    my $frag = $parser->parse_balanced_chunk($chunk);
    isa_ok($frag, 'XML::LibXML::DocumentFragment');

    my $child = $frag->firstChild;
    is($child->nodeName, 'foo:bar', 'prefixed element name preserved');
    is($child->namespaceURI, 'http://example.com', 'namespace URI preserved');
    is($child->prefix, 'foo', 'prefix preserved');
    is($child->textContent, 'content', 'text content preserved');
}

{
    my $chunk = '<root xmlns="http://default.ns"><child/></root>';
    my $frag = $parser->parse_balanced_chunk($chunk);
    my $root = $frag->firstChild;
    is($root->namespaceURI, 'http://default.ns', 'default namespace preserved');
    my $child = $root->firstChild;
    is($child->namespaceURI, 'http://default.ns', 'child inherits default namespace');
}

{
    my $chunk = '<a:x xmlns:a="urn:a"><b:y xmlns:b="urn:b"/></a:x>';
    my $frag = $parser->parse_balanced_chunk($chunk);
    my $root = $frag->firstChild;
    is($root->namespaceURI, 'urn:a', 'first namespace correct');
    my $child = $root->firstChild;
    is($child->namespaceURI, 'urn:b', 'nested namespace correct');
}

{
    my $chunk = '<item/><item/><item/>';
    my $frag = $parser->parse_balanced_chunk($chunk);
    my @children = $frag->childNodes;
    is(scalar @children, 3, 'multiple top-level nodes in chunk');
}
