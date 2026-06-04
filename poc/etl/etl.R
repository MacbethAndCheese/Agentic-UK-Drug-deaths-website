# =============================================================================
# poc/etl/etl.R
# -----------------------------------------------------------------------------
# Reads dummy_source.sav (or .parquet fallback) + DATA_DICTIONARY.csv and
# produces:
#   poc/data/full/full_restricted.parquet   — all non-never columns, untransformed
#   poc/data/public/public_slim.parquet     — public + in_poc=yes columns, with
#                                             transforms applied
#
# Columns not listed in the dictionary default to tier=restricted, in_poc=no.
#
# Run from repo root:
#   Rscript poc/etl/etl.R
# =============================================================================

suppressPackageStartupMessages({
  library(haven)
  library(arrow)
  library(dplyr)
  library(readr)
})

SAV_PATH   <- file.path("poc", "data", "full", "dummy_source.sav")
PARQ_PATH  <- file.path("poc", "data", "full", "dummy_source.parquet")
DICT_PATH  <- file.path("user_docs", "underconstruction", "DATA_DICTIONARY.csv")
OUT_FULL   <- file.path("poc", "data", "full",   "full_restricted.parquet")
OUT_PUBLIC <- file.path("poc", "data", "public", "public_slim.parquet")

# --- Load source data --------------------------------------------------------
if (file.exists(SAV_PATH)) {
  message("Reading .sav: ", SAV_PATH)
  df <- haven::read_sav(SAV_PATH) |> as_tibble()
} else if (file.exists(PARQ_PATH)) {
  message("No .sav found; reading parquet fallback: ", PARQ_PATH)
  df <- arrow::read_parquet(PARQ_PATH) |> as_tibble()
} else {
  stop("No source data found at ", SAV_PATH, ". Run generate_dummy_data.R first.")
}
message(sprintf("Loaded: %d rows x %d columns", nrow(df), ncol(df)))

# --- Load dictionary ---------------------------------------------------------
dict <- readr::read_csv(DICT_PATH, show_col_types = FALSE) |>
  filter(!is.na(column_name), !grepl("^FILL_IN", column_name)) |>
  select(column_name, tier, in_poc, public_transform) |>
  mutate(across(everything(), as.character))

# Join against all columns; anything not in dict defaults to restricted/no
dict_full <- tibble(column_name = names(df)) |>
  left_join(dict, by = "column_name") |>
  mutate(
    tier             = coalesce(tier, "restricted"),
    in_poc           = coalesce(in_poc, "no"),
    public_transform = coalesce(public_transform, "full-tier-only")
  )

message(sprintf(
  "Column breakdown — public (in_poc=yes): %d | restricted: %d | never: %d | defaulted: %d",
  sum(dict_full$tier == "public" & dict_full$in_poc == "yes"),
  sum(dict_full$tier == "restricted"),
  sum(dict_full$tier == "never"),
  sum(!dict_full$column_name %in% dict$column_name)
))

# --- full_restricted.parquet — all columns except tier=never -----------------
full_cols <- dict_full |> filter(tier != "never") |> pull(column_name)
df_full   <- df |> select(all_of(full_cols))

dir.create(dirname(OUT_FULL), recursive = TRUE, showWarnings = FALSE)
arrow::write_parquet(df_full, OUT_FULL, compression = "snappy")
message(sprintf("Wrote full_restricted.parquet: %d rows x %d cols", nrow(df_full), ncol(df_full)))

# --- public_slim.parquet — public + in_poc=yes, transforms applied -----------
public_dict <- dict_full |> filter(tier == "public", in_poc == "yes")
df_public   <- df |> select(all_of(public_dict$column_name))

for (i in seq_len(nrow(public_dict))) {
  col   <- public_dict$column_name[i]
  trans <- public_dict$public_transform[i]
  if (!col %in% names(df_public)) next

  if (trans == "year-month") {
    df_public[[col]] <- format(as.Date(df_public[[col]]), "%Y-%m")
  }
  # "as-is": leave unchanged
}

dir.create(dirname(OUT_PUBLIC), recursive = TRUE, showWarnings = FALSE)
arrow::write_parquet(df_public, OUT_PUBLIC, compression = "snappy")
message(sprintf("Wrote public_slim.parquet:     %d rows x %d cols", nrow(df_public), ncol(df_public)))

message("\nPublic columns: ", paste(names(df_public), collapse = ", "))
message("\nETL complete. Check above — no restricted/never column names should appear in public columns.")
