# 0004 — AI-safe credential entry via native OS GUI dialog

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

When the AI is the operator's primary driver (Claude Code, Claude Desktop, etc.), the AI cannot run a TTY-based `setup` flow — there is no controlling terminal in the AI's context. The naive workaround is "ask the user to paste the credentials in chat" — which puts the credentials in the AI's context, defeating the entire safety posture.

Reference: linode-api-skill solved the same problem with a native OS password dialog. Shiprocket adds one complication: the credential is a `(email, password)` pair (used to mint a 10-day JWT), not a single token string.

## Decision

`shiprocket-api-skill gui-setup` pops a native OS dialog using only stdlib tooling that ships with the OS:

- macOS — two sequential `osascript display dialog` calls (email visible, password `with hidden answer`).
- Linux — `zenity --forms --add-entry=Email --add-password=Password` (single combined form). Fallback to two sequential `kdialog` dialogs if zenity is not installed.
- Windows — `Get-Credential -Message ...` (single dialog with username + password fields).

The dialog is rendered by the OS WindowServer/compositor, completely out-of-band from any pipe the AI process can read. The user's keystrokes flow to the dialog process; the dialog process emits the captured email/password to its own stdout; `subprocess.run(..., capture_output=True)` puts those bytes into the `shiprocket-api-skill` Python process's memory and never re-prints them.

Inside the Python process:
1. Call `_login(email, password)` → exchanges via `POST /v1/external/auth/login` → returns JWT.
2. `del password` immediately after the exchange — email/password go out of scope.
3. Validate the JWT with a read call (`GET /orders?per_page=1`).
4. Persist **only the JWT** in the keystore.

The CLI prints only success metadata (`Authenticated as: <name> — <email>`); no token bytes ever cross stdout.

## Consequences

- **AI-runnable add and rotate.** Claude can run `gui-setup`, see only metadata, and the user enters credentials out-of-band.
- **Headless / SSH falls through to TTY.** `_has_display()` returns false when `SSH_CONNECTION` is set or no `DISPLAY` / `WAYLAND_DISPLAY` is present. The CLI errors out with a clear message pointing the operator at `setup` in their terminal.
- **Email and password live in memory for ~1 second.** They are exchanged for the JWT and dropped. The persisted secret material is the short-lived JWT — a smaller blast radius if the keystore is compromised.
- **The previous JWT remains valid on Shiprocket's side after local rotation.** The operator is reminded to rotate the API-user password too if they suspect leakage.

## Related

- [[0003-cross-platform-token-storage]]
- [[0009-shiprocket-jwt-via-login-exchange]]
- linode-api-skill ADR 0004.
