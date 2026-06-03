# Project Brief

> Single source of truth for this project. Keep it short and current. If a
> decision changes, update this file and add a line to `DECISION_LOG.md`.
> Items in `[SQUARE BRACKETS]` are placeholders to fill in.

## One-line purpose

A self-service tool that lets users browse a curated, anonymised view of a
drug-related-deaths dataset and download the slice they need — removing the
manual data-export work the client currently does by hand.

## The problem

The client maintains a large dataset of drug-related deaths and is repeatedly
asked for custom extracts. Today she fulfils these by hand, exporting portions
of the file per request (currently ~1 request/week). This is slow and
repetitive. She wants requesters to self-serve a safe version, while she
retains control over who receives the full-detail data.

## Goal

- Requesters can view and download an **anonymised** subset themselves, with no
  manual work from the client.
- For full-detail data, the client keeps a simple, **offline** workflow she
  controls: she vets the requester and produces the high-fidelity extract on her
  own machine.
- After delivery, the client's only recurring tasks are: drop in a new data
  file and click to regenerate, optionally vet users and send them full
  extracts, and pay any small hosting fees.

## The data

- Source format: SPSS `.sav`, ~2.5 GB.
- Shape: **~700 columns × ~60,000 rows**, mostly empty/null/error — only **~50 columns**
  matter to the vast majority of users.
- Compresses to a **~13 MB parquet**.
- Update cadence: **2–3 times per year**.
- Subject matter: collation of drug-related deaths. Per the client, all subjects
  are deceased and the underlying information already exists in the public
  record. See `DISCLOSURE_CONTROL.md` for the data-handling posture.

## Users and scale

- Two audiences:
  - **Public/anonymised tier** — anyone with the link. Views curated columns,
    downloads anonymised subsets.
  - **Full/restricted tier** — vetted requesters who receive high-fidelity
    extracts directly from the client.
- Volume is very small: client estimates **max ~5 users/day** at peak adoption,
  realistically closer to **1 request/week** today. No scaling concerns.

## Chosen architecture (summary)

Three independent components — see `ARCHITECTURE.md` for detail:

1. **ETL (local R script).** Converts the `.sav` to two parquet files: a slim
   anonymised public file (~50 columns, transformed) and a full restricted file.
   Runs on the client's machine only.
2. **Public viewer (Shinylive).** A Shiny app compiled to run entirely in the
   browser, hosted as free static files. Loads only the slim anonymised parquet.
   Users filter, visualise, preview, and download an anonymised subset — or download a
   small **request file** describing their filters to send to the client. This viewer should visualise the data in a form of graphs, geographic distributions, values over time, etc... [exact details to resolve when working on this portion]. Importantly requires user input to visualise and view data to select the data worth downloading.
3. **Client fulfilment tool (local Shiny GUI).** A drag-and-click desktop app:
   the client drops in the request file + full data [maybe just into a folder or perhaps something else], clicks one button, and gets
   the full-detail extract to send to a vetted requester. The same GUI also
   handles the data-update step.

The full data and the `.sav` **never leave the client's machine** and are never
hosted online. This is the security spine of the design.

## Constraints

- **Free during development.** Build and prove the concept at $0.
- **Minimal client maintenance.** Target experience: drag files into place,
  click one button. No command-line steps for routine tasks.
- **Small ongoing budget** for hosting/fees only -- max 200 GBP a year, ideally cheaper.
- **R-first.** Use other languages only if strictly necessary.

## Out of scope (deliberately)

- In-app authentication or online storage of full-detail data.
- Strict statistical disclosure control / k-anonymity. Light abstraction
  (see `DISCLOSURE_CONTROL.md`) is sufficient per the client's risk decision.
- Real-time / automated data ingestion. Updates are manual, 2–3×/year.

## Proof-of-concept scope (short term)

- Generate **synthetic dummy data** matching the real shape (~700 cols ×
  ~60k rows, ~50 meaningful) so no real data is needed to build or test.
- Working ETL producing the slim anonymised parquet from dummy data.
- A minimal Shinylive app that loads the slim parquet, filters, previews, and
  downloads an anonymised CSV + a request file.
- A minimal local fulfilment GUI stub.

## Success criteria (POC)

- A stranger can open the app URL and download an anonymised subset of dummy
  data without any help.
- The client can run the update step by dragging a file and clicking once.
- No real or full-detail data exists anywhere in the public app.

## Open questions / TODO

- [ ] Obtain the 700-column list and complete `DATA_DICTIONARY.csv`.
- [ ] Confirm in-browser parquet reader works in webR (arrow vs nanoparquet vs
      DuckDB-WASM).
- [ ] Choose the static host (GitHub Pages / Netlify / Cloudflare Pages).
- [ ] Confirm postcode granularity is acceptable to the client.
- [ ] [ANY CLIENT-SPECIFIC ITEMS]

## Glossary

- **Tier 1 / public / anonymised** — the safe data served by the app.
- **Tier 2 / full / restricted** — high-fidelity data the client sends manually.
- **Request file** — a small JSON file describing a user's chosen filters and
  columns, used by the client to reproduce that selection against full data.
- **Shinylive** — Shiny compiled to run in the browser via WebAssembly, no
  server required.
