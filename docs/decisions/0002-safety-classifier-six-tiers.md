# 0002 — Six-tier safety classifier

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

Shiprocket's API surface includes endpoints whose blast radius varies by orders of magnitude:

- `GET /orders` lists data — recoverable, no cost.
- `POST /orders/create/adhoc` creates a record — recoverable, no cost.
- `POST /courier/assign/awb` commits a carrier booking — **costs real money**.
- `POST /orders/cancel/shipment/awbs` cancels a shipment — **may incur RTO / cancellation fees** after AWB assigned.
- `POST /wallet/recharge` moves money.
- `POST /auth/login` and `/api-users/*` issue credentials.

A single `--yes` flag for all of these would either be too strict (annoying for trivial mutations) or too loose (a typo recharges your wallet).

## Decision

Every API call is classified into one of six tiers, each with its own required-flag matrix:

| Tier | Required flags |
| --- | --- |
| `read` | (none) |
| `mutating` | `--yes` |
| `destructive` | `--yes --confirm-id <id>` |
| `billable` | `--yes --i-understand-billing` |
| `financial` | `--yes --allow-financial` |
| `privilege` | `--yes --allow-privilege` |

The classifier is implemented as four hand-curated collections (`_BILLABLE_EXACT`, `_DESTRUCTIVE_EXACT`, `_FINANCIAL_PREFIXES`, `_PRIVILEGE_PREFIXES`) plus a `_MUTATING_EXACT` override table. Unknown endpoints fall through to a method-based default: GET → read, DELETE → destructive, anything else → mutating. **Unknown endpoints are never silently classified as `read`.**

## Consequences

- **Hand-curation is required to extend the classifier.** A new billable endpoint will fall through to `mutating` (gated only by `--yes`) until someone adds it. This is a known gap documented in `SECURITY.md` and `CHANGELOG.md`.
- **Some POST endpoints are read-shaped on Shiprocket.** Those will be over-classified as `mutating`. The operator can still proceed with `--yes`; that is a tolerable annoyance, not a safety hole.
- **The tier system is the operator's and AI's mental model.** Don't change the names or the count across vendors of this skill family.

## Related

- [[0001-stdlib-only-python]]
- [[0010-conservative-classifier-under-undocumented-surface]]
- linode-api-skill ADR 0002 — same six-tier taxonomy.
