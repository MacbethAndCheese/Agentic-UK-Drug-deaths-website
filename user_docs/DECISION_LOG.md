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


---

<!-- Add new entries below this line -->
