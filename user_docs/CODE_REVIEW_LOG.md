# Code Review Log

> **What this is:** an append-only record of code review findings. Each review
> adds a dated section. Findings are never deleted — resolved ones are marked
> with their fix. This is a reference document for the developer; it is not a
> task list (use GitHub Issues or a separate tracker for that).
>
> **Status values:** `open` | `resolved (YYYY-MM-DD)` | `by-design (reason)`
>
> **Severity:** `critical` | `high` | `medium` | `low`

---

## Review 001 — 2026-06-05 (pre-production readiness, by claude/high effort)

Scope: Full POC codebase (`poc/app/app.R`, `poc/fulfilment/app.R`, `poc/etl/etl.R`,
`.gitignore`, `user_docs/`). Reviewed against `ARCHITECTURE.md`, `DECISION_LOG.md`,
`PROJECT_BRIEF.md`, `DISCLOSURE_CONTROL.md`, `DATA_DICTIONARY.csv`.
Focus: anything that would cause problems moving from POC to production.

### Finding 001-01 — date_of_birth exposed at full precision in fulfilment extract
- **Severity:** high
- **Status:** open
- **File:** `poc/fulfilment/app.R:214` / `poc/etl/etl.R:82`
- **Detail:** ETL applies the `year-month` truncation only when writing `public_slim.csv`.
  `full_restricted.parquet` retains raw full-precision dates. The fulfilment
  `downloadHandler` applies no re-transform before `write.csv`, so a requester
  who selects `date_of_birth` receives `"1985-06-14"` instead of the `"1985-06"`
  they saw in the public app. `DATA_DICTIONARY.csv` marks this column
  `public_transform=year-month`.
- **Design note:** This is a design decision, not a clear-cut bug. Vetted
  requesters may legitimately need full-precision dates. The issue is that the
  choice is currently undocumented and inconsistent with what the public user saw.
  **A decision log entry is needed** clarifying whether the full extract should
  re-apply public transforms or expose full-precision data.

### Finding 001-02 — date_of_death same full-precision issue
- **Severity:** high
- **Status:** open
- **File:** `poc/etl/etl.R:80` / `poc/fulfilment/app.R:214`
- **Detail:** Identical root cause to 001-01 but for `date_of_death`. Slightly
  lower sensitivity (date of death less identifying than DOB) but same
  design-decision gap.

### Finding 001-03 — full extract CSVs not git-ignored; two already tracked in repo
- **Severity:** high
- **Status:** open
- **File:** `.gitignore`
- **Detail:** `git ls-files` confirms `Csvs to check/full_extract_20260604(3).csv`
  and `Csvs to check/drug_deaths_20260604(10).csv` are tracked. The `.gitignore`
  has no rule covering `full_extract_*.csv` or the `Csvs to check/` folder —
  only `poc/data/full/` is protected. When real data runs through the fulfilment
  tool, a `git add .` will commit full-detail records of deceased persons.
- **Fix required:** Add ignore rules for `full_extract_*.csv`, `Csvs to check/`,
  and any other directory where extracts may land. Revisit as part of the
  planned folder structure overhaul (Phase 3).

### Finding 001-04 — age filter silently drops all rows with missing age
- **Severity:** medium
- **Status:** open
- **File:** `poc/app/app.R:216` / `poc/fulfilment/app.R:204`
- **Detail:** Both apps filter `age_at_death >= slider_min`. In R, `NA >= numeric`
  evaluates to `NA`, which `dplyr::filter` treats as `FALSE` and drops. Records
  with a missing age are silently excluded even when the slider is at its full
  extent. The fulfilment extract will silently undercount relative to what the
  public user saw, with no warning in the UI.
- **Fix:** Add `| is.na(age_at_death)` to the age filter conditions in both apps,
  or pre-separate missing-age rows and re-join after filtering.

### Finding 001-05 — ETL has no programmatic assertion that public output is clean
- **Severity:** medium
- **Status:** open
- **File:** `poc/etl/etl.R:92`
- **Detail:** The final safety check is a `message()` asking the developer to
  visually scan the column list. There is no `stopifnot()` or `stop()` that
  would halt the ETL if a `tier=restricted` or `tier=never` column name
  appeared in `names(df_public)`. At 700 columns in production, a single
  misclassified row in `DATA_DICTIONARY.csv` would silently write a restricted
  column to `public_slim.csv` and publish it to GitHub Pages.
- **Fix:** Add an explicit assertion after building `df_public`:
  `stopifnot(all(names(df_public) %in% public_dict$column_name))`

### Finding 001-06 — MISSING_STRINGS, normalise_cat(), FILTER_COLS duplicated in both apps
- **Severity:** medium
- **Status:** open
- **File:** `poc/app/app.R:31–40` / `poc/fulfilment/app.R:25–38`
- **Detail:** All three definitions are copy-pasted verbatim with no shared
  `source()`. Any change to the sentinel list in one file that isn't replicated
  to the other causes the public viewer and fulfilment app to normalise missing
  values differently — filter values from the request.json stop matching records
  in the full parquet, silently producing wrong row counts.
- **Fix:** Extract to `poc/shared/data_utils.R` and `source()` it from both apps.

### Finding 001-07 — secondary_substances in FILTER_COLS but never written to request.json
- **Severity:** medium
- **Status:** open
- **File:** `poc/app/app.R:39`
- **Detail:** `secondary_substances` is in `FILTER_COLS` (implying filter intent)
  but the public app has no checkbox UI for it and the request.json payload has
  no `secondary_substances` key. The fulfilment filter chain also doesn't use it,
  so the mismatch is currently harmless. However, if a future maintainer adds
  `secondary_substances %in% norm_filter(filters$secondary_substances)` to the
  fulfilment filter chain, `filters$secondary_substances` will be `NULL` and
  every extract will silently return zero rows.
- **Fix:** Either remove `secondary_substances` from `FILTER_COLS` (if filtering
  is not intended), or add it fully — UI checkbox, request.json key, and
  fulfilment filter condition — in one coordinated change.

### Finding 001-08 — fulfilment app reloads full parquet on every download click
- **Severity:** low
- **Status:** open
- **File:** `poc/fulfilment/app.R:195`
- **Detail:** `arrow::read_parquet()` + `as.data.frame()` + `mutate` + `filter`
  runs inside `downloadHandler$content`, which executes on every button click.
  For dummy data this is invisible. At production scale (real data, possibly on
  a network share), each click re-reads and reprocesses the whole file causing
  multi-second hangs.
- **Fix:** Move the parquet load + normalisation into a `reactive()` keyed on
  `input$parquet_path`. The `downloadHandler` then filters the already-loaded
  cached frame.

### Finding 001-09 — DISCLOSURE_CONTROL.md stale and unsigned
- **Severity:** low
- **Status:** open
- **File:** `user_docs/DISCLOSURE_CONTROL.md:56`
- **Detail:** Two problems:
  1. Section 6 ("Publish gate") still reads "Only `data/public/public_slim.parquet`
     is ever published" — Decision 011 switched the output to CSV. An auditor
     checking this gate would conclude it's satisfied because the parquet doesn't
     exist, missing the live CSV entirely.
  2. Section 2 (sign-off) has three unfilled `[NAME / ROLE]` / `[DATE]` /
     `[NOTES]` placeholders. Living-third-party field treatment and postcode
     granularity are also unresolved `[CLIENT DECISION]` items.
- **Fix:** Update the parquet reference to CSV. Complete sign-offs and open
  decisions before any real data is published.

### Finding 001-10 — docs/ Shinylive bundle on main will bloat git history on every refresh
- **Severity:** low (structural debt, grows over time)
- **Status:** open (logged as Decision 015)
- **File:** `docs/`
- **Detail:** `docs/app.json` is ~16.7 MB of base64-encoded app + CSV data.
  Each quarterly data refresh re-commits this file to `main`. Git stores the
  full content of every committed version — after a year of updates the repo
  accumulates ~60+ MB of binary blobs. `git clone` slows; diffs are unreadable.
- **Fix:** Adopt a `gh-pages` orphan branch. GitHub Pages serves from that
  branch; the compiled output is force-pushed each refresh (replacing, not
  appending). `main` stays source-only and lean. Implement before the first
  real-data refresh.
- **Cross-ref:** Decision 015.
