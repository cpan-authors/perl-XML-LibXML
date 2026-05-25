use strict;
use warnings;
use Test::More tests => 1;
use XML::LibXML;
use XML::LibXML::Devel;

# GH #148: PmmContextREFCNT_dec must not xmlFree the proxy node when
# refcount is still positive.  Before the fix, xmlFree(node) sat outside
# the "if (refcount <= 0)" guard, so every decrement freed the proxy
# regardless of remaining references — a latent use-after-free.
#
# _test_context_refcnt_dec_double() creates a context proxy with
# count=2, decrements once, then reads the refcount (must be 1).
# With the old code the read hits freed memory → crash or wrong value.

# TEST
is(
    XML::LibXML::Devel::_test_context_refcnt_dec_double(), 1,
    'PmmContextREFCNT_dec preserves proxy when refcount > 0 (GH #148)',
);
