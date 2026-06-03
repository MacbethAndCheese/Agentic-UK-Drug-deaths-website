# Architecture

Chosen path for the drug-related-deaths self-service tool. Read `PROJECT_BRIEF.md`
first for context. Update `DECISION_LOG.md` if any of this changes.

## Design principle

The full data and the `.sav` source live **only on the client's machine** and
are **never hosted online**. The public app only ever holds the slim,
anonymised parquet (~13 MB). A breach of the public app therefore leaks nothing
sensitive. Everything below follows from that principle.

## Data flow

```
                 CLIENT'S MACHINE (offline, private)
   ┌───────────────────────────────────────────────────────────────┐
   │                                                                 │
   │   new .sav (2.5 GB)                                             │
   │        │                                                        │
   │        ▼                                                        │
   │   [ ETL script ] ── reads DATA_DICTIONARY.csv ──┐               │
   │        │                                        │               │
   │        ├──► full_restricted.parquet  (all cols, stays here)     │
   │        │                                        │               │
   │        └──► public_slim.parquet                 │               │
   │            (~50 cols, anonymised)               │               │
   │            (to be accessed by app)              │               │
   │                                                 ▼               │
   │   [ Fulfilment GUI ] ◄────  (drag request file + full data,     │
   │        │                     click → full-detail extract)       │
   │        ▼                                                        │
   │   full extract.csv ──► emailed to a vetted requester            │
   └─────────────────────────────┬───────────────────────────────────┘
                                 │ publish public_slim.parquet + app
                                 ▼
                 STATIC HOST (free: GitHub Pages / Netlify / CF Pages)
   ┌───────────────────────────────────────────────────────────────┐
   │   Shinylive app (runs in the visitor's browser via webR)        │
   │     • loads public_slim.parquet                                 │
   │     • filter / preview                                          │
   │     • download anonymised subset (CSV)                          │
   │     • download request file (JSON) to send to the client        │
   └───────────────────────────────────────────────────────────────┘
                                 ▲
                                 │ opens URL
                            any requester
```

## Components

### 1. ETL script (`etl/`) — local R, run by the client

Responsibilities:
- Read the `.sav` with `haven::read_sav()`.
- Read `docs/DATA_DICTIONARY.csv` to decide, per column: keep/drop, which tier,
  and the public transform.
- Produce two outputs:
  - `data/full/full_restricted.parquet` — all needed columns, untransformed.
    **Stays on the client machine. Git-ignored.**
  - `data/public/public_slim.parquet` — only `tier = public` + `in_poc` columns
    (~50), with transforms applied (e.g. dates → year-month, names removed).
- Be idempotent: re-running on a new `.sav` simply regenerates both files.

Why slim the columns at ETL time: the full data is ~700 columns and mostly
empty. Selecting the ~50 relevant columns *before* the file reaches the browser
keeps the public parquet tiny and keeps webR memory use low.

Key packages: `haven` (read .sav), `arrow` (write parquet), `dplyr` (transforms),
`readr`/`vroom` if needed. R handles 60k × 700 in memory comfortably; the cost is
read time on the 2.5 GB `.sav`, which only happens 2–3×/year.

### 2. Public viewer — Shinylive

A Shiny for R app exported with the `shinylive` package to static files.

Responsibilities:
- Load `public_slim.parquet` (shipped as a static asset alongside the app).
- Let users filter by the core fields (e.g. year, location, substance) and pick
  columns.
- **Preview** the filtered table (paginated; `DT` or `reactable`).
- **Download anonymised subset** as CSV.
- **Download request file** (JSON via `jsonlite`) capturing the exact filter +
  column selection, so the client can reproduce it against full data.

webR / Shinylive notes and caveats:
- Runs entirely in the visitor's browser; no server. Hostable on any static host.
- First load downloads the webR runtime (tens of MB, ~10–30s), then cached.
- Only **precompiled WebAssembly** R packages work; you cannot install from
  source in webR. Check https://repo.r-wasm.org/ for availability.
- **Validate the parquet reader early.** `arrow` can be heavy in WASM. Lighter
  options: `nanoparquet`, or DuckDB-WASM. If parquet proves awkward in-browser,
  fallback is to ship the slim data as compressed CSV/RDS.
- Keep the in-browser dataset slim (the ~50-column file) to stay within memory.

### 3. Client fulfilment + update tool — local Shiny GUI

A small Shiny app the client runs locally (`shiny::runApp()` or a one-click
launcher). Designed for drag-and-click, no command line:

- **Fulfil a request:** drag in the requester's `request.json` and point at the
  full data → click **Generate** → produces the full-detail extract (CSV/XLSX)
  ready to send. Reuses the *same* filter logic as the public app so "full"
  means exactly the requester's selection.
- **Update the data:** drag in a new `.sav` → click **Update** → runs the ETL,
  regenerates both parquets, and (optionally) prints the one publish command.

Making it friendly: a launcher (e.g. a `.bat`/`.command` file or an R-based
desktop shortcut) that opens the GUI in the browser means the client never sees
a console. Document this in `README.md` once built.

## Tech stack

| Concern | Choice |
|---|---|
| Language | R |
| Read .sav | `haven` |
| Columnar storage | parquet via `arrow` |
| Transforms | `dplyr` |
| App framework | Shiny for R |
| In-browser runtime | Shinylive / webR |
| Tables | `DT` or `reactable` |
| Request files | `jsonlite` |
| In-browser parquet (to verify) | `arrow` → else `nanoparquet` / DuckDB-WASM |

## Hosting & deployment

- **Public app:** free static hosting — GitHub Pages, Netlify, or Cloudflare
  Pages. Export with `shinylive::export("app", "site")`, then publish the `site/`
  folder. No server, no per-hour limits, effectively $0.
- **Update flow:** client regenerates `public_slim.parquet` locally, then
  re-publishes (a single command, or wrapped behind the GUI's Update button).
- The chosen host is an open item — see `PROJECT_BRIEF.md` TODO.

## Data handling rules

- `.sav` source and `full_restricted.parquet` are **never** committed or
  uploaded. Enforce via `.gitignore`.
- Only `public_slim.parquet` (already anonymised) may be published.
- No real data in any Claude chat — use the synthetic generator below.

## Proof-of-concept plan (today)

1. **Dummy data:** `etl/generate_dummy_data.R` creates a synthetic dataset of
   the real shape (~700 cols × ~60k rows, ~50 meaningful + sparse filler) and
   writes a `.sav` (or parquet) so the rest of the pipeline can be built and
   tested with zero real data.
2. **ETL:** read dummy `.sav` + dictionary → write slim public parquet + full
   parquet.
3. **App:** minimal Shinylive app — load slim parquet, filter, preview, download
   CSV + request JSON. Test locally, then export to static and open in a browser
   to confirm a cold URL load works.
4. **Fulfilment GUI:** minimal stub — load a request JSON, apply to full
   parquet, output a full CSV.

Build these in separate, focused chats (ideally via Claude Code in the repo).

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Parquet hard to read in webR | Test early; fall back to nanoparquet/DuckDB-WASM or compressed CSV/RDS |
| Slow first load annoys users | Communicate the one-time load; keep data slim |
| Client finds CLI steps daunting | Wrap everything behind the drag-and-click GUI + launcher |
| Accidental publish of full data | `.gitignore` + a publish step that only ever copies `public/` |
| Re-identification via field combos | Light abstraction now; dial up in `DISCLOSURE_CONTROL.md` if needed |
