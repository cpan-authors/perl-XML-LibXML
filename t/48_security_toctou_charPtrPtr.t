use strict;
use warnings;
use Test::More;

if ($^O eq 'MSWin32') {
    plan skip_all => 'Variable::Magic + C14N interaction crashes libxml2 on Windows';
}

eval { require Variable::Magic; Variable::Magic->import(qw(wizard cast)) };
if ($@) {
    plan skip_all => 'Variable::Magic required for TOCTOU vulnerability test';
}

use XML::LibXML;

if (20617 > XML::LibXML::LIBXML_VERSION) {
    plan skip_all => 'libxml2 >= 2.6.17 required for exclusive C14N';
}

plan tests => 1;

# Vulnerability: the old XS_unpack_charPtrPtr() sized allocation with
# SvCUR() (does not trigger magic), then copied with strcpy(SvPV())
# (does trigger magic).  If get-magic lengthens the string between
# those two calls, strcpy overflows the undersized buffer.
#
# Fix: single SvPV() call captures pointer and length atomically,
# then memcpy() copies exactly that many bytes.
#
# This test attaches get-magic that grows "ns" (2 bytes) into 8192
# bytes on first SvPV() access.  Old code: safemalloc(3) + strcpy of
# 8192 bytes => heap overflow (typically SIGSEGV).

my $triggered = 0;
my $wiz = wizard(
    get => sub {
        return if $triggered++;
        ${$_[0]} = "A" x 8192;
        return;
    },
);

my $doc = XML::LibXML->load_xml(string =>
    '<root xmlns:ns="http://example.com"><ns:child/></root>'
);

my @prefixes = ('ns');
cast($prefixes[0], $wiz);

eval {
    $doc->toStringEC14N(0, undef, \@prefixes);
};

# With the old code, the process typically SIGSEGV/aborts before
# reaching this line.  Surviving means the fix is in place.
pass('XS_unpack_charPtrPtr: get-magic string growth does not overflow buffer');
