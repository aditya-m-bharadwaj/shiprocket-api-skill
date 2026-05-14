# Project: Shiprocket-API Skill (`shiprocket-api-skill`)

A safe, cross-platform CLI (`shiprocket-api-skill`) for the [Shiprocket API](https://apidocs.shiprocket.in/), plus a matching Claude skill that drives it. The skill at [.claude/skills/shiprocket-api-skill/SKILL.md](.claude/skills/shiprocket-api-skill/SKILL.md) is authoritative for runtime behavior — read it before acting on any Shiprocket-related request.

## Hard rules (override anything else)

1. **Never read the user's Shiprocket credentials.** Do not run `security find-generic-password`, `secret-tool lookup`, `cmdkey`, `printenv SHIPROCKET_TOKEN`, `env | grep SHIPROCKET`, or `cat ~/.shiprocket-api-skill/token`. Do not ask the user to paste their API-user email/password or JWT into chat — even "temporarily".
2. **Never call the Shiprocket API directly** with `curl`/`wget`/`requests`. Always go through `./bin/shiprocket-api-skill` (or `shiprocket-api-skill` if installed). Direct API calls bypass classification and audit.
3. **Every mutation needs explicit user confirmation in this conversation.** The CLI's `--yes` is the *machine* gate; the user's "yes" in chat is the *human* gate.
4. **Respect classifier output.** The CLI categorizes every endpoint as `read`, `mutating`, `destructive`, `billable`, `financial`, or `privilege`, and refuses mutations without the matching flags. If you don't know a path's classification, run `shiprocket-api-skill classify <METHOD> <path>` before you plan the call.
5. **Cancellation after AWB assign may incur fees.** Even though `/orders/cancel` is classified `destructive` (not `billable`), Shiprocket may charge cancellation / RTO fees on shipments that already had a carrier booked. Always tell the user before cancelling a shipment that has an AWB attached.

## Billable actions in Shiprocket

The classifier table identifies these endpoints as the points where Shiprocket actually commits courier capacity (and so the operator is charged):

- `POST /courier/assign/awb` — assigns the carrier (the financial commit point for forward shipments).
- `POST /courier/assign/awb/return` — for return shipments.
- `POST /courier/generate/{pickup,label,invoice,manifest}` — generating shipping artifacts is paid per pull on most plans.
- `POST /shipments/create/{forward-shipment,return}` — books carrier capacity.

Treat order creation (`POST /orders/create/adhoc`) as free; the order record itself doesn't commit money. The billable moment is AWB assignment.

## When asked to "set up the token"

Tell the user to run `./bin/shiprocket-api-skill setup` (or `shiprocket-api-skill setup`) themselves. You cannot — it reads from a TTY, which you don't have. If they want an AI-runnable path, offer `shiprocket-api-skill gui-setup` instead (pops a native OS credential dialog the AI cannot observe).

## Cross-platform notes

Token storage by platform: macOS Keychain → Linux Secret Service (libsecret) → file fallback at `~/.shiprocket-api-skill/token` (mode 600). The CLI picks the strongest available backend at run time.

## Memory protocol (binding for /resume, /save, and any agent in this repo)

Project memory is split into three layers by purpose:

| Layer | Location | Tracked by git? | What lives there |
| --- | --- | --- | --- |
| **In-repo canonical** | `docs/` | yes | Decision records (ADRs), session-by-session progress notes |
| **Live code graph** | `graphify-out/` | no (auto-regenerated) | `GRAPH_REPORT.md`, `graph.json`, `graph.html`. Rebuilt by graphify post-commit hook |
| **Operator's centralized vault** | `~/.claude/vault/` | no (lives outside the repo) | Cross-project graphify snapshots at `graphify/shiprocket-api-skill/`; cross-project concept notes at `zettel/concepts/` |

In-repo layout:

```
docs/
├── README.md                                ← memory layer index
├── progress/                                ← session-by-session progress notes
│   ├── TEMPLATE.md
│   └── YYYY-MM-DD-<slug>.md
└── decisions/                               ← ADRs (numbered)
    ├── TEMPLATE.md
    └── NNNN-<slug>.md
```

`graphify-out/` (gitignored, in repo root) contains the live code-structure graph. After cloning, run `graphify update .` once to populate it; the post-commit hook keeps it fresh thereafter.

### `/resume` reads, in order:

1. The most recent file in `docs/progress/` (sorted by filename = sorted by date).
2. `graphify-out/GRAPH_REPORT.md` for current code structure (run `graphify update .` first if absent on a fresh clone).
3. The 3 most recent files in `docs/decisions/`.

Then summarizes: where we left off, what's in-flight, what's next, open questions.

### `/save` writes:

- A new progress note at `docs/progress/YYYY-MM-DD-<slug>.md` summarizing the just-finished session.
- If a material design decision was made in the session, also a new ADR at `docs/decisions/NNNN-<slug>.md` (use the next available number).

### What goes in the centralized vault vs. the in-repo `docs/`

- **`docs/`** is the *canonical, tracked* memory of this project. ADRs and progress notes live here and are part of the public artifact. **Do not duplicate them** to the centralized vault.
- **`~/.claude/vault/graphify/shiprocket-api-skill/`** holds a copy of the latest graphify output for use by the operator's Obsidian + MCP setup. It is operator-local; collaborators don't see it.
- **`~/.claude/vault/zettel/concepts/`** holds reusable, cross-project concept notes. These are the operator's exploratory knowledge graph, not project-specific deliverables.

The split rule: anything that should ship with the repo or guide a contributor goes in `docs/`. Anything that's a working surface for the operator's personal Obsidian / graphify workflow goes in `~/.claude/vault/`.

## Commit-message rules (binding for any AI agent in this repo)

When you produce a commit on behalf of the operator, follow [CONTRIBUTING.md](CONTRIBUTING.md) §"Commit message format" exactly. Format:

```
type(scope): short subject

Brief description.

- Bullet per logical change.

Prompted-By: <operator name> <operator email>
Co-Authored-By: <model name and version> <noreply address>
```

- **`type`** ∈ {`feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `ci`, `build`}.
- **`Prompted-By:`** identifies the human who directed the commit. Use the *current operator's* name and email — read it from `git config user.name` / `git config user.email` if not told otherwise. Do not assume any specific person; this project is open source and any contributor may run you.
- **`Co-Authored-By:`** identifies the model that wrote the code. Use the actual model identifier you are running as (e.g. `Claude Opus 4.7 (1M context) <noreply@anthropic.com>`). Don't fabricate versions.
- Add the trailers only when the AI materially shaped the commit; omit them on hand-typed changes.
- One logical change per commit. Split unrelated work.
- Never bypass commit hooks (`--no-verify`, `--no-gpg-sign`) without an explicit per-commit instruction from the operator.

If the operator has not given explicit go-ahead to commit, draft the message and stop — do not run `git commit`.

## graphify

This project will have a graphify knowledge graph at `graphify-out/` (populated by `graphify update .` after the first commit lands).

Rules:
- Before answering architecture or codebase questions, read `graphify-out/GRAPH_REPORT.md` for the structure overview.
- For cross-file "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's extracted + inferred edges.
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST + markdown extraction, no API cost).
