# 0003 — Cross-platform token storage: OS-native first, file fallback at 0600

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

The credential we persist is a Shiprocket JWT (~10-day lifetime). Storage backend choices, from strongest to weakest:

1. **macOS Keychain** — ACL-gated, prompts on cross-process access, integrated with system auth.
2. **Linux Secret Service / libsecret** — D-Bus-mediated; gnome-keyring or KWallet provides the actual store. Requires `secret-tool` (libsecret-tools / libsecret-tools package).
3. **File at `~/.shiprocket-api-skill/token`** — mode `0600`. Same-user readable; rest-of-world denied.

Environment variables (`SHIPROCKET_TOKEN`) sit below all of these — convenient for CI, but easy to leak into shell history, into a child process's `env`, or into a process listing.

## Decision

The CLI picks the strongest available backend at run time:

- macOS → Keychain (via `security`).
- Linux → Secret Service (via `secret-tool`) if installed; otherwise file.
- Windows / fallback → file at `~/.shiprocket-api-skill/token`, mode `0600` (Unix) or `icacls`-locked-down ACL (Windows).

`SHIPROCKET_TOKEN` is **only** consulted if no keystore copy exists — it is a documented escape hatch, not the primary path.

The CLI refuses to read the file fallback if its POSIX mode is broader than `0600`.

## Consequences

- **Bring-your-own-libsecret on Linux.** Headless / minimal-image Linux systems will fall through to the file backend until `libsecret-tools` is installed. Documented in `README.md` and `SECURITY.md`.
- **The keychain `security` CLI takes the token in argv.** Same-user `ps` can observe it for the lifetime of one `security add-generic-password` subprocess. Same-user attackers already have keychain access; documented as not-defended.
- **Single backend at a time.** When `token_set(prefer="file")` is used, any keystore copy is evicted so there's exactly one source of truth.

## Related

- [[0004-ai-safe-credential-entry-gui-dialog]]
- [[0009-shiprocket-jwt-via-login-exchange]]
- linode-api-skill ADR 0003.
