use strict;
use warnings;
use Test::More tests => 8;
use XML::LibXML;

sub _u { my $s = shift; utf8::upgrade($s);      $s }
sub _d { my $s = shift; utf8::downgrade($s, 1); $s }

sub gen_text_node {
    my ($encoding, $text) = @_;
    my $doc = XML::LibXML::Document->new("1.0", $encoding);
    my $root = $doc->createElement("root");
    $doc->setDocumentElement($root);
    $root->appendText($text);
    return $doc->toString();
}

sub parse_text_node {
    my ($xml) = @_;
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string($xml);
    return $doc->documentElement->textContent();
}

sub gen_attr_node {
    my ($encoding, $text) = @_;
    my $doc = XML::LibXML::Document->new("1.0", $encoding);
    my $root = $doc->createElement("root");
    $doc->setDocumentElement($root);
    $root->setAttribute('attr', $text);
    return $doc->toString();
}

sub parse_attr_node {
    my ($xml) = @_;
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string($xml);
    return $doc->documentElement->getAttribute('attr');
}

{
    my $text = "\xC9\xE9";
    my $text_u = _u($text);
    my $text_d = _d($text);

    # TEST
    is($text_d, $text_u, "upgraded and downgraded are equal");

    for my $encoding (qw( UTF-8 )) {
        {
            my $xml_u = gen_text_node($encoding, $text_u);
            my $xml_d = gen_text_node($encoding, $text_d);

            # TEST
            is($xml_d, $xml_u,
                "gen_text_node produces identical XML for upgraded/downgraded ($encoding)");

            my $got = parse_text_node($xml_u);
            # TEST
            is(sprintf("%vX", $got), sprintf("%vX", $text),
                "round-trip upgraded text node ($encoding)");

            $got = parse_text_node($xml_d);
            # TEST
            is(sprintf("%vX", $got), sprintf("%vX", $text),
                "round-trip downgraded text node ($encoding)");
        }

        {
            my $xml_u = gen_attr_node($encoding, $text_u);
            my $xml_d = gen_attr_node($encoding, $text_d);

            # TEST
            is($xml_d, $xml_u,
                "gen_attr_node produces identical XML for upgraded/downgraded ($encoding)");

            my $got = parse_attr_node($xml_u);
            # TEST
            is(sprintf("%vX", $got), sprintf("%vX", $text),
                "round-trip upgraded attribute ($encoding)");

            $got = parse_attr_node($xml_d);
            # TEST
            is(sprintf("%vX", $got), sprintf("%vX", $text),
                "round-trip downgraded attribute ($encoding)");
        }
    }

    {
        my $doc = XML::LibXML::Document->new("1.0");
        my $root = $doc->createElement("root");
        $doc->setDocumentElement($root);
        $root->appendText($text_d);
        my $got = $doc->documentElement->textContent();
        # TEST
        is(sprintf("%vX", $got), sprintf("%vX", $text),
            "appendText on doc without encoding, downgraded string");
    }
}
