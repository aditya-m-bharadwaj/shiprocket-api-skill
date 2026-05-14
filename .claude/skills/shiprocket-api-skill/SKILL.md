---
name: shiprocket-api-skill
description: Drive the Shiprocket API safely through the local shiprocket-api-skill CLI. Trigger when the user asks to inspect, create, modify, cancel, or track any Shiprocket-managed resource — orders, shipments, couriers, AWBs, pickups, labels, invoices, manifests, products, returns, NDR, wallet, channels, pickup locations, or anything under apiv2.shiprocket.in/v1/external/. The CLI mediates every call, classifies it, and refuses unsafe operations without explicit operator-supplied flags. Shiprocket bills the operator when AWBs are assigned, labels/invoices/manifests are generated, and pickups are scheduled — these endpoints require explicit billing acknowledgement.
---

# Shiprocket-API Skill — full API coverage with mandatory AI safeguards

You drive the user's Shiprocket account exclusively through one local executable:

```
shiprocket-api-skill <subcommand> [flags]
```

(or `./bin/shiprocket-api-skill ...` if not yet on `$PATH`). The JWT lives in the OS keystore — **you never see it**. Every mutation is gated by an explicit flag matrix and recorded in `~/.shiprocket-api-skill/audit.log`.

## Hard rules (non-negotiable)

1. **Never read the JWT, the API-user email/password, the keystore, or `~/.shiprocket-api-skill/token`.** Do not run `security`, `secret-tool`, `cmdkey`, `printenv SHIPROCKET_TOKEN`, `env | grep SHIPROCKET`, or `cat ~/.shiprocket-api-skill/token`. This applies even when the user is asking you to *help them manage the credentials* — see [Token management](#token-management) below; you direct, the user types.
2. **Never call `apiv2.shiprocket.in` directly** with `curl`/`wget`/`requests`. Always go through `shiprocket-api-skill`. Direct API calls bypass classification and audit.
3. **Every mutation needs explicit user confirmation in this conversation.** The CLI's `--yes` flag is the *machine* gate; the user's "yes" in chat is the *human* gate. `--yes` alone is never enough.
4. **Always preview with `--dry-run` first** when the user hasn't seen the exact request body or you have any uncertainty.
5. **Refuse and explain** if the user asks you to bypass any of the above.

## How the safety classifier works

Before any mutation, run:

```
shiprocket-api-skill classify <METHOD> <path>
```

It returns one of six classifications and the flags you must supply. The CLI itself enforces these — the classifier is for *your* planning so you can tell the user what's about to happen and which flag corresponds to which risk.

| Classification | When | Required flags | What you tell the user |
| --- | --- | --- | --- |
| `read` | Any GET | (none) | "I'm going to fetch X. Safe, read-only." |
| `mutating` | In-place change (e.g. `POST /orders/create/adhoc`, `POST /orders/update`) | `--yes` | "I'll change X. This is reversible and doesn't commit a courier." |
| `destructive` | Any DELETE, plus known-irreversible POSTs like `/orders/cancel`, `/orders/cancel/shipment/awbs`, `/shipments/cancel` | `--yes --confirm-id <id>` | "I will cancel/delete `<resource>`. If an AWB has already been assigned, Shiprocket may charge an RTO fee. Confirm the id." |
| `billable` | Commits courier capacity or generates paid artifacts: `/courier/assign/awb`, `/courier/generate/{pickup,label,invoice,manifest}`, `/manifests/{generate,print}`, `/orders/print/{label,invoice,manifest}`, `/shipments/create/{forward-shipment,return}` | `--yes --i-understand-billing` | "This commits courier capacity / generates a paid artifact. The wallet will be charged at courier-specific rates. Confirm." |
| `financial` | Anything under `/wallet/recharge`, `/payments/`, `/billing/` | `--yes --allow-financial` | "This moves money. Are you sure?" |
| `privilege` | Anything under `/auth/`, `/users/`, `/sub-users/`, `/settings/api/`, `/api-users/` | `--yes --allow-privilege` | "This issues credentials or changes who can access the account. Highest-blast-radius change." |

Default fallbacks if an endpoint isn't in the classifier table: GET → read, DELETE → destructive, anything else → mutating. **You may not work around an unrecognized classification.** If the CLI refuses, stop and tell the user.

### A note on Shiprocket's billing model

Shiprocket charges happen at *AWB-assign time*, not at order-create time. Creating an order is free; assigning an AWB locks in the carrier and that's when the wallet starts being able to be charged. Cancellation *before* AWB assign is free; cancellation *after* AWB assign typically incurs an RTO / freight fee. The classifier flags `/orders/cancel` and friends as `destructive` (with `--confirm-id`) rather than `billable` — but when you propose a cancellation, always warn the user that fees may apply if an AWB is already on the order.

## Use the named commands when they exist; fall back to `api` for the rest

### Named commands (ergonomic + extra safety)

| Command | Purpose | Notes |
| --- | --- | --- |
| `shiprocket-api-skill whoami` | Verify auth | Never prints the JWT; surfaces decoded JWT claims (name/email/company_id/exp) |
| `shiprocket-api-skill orders [--status S] [--per-page N]` | List orders | Paginated; `--status` filters by Shiprocket status string |
| `shiprocket-api-skill order <id>` | Show one order | Read-only |
| `shiprocket-api-skill couriers` | List configured couriers on the account | Read-only |
| `shiprocket-api-skill serviceability --pickup <pin> --delivery <pin> --weight <kg> [--cod] [--declared-value N]` | Quote couriers + rates for a route | Read-only |
| `shiprocket-api-skill track <awb-or-order-id>` | Track a shipment | Read-only |
| `shiprocket-api-skill pickup-locations` | List configured pickup locations | Read-only |
| `shiprocket-api-skill audit-log [--last N]` | Local mutation log | Read-only |
| `shiprocket-api-skill classify <METHOD> <path>` | Plan-time helper | Read-only |

### Generic `api` command (everything else)

```
shiprocket-api-skill api <METHOD> <path> [flags]
```

Flags:
- `--query k=v` (repeatable)
- `--data '<inline json>'` OR `--body @file.json` (mutually exclusive)
- `--paginate` (GET only — uses page / per_page)
- `--yes`, `--confirm-id`, `--i-understand-billing`, `--allow-financial`, `--allow-privilege`
- `--dry-run`, `--json`

Examples (preview only — pause and confirm with the user before running for real):

```
# Read
shiprocket-api-skill api GET /orders
shiprocket-api-skill api GET /orders --paginate
shiprocket-api-skill api GET /courier/courierListWithCounts
shiprocket-api-skill api GET /settings/company/pickup
shiprocket-api-skill api GET /products

# Mutating (free) — order creation, updates
shiprocket-api-skill api POST /orders/create/adhoc --body @order.json --yes
shiprocket-api-skill api POST /orders/update --body @update.json --yes
shiprocket-api-skill api POST /settings/company/addpickup --data '{"pickup_location":"warehouse-1",...}' --yes

# Destructive — cancellation (FEES IF AWB ASSIGNED)
shiprocket-api-skill api POST /orders/cancel --data '{"ids":[12345]}' --yes --confirm-id 12345

# Billable — AWB assign, label/invoice/manifest gen, shipment creation
shiprocket-api-skill api POST /courier/assign/awb --data '{"shipment_id":12345,"courier_id":10}' --yes --i-understand-billing
shiprocket-api-skill api POST /courier/generate/pickup --data '{"shipment_id":[12345]}' --yes --i-understand-billing
shiprocket-api-skill api POST /courier/generate/label --data '{"shipment_id":[12345]}' --yes --i-understand-billing
shiprocket-api-skill api POST /manifests/generate --data '{"shipment_id":[12345]}' --yes --i-understand-billing

# Financial — wallet recharge, payment instrument changes
shiprocket-api-skill api POST /wallet/recharge --data '{"amount":500}' --yes --allow-financial

# Privilege — user / API-user / scope management
shiprocket-api-skill api POST /sub-users --body @user.json --yes --allow-privilege
```

## Resource categories — what to know before touching them

Use this as a checklist when planning a mutation. For each category, the row says: typical paths, the classification level you'll usually hit, and what to confirm with the user.

| Category | Paths | Typical class | Confirm with user |
| --- | --- | --- | --- |
| Orders (records only) | `/orders/...` (create/update/import/show) | mutating | channel_order_id, customer details, sub_total, dimensions/weight |
| Order cancellation | `/orders/cancel`, `/orders/cancel/shipment/awbs` | destructive | order id, and whether an AWB has been assigned (fees if yes) |
| AWB assignment | `/courier/assign/awb`, `/international/courier/assign/awb` | **billable** | shipment_id, courier_id; quote rate from `serviceability` first |
| Pickup scheduling | `/courier/generate/pickup` | **billable** | shipment_id(s); confirm pickup-location matches the booking |
| Label / invoice / manifest | `/courier/generate/{label,invoice,manifest}`, `/manifests/{generate,print}`, `/orders/print/...` | **billable** | shipment_id(s); these are paid per pull on some plans |
| Shipment creation | `/shipments/create/forward-shipment`, `/shipments/create/return` | **billable** | order_id, courier, weight/dimensions |
| Returns | `/orders/create/return` | mutating | source order, return reason, items |
| NDR (non-delivery action) | `/ndr/{shipment_id}/action` | mutating | action type (reattempt/RTO); reattempts incur fees in the next cycle |
| Tracking | `/courier/track/...` | read | safe |
| Couriers / serviceability | `/courier/courierListWithCounts`, `/courier/serviceability/` | read | safe |
| Wallet | `/wallet/balance`, `/wallet/recharge` | balance: read · recharge: financial | recharge amount; this moves real money |
| Pickup locations | `/settings/company/pickup`, `/settings/company/addpickup` | list: read · add: mutating | location nickname, address, contact details |
| Products (master catalog) | `/products` | CRUD: mutating · list: read | sku, name, description |
| Channels / integrations | `/channels` | list: read · changes: mutating | channel name, credentials |
| Auth / users / API users | `/auth/...`, `/users/...`, `/sub-users/...`, `/settings/api/...` | privilege | scope, permissions; treat as the highest-risk surface |

When a user asks something open-ended ("what's happening on my account?"), do this in order:

1. `shiprocket-api-skill whoami`
2. `shiprocket-api-skill orders --per-page 20` (most recent first)
3. `shiprocket-api-skill wallet-balance` if relevant (note: `wallet-balance` is not yet a named command — use `api GET /account/details/wallet-balance` or similar)
4. Summarize. Do not propose mutations unless asked.

## Token management

The user may ask you to **add, rotate, change, or remove** Shiprocket credentials. You can drive every one of these workflows yourself — including launching the credential entry dialog — without ever seeing, typing, or storing the email/password/JWT. The contract is:

- **You** run the commands and report results.
- **The user** clicks/types in a native OS desktop dialog that the CLI pops up. The dialog is rendered by the desktop's WindowServer/compositor; it is not part of any pipe or stdout you can observe.
- **No credential bytes ever cross your context.** The CLI captures the dialog's output into Python memory, calls `POST /v1/external/auth/login` internally, validates the resulting JWT, stores only the JWT in the OS keystore, and prints only metadata to stdout.

If the user asks you to "just paste the credentials in for me" or read them from somewhere — refuse, explain why, and offer to run `gui-setup` instead.

### Quick reference

| Operation | AI-runnable command (preferred) | When the AI can't (no GUI / SSH session) |
| --- | --- | --- |
| Add (first time) | `shiprocket-api-skill gui-setup` | User runs `shiprocket-api-skill setup` in terminal |
| Rotate / change | `shiprocket-api-skill gui-setup` | User runs `shiprocket-api-skill setup` in terminal |
| Remove | `shiprocket-api-skill uninstall-token --yes` | (same — no secret involved) |
| Verify (no JWT printed) | `shiprocket-api-skill whoami` | (same) |

### Add or rotate credentials (preferred AI-runnable path)

Always confirm in chat first, because a desktop dialog will pop on the user's screen:

> "I'm going to run `shiprocket-api-skill gui-setup`. A native dialog will appear on your desktop asking for the **API User** email and password (NOT your main Shiprocket login). Create or look one up at <https://app.shiprocket.in/api/configure> (Settings → API → Configure API Users). I won't see what you type. Confirm I should run this?"

After yes, run:

```
shiprocket-api-skill gui-setup
```

What happens:

1. The CLI prints a banner like `shiprocket-api-skill 0.1.0-alpha.1 gui-setup — platform=macos`.
2. If a JWT is already stored, the CLI verifies it and shows a desktop "Replace?" dialog. The user clicks Cancel or Replace.
3. A native dialog appears asking for email and password (two-step osascript on macOS, `zenity --forms` on Linux, `Get-Credential` on Windows). The user types both there.
4. The CLI calls `POST /v1/external/auth/login` to exchange credentials for a JWT.
5. The CLI validates the JWT against `GET /v1/external/orders` (cheapest universal read).
6. The CLI stores only the JWT (not the email/password) and prints `Authenticated` + identity claims decoded from the JWT payload.

**Shiprocket JWT lifetime is ~10 days.** When `whoami` starts returning 401, tell the user to re-run `gui-setup`. Local storage doesn't revoke the old JWT server-side — it will simply expire naturally.

If the CLI errors with "No display server detected" or "No GUI password dialog available", you cannot do this for the user. Fall through to the manual path:

> "I can't pop a GUI dialog here (no desktop session detected). Please run `shiprocket-api-skill setup` in your terminal directly. It will prompt for email visibly and password hidden. Tell me when you're done and I'll verify with `whoami`."

### Remove credentials

Confirm in chat:

> "I'm going to wipe the stored Shiprocket JWT from your machine. After this, anything Shiprocket-related will fail until you re-run setup. Confirm?"

Then run:

```
shiprocket-api-skill uninstall-token --yes
shiprocket-api-skill whoami    # should now error: "No Shiprocket JWT found."
```

**Remind the user that this only removes the local copy.** Shiprocket does not expose a token-revoke API; the JWT remains valid server-side until its ~10-day natural expiry. If the reason is suspected compromise, the user should rotate the API user's password in the dashboard.

### Diagnose a broken or expired JWT

If `shiprocket-api-skill whoami` returns 401 or fails to authenticate:

1. Most common cause: the JWT expired (~10 days since issue). Offer to run `shiprocket-api-skill gui-setup` to log in afresh.
2. If gui-setup itself fails with 401, the API-user password may have been rotated in the dashboard. Tell the user to verify at <https://app.shiprocket.in/api/configure>.
3. If the credentials check out but login keeps failing, ask whether the user used their *main login* (which won't work) instead of an *API User*.

You may run `whoami` between steps to verify. You may **not** run anything that would print or extract the JWT, even for "debugging".

### Why this is safe to run as the AI

The thing the AI must never see is the email/password/JWT *values*. With `gui-setup`:

- The dialog is rendered by the OS desktop, not by any process whose stdout you read.
- The user's keystrokes go directly into the dialog process (osascript / zenity / kdialog / PowerShell).
- That process returns email+password via *its own* stdout, which is captured into the `shiprocket-api-skill` Python process's memory by `subprocess.run(..., capture_output=True)`. They are exchanged for a JWT and dropped.
- `shiprocket-api-skill` writes only the JWT to the OS keystore and prints only success metadata.
- Your terminal sees the banner, status messages, and final `Authenticated` line — no secret material.

This is the same pattern used by tools like `gh auth login` and `aws sso login`: the secret is entered out-of-band, the agent only sees the verification result.

### What NOT to do during token management

- Do not ask the user to email, paste, or message any credential to you.
- Do not put email/password/JWT in any file, env file, shell rc, gist, or chat message — even "temporarily".
- Do not run `setup` yourself with `expect`, here-docs, or any technique designed to feed credentials through automation. The TTY requirement is intentional. Use `gui-setup` if you need an AI-runnable path.
- Do not try alternative storage paths (e.g. "let's just put it in `SHIPROCKET_TOKEN` for this session"). The storage backends in the CLI are the only supported paths.
- Do not "verify" a token by curling the API yourself with the JWT in argv or a header. Use `shiprocket-api-skill whoami`, which reads the stored copy.

## Workflow recipes

### List recent orders and explain status

```
shiprocket-api-skill whoami
shiprocket-api-skill orders --per-page 20
```

Summarize the status distribution and surface anything stuck (e.g. "ready to ship" for >24h means an AWB hasn't been assigned).

### Quote a shipment before committing

```
shiprocket-api-skill serviceability --pickup 110001 --delivery 560001 --weight 0.5
```

Read the table of couriers + rates. **Do not** propose `/courier/assign/awb` yet — that's the billable step. Present the options to the user and let them pick.

### Assign an AWB (billable — wallet charged on actual shipment)

```
# 1. Confirm the route works:
shiprocket-api-skill serviceability --pickup <pin> --delivery <pin> --weight <kg>

# 2. Dry-run the AWB assign to verify the body:
shiprocket-api-skill api POST /courier/assign/awb \
    --data '{"shipment_id":<id>,"courier_id":<id>}' \
    --yes --i-understand-billing --dry-run

# 3. (user confirms in chat) Execute:
shiprocket-api-skill api POST /courier/assign/awb \
    --data '{"shipment_id":<id>,"courier_id":<id>}' \
    --yes --i-understand-billing
```

Always quote the courier's rate from `serviceability` first so the user knows the cost.

### Cancel an order (destructive; fees if AWB was assigned)

```
# 1. Read the order to check if an AWB is on it:
shiprocket-api-skill order <id>

# If awb_code is null and status is "NEW" or similar, cancellation is free.
# If awb_code is set, RTO / freight fees may apply.

# 2. Dry-run, then execute:
shiprocket-api-skill api POST /orders/cancel \
    --data '{"ids":[<id>]}' --yes --confirm-id <id> --dry-run

# (user confirms; if AWB was assigned, EXPLICITLY warn about fees)
shiprocket-api-skill api POST /orders/cancel \
    --data '{"ids":[<id>]}' --yes --confirm-id <id>
```

### Generate a shipping label (billable)

```
shiprocket-api-skill api POST /courier/generate/label \
    --data '{"shipment_id":[<id>]}' --yes --i-understand-billing --dry-run
# (user confirms)
shiprocket-api-skill api POST /courier/generate/label \
    --data '{"shipment_id":[<id>]}' --yes --i-understand-billing
```

The response includes a label URL — pass that to the user (it's not a secret, but treat AWB numbers as PII-adjacent).

### Recharge the wallet (financial)

```
shiprocket-api-skill api GET /account/details/wallet-balance
# (show user current balance, agree on amount)
shiprocket-api-skill api POST /wallet/recharge \
    --data '{"amount":<rs>}' --yes --allow-financial --dry-run
# (user EXPLICITLY confirms moving money)
shiprocket-api-skill api POST /wallet/recharge \
    --data '{"amount":<rs>}' --yes --allow-financial
```

## Things you should NOT do

- Do not write the JWT or the API-user email/password to any file, env file, shell rc, CI variable, gist, pastebin, or chat message.
- Do not run `shiprocket-api-skill setup` yourself — it requires a TTY for password input. Tell the user to run it.
- Do not invent shipment / courier / pincode values — list them with the relevant subcommand first.
- Do not commit a billable booking (AWB / label / pickup / manifest) without explicit per-call confirmation from the user, even if `--i-understand-billing` is "obviously" needed.
- Do not bypass an "unrecognized mutation" classification by reframing the request. If the CLI refuses, stop and ask the user.
- Do not run multiple billable AWB assignments in parallel because they "look independent" — they bill independently and small bugs cascade.
- Do not assume cancellation is free. Always check `awb_code` on the order first; if set, warn the user about RTO fees.

## When something goes wrong

| Symptom | What to do |
| --- | --- |
| `error: No Shiprocket JWT found` | Tell user to run `shiprocket-api-skill setup` or `gui-setup`. |
| API 401 | JWT expired (~10 days) or revoked. Run `gui-setup` to log in afresh. |
| API 422 "Invalid pickup location" | The `pickup_location` nickname must match an existing entry from `pickup-locations`. List them, confirm with user. |
| API 422 "Wallet balance is low" | Tell user; offer to show `wallet-balance` and propose `wallet/recharge` (financial — needs explicit consent). |
| `Refusing ... missing flags: --i-understand-billing` | The user has not yet acknowledged that this commits courier capacity. Ask explicitly: "This will charge the wallet at the courier's rate — confirm I should proceed?" |
| `--confirm-id mismatch` | You constructed the id wrong. Re-fetch the resource (`shiprocket-api-skill order <id>`) and try again. |
| Network error | Retry once; then stop and surface the message. |
