# docs/ — project memory layer

This directory is the **canonical, in-repo, tracked** memory of `shiprocket-api-skill`. Everything here ships with the project and helps a future contributor (human or AI) understand *why* the code looks the way it does.

The split:

| Layer | Location | Tracked? | Contents |
| --- | --- | --- | --- |
| **In-repo canonical** | `docs/` (this dir) | yes | ADRs (`decisions/`) + session progress notes (`progress/`) |
| **Live code graph** | `graphify-out/` (repo root) | no — auto-regenerated | `GRAPH_REPORT.md`, `graph.json`, `graph.html`. Rebuilt by the graphify post-commit hook |
| **Operator's centralized vault** | `~/.claude/vault/` | no — outside the repo | Cross-project graphify snapshots; cross-project concept notes |

## Subdirectories

- [`progress/`](progress/) — session-by-session progress notes. One file per session, named `YYYY-MM-DD-<slug>.md`. Use [`progress/TEMPLATE.md`](progress/TEMPLATE.md) as the starting point.
- [`decisions/`](decisions/) — Architecture Decision Records. Numbered monotonically (`NNNN-<slug>.md`). Use [`decisions/TEMPLATE.md`](decisions/TEMPLATE.md) and link related ADRs with `[[NNNN-other-decision]]`.

## How the `/resume` and `/save` slash commands use this

The project-level slash commands in [`.claude/commands/`](../.claude/commands/) drive this layer:

- `/resume` reads, in order:
  1. The most recent file in `docs/progress/`.
  2. `graphify-out/GRAPH_REPORT.md` (the live code-structure graph; run `graphify update .` once if absent on a fresh clone).
  3. The 3 most recent files in `docs/decisions/`.

- `/save` writes:
  1. A new `docs/progress/YYYY-MM-DD-<slug>.md` summarizing the just-finished session.
  2. (if a material decision was made) A new `docs/decisions/NNNN-<slug>.md` with the next available number.

The protocol is documented for AI agents in [`../CLAUDE.md`](../CLAUDE.md) §"Memory protocol".

## graphify

The `graphify` knowledge graph at `graphify-out/` is gitignored and auto-regenerated. After cloning a fresh repo, run `graphify update .` once to populate it. The post-commit hook installed by `graphify hook install` keeps it fresh.

For cross-file "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep.

## Operator's centralized vault

If you use Obsidian + MCP for cross-project workflow, open `~/.claude/vault/` as your single working vault across all your projects:

- `~/.claude/vault/graphify/shiprocket-api-skill/` — operator-local copy of the latest graphify snapshot.
- `~/.claude/vault/zettel/concepts/` — cross-project concept notes (operator's exploratory knowledge graph).

Neither is part of this repo. ADRs and progress notes stay in `docs/`; they are not mirrored.

## Harness deny-list template

[`settings.local.json.template`](settings.local.json.template) is the harness deny-list template. Copy to `.claude/settings.local.json` in this repo to mechanically prevent the AI from running the keystore commands, calling `apiv2.shiprocket.in` directly via `curl`, or reading `~/.shiprocket-api-skill/token`.

```sh
cp docs/settings.local.json.template .claude/settings.local.json
```

You install the rules — the AI cannot remove its own sandbox.
