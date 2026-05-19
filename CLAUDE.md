# CLAUDE.md

## Project Overview

XML::LibXML is a Perl XS binding to the Gnome libxml2 C library, providing a full DOM, XPath, SAX, RelaxNG/Schema validation, and streaming Reader interface for XML processing. It is a mature CPAN distribution.

## Build and Test

```bash
perl Makefile.PL          # Configure (detects libxml2 via Alien::Libxml2)
make                      # Compile XS/C code
make test                 # Run test suite (~80 test files)
make install              # Install module + register SAX parsers
make docs                 # Regenerate POD from docs/libxml.dbk (requires xsltproc)
```

**Build options:**
- `XMLPREFIX=/path` — use a custom libxml2 installation
- `SKIP_SAX_INSTALL=1` — skip SAX parser registration during install

**System dependencies:** libxml2 development headers (e.g. `libxml2-dev` on Debian/Ubuntu).

## Architecture

```
LibXML.pm + lib/XML/LibXML/*.pm   (Perl API)
        ↓
LibXML.xs / Devel.xs              (XS binding layer)
        ↓
dom.c, perl-libxml-mm.c,          (C wrappers: DOM ops, memory mgmt,
 perl-libxml-sax.c, xpath.c)       SAX handlers, XPath helpers)
        ↓
libxml2                           (system C library)
```

### Key source files

| File | Role |
|------|------|
| `LibXML.pm` | Main module — parser creation, config, proxy node registry, constants |
| `LibXML.xs` | XS bindings — DOM, parsing, XPath, SAX, Reader, error handling |
| `dom.c` / `dom.h` | DOM wrapper functions (node ops, namespace reconciliation) |
| `perl-libxml-mm.c` / `.h` | ProxyNode memory management, UTF-8 conversion, ref counting |
| `perl-libxml-sax.c` / `.h` | SAX event handler dispatch to Perl callbacks |
| `xpath.c` / `xpath.h` | XPath context management, function/variable registration |
| `typemap` | XS type mappings between C and Perl types |

### Key Perl modules (`lib/XML/LibXML/`)

- `Reader.pm` — streaming XML reader (requires libxml2 >= 2.6.21)
- `SAX.pm`, `SAX/*.pm` — SAX parser interface (requires XML::SAX)
- `XPathContext.pm` — advanced XPath with registered functions/variables
- `Error.pm` — structured error/exception handling
- `NodeList.pm` — node collection with iterator support
- `Common.pm` — shared encoding utilities and constants

## Testing

- Framework: `Test::More` with `Test::Count` annotations (`# TEST` markers)
- Test data lives in `t/` (test scripts) and `test/` (XML fixtures, schemas, DTDs)
- Helper modules in `t/lib/` (TestHelpers.pm, Counter.pm, etc.)
- Tests must **not** access external network resources
- Developer/release tests (pod, kwalitee, trailing-space) run when `AUTHOR_TESTING=1`

## Compatibility

- **Perl:** 5.8.1+ required
- **libxml2:** 2.6.16+ required; features conditionally compiled based on version:
  - `HAVE_SCHEMAS` (>= 2.5.10) — RelaxNG and XML Schema
  - `HAVE_READER_SUPPORT` / `WITH_SERRORS` (>= 2.6.21) — Reader API, structured errors
- **Threads:** optional support via `:threads_shared` import tag

### libxml2 versions in the wild

The same XML::LibXML build can behave very differently depending on the linked libxml2. Distros span a wide range:

- **2.9.x** — RHEL 7–9, Ubuntu LTS up to 24.04, Debian 11–13, Alpine ≤ 3.16. Still the most common in production. RHEL 7 ELS pins 2.9.1 (2013); most others pin 2.9.10 / 2.9.13 / 2.9.14 with backported CVE fixes.
- **2.10–2.13** — Fedora, Alpine 3.17–3.21, openSUSE Leap, RHEL 10, Debian sid.
- **2.14–2.15** — Arch, FreeBSD/OpenBSD/NetBSD, Homebrew/MacPorts, openSUSE Tumbleweed, Ubuntu 26.04 dev.

Notable upstream milestones (helpful when triaging bug reports):
- **2.11.0** (2023-04) — major entity-expansion-attack hardening
- **2.12.0** (2023-11) — quadratic-parsing fixes across the XML parser
- **2.13.0** (2024-06) — reliable malloc-failure reporting in core code
- **2.14.0** (2025-03) — full HTML5 tokenizer conformance

Ask bug reporters for the linked libxml2 version: `perl -MXML::LibXML -E 'say XML::LibXML::LIBXML_DOTTED_VERSION'`. A failing test on RHEL 8 (2.9.7) is often a fixed-upstream bug, not an XML::LibXML bug.

Quirk: Debian trixie's package version reads `2.12.7+really2.9.14` — the binary is actually **2.9.14**, not 2.12.x (Debian's "+really" downgrade convention). Repology and naive version checks will mislead.

See the wiki for full tables:
- [libxml2 release history](https://github.com/cpan-authors/XML-LibXML/wiki/libxml2-hist) — every upstream release 2016–present
- [libxml2 distro versions](https://github.com/cpan-authors/XML-LibXML/wiki/libxml2-distro-versions) — per-distro shipped versions and lag

## Coding Conventions

### C code (from HACKING.txt)
- 4-space indent, no tabs
- Opening braces on separate line
- snake_case identifiers; type names end in `_t`, struct names in `_struct`
- No declarations after statements
- Always use braces for if/while blocks

### Perl code
- Avoid `unless`, `until` — use `if !` / `if not`
- Avoid trailing statement modifiers

### XS code (`LibXML.xs`, `Devel.xs`)
- Comments **between XSUB definitions** (XS top level) must use `#` line comments, not C-style `/* */`. `xsubpp` parses lines starting with ` *` as function-definition attempts and fails with `Cannot parse function definition`. C-style comments are only safe inside `CODE:` / `PREINIT:` blocks and in the C preamble before the first `MODULE =` line.
- Always run `make` locally after editing `.xs` files — `xsubpp` errors are not caught by Perl syntax checks.

### General
- External DTD/entity loading is disabled by default (security)

## Contributing Guidelines

- All changes **must pass CI** before being submitted
- Keep changes **focused on the requested fix** — do not add unrelated cleanup, refactoring, or scope expansion
- Do **not** edit or re-sort `MANIFEST` — it is generated by `make manifest`
- Do **not** edit `README.md` — it is generated from the primary module's POD via `pod2markdown LibXML.pm > README.md`. Update the POD instead.
- Do **not** bump the version number or modify `Changes` — releases are performed by a human maintainer; bug fixes and feature PRs must never touch versioning or the changelog

## CI

GitHub Actions (`.github/workflows/ci.yml`):
- **author-testing** — full release tests on Ubuntu (`make docs`, `make disttest`)
- **linux** — matrix across Perl 5.8 through devel via perldocker containers
- **macOS** — system Perl compatibility check

## Dependencies

**Runtime:** Alien::Libxml2 (>= 0.14), XML::SAX (>= 0.11), XML::SAX::Base, XML::NamespaceSupport (>= 1.07)
**Build:** Alien::Base::Wrapper, ExtUtils::MakeMaker
