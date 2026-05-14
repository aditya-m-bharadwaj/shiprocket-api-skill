Generate a session log per the memory protocol in this project's CLAUDE.md.

1. Pick a short slug for what this session was about (e.g. `add-wallet-recharge-classifier`).
2. Write a new file at `docs/progress/YYYY-MM-DD-<slug>.md` using `docs/progress/TEMPLATE.md` as the structure. Today's date in `YYYY-MM-DD` form.

The progress note must include:
- **What was done** — bullets with file paths, function names, commit hashes if relevant.
- **What's in-flight (not finished)** — what was started but blocked or deferred.
- **What's next (recommended pickup)** — one or two concrete next steps.
- **Open questions** — decisions not yet made, things to ask the operator about.
- **Related files / links** — wikilinks to ADRs touched (`[[NNNN-slug]]`), commit hashes, external links.

If a material design decision was made in this session (an architectural choice with tradeoffs that aren't obvious from the diff), also create a new ADR:

- Read the highest-numbered file in `docs/decisions/` to find the next ADR number.
- Copy `docs/decisions/TEMPLATE.md` → `docs/decisions/<NNNN>-<slug>.md` and fill it in.
- Reference the new ADR from the progress note via `[[<NNNN>-<slug>]]`.

Do **not** modify or delete existing notes. Only create new ones, or append to the in-flight progress note if a session continues across multiple invocations of this command.

After writing, list what was created so the operator can verify.
