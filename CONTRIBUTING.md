# Contributing

Thanks for taking an interest. `shiprocket-api-skill` is a small project with a strong opinion: every Shiprocket API call goes through one classifier, and unsafe mutations are blocked by default.

## Ground rules

1. **Stdlib only in `bin/shiprocket-api-skill`.** No `requests`, no `pyyaml`, no `click`. Adding a runtime dep means every user has to install it; the value bar for that is high.
2. **No secrets in code, tests, or docs.** Don't commit a real Shiprocket JWT or API-user password — even one you're about to rotate. Tests should not require live API access; mock at the `_request` boundary.
3. **Classifier is allow-list-y, not deny-list-y.** When in doubt about a new endpoint, classify it stricter, not looser. Better to make the operator pass an extra flag than to silently spend their money.
4. **Don't add a wrapper command for every endpoint.** The generic `api` command covers the API surface. Add a named command only when it bundles meaningful extra safety or significantly improves ergonomics for a common read-only task.

## Development setup

```bash
git clone <repo>
cd shiprocket-api-skill
python3 -c "import py_compile; py_compile.compile('bin/shiprocket-api-skill', cfile='/tmp/shiprocket-api-skill.pyc', doraise=True)"
./bin/shiprocket-api-skill --help
python3 -m unittest discover tests
```

Python 3.8+ is required. Tests are offline and stdlib-only.

## How to add an endpoint to the classifier

Open [bin/shiprocket-api-skill](bin/shiprocket-api-skill) and find `_BILLABLE_EXACT`, `_DESTRUCTIVE_EXACT`, `_FINANCIAL_PREFIXES`, `_PRIVILEGE_PREFIXES`, or `_MUTATING_EXACT`. Add the `(METHOD, normalized_path)` tuple (or the prefix string for the prefix tables). Path segments that are numeric ids should be `{id}`. Submit a PR with:

- a link to the Shiprocket API docs page for the endpoint (or a screenshot if the doc page is JS-rendered and not linkable),
- a one-line justification for the classification you chose,
- a `shiprocket-api-skill classify <METHOD> <path>` example showing the new behavior,
- a corresponding test in `tests/test_classify.py`.

## Tests

`tests/test_classify.py` covers the classifier table, normalized-path matching, `_validate_path`, JWT payload decoding, and platform helpers. Run with `python3 -m unittest discover tests`. Don't hit the real API in tests — mock `urllib.request.urlopen` if you need to exercise `_request`.

## Contributing to the wiki

The GitHub wiki (a separate `<repo>.wiki.git` repository) is a contributor-friendly summary layer. Canonical documentation lives in `docs/`; the wiki summarizes and links to it. When `docs/` and the wiki disagree, `docs/` wins.

Local workflow:

```sh
git clone https://github.com/<owner>/shiprocket-api-skill.wiki.git wiki
cd wiki
# Edit *.md (filenames are flat; internal links use [[Page Name]])
git add -A && git commit -m "wiki: <what you changed>"
git push origin master    # wikis default to master, not main
```

Page conventions:
- Files are `Page-Name.md` at the wiki root. No subdirectories — GitHub wikis are flat.
- Internal links: `[[Page Name]]`.
- Links from wiki back to this repo: **absolute** `https://github.com/<owner>/shiprocket-api-skill/blob/main/...` URLs (the two repos are separate).

If you add wiki content that should be canonical, also add it to `docs/` and have the wiki link to it.

## Code style

- 4-space indent, type hints, keep functions short.
- Error messages should tell the user what to do, not just what failed.
- Comments explain the *why*, not the *what*.

## Commit message format

This project uses a Conventional-Commits-shaped subject plus a `Prompted-By` / `Co-Authored-By` trailer block.

```
type(scope): short subject

Brief description (one sentence is enough).

- Bullet per logical change.
- Another bullet.

Prompted-By: Human Name <human@example.com>
Co-Authored-By: AI Model Name <model-noreply-address>
```

- **`type`** is one of `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `ci`, `build`. Match the dominant nature of the change.
- **`scope`** is optional. Use it when the change is localized (`feat(api): …`, `fix(classifier): …`).
- **Subject** is short, imperative, lowercase first letter, no trailing period. Aim for ≤ 72 chars.
- **Brief description** is one sentence explaining *why*, not *what* (the bullets cover *what*).
- **Bullets** are one per logical change. Don't bundle unrelated work into one commit — split it.

### AI-assisted commits

This project distinguishes the **human who prompted/directed** the work from the **model that wrote** the code. Both get credit:

```
Prompted-By: Your Name <you@example.com>
Co-Authored-By: <Model Name and Version> <noreply-address>
```

- **`Prompted-By:`** — the human who directed the AI. Non-standard but increasingly common; it accurately reflects roles when you didn't physically write the code. Add this line whenever the substantive content of the commit was produced through AI prompting.
- **`Co-Authored-By:`** — the model that produced the code. GitHub recognizes this trailer and counts it toward the linked email's contribution graph.
- If your git-config email differs from your GitHub-recognized email, add a second `Co-Authored-By:` for yourself with the GitHub-linked address so the contribution graph still finds you.
- **Use the model identifier you actually used.** Don't invent versions. Examples: `Claude Opus 4.7 (1M context) <noreply@anthropic.com>`, `Claude Sonnet 4.6 <noreply@anthropic.com>`, `GPT-5 <noreply@openai.com>`, `Gemini 2.5 Pro <noreply@google.com>`.
- **Don't credit an AI for changes the AI didn't make.** Conversely, do credit it when it materially produced the diff — even for "small" changes. Honest provenance > flattery in either direction.

### Examples

A typical AI-assisted commit:

```
feat(classifier): mark POST /courier/generate/manifest as billable

Generating a manifest is a paid action on most Shiprocket plans — operators
should have to pass --i-understand-billing.

- Add (POST, /courier/generate/manifest) to _BILLABLE_EXACT.
- Update tests/test_classify.py with the new expectation.

Prompted-By: Your Name <you@example.com>
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

A hand-typed commit (no AI trailers):

```
fix(install): handle PowerShell paths with spaces

- Quote $Py and $Bin in the .cmd shim so USERPROFILE paths
  containing spaces don't break the launcher.
```
