# 2026-05-15 — initial alpha scaffolded by api-skill-builder

## What happened

Bootstrapped `shiprocket-api-skill` v0.1.0-alpha.1 by running the
`api-skill-builder` Claude skill (which lives in
`/Users/aditya/Code/APIskillBuilderSkill/.claude/skills/api-skill-builder/`)
against the Shiprocket API at <https://apidocs.shiprocket.in/>.

The Shiprocket docs page is JavaScript-rendered (Postman-style), so the
skill's WebFetch couldn't parse the canonical endpoint list. The classifier
table was authored from established knowledge of the public API surface
(documented as a known limitation in `CHANGELOG.md` and revisited in ADR
0009).

## What changed

New repository at `~/Code/shiprocket-api-skill/`, mirroring the structure of
[`linode-api-skill`](https://github.com/aditya-m-bharadwaj/linode-api-skill):

- `bin/shiprocket-api-skill` — single-file Python 3.8+ CLI, stdlib only.
  Implements the six-tier safety classifier, cross-platform token storage
  (macOS Keychain / Linux Secret Service / file fallback at mode 0600), the
  generic `api` gateway with flag-gated mutations, and named commands for
  the common reads (`whoami`, `orders`, `order`, `couriers`,
  `serviceability`, `track`, `pickup-locations`, `audit-log`, `classify`).
- `tests/test_classify.py` — 44 offline unit tests covering classifier table
  entries, normalized-path matching, prefix-strip for `/v1/external`, path
  validation, JWT payload decoding, and platform helpers. All passing.
- `.claude/skills/shiprocket-api-skill/SKILL.md` — runtime Claude skill
  with the safety matrix, per-resource confirmation playbooks, token-
  management workflows, and recipes for the common multi-step operations
  (assign-AWB, cancel, label generation, wallet recharge).
- `README.md`, `AUTHORS.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CLAUDE.md`,
  `SECURITY.md`, `LICENSE`, `.gitignore` — full top-level doc set with the
  AI-authorship disclaimer and the Prompted-By / Co-Authored-By trailer
  convention.
- `.github/` — CI matrix (3 OS × Python 3.8–3.12, with macOS 3.8/3.9
  excluded due to runner image availability), shellcheck job, issue and
  discussion templates, `FUNDING.yml`.
- `install.sh` (POSIX) + `install.ps1` (Windows) — installers that verify
  Python 3.8+, symlink/shim the CLI into `~/.local/bin`, optionally install
  the Claude skill, and optionally run `setup`. The Unix installer
  re-attaches stdin to `/dev/tty` under `curl … | sh`.
- `docs/` memory layer with this progress note, ADR templates, and the
  initial ADRs (`0001`–`0008`) inherited from the reference implementation
  plus Shiprocket-specific ones for JWT auth (`0009`) and the
  conservative-classifier-under-undocumented-surface decision (`0010`).

## What's in-flight

- The repo has not been pushed to GitHub yet. The operator needs to
  authorize the push and then run Step 14 of the api-skill-builder skill
  (GitHub repo configuration: About panel, Features, Code security,
  Branch protection, Wiki bootstrap).
- No live smoke test has run. Step 15 of the skill prescribes the
  methodology; the operator needs a sandbox API user with a low-balance
  wallet to exercise the billable / destructive tiers safely.

## What's next

1. Operator review of the classifier table, particularly:
   - Whether `/orders/print/{label,invoice,manifest}` should be `billable`
     or only `mutating` on the operator's plan.
   - Whether pickup scheduling (`/courier/generate/pickup`) is paid on
     the operator's plan.
   - Whether any wallet-related endpoint path beyond `/wallet/recharge`
     should be in `_FINANCIAL_PREFIXES`.
2. Push to `github.com/aditya-m-bharadwaj/shiprocket-api-skill`.
3. Configure the GitHub repo per Step 14.
4. Live smoke test per Step 15.
5. Tag `v0.1.0-alpha.1`.

## Open questions

- Shiprocket's docs site doesn't have a stable per-endpoint URL we can
  link to from PR review comments and ADRs. Is there an OpenAPI spec we
  could mirror in `docs/spec/` so contributors have a citeable surface?
- The `wallet-balance` named command was sketched in the SKILL.md but
  not implemented in `bin/shiprocket-api-skill`. Should we add it, or
  keep the SKILL.md pointing at `api GET /wallet/balance` as the
  generic gateway recipe?
- Shiprocket sometimes uses POST for read-like endpoints (e.g. some
  serviceability quote shapes). The classifier conservatively treats
  unknown POSTs as `mutating`. Should we maintain an explicit
  `_READ_POST_EXACT` table for the well-known read-shaped POSTs to keep
  them out of the `--yes` gate?
