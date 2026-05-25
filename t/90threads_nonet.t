# -*- cperl -*-

use strict;
use warnings;

use Test::More;
use Config;

use constant MAX_THREADS => 10;
use constant MAX_LOOP => 50;

BEGIN
{
    my $will_run = 0;
    if ( $Config{useithreads} )
    {
        if ($ENV{THREAD_TEST})
        {
            require threads;
            require threads::shared;
            $will_run = 1;
        }
        else
        {
            plan skip_all => "optional (set THREAD_TEST=1 to run these tests)";
        }
    }
    else
    {
        plan skip_all => "no ithreads in this Perl";
    }

    if ($will_run)
    {
        plan tests => 2;
    }
}

use XML::LibXML qw(:threads_shared);

# GH #147: The 5 Schema/RelaxNG NONET swap sites temporarily replace the
# process-global entity loader.  Without mutex protection, concurrent threads
# can race to corrupt the saved/restored loader pointer.

my $rng_schema = <<'EOF';
<grammar xmlns="http://relaxng.org/ns/structure/1.0">
<start>
  <element name="foo"><empty/></element>
</start>
</grammar>
EOF

{
    for (1..MAX_THREADS)
    {
        threads->new(sub {
            for (1..MAX_LOOP)
            {
                eval {
                    XML::LibXML::RelaxNG->new(
                        string => $rng_schema,
                        no_network => 1,
                    );
                };
            }
            return 1;
        });
    }
    $_->join for (threads->list);
    # TEST
    ok(1, "concurrent RelaxNG parsing with no_network");
}

my $xsd_schema = <<'EOF';
<?xml version="1.0"?>
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:element name="foo"/>
</xsd:schema>
EOF

{
    for (1..MAX_THREADS)
    {
        threads->new(sub {
            for (1..MAX_LOOP)
            {
                eval {
                    XML::LibXML::Schema->new(
                        string => $xsd_schema,
                        no_network => 1,
                    );
                };
            }
            return 1;
        });
    }
    $_->join for (threads->list);
    # TEST
    ok(1, "concurrent Schema parsing with no_network");
}
