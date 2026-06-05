# Decision Log

> **What this is:** an append-only record of significant project decisions and
> *why* they were made. It is a **hybrid** log — both you and Claude write to it.
> Future chats read it to avoid re-litigating settled choices, and append a new
> entry whenever a significant decision is made.
>
> **How to use it:**
> - One entry per decision. Newest at the bottom. **Never edit or delete old
>   entries** — if a decision is reversed, add a new entry that supersedes it and
>   reference the old one.
> - Keep entries short: what was decided, why, and what it rules out.
> - A "significant decision" = anything affecting architecture, scope, data
>   handling, tooling, or hosting. Routine code choices don't need an entry.
> - The instruction for Claude to maintain this lives in
>   `CLAUDE_PROJECT_INSTRUCTIONS.md`.
> - note: the current year is 2026
>
> **Entry format:**
> ```
> ## NNN. <Title>   (YYYY-MM-DD, by <human|claude>) 
> - Decision: ...
> - Why: ...
> - Rules out / supersedes: ...
> ```

---

## 001. Anonymised data only ever leaves the client machine via the public tier -- Which is to say that public tier only contains anonymised data (2026, by human+claude)
- Decision: The `.sav` source and full-detail data stay only on the client's
  machine. The public app holds only the slim anonymised parquet.
- Why: A breach of the public app then leaks nothing sensitive; avoids hosting
  sensitive data online; keeps client in control of full extracts.
- Rules out: in-app authentication and online storage of full-detail data.

## 002. Two-tier model via an offline "request file"   (2026, by human+claude)
- Decision: Public users download an anonymised subset and/or a JSON request
  file describing their selection. The client reproduces that selection against
  full data offline and sends the full extract to vetted requesters.
- Why: Secure and free; no online auth needed; client retains vetting control.
- Rules out: any real-time full-data download path.

## 003. Shinylive (in-browser) for the public app   (2026, by human+claude)
- Decision: Build the public viewer with Shinylive (Shiny compiled to webR),
  hosted as free static files.
- Why: $0 hosting, no per-hour caps, scales trivially for the expected volume
  (max ~5 users/day), and the public tier only handles safe data so client-side
  execution is fine.
- Rules out (for now): server-based Shiny (shinyapps.io free is capped at 25
  active hours/month; Posit Connect Cloud free is the fallback if a needed
  package is unavailable in webR).
- Open: validate in-browser parquet reading (arrow vs nanoparquet vs DuckDB-WASM).

## 004. Slim to ~50 columns at ETL time   (2026, by human+claude)
- Decision: Select the ~50 relevant columns before the data reaches the browser;
  the public parquet contains only those.
- Why: Source is ~700 cols × 60k rows but mostly empty, or contains data only needed by edge cases. Slimming keeps the public file tiny and webR memory low.

## 005. Light abstraction, no strict suppression   (2026, by human+claude)
- Decision: Apply light anonymisation (names removed, dates → year-month,
  locations → postcode). Do **not** implement small-cell suppression / k-anonymity.
- Why: Per client, subjects are deceased and data is from the public record;
  controls are precautionary, not legally mandated. Suppression can be dialled up
  later via `DISCLOSURE_CONTROL.md` if needed.

## 006. Build POC on synthetic dummy data   (2026, by human+claude)
- Decision: Generate synthetic data matching the real shape to build and test
  the whole pipeline today; never put real data in a chat.
- Why: Lets the POC proceed at $0 with no privacy exposure.

## 007. Current workflow plan currently -- all on web (2026, by human)
- Decision: Handle all the workflow on web version, with each section done in a seperate chat, sometimes multiple
- Why: although using claude code would be more efficient the human user has decided on the ease of use and higher degree of control that is accessed by manually working on the code in tandem with work online. 
- IMPORTANT: This may change at a later date.


## 008. Switch to agent-based coding via Claude Code   (2026-06-03, by human+claude)
- Decision: All future coding work will be done using Claude Code (agentic CLI), operating directly on the local repo, rather than via web chat with copy-pasted code.
- Why: More efficient multi-file builds, tighter feedback loop, no manual file-pasting, and better version control integration.
- Rules out / supersedes: Decision 007 (web-only workflow). Web chat may still be used for design discussion, but code production moves to Claude Code.

---

## 009. POC public viewer — local Shiny app first, Shinylive export later   (2026-06-03, by human+claude)
- Decision: Build the public viewer as a standard local Shiny app (`poc/app/app.R`) and validate it fully before attempting Shinylive export.
- Why: Shinylive/webR compatibility of `arrow` (parquet reader) is an open risk noted in ARCHITECTURE.md. Validating the app logic locally first separates UI/UX concerns from the WASM packaging concern.
- Rules out: Attempting `shinylive::export()` before the local app is confirmed working.

## 010. request.json schema v1.1 — add columns_selected field   (2026-06-04, by human+claude)
- Decision: The `request.json` produced by the public app now includes a `columns_selected` array alongside the existing `filters` block. Schema version bumped from 1.0 → 1.1.
- Why: The CSV download was updated to respect the user's column selection on the Data tab; the JSON must carry the same information so the fulfilment GUI can reproduce the exact extract (rows AND columns) the requester saw.
- Rules out: The fulfilment GUI (Component 3) reading only `filters` from the request file — it must also apply `columns_selected` to the full-detail extract.

## 011. Public slim output: parquet → CSV   (2026-06-04, by human+claude)
- Decision: ETL now writes `public_slim.csv` (base R `write.csv`) instead of `public_slim.parquet`. The app reads it with `read.csv()`. `full_restricted.parquet` stays as parquet (used only in the local fulfilment tool where `arrow` is always available).
- Why: Eliminates the `arrow`/webR compatibility risk that was blocking Shinylive export (Decision 003). At 44 public columns × 60k rows the CSV is small enough (~5–8 MB) that there is no meaningful size or performance penalty vs parquet.
- Rules out / watch point: If the public column count ever grows significantly above ~100 columns, or the public file exceeds ~15 MB, revisit parquet + a webR-compatible reader (nanoparquet or DuckDB-WASM) as noted in Decision 003.

## 012. Missing value normalisation in public viewer   (2026-06-04, by human+claude)
- Decision: At app load time, the following values in categorical filter columns (sex, location_of_death, primary_substance, secondary_substances, cause_of_death) are collapsed to the display label `"Missing"`: R `NA`, empty string `""`, and the strings `"NA"`, `"NULL"`, `"null"`, `"N/A"`, `"n/a"`, `"Error"`, `"error"`, `"Inf"`, `"-Inf"`. For numeric columns, `Inf`/`-Inf` are coerced to `NA` so sliders ignore them.
- Why: Real data will contain dirty values from multiple sources. Displaying a blank checkbox label (or crashing on Inf) is confusing to users. Collapsing to "Missing" keeps the UI clean.
- IMPORTANT — what this hides: The source distinctions between these sentinel types (e.g. blank vs NULL vs string "NA") are meaningful to the client and may reflect different data collection outcomes. These distinctions are **preserved in the `.sav` and `full_restricted.parquet`** and are never altered by this normalisation. If the client later needs to distinguish missing-value subtypes in the public view, this sentinel list must be revisited.
- Rules out: Showing raw blank/null values as filter choices in the public app.

## 013. Known limitation — chart rendering latency in Shinylive   (2026-06-04, by human+claude)
- Observation: Filter changes trigger 4–6 second re-renders in the Shinylive (webR) app. The data table tab is fast; the bottleneck is the four ggplot2 charts re-aggregating 60k rows on every filter change inside the WebAssembly runtime (~3–10× slower than native R).
- Not fixed now: no quick fix exists that doesn't significantly change the ETL and app architecture.
- Likely solution when addressed: pre-aggregate chart data (counts by year, substance, location, age band) at ETL time and ship lookup tables alongside the CSV. The app then joins rather than group-summarises, cutting webR work dramatically. This will need design discussion before implementation.
- Will worsen over time: row count grows year-on-year, so latency will increase. Revisit when it becomes user-noticeable at production scale.

## 014. .gitignore must be updated alongside any new data folder structure   (2026-06-04, by human+claude)
- Decision: As a standing rule, any new `data/full/` or `data/private/` style folder created during the move from POC to production must have a corresponding `.gitignore` rule added at the same time. The current rule only covers `poc/data/full/`.
- Why: The POC `.gitignore` was added retroactively after dummy data had already been committed. Real source data (`full_restricted.parquet`, `.sav`) must never reach GitHub. Adding the ignore rule alongside the folder creation prevents the gap.
- Rules out: Creating a new full/private data folder without immediately adding a gitignore rule for it.
- Action required: When scaffolding the real app folder structure, add `data/full/` and any equivalent private data paths to `.gitignore` before running any ETL.

<!-- Add new entries below this line -->
