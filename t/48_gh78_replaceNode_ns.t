use strict;
use warnings;
use Test::More;

use XML::LibXML;
use XML::LibXML::XPathContext;

# GH #78: replaceNode drops namespace declarations when the parent
# tree already declares the same prefix, causing toString to produce
# XML with undeclared prefixes.

my $parser = XML::LibXML->new;

# Original document with saml: prefix
my $xmlstring
    = q{<saml:foo xmlns:saml="foobar">bar<foobar/><saml:bar><saml:baz>foo</saml:baz></saml:bar></saml:foo>};

my $doc = $parser->parse_string($xmlstring);

# Replacement node: has both default ns and prefixed ns
my $replace = q{<saml:Assertion xmlns="foobar" xmlns:saml="foobar" ID="ID_test" Version="2.0">Some assertion data</saml:Assertion>};

my $rnode = $parser->parse_string($replace)->findnodes('//*')->[0];

# TEST
is($rnode->toString, $replace, "replacement node parses correctly");

my $xpc = XML::LibXML::XPathContext->new($doc);
$xpc->registerNs('saml', 'foobar');

my $tbr = $xpc->findnodes('//saml:baz')->get_node(1);
$tbr->replaceNode($rnode);

my $assertion = $xpc->findnodes('//saml:Assertion')->[0];
# TEST
ok(defined $assertion, "replacement node found in tree");

# TEST
is($assertion->namespaceURI, 'foobar', "namespace URI preserved");

# TEST
is($assertion->prefix, 'saml', "prefix preserved");

# The key assertion: toString must include xmlns:saml declaration
# so the output is valid XML when taken as a standalone fragment
my $str = $assertion->toString;
# TEST
like($str, qr/xmlns:saml="foobar"/, "xmlns:saml declaration preserved in toString");
# TEST
like($str, qr/xmlns="foobar"/, "default xmlns declaration preserved in toString");

# Verify the full document is also correct
my $doc_str = $doc->toString;
# TEST
like($doc_str, qr/<saml:Assertion/, "element present in document serialization");

done_testing();
