# Security policy

`shiprocket-api-skill` is a privileged tool: with a valid JWT it can create orders, commit courier bookings (which cost money), cancel shipments, recharge wallets, and issue new credentials. The threat model below explains what the tool defends against and what it does not.

## Reporting a vulnerability

If you find a security issue — credential leakage, classifier bypass, sandbox-escape via the generic `api` command, etc. — please open a private security advisory on the project's GitHub repository rather than a public issue. Include:

- a description of the issue,
- minimum repro (commands and expected vs. observed behavior),
- the version reported by `shiprocket-api-skill --version`,
- and your platform.

We aim to acknowledge within 5 business days.

## Threat model

### Defended

- **Credentials at rest.** Only the short-lived JWT is persisted, not the API-user email/password. The JWT is stored in an OS-native secret store when available (macOS Keychain, Linux Secret Service / libsecret). On platforms without one, it falls back to a file in `~/.shiprocket-api-skill/token` with mode `0600`. The CLI refuses to read the file if its permissions allow group or world read.
- **Credentials in transit (within the host).** The email/password entered into `setup` or `gui-setup` are held in process memory only for the duration of the `/auth/login` exchange and dropped immediately. The JWT never appears in argv, environment exported to children, log files, or stdout. It is held in process memory only for the lifetime of one CLI call.
- **Accidental destructive operations.** The CLI's safety classifier requires explicit per-class flags before any mutation:
  - `--yes` for any mutation,
  - `--confirm-id` for any DELETE or known-destructive POST (cancellations),
  - `--i-understand-billing` for endpoints that commit courier capacity or generate paid artifacts,
  - `--allow-financial` for `/wallet/recharge`, `/payments/`, `/billing/`,
  - `--allow-privilege` for `/auth/`, `/users/`, `/sub-users/`, `/settings/api/`, `/api-users/`.
- **AI agents driving the tool.** When run from inside a Claude (or other AI) session, the accompanying skill (`.claude/skills/shiprocket-api-skill/SKILL.md`) instructs the agent to:
  - never read the JWT or `~/.shiprocket-api-skill/token`,
  - never call the API directly (e.g. with `curl`),
  - obtain explicit human confirmation in chat before any mutation,
  - prefer `--dry-run` first.
  Operators can additionally enforce these constraints at the harness level via `.claude/settings.local.json` (template at [docs/settings.local.json.template](docs/settings.local.json.template)).
- **Audit trail.** Every mutation appends one JSON line to `~/.shiprocket-api-skill/audit.log` with timestamp, user, action, target, and parameter metadata (body keys for generic `api` calls — never the token, never request body values). The log is mode `0600`. Rotation is the operator's responsibility — `shiprocket-api-skill audit-log --last N` reads it; `cp /dev/null ~/.shiprocket-api-skill/audit.log` truncates it.

### Not defended

- **Compromise of the local user account.** If the operator's user session is compromised, an attacker can read the keystore, the file fallback, and the audit log just as the user can. Use disk encryption and standard endpoint security.
- **Shiprocket-side IAM / API-user scope.** The CLI passes whatever JWT it minted. Use a dedicated API user with the minimum-necessary permissions and rotate the API user's password regularly.
- **JWT replay after local compromise.** Until the JWT expires (~10 days) or the API user's password is rotated, an attacker with a copy of the JWT can use it from any host. Treat JWT exposure the same as credential exposure: rotate the API-user password immediately.
- **Network adversaries.** TLS to `apiv2.shiprocket.in` is provided by the OS / Python stdlib trust store. The tool does not pin certificates.
- **Side channels.** Order counts, AWB numbers, and timing are observable via the audit log and by listing orders; do not assume secrecy of resource metadata.
- **Tool freshness.** New Shiprocket endpoints not in the classifier table fall through to the strictest applicable default (DELETE → destructive, other writes → mutating). They are never auto-classified as `read`. But a future endpoint that is privately *billable* without being in the table will be gated only by `--yes`. We accept this trade-off; users can extend the classifier locally and we welcome PRs.

## Hardening recommendations

- **Use a dedicated API user**, not your main Shiprocket login. Create one in the Shiprocket dashboard with the minimum permissions you need.
- Rotate the API-user password periodically and immediately on suspicion. Local JWT removal (`uninstall-token`) does not invalidate the JWT server-side.
- On Linux, install `libsecret-tools` (`apt install libsecret-tools` / `dnf install libsecret`) so the JWT lives in the Secret Service rather than a file.
- When running under an AI agent, enable the harness deny rules from [docs/settings.local.json.template](docs/settings.local.json.template). These mechanically prevent the agent from reading the token or calling the API directly.
- Review `~/.shiprocket-api-skill/audit.log` periodically. Forward it to your SIEM if you have one.

## Cryptographic notes

- The JWT signature is validated by Shiprocket's server, not by this CLI. The client decodes the JWT payload solely to display identity to the operator (in `whoami`).
- No secrets are written to stdout, stderr, or the audit log.
