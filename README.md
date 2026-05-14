# Shiprocket-API Skill

> **Status: v0.1.0-alpha.1 — initial public alpha.** Expect rough edges and breaking changes before v1.0. Audit `bin/shiprocket-api-skill` and use `--dry-run` before pointing this at a production Shiprocket account. See [AUTHORS.md](AUTHORS.md) and [SECURITY.md](SECURITY.md).

A safe, cross-platform CLI (`shiprocket-api-skill`) for the [Shiprocket API](https://apidocs.shiprocket.in/), plus a matching [Claude](https://claude.com/claude-code) skill that drives it.

The design goal is **credentials stay out of AI context** and **mutations require explicit, classified consent**. An AI agent can use this tool to do real work on your Shiprocket account without ever touching your API-user password or JWT, accidentally committing courier capacity, or cancelling the wrong shipment.

> **AI-authored.** This tool was designed, written, and documented by **Claude** (Anthropic, Claude Opus 4.7) under direction from a human operator. See [AUTHORS.md](AUTHORS.md) for the full attribution and an AI-disclaimer you should read before trusting this with a production Shiprocket account.

## Highlights

- **Stdlib-only Python.** Zero pip dependencies. Runs on macOS, Linux, and Windows with Python 3.8+.
- **OS-native credential storage.** macOS Keychain → Linux Secret Service (libsecret) → file fallback at `~/.shiprocket-api-skill/token` (mode `0600`). Only the short-lived JWT is persisted; the API-user email/password are exchanged for a JWT in memory and immediately discarded.
- **Full API coverage.** Named ergonomic commands for the common reads (`orders`, `order`, `couriers`, `serviceability`, `track`, `pickup-locations`, `whoami`) and a generic `api` gateway that can call anything else under `/v1/external/`.
- **Safety classifier with six tiers.** `read`, `mutating`, `destructive`, `billable`, `financial`, `privilege`. Each tier requires explicit operator-supplied flags before the CLI will send the request.
- **Audit log.** Every mutation appends one JSON line to `~/.shiprocket-api-skill/audit.log`.
- **AI safeguards.** Bundled Claude skill at [.claude/skills/shiprocket-api-skill/SKILL.md](.claude/skills/shiprocket-api-skill/SKILL.md), and a harness deny-list template at [docs/settings.local.json.template](docs/settings.local.json.template) so the AI is mechanically prevented from reading the token, calling the API directly, or running mutations without confirmation.
- **MIT licensed.** Use it however you want.

## Install

### One-liner (Unix; replace the URL once you've published the repo)

```sh
curl -fsSL https://raw.githubusercontent.com/aditya-m-bharadwaj/shiprocket-api-skill/main/install.sh | sh
```

### One-liner (Windows PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/aditya-m-bharadwaj/shiprocket-api-skill/main/install.ps1 | iex
```

### From a local checkout

```sh
git clone <repo-url> shiprocket-api-skill
cd shiprocket-api-skill
./install.sh                  # macOS / Linux
# or, on Windows:
.\install.ps1
```

The installer will:
1. Verify Python 3.8+,
2. Place a `shiprocket-api-skill` symlink (Unix) or `.cmd` shim (Windows) into `~/.local/bin`,
3. **Prompt** to install the Claude skill into `~/.claude/skills/shiprocket-api-skill/SKILL.md` (skipped if you decline or are running non-interactively without `INSTALL_SKILL=1`).
4. **Prompt** to run `shiprocket-api-skill setup` so you can paste your credentials immediately. Under `curl … | sh` the installer re-attaches stdin to `/dev/tty` so the hidden prompt still works.

If `~/.local/bin` isn't on your `PATH`, the installer prints exactly what to add to your shell rc.

### Then, once installed

The installer offers to run `shiprocket-api-skill setup` at the end. Say yes and enter your API-user email + password — password input is hidden, both are exchanged for a JWT in memory, and only the JWT lands in the OS keystore (never the password).

```sh
shiprocket-api-skill setup              # enter API-user email + password; stores JWT
shiprocket-api-skill whoami             # verify auth (no token printed)
```

Create a dedicated API user in the Shiprocket dashboard at <https://app.shiprocket.in/api-user>. **Don't use your main Shiprocket login.**

> The `setup` command requires a TTY — an AI agent **cannot** run it for you, by design. Credentials must be entered in your terminal, with you typing into a hidden prompt.

## Token management

Two paths, same backing store. Pick whichever fits the moment.

| What you want | Command | Where you type credentials | AI-runnable? |
| --- | --- | --- | --- |
| **Add** a token (first time) | `shiprocket-api-skill gui-setup` | Native desktop credential dialog | **Yes** |
| **Add** a token (first time) | `shiprocket-api-skill setup` | Hidden terminal prompt | No — needs TTY |
| **Rotate / change** the token | `shiprocket-api-skill gui-setup` | Native desktop credential dialog | **Yes** |
| **Rotate / change** the token | `shiprocket-api-skill setup` (alias `rotate-token`) | Hidden terminal prompt | No — needs TTY |
| **Remove** the token | `shiprocket-api-skill uninstall-token --yes` | n/a (no secret involved) | **Yes** |
| **Verify** auth (no token printed) | `shiprocket-api-skill whoami` | n/a | **Yes** |

`gui-setup` is the path designed for vibe-coding with an AI. The AI runs the command; a native credential dialog pops up on your desktop (`osascript` on macOS, `zenity --forms` / `kdialog` on Linux, `Get-Credential` on Windows); you type your API-user email + password into the dialog; the CLI exchanges them for a JWT and stores only the JWT; the AI only ever sees `Authenticated as: <identity>`. **No credential bytes cross the AI's terminal context.**

If you don't have a desktop session (e.g. SSH'd into a headless server) `gui-setup` errors out cleanly and tells you to use `setup` in the terminal instead.

Shiprocket JWTs expire after ~10 days. When that happens, re-run `gui-setup` (or `setup`) to mint a fresh one.

### Why this is safe for an AI-driven workflow

- **`gui-setup`**: The dialog is rendered by the OS desktop, completely out-of-band from any pipe an AI agent can observe. Your keystrokes go to the dialog process; that process returns the credentials via its own stdout, which is captured into the `shiprocket-api-skill` Python process's memory by `subprocess.run(..., capture_output=True)` and never re-printed. The CLI exchanges the credentials for a JWT, writes the JWT to the OS keystore, and prints only identity metadata.
- **`setup`**: Email is read visibly, password is read by Python's `getpass` (input hidden, no shell history, no argv exposure). Both go straight into the Python process; only the resulting JWT lands on disk / in the keystore.
- **Install scripts**: never touch the credentials. They `exec` the binary, which runs credential entry in its own process. Under `curl … | sh`, the script re-attaches stdin to `/dev/tty` so the hidden prompt still works.
- **Keystore reads are denied to the AI** by the optional harness rules in [docs/settings.local.json.template](docs/settings.local.json.template) — `security`, `secret-tool`, `cmdkey`, `printenv SHIPROCKET_TOKEN`, and reads of `~/.shiprocket-api-skill/token` are all blocked.
- **`whoami` and `uninstall-token`** are AI-safe by construction: they do not print or expose the token.

## The safety classifier

Every Shiprocket API endpoint is one of:

| Tier | Examples | Required flags |
| --- | --- | --- |
| `read` | `GET /orders`, `GET /courier/serviceability`, `GET /courier/track/awb/{awb}` | (none) |
| `mutating` | `POST /orders/create/adhoc`, `POST /orders/update`, `POST /settings/company/addpickup` | `--yes` |
| `destructive` | Any `DELETE`; `POST /orders/cancel`, `POST /shipments/cancel`, `POST /orders/cancel/shipment/awbs` | `--yes --confirm-id <id>` |
| `billable` | `POST /courier/assign/awb`, `POST /courier/generate/{pickup,label,invoice,manifest}`, `POST /shipments/create/forward-shipment`, `POST /orders/print/{label,invoice,manifest}` | `--yes --i-understand-billing` |
| `financial` | Anything under `/wallet/recharge`, `/payments/`, `/billing/` | `--yes --allow-financial` |
| `privilege` | Anything under `/auth/`, `/users/`, `/sub-users/`, `/settings/api/`, `/api-users/` | `--yes --allow-privilege` |

If an endpoint isn't in the classifier table, the default is the strictest applicable: `DELETE` → `destructive`, anything else mutating → `mutating`. New endpoints will never be silently treated as `read`.

Inspect any path's classification:

```sh
shiprocket-api-skill classify POST /courier/assign/awb
shiprocket-api-skill classify DELETE /products/12345
shiprocket-api-skill classify POST /wallet/recharge
```

## Usage

### Named commands

```sh
shiprocket-api-skill orders                                  # list recent orders
shiprocket-api-skill orders --status NEW --limit 50
shiprocket-api-skill order 12345                             # one order
shiprocket-api-skill couriers                                # list couriers

# Get a serviceability quote (read-only)
shiprocket-api-skill serviceability \
    --pickup-pin 110001 --delivery-pin 560001 \
    --weight 0.5 --cod --declared-value 1500

# Track a shipment
shiprocket-api-skill track --awb 1234567890
shiprocket-api-skill track --order-id 98765

# Pickup locations
shiprocket-api-skill pickup-locations

# Local audit log
shiprocket-api-skill audit-log --last 20

# Plan-time classifier check
shiprocket-api-skill classify POST /courier/assign/awb
```

### Generic API gateway

For anything without a named command (and for every mutation):

```sh
# Read
shiprocket-api-skill api GET /orders --query per_page=10
shiprocket-api-skill api GET /v1/external/orders/show --query order_id=12345

# Mutating — order creation is FREE; AWB assign is the billable step
shiprocket-api-skill api POST /orders/create/adhoc --body @order.json --yes --dry-run
shiprocket-api-skill api POST /orders/create/adhoc --body @order.json --yes

# Billable — books a carrier
shiprocket-api-skill api POST /courier/assign/awb \
    --data '{"shipment_id":1234567,"courier_id":24}' \
    --yes --i-understand-billing --dry-run

# Destructive — cancellation may incur fees after AWB assigned
shiprocket-api-skill api POST /orders/cancel \
    --data '{"ids":[12345]}' \
    --yes --confirm-id 12345

# Financial — moves money
shiprocket-api-skill api POST /wallet/recharge \
    --data '{"amount":500}' \
    --yes --allow-financial

# Privilege — issues credentials
shiprocket-api-skill api POST /api-users/create \
    --data '{...}' \
    --yes --allow-privilege
```

Every command supports `--dry-run` (prints the would-send request and exits without calling the API) and `--json` (machine-readable output).

## AI safeguards (when using Claude or another agent)

This repo ships a Claude skill at [.claude/skills/shiprocket-api-skill/SKILL.md](.claude/skills/shiprocket-api-skill/SKILL.md). When an AI agent has this skill loaded, it knows to:

1. Always go through `shiprocket-api-skill` — never `curl` the API.
2. Never read the JWT or `~/.shiprocket-api-skill/`.
3. Confirm every mutation in chat before running.
4. Use `--dry-run` first when uncertain.

For belt-and-braces, copy the harness deny-list template:

```sh
cp docs/settings.local.json.template .claude/settings.local.json
```

This blocks Claude (and any other harness that honors the file) from running the OS keystore commands, `printenv SHIPROCKET_TOKEN`, `curl https://apiv2.shiprocket.in/...`, or reading `~/.shiprocket-api-skill/token` — even if the agent tries.

> **Why does the README tell you to copy this manually?** Because Claude's auto mode deliberately refuses to write `.claude/settings.local.json` itself. That's the whole point: the agent shouldn't be able to relax its own sandbox. You install the rules; the agent can't remove them.

## Threat model

See [SECURITY.md](SECURITY.md) for the full version. Short version: the tool defends against accidental destructive operations and AI-driven mistakes; it does not defend against compromise of the local user account.

## Repository layout

```
.
├── bin/shiprocket-api-skill                     # the CLI (single Python file, stdlib only)
├── tests/                                       # offline classifier + path-validation tests (unittest)
├── install.sh                                   # macOS/Linux installer (POSIX shell)
├── install.ps1                                  # Windows installer (PowerShell)
├── .claude/
│   ├── skills/shiprocket-api-skill/SKILL.md     # Claude skill for AI-driven use
│   └── commands/{resume,save}.md                # project-level slash commands
├── docs/                                        # project memory layer — tracked (see below)
│   ├── README.md                                # how the memory layer works
│   ├── progress/                                # session-by-session progress notes
│   ├── decisions/                               # ADRs (numbered, append-only)
│   └── settings.local.json.template             # harness deny-list template
├── README.md
├── AUTHORS.md                                   # AI-authorship attribution + disclaimer
├── CHANGELOG.md
├── CLAUDE.md                                    # project-level hard rules for any AI agent in this repo
├── CONTRIBUTING.md
├── SECURITY.md                                  # threat model, hardening, vuln reporting
├── LICENSE                                      # MIT
└── .gitignore
```

The layout is deliberately flat — one Python file (`bin/shiprocket-api-skill`), one skill, one installer per OS, plus the conventional set of project meta files. There is no `src/` package, no compile step, and no third-party runtime dependencies. `tests/` is offline and stdlib-only; run with `python3 -m unittest discover tests`.

## Project memory

The project memory is split by purpose:

| Layer | Location | Tracked? | Contents |
| --- | --- | --- | --- |
| In-repo canonical | `docs/` | yes | ADRs (`docs/decisions/`), session progress notes (`docs/progress/`) |
| Live code graph | `graphify-out/` (in repo root) | no — auto-regenerated | `GRAPH_REPORT.md`, `graph.json`, `graph.html`. Refreshed by the post-commit git hook (installed by `graphify hook install`) |
| Operator's centralized vault | `~/.claude/vault/` | no — outside the repo | Cross-project graphify snapshots (`graphify/shiprocket-api-skill/`) and concept notes (`zettel/concepts/`) for the operator's Obsidian + MCP workflow |

The `/resume` slash command reads, in order: the most recent file in `docs/progress/` → `graphify-out/GRAPH_REPORT.md` → the 3 most recent ADRs. The `/save` skill appends new entries at end-of-session.

To populate `graphify-out/` after a fresh clone:

```sh
graphify update .
```

(Install graphify with `uv tool install graphifyy` or `pipx install graphifyy`.) The post-commit hook keeps it fresh thereafter.

## Uninstall

```sh
shiprocket-api-skill uninstall-token --yes              # removes the stored token
rm "$(command -v shiprocket-api-skill)"                 # remove the launcher
rm -rf ~/.local/share/shiprocket-api-skill              # remove the cloned repo
rm -rf ~/.shiprocket-api-skill                          # remove audit log + secrets dir
```

On Windows, delete `%USERPROFILE%\.local\bin\shiprocket-api-skill.cmd`, `%USERPROFILE%\.local\share\shiprocket-api-skill`, and `%USERPROFILE%\.shiprocket-api-skill`.

## License & attribution

MIT. See [LICENSE](LICENSE). For the full author attribution and an AI-authorship disclaimer (please read it before running mutations against a production account), see [AUTHORS.md](AUTHORS.md).
