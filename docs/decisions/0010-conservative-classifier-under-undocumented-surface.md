# 0010 — Conservative classifier under undocumented surface

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

Shiprocket's developer documentation at <https://apidocs.shiprocket.in/> is a JavaScript-rendered Postman portal. Static fetchers (Claude Code's WebFetch, plain `curl`) see only the page title; the endpoint list is hydrated client-side.

This means the classifier table cannot be authored by mechanical extraction from the docs. It was authored from established knowledge of Shiprocket's REST surface and conservative defaults. There are paths I'm sure about (`/courier/assign/awb` is billable; `/orders` is read), paths I'm reasonably sure about (`/wallet/recharge` is financial), and paths whose existence I'm not certain of (some Shiprocket accounts may not have `/api-users/` at all; the financial-prefix list is best-effort).

## Decision

Where I am uncertain about an endpoint:

- If the endpoint *might* be billable / financial / privilege, classify it that way. Operator can complain in a PR if it's stricter than reality.
- If the endpoint is clearly read-shaped (GET), trust the default.
- For POSTs that *might* be read-shaped (e.g. some Shiprocket serviceability quote endpoints), let them fall through to `mutating`. The operator can pass `--yes` to proceed. Stricter than necessary, but not unsafe.

The classifier's design guarantees this: unknown DELETE → destructive; unknown other-non-GET → mutating. *Nothing* falls through to read unless it's a GET.

## Consequences

- **Some endpoints are over-classified.** Operators may need to pass `--yes` for what is actually a free read-shaped POST. Documented in `CHANGELOG.md` known limitations.
- **The classifier needs a feedback loop.** A real-world operator running the live smoke test (`api-skill-builder` Step 15) will surface mis-classifications. Each one becomes a CHANGELOG entry + a `tests/test_classify.py` test + a `(METHOD, normalized_path)` table update.
- **No mechanical regeneration.** The Shiprocket docs site has no OpenAPI spec we can mirror. If one becomes available (or we mirror enough endpoints in `docs/spec/` from manual exploration), we can add a `tools/regenerate-classifier.py`. Not for the alpha.

## Related

- [[0002-safety-classifier-six-tiers]]
- [[0008-billable-at-awb-not-order-creation]]
