Per the memory protocol in this project's CLAUDE.md:

1. Read the **most recent** file in `docs/progress/` (sorted by filename = sorted by date).
2. Read `graphify-out/GRAPH_REPORT.md` for current code structure. If it doesn't exist (fresh clone), run `graphify update .` first to populate it.
3. Skim the **3 most recent** files in `docs/decisions/`.

Then summarize, in this order:
- **Where we left off** — one-line headline, then a short paragraph.
- **What's in-flight** — work that was started but not finished, with a clear pickup point.
- **What's next** — concrete recommended next steps.
- **Open questions** — decisions not yet made, things to ask the operator about.

Keep the summary tight. The point is to onboard the next session in under a minute, not to recap everything.
