
use strict;
use warnings;

use constant HAS_LEAKTRACE => eval { require Test::LeakTrace };
use Test::More HAS_LEAKTRACE
    ? (tests => 3)
    : (skip_all => 'Test::LeakTrace is required for memory leak tests.');
use Test::LeakTrace;

use XML::LibXML;
use XML::LibXML::SAX::Builder;
use IO::File;

# _parse_sax_file leaked the SAX handler on every invocation (the redundant
# PSaxGetHandler() call overwrote ctxt->sax without freeing the original).
# Warmup primes any one-time caches, then repeated parses must not leak.
{
    my $handler = XML::LibXML::SAX::Builder->new();
    my $parser = XML::LibXML->new();
    $parser->set_handler($handler);
    eval { $parser->parse_file("example/dromeds.xml") };

    # TEST
    no_leaks_ok {
        eval { $parser->parse_file("example/dromeds.xml") };
    } '_parse_sax_file does not leak SAX handler on repeated calls';
}

# _parse_sax_fh success path - verify no leaks on repeated filehandle parses.
{
    my $handler = XML::LibXML::SAX::Builder->new();
    my $parser = XML::LibXML->new();
    $parser->set_handler($handler);
    my $fh = IO::File->new("example/dromeds.xml", "r");
    eval { $parser->parse_fh($fh) };
    $fh->close;

    # TEST
    no_leaks_ok {
        my $fh2 = IO::File->new("example/dromeds.xml", "r");
        eval { $parser->parse_fh($fh2) };
        $fh2->close;
    } '_parse_sax_fh does not leak on repeated calls';
}

# _parse_sax_xml_chunk success path - verify no leaks on repeated chunk parses.
{
    my $handler = XML::LibXML::SAX::Builder->new();
    my $parser = XML::LibXML->new();
    $parser->set_handler($handler);
    eval { $parser->parse_xml_chunk("<foo>bar</foo>") };

    # TEST
    no_leaks_ok {
        eval { $parser->parse_xml_chunk("<foo>bar</foo>") };
    } '_parse_sax_xml_chunk does not leak on repeated calls';
}
