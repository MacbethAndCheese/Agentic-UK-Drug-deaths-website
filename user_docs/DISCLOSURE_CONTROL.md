# Disclosure Control & Data-Handling Posture

> Fill-in template. This file records **what the public/anonymised tier is
> allowed to show and how**, plus who approved it. It is deliberately light:
> per the client, controls here are precautionary risk-reduction, not a strict
> legal requirement, because the subjects are deceased and the underlying
> information already exists in the public record. Items in `[BRACKETS]` are
> for you/the client to complete.

## 1. Context & rationale

- Subjects: all deceased. Per the client, GDPR does not apply to the personal
  data of deceased persons (Recital 27), though member states may add rules.
- Source: a collation of information already in the public record.
- Posture: apply **light abstraction** to reduce residual risk and head off
  future issues — not full statistical disclosure control / k-anonymity.
- One item to confirm: records about a deceased person can still reference
  **living** people (e.g. a named surviving relative, a shared address). Decide
  how those fields are treated. `[CLIENT DECISION]`

## 2. Sign-off

- Posture approved by: `[NAME / ROLE]`
- Date: `[DATE]`
- Notes / scope of approval: `[NOTES]`

## 3. Default transforms (starting point — edit freely)

| Field type | Public-tier treatment | Status |
|---|---|---|
| Personal names | Removed entirely | `[CONFIRM]` |
| Dates (birth/death) | Truncate to year-month (drop day) | `[CONFIRM]` |
| Location | Postcode only (no street/house) | `[CONFIRM]` |
| Free-text notes | Excluded from public tier | `[CONFIRM]` |
| Direct identifiers (IDs, refs) | Removed or replaced with surrogate key | `[CONFIRM]` |
| Living third parties | `[DECISION]` | `[CONFIRM]` |

## 4. Per-column rules

The authoritative, column-by-column rules live in `DATA_DICTIONARY.csv`
(`tier` + `public_transform`). This file records the **principles**; the
dictionary records the **per-column application**. Keep them consistent.

## 5. Optional suppression (currently OFF)

Small-cell suppression / minimum cell counts are **not enabled**, per the
client's risk decision. If you later choose to enable it:

- Minimum cell count threshold: `[e.g. n < 5 suppressed]` — currently: OFF
- Fields it would apply to: `[LIST]`
- Postcode granularity dial: `[full postcode | partial | region]` —
  currently: `[full postcode]`, pending client confirmation.

## 6. Publish gate (operational)

- Only `data/public/public_slim.parquet` is ever published.
- The `.sav` and `full_restricted.parquet` are git-ignored and never uploaded.
- Before publishing, confirm the file contains **no** `tier = restricted` or
  `tier = never` columns.

## 7. Change history

| Date | Change | By |
|---|---|---|
| `[DATE]` | Initial posture defined | `[NAME]` |
