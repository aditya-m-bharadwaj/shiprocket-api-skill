# 0005 — Commit-trailer convention: `Prompted-By:` + `Co-Authored-By:`

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

This project is open source, AI-authored, and may attract contributions from operators running their own AI agents against it. Honest provenance matters:

- The human who *directed* the work made non-trivial decisions (security posture, classifier scope, what to ship vs. defer).
- The model that *wrote* the code is verifiable and should be cited so reviewers know the failure modes.
- GitHub's `Co-Authored-By:` trailer is well-understood by tooling and counts toward the contribution graph.

GitHub doesn't (yet) recognize a `Prompted-By:` trailer in its UI. That doesn't matter for the convention's value — it gives reviewers a single line of grep to find AI-assisted commits and verify the directing human.

## Decision

Commits produced through AI assistance use this trailer block:

```
Prompted-By: <Operator Name> <operator@example.com>
Co-Authored-By: <Model Name and Version> <noreply-address>
```

- `Prompted-By:` is the human who directed the AI. Use the current operator's `git config user.name` / `user.email` unless told otherwise. Multiple operators on a single commit get multiple `Prompted-By:` lines.
- `Co-Authored-By:` is the model identifier you are actually running as. Don't fabricate versions. Use the canonical noreply address (`noreply@anthropic.com` for Claude, etc.).
- Trailers are omitted on hand-typed commits — don't claim AI authorship the AI didn't do.

The full subject + bullet format is documented in `CONTRIBUTING.md` §"Commit message format".

## Consequences

- **Reviewers can filter for AI commits.** `git log --grep '^Co-Authored-By: Claude'` finds every Claude-authored commit.
- **No tooling guarantees against forged trailers.** A bad actor can fake either line. Reviewers should weight code review accordingly.
- **Inconsistent across upstream tools.** Some AI tools default to `Authored-By:` or no trailer at all. The shape we use is documented in `CONTRIBUTING.md` and reinforced in the project-level `CLAUDE.md`.

## Related

- linode-api-skill ADR 0005.
