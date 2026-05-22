use strict;
use warnings;

# Regression test for RT #96384 / GH #221:
# Non-numeric ExtUtils::MakeMaker versions (e.g. '6.57_05') must not
# crash the version checks in Makefile.PL.

use Test::More tests => 4;

use ExtUtils::MakeMaker;

my @thresholds = ('6.31', '6.46', '6.48', '6.52');

{
    local $ExtUtils::MakeMaker::VERSION = '6.57_05';

    for my $threshold (@thresholds) {
        # TEST*4
        my $ok = eval { ExtUtils::MakeMaker->VERSION($threshold); 1 };
        ok($ok, "EU::MM '6.57_05' satisfies ->VERSION('$threshold') without dying");
    }
}
