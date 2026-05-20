#!/usr/bin/env perl
use strict;
use warnings;
use File::Find ();
use Getopt::Long;

my $usage = <<'END_USAGE';
Usage: bump.pl <new_version> [--rename-changes] [--check]

Bumps XML::LibXML's version string across every version-bearing file.

The script auto-detects the current version from LibXML.pm and rewrites:
  - LibXML.pm
  - every lib/XML/LibXML/*.pm carrying "# VERSION TEMPLATE: DO NOT CHANGE"
  - docs/libxml.dbk (<edition> tag)

Options:
  --rename-changes   Also rewrite the topmost Changes entry: replace the
                     version on the header line and strip any
                     "(developer/trial release)" annotation. Use this
                     when promoting a CPAN underscore developer release
                     (e.g. 2.0210_11) to a real release (e.g. 2.0211).
  --check            Print what would change but do not modify any files.

Must be run from the repo root.

Per CLAUDE.md, the trailing digit of a release must not be 0 (those are
reserved). Developer releases use a CPAN underscore, e.g. 2.0211_01.

After running, manually:
  - add or update the Changes entry body
  - update README.md's "Package History" section
END_USAGE

my $rename_changes = 0;
my $check_only     = 0;
GetOptions(
    'rename-changes' => \$rename_changes,
    'check'          => \$check_only,
    'help|h'         => sub { print $usage; exit 0 },
) or die $usage;

my $new_version = shift @ARGV;
die $usage unless defined $new_version && length $new_version;
die "Unexpected extra arguments: @ARGV\n" if @ARGV;

die "Run me from the repo root (LibXML.pm not found here).\n"
    unless -f 'LibXML.pm';

# Detect current version.
my $current;
{
    open my $fh, '<', 'LibXML.pm' or die "open LibXML.pm: $!";
    while (<$fh>) {
        if (/\$VERSION\s*=\s*"([^"]+)"\s*;\s*#\s*VERSION TEMPLATE/) {
            $current = $1;
            last;
        }
    }
    close $fh;
}
die "Could not detect current version in LibXML.pm\n" unless defined $current;

if ($current eq $new_version) {
    die "Current version is already $new_version; nothing to do.\n";
}

if ($new_version !~ /_/ && $new_version =~ /0\z/) {
    warn "WARNING: $new_version ends in 0 — CLAUDE.md says trailing-zero "
        . "versions are reserved. Proceeding anyway.\n";
}

print "Bumping $current -> $new_version"
    . ($check_only ? " (check mode, no writes)" : "")
    . "\n";

# Gather .pm files.
my @pm_files = ('LibXML.pm');
File::Find::find(
    sub { push @pm_files, $File::Find::name if /\.pm\z/ },
    'lib',
);

my $changed = 0;

for my $file (@pm_files) {
    my $content = _slurp($file);
    my $new = $content;
    $new =~ s{
        ( \$VERSION \s* = \s* )
        " \Q$current\E "
        ( \s* ; \s* \# \s* VERSION\ TEMPLATE )
    }{$1"$new_version"$2}x;

    next if $new eq $content;
    _write($file, $new);
    print "  updated $file\n";
    $changed++;
}

my $dbk = 'docs/libxml.dbk';
if (-f $dbk) {
    my $content = _slurp($dbk);
    if ($content =~ s{<edition>\Q$current\E</edition>}
                     {<edition>$new_version</edition>}) {
        _write($dbk, $content);
        print "  updated $dbk\n";
        $changed++;
    }
    else {
        warn "  WARNING: <edition>$current</edition> not found in $dbk\n";
    }
}

if ($rename_changes) {
    my $changes = 'Changes';
    open my $fh, '<', $changes or die "open $changes: $!";
    my @lines = <$fh>;
    close $fh;

    my $hit = 0;
    for my $line (@lines) {
        next unless $line =~ /\A\Q$current\E\b/;
        $line =~ s/\A\Q$current\E/$new_version/;
        $line =~ s/\s*\(developer\/trial release\)//;
        $hit = 1;
        last;
    }

    if ($hit) {
        _write($changes, join('', @lines));
        print "  updated $changes (top entry renamed)\n";
        $changed++;
    }
    else {
        warn "  WARNING: no Changes entry beginning with $current found\n";
    }
}

print "\n";
if ($check_only) {
    print "Check mode: $changed file(s) would be updated.\n";
}
else {
    print "Done: $changed file(s) updated.\n";
    print "Verify with: grep -rn '$current' LibXML.pm lib/ docs/libxml.dbk Changes\n";
    print "Then update README.md \"Package History\" and the Changes body as needed.\n";
}

sub _slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub _write {
    my ($path, $content) = @_;
    return if $check_only;
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} $content;
    close $fh;
}
