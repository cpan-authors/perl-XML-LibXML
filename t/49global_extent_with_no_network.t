use strict;
use warnings;

# Contract enforced here (see CLAUDE.md "Entity loaders"):
#   externalEntityLoader(\&cb) is an explicit opt-out of libxml2's network
#   policy. Once installed, the callback receives every external-entity URL,
#   including network URLs, *regardless* of no_network on the parser.
#
# This file locks that contract in across:
#   - plain XML parsing (DTD entity references)
#   - RelaxNG parsing (<include href="http://..."/>)
#   - XML Schema parsing (<xs:import schemaLocation="http://..."/>)
#
# and the inverse: when no loader is installed, no_network still blocks
# network URLs through libxml2's default loader.
#
# Regression target: GH #143 (reverted), which both filtered URLs inside
# LibXML_load_external_entity and removed the EXTERNAL_ENTITY_LOADER_FUNC
# guards on the 5 Schema/RelaxNG NONET swap sites.

use Test::More;
use XML::LibXML;

if (XML::LibXML::LIBXML_VERSION() < 20627) {
    plan skip_all => "skipping for libxml2 < 2.6.27";
}
else {
    plan tests => 17;
}

# Always tear down between subtests so process-global state never leaks.
sub _reset_global_loader {
    XML::LibXML::externalEntityLoader(undef);
}

# ---------------------------------------------------------------------------
# Plain-parse XML fixtures
# ---------------------------------------------------------------------------

my $xml_http = <<'EOF';
<?xml version="1.0"?>
<!DOCTYPE foo [
<!ENTITY a SYSTEM "http:///invalid-url-http">
]>
<root>&a;</root>
EOF

my $xml_https = <<'EOF';
<?xml version="1.0"?>
<!DOCTYPE foo [
<!ENTITY a SYSTEM "https:///invalid-url-https">
]>
<root>&a;</root>
EOF

my $xml_ftp = <<'EOF';
<?xml version="1.0"?>
<!DOCTYPE foo [
<!ENTITY a SYSTEM "ftp:///invalid-url-ftp">
]>
<root>&a;</root>
EOF

my $xml_mixed_schemes = <<'EOF';
<?xml version="1.0"?>
<!DOCTYPE foo [
<!ENTITY g SYSTEM "gopher://example.invalid/g">
<!ENTITY d SYSTEM "dict://example.invalid/d">
<!ENTITY x SYSTEM "xmpp://example.invalid/x">
]>
<root><a>&g;</a><b>&d;</b><c>&x;</c></root>
EOF

my $xml_multi = <<'EOF';
<?xml version="1.0"?>
<!DOCTYPE foo [
<!ENTITY a SYSTEM "http:///url-a">
<!ENTITY b SYSTEM "https:///url-b">
<!ENTITY c SYSTEM "ftp:///url-c">
]>
<root><x>&a;</x><y>&b;</y><z>&c;</z></root>
EOF

my $xml_public = <<'EOF';
<?xml version="1.0"?>
<!DOCTYPE foo [
<!ENTITY p PUBLIC "//public/id" "http:///system-url">
]>
<root>&p;</root>
EOF

# ---------------------------------------------------------------------------
# 1. http:// entity reaches the global loader when no_network is set
# ---------------------------------------------------------------------------
# TEST
subtest "global loader receives http:// URL despite no_network" => sub {
    plan tests => 3;
    my $got_url;
    XML::LibXML::externalEntityLoader(sub {
        my ($url, $id) = @_;
        $got_url = $url;
        return "<!-- loaded -->";
    });
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    my $doc;
    my $err = do { local $@; eval { $doc = $parser->parse_string($xml_http) }; $@ };
    is($err, '', "no error when loader handles the URL");
    is($got_url, 'http:///invalid-url-http', "loader received the http URL");
    like($doc && $doc->toString(), qr/loaded/, "loader content was substituted");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 2. https:// entity reaches the global loader when no_network is set
# ---------------------------------------------------------------------------
# TEST
subtest "global loader receives https:// URL despite no_network" => sub {
    plan tests => 2;
    my $got_url;
    XML::LibXML::externalEntityLoader(sub { $got_url = $_[0]; return "<!-- ok -->" });
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $parser->parse_string($xml_https) };
    is($@, '', "no error");
    is($got_url, 'https:///invalid-url-https', "loader received the https URL");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 3. ftp:// entity reaches the global loader when no_network is set
# ---------------------------------------------------------------------------
# TEST
subtest "global loader receives ftp:// URL despite no_network" => sub {
    plan tests => 2;
    my $got_url;
    XML::LibXML::externalEntityLoader(sub { $got_url = $_[0]; return "<!-- ok -->" });
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $parser->parse_string($xml_ftp) };
    is($@, '', "no error");
    is($got_url, 'ftp:///invalid-url-ftp', "loader received the ftp URL");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 4. Schemes outside http/https/ftp also reach the loader (no scheme allowlist
#    should exist anywhere in the dispatch path).
# ---------------------------------------------------------------------------
# TEST
subtest "global loader receives non-http schemes too" => sub {
    plan tests => 4;
    my @urls;
    XML::LibXML::externalEntityLoader(sub { push @urls, $_[0]; return "<!-- ok -->" });
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $parser->parse_string($xml_mixed_schemes) };
    is($@, '', "no error");
    ok((grep { $_ eq 'gopher://example.invalid/g' } @urls), "gopher URL reached loader");
    ok((grep { $_ eq 'dict://example.invalid/d' }   @urls), "dict URL reached loader");
    ok((grep { $_ eq 'xmpp://example.invalid/x' }   @urls), "xmpp URL reached loader");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 5. All entity URLs in a single document reach the loader.
# ---------------------------------------------------------------------------
# TEST
subtest "global loader receives every entity URL in one document" => sub {
    plan tests => 5;
    my @urls;
    XML::LibXML::externalEntityLoader(sub {
        push @urls, $_[0];
        my $tag = $_[0];
        $tag =~ s{[^A-Za-z0-9]+}{_}g;
        return "<v>$tag</v>";
    });
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    my $doc;
    eval { $doc = $parser->parse_string($xml_multi) };
    is($@, '', "no error");
    is(scalar(@urls), 3, "loader called once per external entity");
    ok((grep { $_ eq 'http:///url-a'  } @urls), "url-a reached loader");
    ok((grep { $_ eq 'https:///url-b' } @urls), "url-b reached loader");
    ok((grep { $_ eq 'ftp:///url-c'   } @urls), "url-c reached loader");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 6. PUBLIC identifiers are passed alongside the SYSTEM URL.
# ---------------------------------------------------------------------------
# TEST
subtest "global loader receives PUBLIC id with no_network" => sub {
    plan tests => 3;
    my ($url, $pubid);
    XML::LibXML::externalEntityLoader(sub {
        ($url, $pubid) = @_;
        return "<!-- ok -->";
    });
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $parser->parse_string($xml_public) };
    is($@, '', "no error");
    is($url,   'http:///system-url', "loader received the SYSTEM URL");
    is($pubid, '//public/id',        "loader received the PUBLIC identifier");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 7. Loader exceptions propagate.
# ---------------------------------------------------------------------------
# TEST
subtest "loader croak propagates through libxml2 with no_network" => sub {
    plan tests => 2;
    XML::LibXML::externalEntityLoader(sub { die "loader-boom\n" });
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    my $doc;
    eval { $doc = $parser->parse_string($xml_http) };
    ok($@, "parse failed");
    is($doc, undef, "doc not produced");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 8. Per-parser ext_ent_handler still receives network URLs under no_network.
#    (The contract applies to per-parser handlers too: ext_ent_handler is also
#    an explicit opt-in by the user.)
# ---------------------------------------------------------------------------
# TEST
subtest "per-parser ext_ent_handler receives http URL under no_network" => sub {
    plan tests => 2;
    my $got_url;
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        no_network      => 1,
        ext_ent_handler => sub { $got_url = $_[0]; return "<!-- ok -->" },
    });
    eval { $parser->parse_string($xml_http) };
    is($@, '', "no error");
    is($got_url, 'http:///invalid-url-http', "per-parser handler received the http URL");
    # no global loader was set, so nothing to reset
};

# ---------------------------------------------------------------------------
# 9. Global loader overrides per-parser handler when both are set + no_network.
# ---------------------------------------------------------------------------
# TEST
subtest "global loader takes precedence over ext_ent_handler under no_network" => sub {
    plan tests => 3;
    my ($global_called, $private_called) = (0, 0);
    XML::LibXML::externalEntityLoader(sub { $global_called++; return "<g/>" });
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        no_network      => 1,
        ext_ent_handler => sub { $private_called++; return "<p/>" },
    });
    my $doc;
    eval { $doc = $parser->parse_string($xml_http) };
    is($@, '', "no error");
    is($global_called,  1, "global loader was invoked");
    is($private_called, 0, "per-parser handler was not invoked");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 10. After clearing the global loader, no_network blocks network URLs again.
# ---------------------------------------------------------------------------
# TEST
subtest "no_network blocks network URLs once the global loader is cleared" => sub {
    plan tests => 3;
    # Install, parse, clear.
    XML::LibXML::externalEntityLoader(sub { return "<!-- ok -->" });
    my $p1 = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $p1->parse_string($xml_http) };
    is($@, '', "global loader handled the URL while installed");

    _reset_global_loader();

    my $p2 = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    my $doc;
    eval { $doc = $p2->parse_string($xml_http) };
    ok($@,            "no_network now blocks the network entity");
    is($doc, undef,  "doc not produced after clearing the loader");
};

# ---------------------------------------------------------------------------
# 11. set -> clear -> set cycle, each phase under no_network.
# ---------------------------------------------------------------------------
# TEST
subtest "set/clear/set cycle preserves the contract on each phase" => sub {
    plan tests => 5;
    my $calls = 0;
    XML::LibXML::externalEntityLoader(sub { $calls++; return "<!-- ok -->" });

    my $p_a = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $p_a->parse_string($xml_http) };
    is($@,     '', "phase 1: loader installed - parse OK");
    is($calls, 1,  "phase 1: loader invoked once");

    _reset_global_loader();
    my $p_b = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $p_b->parse_string($xml_http) };
    ok($@, "phase 2: loader cleared - parse fails");

    XML::LibXML::externalEntityLoader(sub { $calls++; return "<!-- ok again -->" });
    my $p_c = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    eval { $p_c->parse_string($xml_http) };
    is($@,     '', "phase 3: loader reinstalled - parse OK");
    is($calls, 2,  "phase 3: loader invoked again");

    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 12. Baseline regression check: no_network without any loader still blocks.
# ---------------------------------------------------------------------------
# TEST
subtest "no_network + no loader still blocks network URLs (default-loader path)" => sub {
    plan tests => 2;
    _reset_global_loader();   # paranoia in case a prior test leaked
    my $parser = XML::LibXML->new({ expand_entities => 1, no_network => 1 });
    my $doc;
    eval { $doc = $parser->parse_string($xml_http) };
    ok($@,           "parse fails with no_network and no callback");
    is($doc, undef, "no doc produced");
};

# ---------------------------------------------------------------------------
# Schema / RelaxNG fixtures.
# Use string=> so the only entity load is the http:// include/import — that's
# the path the EXTERNAL_ENTITY_LOADER_FUNC guard at the 5 NONET swap sites in
# LibXML.xs protects.
# ---------------------------------------------------------------------------
my $rng_with_http_include = <<'EOF';
<?xml version="1.0" encoding="iso-8859-1"?>
<grammar xmlns="http://relaxng.org/ns/structure/1.0">
  <include href="http://example.invalid/inner.rng"/>
  <start><ref name="root"/></start>
</grammar>
EOF

my $rng_included = <<'EOF';
<?xml version="1.0" encoding="iso-8859-1"?>
<grammar xmlns="http://relaxng.org/ns/structure/1.0">
  <define name="root">
    <element name="root"><text/></element>
  </define>
</grammar>
EOF

my $xsd_with_http_import = <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns:ext="http://example.invalid/ns">
  <xsd:import namespace="http://example.invalid/ns"
              schemaLocation="http://example.invalid/inner.xsd"/>
  <xsd:element name="root" type="xsd:string"/>
</xsd:schema>
EOF

my $xsd_imported = <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="http://example.invalid/ns">
  <xsd:element name="ext" type="xsd:string"/>
</xsd:schema>
EOF

# ---------------------------------------------------------------------------
# 13. RelaxNG: no_network + no loader - the http include is blocked.
#     Regression check that we didn't break the default-loader path.
# ---------------------------------------------------------------------------
# TEST
subtest "RelaxNG no_network + no loader blocks http include" => sub {
    plan tests => 2;
    _reset_global_loader();
    my $rng = eval {
        XML::LibXML::RelaxNG->new(string => $rng_with_http_include, no_network => 1)
    };
    ok($@,           "RelaxNG parse failed");
    is($rng, undef, "no RelaxNG produced");
};

# ---------------------------------------------------------------------------
# 14. RelaxNG: no_network + global loader - the http include reaches the loader.
#     This is the test that locks in the EXTERNAL_ENTITY_LOADER_FUNC guard at
#     the 2 RelaxNG NONET swap sites in LibXML.xs.
# ---------------------------------------------------------------------------
# TEST
subtest "RelaxNG no_network + global loader: include URL reaches loader" => sub {
    plan tests => 3;
    my @urls;
    XML::LibXML::externalEntityLoader(sub {
        my ($url) = @_;
        push @urls, $url;
        return $rng_included if $url eq 'http://example.invalid/inner.rng';
        return "";
    });
    my $rng = eval {
        XML::LibXML::RelaxNG->new(string => $rng_with_http_include, no_network => 1)
    };
    is($@, '', "RelaxNG parse succeeded with global loader");
    ok(defined $rng, "RelaxNG object created");
    ok((grep { $_ eq 'http://example.invalid/inner.rng' } @urls),
        "loader received the http include URL during RelaxNG parsing");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 15. Schema: no_network + no loader - the http import is blocked.
# ---------------------------------------------------------------------------
# TEST
subtest "Schema no_network + no loader blocks http import" => sub {
    plan tests => 2;
    _reset_global_loader();
    my $xsd = eval {
        XML::LibXML::Schema->new(string => $xsd_with_http_import, no_network => 1)
    };
    ok($@,           "Schema parse failed");
    is($xsd, undef, "no Schema produced");
};

# ---------------------------------------------------------------------------
# 16. Schema: no_network + global loader - the http import reaches the loader.
#     Locks in the EXTERNAL_ENTITY_LOADER_FUNC guard at the 3 Schema NONET swap
#     sites in LibXML.xs.
# ---------------------------------------------------------------------------
# TEST
subtest "Schema no_network + global loader: import URL reaches loader" => sub {
    plan tests => 3;
    my @urls;
    XML::LibXML::externalEntityLoader(sub {
        my ($url) = @_;
        push @urls, $url;
        return $xsd_imported if $url eq 'http://example.invalid/inner.xsd';
        return "";
    });
    my $xsd = eval {
        XML::LibXML::Schema->new(string => $xsd_with_http_import, no_network => 1)
    };
    is($@, '', "Schema parse succeeded with global loader");
    ok(defined $xsd, "Schema object created");
    ok((grep { $_ eq 'http://example.invalid/inner.xsd' } @urls),
        "loader received the http import URL during Schema parsing");
    _reset_global_loader();
};

# ---------------------------------------------------------------------------
# 17. Schema/RelaxNG cleanup symmetry: after clearing the global loader,
#     no_network blocks Schema/RelaxNG network imports again. Proves the
#     NONET-swap restore path still works once the guard is no longer engaged.
# ---------------------------------------------------------------------------
# TEST
subtest "after clearing global loader, Schema/RelaxNG no_network blocks again" => sub {
    plan tests => 4;

    XML::LibXML::externalEntityLoader(sub { return $rng_included });
    my $ok_rng = eval {
        XML::LibXML::RelaxNG->new(string => $rng_with_http_include, no_network => 1)
    };
    ok(defined $ok_rng, "RelaxNG built while loader was installed");

    _reset_global_loader();

    my $bad_rng = eval {
        XML::LibXML::RelaxNG->new(string => $rng_with_http_include, no_network => 1)
    };
    ok(!defined $bad_rng, "RelaxNG blocked after loader cleared");

    XML::LibXML::externalEntityLoader(sub { return $xsd_imported });
    my $ok_xsd = eval {
        XML::LibXML::Schema->new(string => $xsd_with_http_import, no_network => 1)
    };
    ok(defined $ok_xsd, "Schema built while loader was installed");

    _reset_global_loader();

    my $bad_xsd = eval {
        XML::LibXML::Schema->new(string => $xsd_with_http_import, no_network => 1)
    };
    ok(!defined $bad_xsd, "Schema blocked after loader cleared");
};

END {
    # Final paranoia: never leave a global loader installed after this file.
    eval { XML::LibXML::externalEntityLoader(undef) };
}
