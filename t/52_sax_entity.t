use strict;
use warnings;
use Test::More;

use XML::LibXML;
use XML::LibXML::SAX;

my %tests = (
    predefined =>       ['&quot;',          '"'],
    numeric =>          ['&#65;',           'A'],
    numericampersand => ['&#38;',           '&'],
    ampA =>             ['&#38;A',          '&A'],
    Aamp =>             ['A&#38;',          'A&'],
    AampBampC =>        ['A&#38;B&#38;C',   'A&B&C'],
);
my $ntests = scalar keys %tests;

plan tests => $ntests * 2;

my $input = '<?xml version="1.0"?><root';
for my $test (sort keys %tests) {
    $input .= sprintf(" %s='%s'", $test, $tests{$test}->[0]);
}
$input .= '/>';

my @captured;

{
    package SaxTestHandler;
    sub new { bless {}, shift }
    sub start_element {
        my ($self, $node) = @_;
        for my $attribute (sort keys %{$node->{Attributes}}) {
            my $name = $node->{Attributes}->{$attribute}->{Name};
            push @captured, [$name, $node->{Attributes}->{$attribute}->{Value}]
                if exists $tests{$name};
        }
    }
}

# Test 1: default SAX parser (expand_entities enabled internally)
@captured = ();
XML::LibXML::SAX->new(Handler => SaxTestHandler->new())->parse_string($input);
for my $c (sort { $a->[0] cmp $b->[0] } @captured) {
    is($c->[1], $tests{$c->[0]}->[1],
        "default parser: $c->[0]='${\$tests{$c->[0]}->[0]}' expands correctly");
}

# Test 2: user-supplied parser WITHOUT expand_entities (GH #251 / RT #131498)
@captured = ();
my $sax = XML::LibXML::SAX->new(Handler => SaxTestHandler->new());
$sax->{ParserOptions}{LibParser} = XML::LibXML->new();
$sax->parse_string($input);
for my $c (sort { $a->[0] cmp $b->[0] } @captured) {
    is($c->[1], $tests{$c->[0]}->[1],
        "user parser: $c->[0]='${\$tests{$c->[0]}->[0]}' expands correctly");
}
