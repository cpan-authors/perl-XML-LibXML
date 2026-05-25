# Test that libxml2 callbacks never croak (longjmp) past cleanup code.
# See GH #258: croak in callbacks skips LibXML_cleanup_parser, leaking
# parser state and potentially corrupting the entity loader.

use warnings;
use strict;

use Test::More;
use XML::LibXML;

if (XML::LibXML::LIBXML_VERSION() < 20627)
{
    plan skip_all => "skipping for libxml2 < 2.6.27";
}
else
{
    plan tests => 12;
}

# XML that triggers external entity loading
my $xml_with_entity = <<'EOF';
<?xml version="1.0"?>
<!DOCTYPE foo [
<!ENTITY ext SYSTEM "file:///nonexistent">
]>
<root>&ext;</root>
EOF

# --- Per-parser ext_ent_handler that dies ---

# TEST
{
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        ext_ent_handler => sub { die "handler died\n" },
    });

    my $ok = eval { $parser->parse_string($xml_with_entity); 1 };
    ok(!$ok, "parse_string dies when ext_ent_handler dies");
}

# TEST
{
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        ext_ent_handler => sub { die "handler died\n" },
    });

    eval { $parser->parse_string($xml_with_entity) };
    like($@, qr/handler died/, "original exception preserved from ext_ent_handler");
}

# Parser still works after a callback exception
# TEST
{
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        ext_ent_handler => sub { die "handler died\n" },
    });

    eval { $parser->parse_string($xml_with_entity) };

    # Parse something simple — should work fine
    my $doc = eval { $parser->parse_string('<ok/>') };
    ok($doc, "parser works after ext_ent_handler exception");
}

# --- Global externalEntityLoader that dies ---

# TEST
{
    XML::LibXML::externalEntityLoader(sub { die "global handler died\n" });
    my $parser = XML::LibXML->new({ expand_entities => 1 });

    my $ok = eval { $parser->parse_string($xml_with_entity); 1 };
    ok(!$ok, "parse_string dies when global entity loader dies");
    XML::LibXML::externalEntityLoader(undef);
}

# TEST
{
    XML::LibXML::externalEntityLoader(sub { die "global handler died\n" });
    my $parser = XML::LibXML->new({ expand_entities => 1 });

    eval { $parser->parse_string($xml_with_entity) };
    like($@, qr/global handler died/,
         "original exception preserved from global entity loader");
    XML::LibXML::externalEntityLoader(undef);
}

# Parser works after global loader exception
# TEST
{
    XML::LibXML::externalEntityLoader(sub { die "global handler died\n" });
    my $parser = XML::LibXML->new({ expand_entities => 1 });

    eval { $parser->parse_string($xml_with_entity) };
    XML::LibXML::externalEntityLoader(undef);

    my $doc = eval { $parser->parse_string('<ok/>') };
    ok($doc, "parser works after global entity loader exception");
}

# --- ext_ent_handler that returns a value still works ---

# TEST
{
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        ext_ent_handler => sub { return "replaced" },
    });

    my $doc = $parser->parse_string($xml_with_entity);
    like($doc->toString(), qr/replaced/,
         "ext_ent_handler returning value still works");
}

# --- Verify cleanup: second parse after exception uses correct loader ---

# TEST
{
    my $call_count = 0;
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        ext_ent_handler => sub {
            $call_count++;
            if ($call_count == 1) {
                die "first call dies\n";
            }
            return "second-call-ok";
        },
    });

    eval { $parser->parse_string($xml_with_entity) };

    my $doc = $parser->parse_string($xml_with_entity);
    like($doc->toString(), qr/second-call-ok/,
         "entity loader restored after exception - second parse works");
}

# --- SAX parser callback exception ---

# TEST
{
    my $have_sax = eval {
        require XML::SAX;
        require XML::LibXML::SAX::Parser;
        1;
    };
    SKIP: {
        skip "XML::SAX not available", 2 if !$have_sax;

        {
            package DyingHandler;
            use parent 'XML::SAX::Base';
            sub start_element {
                my ($self, $el) = @_;
                die "SAX handler died in start_element\n"
                    if $el->{LocalName} eq 'boom';
                $self->SUPER::start_element($el);
            }
        }

        my $handler = DyingHandler->new();
        my $parser = XML::LibXML::SAX::Parser->new(Handler => $handler);

        my $ok = eval {
            $parser->parse_string('<root><boom/></root>');
            1;
        };
        # TEST
        ok(!$ok, "SAX parse dies when handler dies");
        # TEST
        like($@, qr/SAX handler died/,
             "SAX handler exception preserved");
    }
}

# --- Verify no double-free / corruption with multiple error sources ---

# TEST
{
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        ext_ent_handler => sub { die "entity error\n" },
        recover => 0,
    });

    eval { $parser->parse_string($xml_with_entity) };
    ok(defined $@, "error reported with no recover and dying handler");
}

# --- Parse file handle with dying entity handler ---

# TEST
{
    my $parser = XML::LibXML->new({
        expand_entities => 1,
        ext_ent_handler => sub { die "fh handler died\n" },
    });

    open my $fh, '<', \$xml_with_entity or die;
    my $ok = eval { $parser->parse_fh($fh); 1 };
    ok(!$ok, "parse_fh dies when ext_ent_handler dies");
    close $fh;
}
