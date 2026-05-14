# 0007 — Versioning: SemVer 2.0 with `-alpha.N` for pre-1.0

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

The CLI's command surface, classifier table, and `--flag` matrix are all things consumers (and AI agents) will rely on. Breaking changes need to be visible.

Choices considered:
- SemVer (`MAJOR.MINOR.PATCH`).
- CalVer (`YYYY.MM.DD`).
- PEP 440 (Python-specific).

## Decision

This project follows **SemVer 2.0** with the conventional pre-1.0 alpha suffix: `0.1.0-alpha.1`, `0.1.0-alpha.2`, … `0.1.0`, `0.2.0`, … `1.0.0`.

Pre-1.0 releases may include breaking changes between iterations. The classifier table, CLI flag matrix, and named-command set are considered **stable starting at 1.0.0**.

If/when we publish to PyPI, the version string switches to PEP 440 (`0.1.0a1` instead of `0.1.0-alpha.1`). The `VERSION` constant in `bin/shiprocket-api-skill` is the source of truth for both.

## Consequences

- **CHANGELOG.md follows Keep a Changelog.** Sections per version: Added / Changed / Deprecated / Removed / Fixed / Security.
- **Git tags use `v<version>`.** E.g. `v0.1.0-alpha.1`.
- **No PyPI for the alpha.** Install is via `curl … | sh` from `raw.githubusercontent.com/.../install.sh`. That can't smuggle a dependency. PEP 440 conversion happens only if/when we publish.

## Related

- linode-api-skill ADR 0007.
