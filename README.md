[![CI](https://github.com/cpan-authors/XML-LibXML/actions/workflows/ci.yml/badge.svg)](https://github.com/cpan-authors/XML-LibXML/actions/workflows/ci.yml)

# Introduction

This module implements a Perl interface to the Gnome libxml2 library which
provides interfaces for parsing and manipulating XML files. This module allows
Perl programmers to make use of its highly capable validating XML parser and
its high performance DOM implementation.


# Important Notes

XML::LibXML was almost entirely reimplemented between version 1.40 to version
1.49. This may cause problems on some production machines. With version 1.50 a
lot of compatibility fixes were applied, so programs written for XML::LibXML
1.40 or less should run with version 1.50 again.

In 1.59, a new callback API was introduced. This new API is not compatible with
the previous one. See `XML::LibXML::InputCallback` manual page for details.

In 1.61 the `XML::LibXML::XPathContext` module, previously distributed
separately, was merged in.

An experimental support for Perl threads introduced in 1.66 has been replaced
in 1.67.


# Dependencies

Prior to installation you MUST have installed the libxml2 library. You can get
the latest libxml2 version from <https://gitlab.gnome.org/GNOME/libxml2>.

Without libxml2 installed this module will neither build nor run.

Also XML::LibXML requires the following packages:

- `XML::SAX` — base class for SAX parsers
- `XML::NamespaceSupport` — namespace support for SAX parsers

These packages are required. If one is missing some tests will fail.

Again, libxml2 is required to make XML::LibXML work. The library is not just
required to build XML::LibXML, it has to be accessible during run-time as well.
Because of this you need to make sure libxml2 is installed properly. To test
this, run the `xmllint` program on your system. `xmllint` is shipped with libxml2
and therefore should be available. For building the module you will also need
the header file for libxml2, which in binary (`.rpm`, `.deb`) etc. distributions
usually dwell in a package named `libxml2-devel` or similar.


# Installation

(These instructions are for UNIX and GNU/Linux systems. For MSWin32, see
[Notes for Microsoft Windows](#notes-for-microsoft-windows) below.)

To install XML::LibXML just follow the standard installation routine for Perl
modules:

```sh
perl Makefile.PL
make
make test
make install   # as superuser
```

Note that XML::LibXML is an XS based Perl extension and you need a C compiler
to build it.

Note also that you should rebuild XML::LibXML if you upgrade libxml2 in order
to avoid problems with possible binary incompatibilities between releases of
the library.


# Notes on libxml2 versions

XML::LibXML requires at least libxml2 2.6.16 to compile and pass all tests and
at least 2.6.21 is required for `XML::LibXML::Reader`. For some older OS versions
this means that an update of the pre-built packages is required.

Although libxml2 claims binary compatibility between its patch levels, it is a
good idea to recompile XML::LibXML and run its tests after an upgrade of
libxml2.

If your libxml2 installation is not within your `$PATH`, you can pass the
`XMLPREFIX=$YOURLIBXMLPREFIX` parameter to `Makefile.PL` determining the correct
libxml2 version in use. e.g.

```sh
perl Makefile.PL XMLPREFIX=/usr/brand-new
```

will ask `/usr/brand-new/bin/xml2-config` about your real libxml2
configuration.

Try to avoid setting `INC` and `LIBS` directly on the command-line, for if used,
`Makefile.PL` does not check the libxml2 version for compatibility with
XML::LibXML.


# Which version of libxml2 should be used?

XML::LibXML is tested against a couple versions of libxml2 before it is
released. Thus there are versions of libxml2 that are known not to work
properly with XML::LibXML. The `Makefile.PL` keeps a blacklist of the
incompatible libxml2 versions using `Alien::Libxml2`. The blacklist itself is
kept inside its `alienfile` file.

If `Makefile.PL` detects one of the incompatible versions, it notifies the user.
It may still happen that XML::LibXML builds and pass its tests with such a
version, but that does not mean everything is OK. There will be no support at
all for blacklisted versions!

As of XML::LibXML 1.61, only versions 2.6.16 and higher are supported.
XML::LibXML will probably not compile with earlier libxml2 versions than 2.5.6.
Versions prior to 2.6.8 are known to be broken for various reasons, versions
prior to 2.1.16 exhibit problems with namespaced attributes and do not
therefore pass XML::LibXML regression tests.

It may happen that an unsupported version of libxml2 passes all tests under
certain conditions. This is no reason to assume that it shall work without
problems. If `Makefile.PL` marks a version of libxml2 as incompatible or broken
it is done for a good reason.

Full linking information for libxml2 can be obtained by invoking
`xml2-config --libs`.


# Notes for Microsoft Windows

On Windows, the recommended way to install XML::LibXML is via
[Strawberry Perl](https://strawberryperl.com/), which ships with a working
toolchain and pulls in libxml2 automatically through `Alien::Libxml2`.

If you need to build against a custom libxml2, pre-built Windows binaries are
available from <https://www.zlatkovic.com/pub/libxml/>.


# Notes for macOS

XML::LibXML builds and runs on supported versions of macOS. libxml2 is
generally available either via the system, [Homebrew](https://brew.sh/)
(`brew install libxml2`), or installed automatically by `Alien::Libxml2`.


# Notes for HPUX

XML::LibXML requires libxml2 2.6.16 or later. There may not exist a usable
binary libxml2 package for HPUX and XML::LibXML. If HPUX `cc` does not compile
libxml2 correctly, you will be forced to recompile perl with `gcc` (unless you
have already done that).

Additionally I received the following Note from Rozi Kovesdi:

> Here is my report if someone else runs into the same problem:
>
> Finally I am done with installing all the libraries and XML Perl
> modules
>
> The combination that worked best for me was:
> gcc
> GNU make
>
> Most importantly - before trying to install Perl modules that depend on
> libxml2:
>
> must set `SHLIB_PATH` to include the path to libxml2 shared library
>
> assuming that you used the default:
>
> ```sh
> export SHLIB=/usr/local/lib
> ```
>
> also, make sure that the config files have execute permission:
>
> ```
> /usr/local/bin/xml2-config
> /usr/local/bin/xslt-config
> ```
>
> they did not have `+x` after they were installed by `make install`
> and it took me a while to realize that this was my problem
>
> or one can use:
>
> ```sh
> perl Makefile.PL LIBS='-L/path/to/lib' INC='-I/path/to/include'
> ```


# Contact

For bug reports and pull requests, please use the issue tracker at
<https://github.com/cpan-authors/XML-LibXML/issues>.


# Package History

- Versions < 0.98 were maintained by Matt Sergeant
- Versions 0.98 – 1.49 were maintained by Matt Sergeant and Christian Glahn
- Versions 1.49 – 1.56 were maintained by Christian Glahn
- Versions 1.56 – 1.58 were co-maintained by Petr Pajas
- Versions 1.59 onward were originally maintained by Petr Pajas
- Subsequently maintained for many years by Shlomi Fish
  (last release: 2.0210, January 2024)
- Release 2.0211, May 2026, under the cpan-authors team
- Release 2.0212, May 2026 (POD shipping fix)
- Now maintained by the cpan-authors team at
  <https://github.com/cpan-authors/XML-LibXML>


# Patches and Developer Version

As XML::LibXML is open source software, help and patches are appreciated. If
you find a bug in the current release, make sure this bug still exists in the
developer version of XML::LibXML. This version can be cloned from its Git
repository. For more information about that, see:

<https://github.com/cpan-authors/XML-LibXML>

Please consider all regression tests as correct. If any test fails it is most
certainly related to a bug.

If you find documentation bugs, please fix them in the `libxml.dbk` file, stored
in the `docs` directory.
