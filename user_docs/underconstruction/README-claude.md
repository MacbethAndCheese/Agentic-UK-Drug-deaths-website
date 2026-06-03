# [PROJECT NAME] — Drug-Related-Deaths Self-Service Tool

A self-service tool for browsing and downloading a curated, anonymised view of a
drug-related-deaths dataset, with an offline workflow for the client to fulfil
full-detail requests. See `docs/PROJECT_BRIEF.md` for the full brief.

## What's in this repo

```
.
├── README.md                  ← you are here
├── docs/
│   ├── PROJECT_BRIEF.md        ← the spec / single source of truth. Read first.
│   ├── ARCHITECTURE.md         ← the chosen design and data flow
│   ├── DATA_DICTIONARY.csv     ← per-column rules (tier + transform). Fill in.
│   ├── DISCLOSURE_CONTROL.md   ← data-handling posture & sign-off. Fill in.
│   └── DECISION_LOG.md         ← append-only record of why decisions were made
├── etl/
│   ├── generate_dummy_data.R   ← creates synthetic test data (no real data needed)
│   └── [convert_sav_to_parquet.R]  ← TODO: the ETL (sav → slim + full parquet)
├── app/                        ← TODO: the Shinylive public viewer
├── client_tools/               ← TODO: the local fulfilment + update GUI
└── data/
    ├── public/                 ← public_slim.parquet (safe to publish)
    └── full/                   ← full_restricted.parquet + .sav  (NEVER committed)
```

> Sections in `[BRACKETS]` and items marked TODO are to be built/filled in.

## File-by-file

- **`docs/PROJECT_BRIEF.md`** — purpose, data description, users, scope, success
  criteria. The thing to read before anything else.
- **`docs/ARCHITECTURE.md`** — the three components (ETL, public app, fulfilment
  tool), the data flow, tech stack, hosting, and POC plan.
- **`docs/DATA_DICTIONARY.csv`** — one row per source column: its tier
  (`public`/`restricted`/`never`), whether it's in the POC, and its public
  transform. Every other component reads this.
- **`docs/DISCLOSURE_CONTROL.md`** — the anonymisation posture and who approved
  it. Light by design.
- **`docs/DECISION_LOG.md`** — append-only log of significant decisions and why.
- **`etl/`** — scripts that turn the `.sav` into parquet files.
- **`app/`** — the in-browser Shinylive viewer.
- **`client_tools/`** — the client's local drag-and-click GUI.
- **`data/`** — generated data. **Only `data/public/` is ever published.**

## Running the proof of concept

> Prerequisites: R (4.x), and the packages listed in `ARCHITECTURE.md`.

1. **Generate dummy data:**
   ```r
   source("etl/generate_dummy_data.R")
   ```
   Produces synthetic data under `data/` matching the real shape.
2. **Run the ETL** (once built): `source("etl/convert_sav_to_parquet.R")` →
   writes `data/public/public_slim.parquet` and `data/full/full_restricted.parquet`.
3. **Run the app locally** (once built), then export to static:
   ```r
   shinylive::export("app", "site")
   # then serve / open site/ in a browser to test a cold URL load
   ```
4. **Publish** the `site/` folder to the chosen static host.

## Client workflows (once built)

- **Update the data:** drag the new `.sav` into the fulfilment GUI → click
  **Update** → it regenerates the parquet files and prints the publish step.
- **Fulfil a full request:** drag the requester's `request.json` into the GUI →
  click **Generate** → send the resulting full extract to the vetted requester.

## Data-handling rules (important)

- **Never commit** the `.sav` or `full_restricted.parquet`. They are git-ignored.
- **Only** `data/public/public_slim.parquet` may be published — and only after
  confirming it contains no `restricted`/`never` columns.
- **Never** paste real data into a Claude chat; use the dummy generator.

## Suggested `.gitignore`

```
data/full/
*.sav
data/public/*.parquet   # optional: publish via the build step, not git
site/
.Rproj.user
.Rhistory
```
