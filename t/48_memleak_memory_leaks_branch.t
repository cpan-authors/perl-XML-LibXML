
use strict;
use warnings;

=head1 DESCRIPTION

Memory leak tests for fixes cherry-picked from the memory-leaks branch
(Nick Wellnhofer, 2014). Exercises parsing, SAX, push parser,
createAttributeNS, substringData, deleteData, and toString/toFH code paths.

=cut

use constant HAS_LEAKTRACE => eval { require Test::LeakTrace };
use Test::More HAS_LEAKTRACE
    ? (tests => 15)
    : (skip_all => 'Test::LeakTrace is required for memory leak tests.');
use Test::LeakTrace;

use XML::LibXML;
use XML::LibXML::SAX;
use XML::LibXML::SAX::Parser;
use XML::LibXML::SAX::Builder;

my $xml = <<'XML';
<?xml version="1.0"?>
<root><child attr="val">text</child></root>
XML

my $xml_ns = <<'XML';
<?xml version="1.0"?>
<root xmlns:x="http://example.com"><x:child>text</x:child></root>
XML

# TEST
no_leaks_ok {
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string($xml);
} 'parse_string: no leaks';

# TEST
no_leaks_ok {
    my $parser = XML::LibXML->new;
    open my $fh, '<', \$xml or die;
    my $doc = $parser->parse_fh($fh);
    close $fh;
} 'parse_fh: no leaks';

# TEST
no_leaks_ok {
    my $handler = XML::LibXML::SAX::Builder->new();
    my $generator = XML::LibXML::SAX->new(Handler => $handler);
    my $doc = $generator->parse_string($xml);
} 'SAX parse_string: no leaks';

# TEST
no_leaks_ok {
    my $handler = XML::LibXML::SAX::Builder->new();
    my $parser = XML::LibXML::SAX::Parser->new(Handler => $handler);
    $parser->parse_uri("example/test.xml");
} 'SAX parse_file: no leaks';

# TEST
no_leaks_ok {
    my $parser = XML::LibXML->new;
    $parser->init_push;
    $parser->push('<root>');
    $parser->push('<child/>');
    $parser->push('</root>');
    my $doc = $parser->finish_push;
} 'push parser: no leaks';

{
    # Warm up error path (loads Encode and Error modules on first call)
    my $p = XML::LibXML->new;
    $p->init_push;
    $p->push('<broken>');
    eval { $p->finish_push; };
}
# TEST
no_leaks_ok {
    my $parser = XML::LibXML->new;
    $parser->init_push;
    $parser->push('<broken>');
    eval { $parser->finish_push; };
} 'push parser (malformed, error path): no leaks';

# TEST
no_leaks_ok {
    my $handler = XML::LibXML::SAX::Builder->new();
    my $parser = XML::LibXML->new;
    $parser->set_handler($handler);
    $parser->push('<root><child/></root>');
    my $doc = $parser->finish_push;
} 'SAX push parser: no leaks';

# TEST
no_leaks_ok {
    my $handler = XML::LibXML::SAX::Builder->new();
    my $parser = XML::LibXML->new;
    $parser->set_handler($handler);
    $parser->push('<broken>');
    eval { $parser->finish_push; };
} 'SAX push parser (malformed, error path): no leaks';

# TEST
no_leaks_ok {
    my $doc = XML::LibXML::Document->new();
    my $root = $doc->createElement('root');
    $doc->setDocumentElement($root);
    $root->setNamespace('http://example.com', 'x', 1);
    my $attr = $doc->createAttributeNS('http://example.com', 'x:foo', 'bar');
} 'createAttributeNS with namespace: no leaks';

# TEST
no_leaks_ok {
    my $doc = XML::LibXML::Document->new();
    my $root = $doc->createElement('root');
    $doc->setDocumentElement($root);
    my $attr = $doc->createAttributeNS(undef, 'foo', 'bar');
} 'createAttributeNS without namespace: no leaks';

# TEST
no_leaks_ok {
    my $doc = XML::LibXML::Document->new();
    my $root = $doc->createElement('root');
    $doc->setDocumentElement($root);
    # Use undeclared prefix — ns lookup fails, exercises error/undef path
    my $attr = $doc->createAttributeNS('http://no.such.ns', 'nosuch:foo', 'bar');
} 'createAttributeNS with undeclared ns (error path): no leaks';

# TEST
no_leaks_ok {
    my $doc = XML::LibXML::Document->new();
    my $text = $doc->createTextNode('hello world');
    my $sub = $text->substringData(0, 5);
} 'substringData: no leaks';

# TEST
no_leaks_ok {
    my $doc = XML::LibXML::Document->new();
    my $text = $doc->createTextNode('hello world');
    $text->deleteData(5, 6);
} 'deleteData: no leaks';

# TEST
no_leaks_ok {
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string(
        '<?xml version="1.0"?><!DOCTYPE root><root><child/></root>'
    );
    $doc->setCompression(-1) if $doc->can('setCompression');
    my $str = $doc->toString(0);
} 'toString with DTD (skipDTD path): no leaks';

# TEST
no_leaks_ok {
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string(
        '<?xml version="1.0"?><!DOCTYPE root><root><child/></root>'
    );
    open my $fh, '>', \my $output or die;
    $doc->toFH($fh, 0);
    close $fh;
} 'toFH with DTD (skipDTD path): no leaks';
