---
name: version-bump
description: Bump XML::LibXML's $VERSION across every version-bearing file in one shot. Use whenever the user asks to bump, change, set, or promote the XML::LibXML version (e.g. "bump to 2.0212", "promote the dev release to stable", "cut 2.0212_01"). Wraps a Perl script that auto-detects the current version from LibXML.pm and rewrites every file carrying the `# VERSION TEMPLATE: DO NOT CHANGE` marker plus the `<edition>` tag in docs/libxml.dbk. Optionally renames the topmost Changes entry when promoting a CPAN-underscore developer release.
---

# version-bump

Run from the repo root:

```bash
.claude/skills/version-bump/bump.pl <new_version>
```

Common flows:

| Goal | Command |
|------|---------|
| Bump to a new release | `.claude/skills/version-bump/bump.pl 2.0212` |
| Cut a developer/trial release | `.claude/skills/version-bump/bump.pl 2.0212_01` |
| Promote a dev release to stable (rewrites the top `Changes` header) | `.claude/skills/version-bump/bump.pl 2.0212 --rename-changes` |
| Preview without writing | `.claude/skills/version-bump/bump.pl 2.0212 --check` |

What the script does:

- detects the current version automatically from `LibXML.pm`
- rewrites `$VERSION = "..."` in every `.pm` file carrying `# VERSION TEMPLATE: DO NOT CHANGE` (LibXML.pm + lib/XML/LibXML/**)
- rewrites `<edition>...</edition>` in `docs/libxml.dbk`
- with `--rename-changes`: replaces the version on the topmost `Changes` header line and strips any trailing `(developer/trial release)` annotation
- warns (but does not block) if the new version ends in `0` — CLAUDE.md says trailing-zero versions are reserved

What the script does **not** do — handle these manually after running:

- add/update the `Changes` entry body with the bullet list of fixes
- update the "Package History" section in `README.md`
- run `make` / tests / commit

After the script runs, sanity-check with:

```bash
grep -rn "$OLD_VERSION" LibXML.pm lib/ docs/libxml.dbk Changes
git diff --stat
```
