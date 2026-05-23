use strict;
use warnings;

# Should be 53
use Test::More tests => 54;

use XML::LibXML;

my $xmlstring = <<EOSTR;
<foo>
    <bar>
        test 1
    </bar>
    <bar>
        test 2
    </bar>
</foo>
EOSTR

{
    my $parser = XML::LibXML->new();

    my $doc = $parser->parse_string( $xmlstring );

    # TEST
    ok($doc, 'Parsing successful.');

    {
        my @nodes = $doc->findnodes( "/foo/bar" );
        # TEST
        is ( scalar( @nodes ), 2, 'Two bar nodes' );

        # TEST
        ok( $doc->isSameNode($nodes[0]->ownerDocument),
            'Doc is the same as the owner document.' );

        my $compiled = XML::LibXML::XPathExpression->new("/foo/bar");
        foreach my $idx (1..3) {
            @nodes = $doc->findnodes( $compiled );
            # TEST*3
            is( scalar( @nodes ), 2, "Two nodes for /foo/bar - try No. $idx" );
        }

        # TEST
        ok( $doc->isSameNode($nodes[0]->ownerDocument),
            'Same owner as previous one',
        );

        my $n = $doc->createElement( "foobar" );

        my $p = $nodes[1]->parentNode;
        $p->insertBefore( $n, $nodes[1] );

        # TEST

        ok( $p->isSameNode( $doc->documentElement ), 'Same as document elem' );
        @nodes = $p->childNodes;
        # TEST
        is( scalar( @nodes ), 6, 'Found child nodes' );
    }

    {
        my $result = $doc->find( "/foo/bar" );
        # TEST
        ok( $result, 'find returns a result for /foo/bar' );
        # TEST
        ok( $result->isa( "XML::LibXML::NodeList" ), 'find /foo/bar returns a NodeList' );
        # TEST
        is( $result->size, 2, 'find /foo/bar returns 2 nodes' );

        # TEST

        ok( $doc->isSameNode($$result[0]->ownerDocument), 'find result has correct owner document' );

        $result = $doc->find( XML::LibXML::XPathExpression->new("/foo/bar") );
        # TEST
        ok( $result, 'find with compiled XPathExpression returns a result' );
        # TEST
        ok( $result->isa( "XML::LibXML::NodeList" ), 'compiled XPath returns a NodeList' );
        # TEST
        is( $result->size, 2, 'compiled XPath returns 2 nodes' );

        # TEST

        ok( $doc->isSameNode($$result[0]->ownerDocument), 'compiled XPath result has correct owner' );

        $result = $doc->find( "string(/foo/bar)" );
        # TEST
        ok( $result, 'find string() returns a result' );
        # TEST
        ok( $result->isa( "XML::LibXML::Literal" ), 'string() result is a Literal' );
        # TEST
        ok( $result->string_value =~ /test 1/, 'string() returns first bar content' );

        $result = $doc->find( "string(/foo/bar)" );
        # TEST
        ok( $result, 'repeated string() find returns a result' );
        # TEST
        ok( $result->isa( "XML::LibXML::Literal" ), 'repeated string() is a Literal' );
        # TEST
        ok( $result->string_value =~ /test 1/, 'repeated string() has correct value' );

        $result = $doc->find( XML::LibXML::XPathExpression->new("count(/foo/bar)") );
        # TEST
        ok( $result, 'count() returns a result' );
        # TEST
        ok( $result->isa( "XML::LibXML::Number" ), 'count() result is a Number' );
        # TEST
        is( $result->value, 2, 'count(/foo/bar) is 2' );

        $result = $doc->find( "contains(/foo/bar[1], 'test 1')" );
        # TEST
        ok( $result, 'contains() returns a result' );
        # TEST
        ok( $result->isa( "XML::LibXML::Boolean" ), 'contains() result is a Boolean' );
        # TEST
        is( $result->string_value, "true", 'contains() is true for matching text' );

        $result = $doc->find( XML::LibXML::XPathExpression->new("contains(/foo/bar[1], 'test 1')") );
        # TEST
        ok( $result, 'compiled contains() returns a result' );
        # TEST
        ok( $result->isa( "XML::LibXML::Boolean" ), 'compiled contains() is a Boolean' );
        # TEST
        is( $result->string_value, "true", 'compiled contains() is true' );

        $result = $doc->find( "contains(/foo/bar[3], 'test 1')" );
        # TEST
        ok( $result == 0, 'contains() on non-existent node returns false' );

        # TEST

        ok( $doc->exists("/foo/bar[2]"), 'exists() true for existing node' );
        # TEST
        is( $doc->exists("/foo/bar[3]"), 0, 'exists() false for non-existent node' );
        # TEST
        is( $doc->exists("-7.2"),1, 'exists() true for non-zero number' );
        # TEST
        is( $doc->exists("0"),0, 'exists() false for zero' );
        # TEST
        is( $doc->exists("'foo'"),1, 'exists() true for non-empty string' );
        # TEST
        is( $doc->exists("''"),0, 'exists() false for empty string' );
        # TEST
        is( $doc->exists("'0'"),1, 'exists() true for string "0"' );

        my ($node) = $doc->findnodes("/foo/bar[1]" );
        # TEST
        ok( $node, 'findnodes returns first bar node' );
        # TEST
        ok ($node->exists("following-sibling::bar"), 'exists() works on node context');
    }

    {
        # test the strange segfault after xpathing
        my $root = $doc->documentElement();
        foreach my $bar ( $root->findnodes( 'bar' )  ) {
            $root->removeChild($bar);
        }
        # TEST
        ok(1, 'removeChild after findnodes does not segfault');
        # warn $root->toString();

        $doc =  $parser->parse_string( $xmlstring );
        my @bars = $doc->findnodes( '//bar' );

        foreach my $node ( @bars ) {
            $node->parentNode()->removeChild( $node );
        }
        # TEST
        ok(1, 'removeChild via parentNode after findnodes does not segfault');
    }
}

{
    # from #39178
    my $p = XML::LibXML->new;
    my $doc = $p->parse_file("example/utf-16-2.xml");
    # TEST
    ok($doc, 'parse utf-16 XML file');
    my @nodes = $doc->findnodes("/cml/*");
    # TEST
    ok (@nodes == 2, 'findnodes returns 2 children from utf-16 doc');
    # TEST
    is ($nodes[1]->textContent, "utf-16 test with umlauts: \x{e4}\x{f6}\x{fc}\x{c4}\x{d6}\x{dc}\x{df}", 'utf-16 text content with umlauts preserved');
}

{
    # from #36576
    my $p = XML::LibXML->new;
    my $doc = $p->parse_html_file("example/utf-16-1.html");
    # TEST
    ok($doc, 'parse utf-16 HTML file (1)');
    use utf8;
    my @nodes = $doc->findnodes("//p");
    # TEST
    ok (@nodes == 1, 'findnodes returns 1 p element from utf-16 HTML');

    # TEST
    _utf16_content_test(\@nodes, 'nodes content is fine.');
}

{
    # from #36576
    my $p = XML::LibXML->new;
    my $doc = $p->parse_html_file("example/utf-16-2.html");
    # TEST
    ok($doc, 'parse utf-16 HTML file (2)');
    my @nodes = $doc->findnodes("//p");
    # TEST
    is (scalar(@nodes), 1, 'Found one p');
    # TEST
    _utf16_content_test(\@nodes, 'p content is fine.');
}

{
    # from #69096
    my $doc = XML::LibXML::Document->createDocument('1.0', 'utf-8');
    my $root = $doc->createElement('root');
    $doc->setDocumentElement($root);
    my $e = $doc->createElement("child");
    my $e2 = $doc->createElement("child");
    my $t1 = $doc->createTextNode( "te" );
    my $t2 = $doc->createTextNode( "st" );
    $root->appendChild($e);
    $root->appendChild($e2);
    $e2->appendChild($t1);
    $e2->appendChild($t2);

    $doc->normalize();
    my @cn = $doc->findnodes('//child[text()="test"]');
    # TEST
    is( scalar( @cn ), 1, 'xpath testing adjacent text nodes' );
}

sub _utf16_content_test
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($nodes_ref, $blurb) = @_;

    SKIP:
    {
        if (XML::LibXML::LIBXML_RUNTIME_VERSION() < 20700)
        {
            skip "UTF-16 and HTML broken in libxml2 < 2.7", 1;
        }

        is ($nodes_ref->[0]->textContent,
            "utf-16 test with umlauts: \x{e4}\x{f6}\x{fc}\x{c4}\x{d6}\x{dc}\x{df}",
            $blurb,
        );
    }
}
