# 0001 — Stdlib-only Python in `bin/shiprocket-api-skill`

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

`shiprocket-api-skill` is a privileged tool — a valid JWT lets it commit courier capacity (which costs money), cancel shipments, recharge the wallet, and issue API users. Anything that runs in the same process as the credential is in scope for compromise.

The reference implementation [`linode-api-skill`](https://github.com/aditya-m-bharadwaj/linode-api-skill) made the same call (see its ADR 0001) for the same reason. We mirror it here without divergence.

## Decision

`bin/shiprocket-api-skill` uses only the Python 3.8+ standard library. No `requests`, no `click`, no `pydantic`, no `keyring`, no `pyjwt`. JWT payload decoding is implemented in ~10 lines using `base64.urlsafe_b64decode` + `json`.

## Consequences

- **Eliminates supply-chain risk.** A typo in a `requests`-replacement package can't ship malicious code into a privileged tool the operator runs without sandboxing.
- **Zero install friction.** No `pip install`. Users can `curl … | sh` the installer, which `chmod +x`'s the file and symlinks it.
- **More code to maintain.** We re-implement what `requests` / `keyring` give us for free. For this tool's scope (one URL base, three OS keystores, two HTTP verbs of interest) that's a fixed, small cost.
- **JWT signature is not validated client-side.** The CLI decodes the payload for display purposes only; the API server is the source of truth for token validity. Trying to verify the HS256/RS256 signature client-side would require a third-party crypto dep.

## Related

- [[0006-monolithic-cli-file]]
- linode-api-skill ADR 0001 — the same decision in the reference implementation.
