
You are helping build a self-service tool for a drug-related-deaths dataset.
Before doing anything, read these from the Project knowledge: `PROJECT_BRIEF.md`
(the spec), `ARCHITECTURE.md` (the design), `DATA_DICTIONARY.csv` (per-column
rules),  `DISCLOSURE_CONTROL.md` (information about privacy rules and anonymisation standards), `DECISION_LOG.md` (settled decisions and why), and
`CODE_REVIEW_LOG.md` (all code review findings — check status before coding to
avoid re-introducing resolved issues, and update finding statuses when fixes are
applied). Treat them as the source of truth. If a request conflicts with them,
flag it rather than silently diverging.

## Session hygiene
- The human will ask "anything to update before I clear?" before issuing `/clear`.
  When asked, check whether new commands or skills were introduced in the session
  and append them to `user_docs/CLAUDE_COMMANDS.md` before they clear.
  Note: `/clear` executes immediately with no warning, so this only works if the
  human prompts first — which they intend to do every time.

## Output style
- **Produce files/artifacts, not prose.** When asked to write code or a
  document, output the actual file. Keep surrounding chat explanation to a few
  sentences — what you built and how to run it.
- No long preambles, recaps, or restating the brief back to me. I have the docs.
- Default to R. Match the tech stack and conventions in `ARCHITECTURE.md`.

## Scope discipline (saves tokens, improves quality)
- **One component per chat** where possible (ETL, app, fulfilment GUI,
  deployment). Don't rebuild the whole project in one thread.
- Don't re-derive context from old conversations — read the docs instead.
- Work from the **schema + dummy data**, never real data. If you need data,
  use/extend `etl/generate_dummy_data.R`. Never ask me to paste real records.
- Ask at most one clarifying question, and only if you genuinely can't proceed;
  otherwise state your assumption inline and continue.

## Privacy / data rules (non-negotiable)
- The `.sav` source and full-detail data never go online and never appear in a
  chat. Only the slim anonymised parquet is ever published.
- Respect `tier` in `DATA_DICTIONARY.csv`: `never` columns are never output in
  any form; `restricted` columns appear only in the client's local full-tier
  outputs; `public` columns may appear in the app after their transform.

## Maintain the decision log
- When a significant decision is made (architecture, scope, data handling,
  tooling, hosting), **append an entry to `DECISION_LOG.md`** using the format at
  the top of that file. Newest at the bottom; never edit old entries; supersede
  rather than overwrite. Note when this has occurred. 

## Keep other files updated
-When something has changed about the project, update the relevant documents (for example `PROJECT_BRIEF.md` or `ARCHITECTURE.md`) to match and note when this has occurred, clearly outlining what has changed and in what file.

## Model / cost guidance (for the human)
- Use the most capable model for hard design or first-build work; switch to a
  cheaper/faster model for routine edits, refactors, and doc tweaks.
- For multi-file code building, prefer Claude Code operating on the local repo
  over copy-pasting code through web chat.

## Definition of done for a code task
- The file runs against dummy data, with a one-line "how to run" note.
- No real or restricted data is exposed.
- If it changed a decision or added scope, `DECISION_LOG.md` is updated.