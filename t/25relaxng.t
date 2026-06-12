# $Id$

##
# Testcases for the RelaxNG interface
#

use strict;
use warnings;

use lib './t/lib';
use TestHelpers qw(slurp);

use Test::More;

BEGIN {
    use XML::LibXML;

    if ( XML::LibXML::LIBXML_VERSION >= 20510 ) {
        plan tests => 21;
    }
    else {
        plan skip_all => 'Skip No RNG Support compiled';
    }
};

if ( XML::LibXML::LIBXML_VERSION >= 20510 ) {

my $xmlparser = XML::LibXML->new();

my $file         = "test/relaxng/schema.rng";
my $badfile      = "test/relaxng/badschema.rng";
my $validfile    = "test/relaxng/demo.xml";
my $invalidfile  = "test/relaxng/invaliddemo.xml";
my $demo4        = "test/relaxng/demo4.rng";
my $netfile      = "test/relaxng/net.rng";

print "# 1 parse schema from a file\n";
{
    my $rngschema = XML::LibXML::RelaxNG->new( location => $file );
    # TEST
    ok ( $rngschema, 'parse RNG schema from file' );

    eval { $rngschema = XML::LibXML::RelaxNG->new( location => $badfile ); };
    # TEST
    ok( $@, 'bad RNG schema from file throws error' );
}

print "# 2 parse schema from a string\n";
{
    my $string = slurp($file);

    my $rngschema = XML::LibXML::RelaxNG->new( string => $string );
    # TEST
    ok ( $rngschema, 'parse RNG schema from string' );

    $string = slurp($badfile);

    eval { $rngschema = XML::LibXML::RelaxNG->new( string => $string ); };
    # TEST
    ok( $@, 'bad RNG schema from string throws error' );
}

print "# 3 parse schema from a document\n";
{
    my $doc       = $xmlparser->parse_file( $file );
    my $rngschema = XML::LibXML::RelaxNG->new( DOM => $doc );
    # TEST
    ok ( $rngschema, 'parse RNG schema from DOM document' );

    $doc       = $xmlparser->parse_file( $badfile );
    eval { $rngschema = XML::LibXML::RelaxNG->new( DOM => $doc ); };
    # TEST
    ok( $@, 'bad RNG schema from DOM throws error' );
}

print "# 4 validate a document\n";
{
    my $doc       = $xmlparser->parse_file( $validfile );
    my $rngschema = XML::LibXML::RelaxNG->new( location => $file );

    my $valid = 0;
    eval { $valid = $rngschema->validate( $doc ); };
    # TEST
    is( $valid, 0, 'valid document passes RNG validation' );

    $doc       = $xmlparser->parse_file( $invalidfile );
    $valid     = 0;
    eval { $valid = $rngschema->validate( $doc ); };
    # TEST
    ok ( $@, 'invalid document fails RNG validation' );
}

print "# 5 re-validate a modified document\n";
{
  my $rng = XML::LibXML::RelaxNG->new(location => $demo4);
  my $seed_xml = <<'EOXML';
<?xml version="1.0" encoding="UTF-8"?>
<root/>
EOXML

  my $doc = $xmlparser->parse_string($seed_xml);
  my $rootElem = $doc->documentElement;
  my $bogusElem = $doc->createElement('bogus-element');

  eval{$rng->validate($doc);};
  # TEST
  ok ($@, 'root without required attribute fails validation');

  $rootElem->setAttribute('name', 'rootElem');
  eval{ $rng->validate($doc); };
  # TEST
  ok (!$@, 'root with required attribute passes validation');

  $rootElem->appendChild($bogusElem);
  eval{$rng->validate($doc);};
  # TEST
  ok ($@, 'added bogus child element fails validation');

  $bogusElem->unlinkNode();
  eval{$rng->validate($doc);};
  # TEST
  ok (!$@, 'removed bogus child element passes validation again');

  $rootElem->removeAttribute('name');
  eval{$rng->validate($doc);};
  # TEST
  ok ($@, 'removed required attribute fails validation again');

}

print "# 6 check that no_network => 1 works\n";
{
    my $rng = eval { XML::LibXML::RelaxNG->new( location => $netfile, no_network => 1 ) };
    # TEST
    like( $@, qr{Attempt to load network entity}, 'RNG from file location with external import and no_network => 1 throws an exception.' );
    # TEST
    ok( !defined $rng, 'RNG from file location with external import and no_network => 1 is not loaded.' );
}
{
    my $rng = eval { XML::LibXML::RelaxNG->new( string => <<'EOF', no_network => 1 ) };
<?xml version="1.0" encoding="iso-8859-1"?>
<grammar xmlns="http://relaxng.org/ns/structure/1.0" datatypeLibrary="http://www.w3.org/2001/XMLSchema-datatypes">
  <include href="http://example.com/xml.rng"/>
  <start>
    <ref name="include"/>
  </start>
  <define name="include">
    <element name="include">
      <text/>
    </element>
  </define>
</grammar>
EOF
    # TEST
    like( $@, qr{Attempt to load network entity}, 'RNG from buffer with external import and no_network => 1 throws an exception.' );
    # TEST
    ok( !defined $rng, 'RNG from buffer with external import and no_network => 1 is not loaded.' );
}


print "# 7 re-validate a namespaced document after DOM modification (RT#63655)\n";
{
    my $namespace = "test/relaxng/ns.rng";
    my $rngschema = XML::LibXML::RelaxNG->new(location => $namespace);
    my $doc = $xmlparser->parse_string(<<'EOD');
<?xml version="1.0" encoding="utf-8"?>
<datastore xmlns="http://xmlns.example.com/2007/test/datastore">
  <data>
    <active>
      <element id="uuidtest1">
        <title>Ze element</title>
        <payload>Ze element payload</payload>
      </element>
    </active>
  </data>
</datastore>
EOD
    eval { $rngschema->validate($doc); };
    # TEST
    ok(!$@, 'initial namespaced document validates');

    my $ns = 'http://xmlns.example.com/2007/test/datastore';
    my $node = $doc->createElementNS($ns, "element");

    my $title = $doc->createElementNS($ns, "title");
    $title->appendText("Annoying tests are annoying");
    $node->appendChild($title);

    my $payload = $doc->createElementNS($ns, "payload");
    $payload->appendText("some payload");
    $node->appendChild($payload);

    $node->setAttribute('id', 'uuidIamAtestElement');

    my ($active) = $doc->getElementsByTagName("active");
    eval { $rngschema->validate($doc); };
    # TEST
    ok(!$@, 'validates before appending new node');

    $active->appendChild($node);

    my $reparsed_doc = $xmlparser->parse_string($doc->toString);
    eval { $rngschema->validate($reparsed_doc); };
    # TEST
    ok(!$@, 'reparsed document with new node validates');

    eval { $rngschema->validate($doc); };
    # TEST
    ok(!$@, 'DOM-modified document re-validates (RT#63655)');
}


} # Version >= 20510 test
