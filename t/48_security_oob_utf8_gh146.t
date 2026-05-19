# Security regression test for GitHub issue #146:
# Out-of-bounds heap read via hand-rolled UTF-8 walker on truncated sequences.
#
# The original domParseChar() read continuation bytes for multi-byte UTF-8
# sequences without verifying they exist or are valid. A truncated sequence
# (e.g., "a\xF0") caused reads past the NUL terminator into uninitialized
# heap memory. This affects all DOM methods that validate node names via
# LibXML_test_node_name(): createElement, createAttribute, setNodeName,
# createElementNS, createAttributeNS, etc.
#
# Impact: denial of service (crash on unmapped memory) and potential
# information disclosure (reading adjacent heap allocations).
#
# Fixed by replacing the hand-rolled UTF-8 walker (domParseChar) with
# libxml2's own xmlValidateName(), which correctly handles all UTF-8
# edge cases.
#
# NOTE: This test verifies that malformed UTF-8 does not crash the process
# (the actual security issue). Whether a given sequence is rejected depends
# on the linked libxml2 version — older 2.9.x builds may accept some
# sequences that newer versions reject.

use strict;
use warnings;

use Test::More;
use XML::LibXML;

# Truncated UTF-8 sequences that previously caused OOB heap reads.
# Each entry: [ bytes, description ]
my @truncated_sequences = (
    [ "a\xC0",             "truncated 2-byte (leader only)" ],
    [ "a\xC2",             "truncated 2-byte (valid leader, missing continuation)" ],
    [ "a\xE0",             "truncated 3-byte (leader only)" ],
    [ "a\xE0\x80",         "truncated 3-byte (leader + 1 continuation)" ],
    [ "a\xF0",             "truncated 4-byte (leader only)" ],
    [ "a\xF0\x80",         "truncated 4-byte (leader + 1 continuation)" ],
    [ "a\xF0\x80\x80",     "truncated 4-byte (leader + 2 continuations)" ],
);

# Invalid continuation bytes — the leader is valid but the continuations
# are not 10xxxxxx.
my @invalid_continuations = (
    [ "a\xC2\x41",         "2-byte with ASCII continuation" ],
    [ "a\xE0\x41\x80",     "3-byte with ASCII in first continuation" ],
    [ "a\xE0\x80\x41",     "3-byte with ASCII in second continuation" ],
    [ "a\xF0\x41\x80\x80", "4-byte with ASCII in first continuation" ],
    [ "a\xF0\x80\x41\x80", "4-byte with ASCII in second continuation" ],
    [ "a\xF0\x80\x80\x41", "4-byte with ASCII in third continuation" ],
);

my @all_bad = (@truncated_sequences, @invalid_continuations);

my @methods = qw( createElement setNodeName createElementNS
                   createAttribute createAttributeNS );

# TEST:$bad_count=13
# TEST:$method_count=5
plan tests => scalar(@all_bad) * scalar(@methods);

my $doc   = XML::LibXML::Document->new();
my $nsURI = "http://example.com/ns";

for my $case (@all_bad) {
    my ($bytes, $desc) = @$case;

    for my $method (@methods) {
        eval {
            if ($method eq 'createElement') {
                $doc->createElement($bytes);
            }
            elsif ($method eq 'setNodeName') {
                my $node = $doc->createElement("tmp");
                $node->setNodeName($bytes);
            }
            elsif ($method eq 'createElementNS') {
                $doc->createElementNS($nsURI, $bytes);
            }
            elsif ($method eq 'createAttribute') {
                $doc->createAttribute($bytes, "value");
            }
            elsif ($method eq 'createAttributeNS') {
                $doc->createAttributeNS($nsURI, $bytes, "value");
            }
        };

        # TEST*$bad_count*$method_count
        pass("$method survives $desc without crashing");
    }
}
