# Changelog

All notable changes are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html). Pre-1.0 releases (alpha / beta / rc) may include breaking changes between iterations; the public API is considered stable starting at `1.0.0`.

## [Unreleased]

## [0.1.0-alpha.1] — 2026-05-15 — initial public alpha

First public alpha. Cross-platform CLI for the [Shiprocket API](https://apidocs.shiprocket.in/), plus a [Claude](https://claude.com/claude-code) skill that drives it under explicit AI-safety constraints. Credentials never enter AI context; every mutation passes through a six-tier safety classifier; every mutation is recorded in a local audit log.

### CLI

- **Single-file Python, stdlib only.** `bin/shiprocket-api-skill`, runs on Python 3.8+.
- **Named commands** for the common read surface: `whoami`, `orders`, `order`, `couriers`, `serviceability`, `track`, `pickup-locations`, `audit-log`, `classify`.
- **Generic `api` gateway** — `shiprocket-api-skill api <METHOD> <path> [flags]` — covers every endpoint under `/v1/external/`. Accepts paths with or without the `/v1/external` prefix. Supports `--query`, `--data`, `--body @file`, `--paginate`, `--dry-run`.
- **Token entry**: `setup` (TTY-only) and `gui-setup` (AI-runnable, OS-native dialog). Both collect API-user email and password, exchange them for a JWT via `POST /v1/external/auth/login`, and persist only the JWT.

### Safety classifier

- **Six tiers**: `read`, `mutating`, `destructive`, `billable`, `financial`, `privilege`. Each tier requires explicit operator-supplied flags before the CLI will send the request.
- **Required-flag matrix**: `read` → none; `mutating` → `--yes`; `destructive` → `--yes --confirm-id`; `billable` → `--yes --i-understand-billing`; `financial` → `--yes --allow-financial`; `privilege` → `--yes --allow-privilege`.
- **Default fallback** for unlisted endpoints is the *strictest applicable*: GET → read; DELETE → destructive; anything else → mutating. Unlisted endpoints are never silently treated as `read`.
- **`shiprocket-api-skill classify <METHOD> <path>`** prints how any path is gated (without sending the request).
- Billable bookings (`/courier/assign/awb`, `/courier/generate/*`, `/shipments/create/*`, label/invoice/manifest printing) require `--i-understand-billing` — these are the points where Shiprocket actually commits courier capacity.
- Cancellations (`/orders/cancel`, `/orders/cancel/shipment/awbs`, `/shipments/cancel`) are classified `destructive` and require `--confirm-id`. The runtime SKILL.md flags that cancelling after AWB assign may incur fees.

### Token storage (cross-platform)

- **macOS**: Keychain via `security` (service `shiprocket-api-skill`).
- **Linux**: Secret Service via `secret-tool` (libsecret) when present; falls through to file storage otherwise.
- **Windows / fallback**: file at `~/.shiprocket-api-skill/token`, mode `0600` (Unix) or `icacls`-locked-down ACL (Windows).
- **Refuses** to read the file fallback if its POSIX mode is broader than `0600`.
- **Verification before storage**: `setup` and `gui-setup` exchange the credentials for a JWT and then validate the JWT against `GET /v1/external/orders` *before* persisting it. A bad credential pair never replaces a working JWT.
- **`--file`** flag forces file storage and evicts any pre-existing keystore copy so the file is the single source of truth.

### AI-safe credential entry

- **`shiprocket-api-skill setup`** — terminal-based, visible email prompt + hidden `getpass` password prompt. Requires a TTY; AI agents cannot run this.
- **`shiprocket-api-skill gui-setup`** — pops a native OS credential dialog (osascript-pair on macOS, `zenity --forms` / `kdialog` on Linux, PowerShell `Get-Credential` on Windows). The dialog is rendered by the desktop's WindowServer / compositor, completely out-of-band from any pipe an AI agent can read. **AI-runnable** for both add and rotate flows.
- **Email and password discarded immediately** after the JWT exchange; only the short-lived JWT is persisted.
- **`shiprocket-api-skill rotate-token`** — alias for `setup`.
- **`shiprocket-api-skill uninstall-token --yes`** — wipes the local copy from every backend the platform supports. AI-runnable (no secret involved).
- **`shiprocket-api-skill whoami`** — verifies auth (live request) and surfaces identity claims decoded from the JWT payload (name, email, id, company_id, exp). The token itself is never printed.

### Audit trail

- Append-only JSON log at `~/.shiprocket-api-skill/audit.log` (mode `0600`). One line per mutation: timestamp, user, action, target, parameter metadata (body *keys* for generic `api` calls — never the token, never request body values).

### AI safeguards (Claude skill + harness deny rules)

- **`.claude/skills/shiprocket-api-skill/SKILL.md`** — full safety matrix, per-resource confirmation playbooks, and a "Token management" section that lets Claude direct add/rotate/remove workflows without seeing, typing, or storing the credentials.
- **`docs/settings.local.json.template`** — copy to `.claude/settings.local.json` to mechanically deny the AI from running `security`, `secret-tool`, `cmdkey`, `printenv SHIPROCKET_TOKEN`, `curl https://apiv2.shiprocket.in/...`, and reads of `~/.shiprocket-api-skill/token`. AI-safe commands (`whoami`, `gui-setup`, `uninstall-token --yes`, read-only listings, `classify`, all `--dry-run` invocations) are pre-allowed.

### Path / argument hardening

- `_validate_path` rejects malformed paths (`PATH_RE`) and explicit `..` / `.` traversal segments. URL-encoded `%`-sequences are rejected at the regex level.
- The classifier strips `/v1/external` (and `/v1`) prefixes at the boundary, so paths copied from apidocs.shiprocket.in/ classify identically with or without the prefix.
- `--header`-style overrides cannot replace the `Authorization` header (filtered case-insensitively in `_request`).
- `--body @file` refuses paths that resolve inside `~/.shiprocket-api-skill/`.
- Mutually exclusive `--data` / `--body`. Method whitelist (`GET`/`POST`/`PUT`/`DELETE`/`PATCH`).

### Install scripts

- **`install.sh`** (POSIX) and **`install.ps1`** (Windows): verify Python 3.8+, place a `shiprocket-api-skill` symlink (Unix) or `.cmd` shim (Windows) on `PATH`, optionally install the Claude skill, optionally run `shiprocket-api-skill setup` immediately. Credentials never enter the install script's variables, argv, or environment.
- Under `curl … | sh`, the Unix installer re-attaches stdin to `/dev/tty` so the hidden `getpass` prompt still works when invoked through a pipe.

### Documentation

- **README.md** — install, token management, classifier reference, common workflows, file map, uninstall.
- **AUTHORS.md** — AI-authorship attribution (Claude Opus 4.7) and an AI-disclaimer.
- **SECURITY.md** — threat model, hardening recommendations, vulnerability reporting.
- **CONTRIBUTING.md** — stdlib-only rule, classifier-extension procedure, test pattern guidance, commit-message format.
- **CLAUDE.md** — project-level hard rules for any AI agent working in the repo.

### Known limitations (alpha)

- The classifier table is hand-curated against publicly documented Shiprocket endpoints as of 2026-05-15. The apidocs.shiprocket.in site is JavaScript-rendered, so the classifier was authored from established knowledge of the API surface rather than mechanical extraction. Endpoints added later (or already present but unfamiliar) will fall through to method-based defaults (DELETE → destructive, other writes → mutating, GET → read) — safe but possibly stricter than necessary. PRs to extend the table are welcome.
- Shiprocket uses POST for some read-like operations (e.g. some serviceability quote shapes). The classifier conservatively treats unknown POSTs as `mutating`. The named `serviceability` command uses the GET form.
- 48 offline unit tests cover the classifier and path validation, but there is no integration test suite hitting the real Shiprocket API. Single-session AI-generated code; a pre-1.0 audit by humans is recommended before you trust this with a production Shiprocket account. See `AUTHORS.md`.
- The macOS `security` CLI requires the token in argv during `add-generic-password`. Same-user `ps` can observe it for the lifetime of one subprocess call. Same-user attackers already have keychain access; documented as not-defended in `SECURITY.md`.
- `gui-setup` was developed and smoke-tested on macOS only; the Linux (`zenity`/`kdialog`) and Windows (`Get-Credential`) code paths fall through to a clear error when no dialog tool is available, but the live dialog flow needs validation by Linux/Windows users in the alpha period.
- Shiprocket JWTs expire after ~10 days. The operator must re-run `gui-setup` (or `setup`) when `whoami` starts returning 401.
