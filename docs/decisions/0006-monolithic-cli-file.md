# 0006 — Monolithic single-file CLI

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

The CLI could be packaged as a Python package (`src/shiprocket_api_skill/`) with submodules per concern (storage, classifier, commands). That's the conventional layout for a tool of this size.

For a privileged tool the operator may want to audit before trusting, monolithic has advantages: one file to read, no import-time side effects, no `__init__.py` mystery, no `.egg-info`.

## Decision

`bin/shiprocket-api-skill` is one Python file, top-to-bottom:

1. Imports + constants
2. `CtlError` exception
3. Token storage (per-platform helpers + `token_get/set/delete`)
4. JWT helpers
5. GUI credential dialog
6. HTTP (`_request`, `_paginate`)
7. Audit log
8. Safety classifier (tables + `classify`)
9. Helpers (`_emit`, `_format_summary`, `_load_body`, `_parse_query`, `_login`)
10. Named commands (`cmd_*`)
11. `cmd_api` (generic gateway)
12. Argparse (`build_parser`, `main`)

The shebang is `#!/usr/bin/env python3`. The file is executable. No build step.

## Consequences

- **Audit-friendly.** A reviewer reads one file, top to bottom, in one sitting.
- **No import-time anything.** Token storage is not initialized until `main()` runs.
- **PEP 561 typing is best-effort.** We use type hints but no `py.typed` marker since there's nothing to import.
- **Test loading uses `SourceFileLoader`.** `tests/test_classify.py` loads the CLI as a module without a package install. Costs us nothing.
- **Future packaging is still possible.** If we publish to PyPI later, we wrap the same file in a `pyproject.toml` and a `[project.scripts]` entry. SemVer would shift to PEP 440 (`0.1.0a1` instead of `0.1.0-alpha.1`).

## Related

- [[0001-stdlib-only-python]]
- [[0007-versioning-semver]]
- linode-api-skill ADR 0006.
