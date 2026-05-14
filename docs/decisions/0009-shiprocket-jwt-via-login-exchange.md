# 0009 — Shiprocket auth: paste-credentials, mint short-lived JWT, persist only the JWT

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

Unlike Linode (long-lived API tokens minted in the dashboard), Shiprocket's auth model gives the operator an **API user** with email + password. Subsequent API calls use a JWT obtained by `POST /v1/external/auth/login` with those credentials. The JWT expires after ~10 days.

Two ways to persist auth state:

- **Option A:** Persist email + password; mint JWT on every CLI invocation (or cache for the JWT's lifetime).
- **Option B:** Operator runs `gui-setup` / `setup`, which exchanges email + password for a JWT in process memory, persists only the JWT, and drops the email/password. The operator re-runs setup every ~10 days.

Option A is more user-friendly (no re-auth ever); Option B has a smaller blast radius (the persisted secret is short-lived and scoped).

## Decision

We persist **only the JWT** (Option B):

- `setup` / `gui-setup` collect email + password (TTY hidden prompt or OS dialog).
- The CLI calls `POST /v1/external/auth/login` to mint a JWT.
- The email and password go out of scope (`del password` after the exchange).
- The JWT is validated against `GET /orders?per_page=1`. If validation fails, the previous keystore copy is left intact (verify-before-store).
- Only the JWT is persisted in the OS keystore.
- When the JWT expires, the operator re-runs `gui-setup` (or `setup`).

The CLI does not implement automatic re-auth from stored email/password because it does not store them.

## Consequences

- **Smaller blast radius on keystore compromise.** An attacker who gets the JWT can act for at most ~10 days; an attacker who got email + password could rotate the JWT forever until the operator rotated the password.
- **Re-auth friction every ~10 days.** Acceptable for an alpha; if operators complain, we can add an opt-in "store hashed credentials in OS-native auth" flow under a separate ADR. Don't do it now.
- **Local JWT deletion does not invalidate the JWT server-side.** Documented in `SECURITY.md` and the runtime SKILL.md. Operators are told to rotate the API-user password if they suspect leakage.
- **No `whoami` API endpoint.** Shiprocket has no `/me` route. We surface identity by decoding the JWT payload (`first_name`, `last_name`, `email`, `id`, `company_id`, `exp`) for display, and verify the JWT is alive with `GET /orders?per_page=1`. Decoding the payload is display-only — we don't trust it for authorization.

## Related

- [[0003-cross-platform-token-storage]]
- [[0004-ai-safe-credential-entry-gui-dialog]]
