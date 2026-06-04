# =============================================================================
# poc/etl/generate_dummy_data.R
# -----------------------------------------------------------------------------
# POC wrapper around the root dummy-data generator.
# Writes synthetic .sav + parquet to poc/data/full/ instead of data/full/.
#
# Run from repo root:
#   Rscript poc/etl/generate_dummy_data.R
# =============================================================================

N_ROWS           <- 60000
N_FILLER         <- 650
FILLER_FILL_RATE <- 0.03
SEED             <- 42
OUT_DIR          <- "poc/data/full"

set.seed(SEED)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

sexes      <- c("Female", "Male", "Other", NA)
regions    <- c("North", "South", "East", "West", "Central", "Coastal")
postcodes  <- sprintf("Z%02d %dZZ", 1:40, sample(1:9, 40, replace = TRUE))
substances <- c("Opioid", "Stimulant", "Depressant", "Cannabinoid",
                "Hallucinogen", "Mixed", "Unknown", "Alcohol-related")
causes     <- c("Accidental overdose", "Intentional", "Undetermined",
                "Medical complication", "Combined toxicity")

rand_date <- function(n, from = as.Date("2005-01-01"), to = as.Date("2024-12-31")) {
  as.Date(runif(n, as.numeric(from), as.numeric(to)), origin = "1970-01-01")
}

id  <- seq_len(N_ROWS)
dob <- rand_date(N_ROWS, from = as.Date("1930-01-01"), to = as.Date("2006-01-01"))
dod <- dob + as.integer(runif(N_ROWS, 365 * 18, 365 * 80))

core <- data.frame(
  case_id              = sprintf("CASE-%06d", id),
  deceased_name        = sprintf("Synthetic Person %05d", id),
  date_of_birth        = dob,
  date_of_death        = dod,
  age_at_death         = as.integer(floor(as.numeric(dod - dob) / 365.25)),
  sex                  = sample(sexes, N_ROWS, replace = TRUE, prob = c(.45,.45,.05,.05)),
  residence_postcode   = sample(postcodes, N_ROWS, replace = TRUE),
  residence_address    = sprintf("%d Example Street", sample(1:300, N_ROWS, TRUE)),
  location_of_death    = sample(regions, N_ROWS, replace = TRUE),
  primary_substance    = sample(substances, N_ROWS, replace = TRUE),
  secondary_substances = sample(c(substances, NA), N_ROWS, replace = TRUE),
  cause_of_death       = sample(causes, N_ROWS, replace = TRUE),
  coroner_notes        = sprintf("Synthetic note ref %05d", sample(id)),
  next_of_kin_name     = sprintf("Synthetic Relative %05d", sample(id)),
  referring_officer    = sprintf("Officer %03d", sample(1:200, N_ROWS, TRUE)),
  stringsAsFactors     = FALSE
)

for (i in seq_len(50 - ncol(core))) {
  if (i %% 2 == 0) {
    core[[sprintf("metric_%02d", i)]] <- round(rnorm(N_ROWS, 50, 15), 1)
  } else {
    core[[sprintf("flag_%02d", i)]] <- sample(c("Y", "N", NA), N_ROWS, TRUE)
  }
}

make_filler <- function(n, fill_rate) {
  x   <- rep(NA_real_, n)
  idx <- which(runif(n) < fill_rate)
  x[idx] <- round(rnorm(length(idx), 0, 1), 2)
  x
}
filler <- as.data.frame(
  setNames(
    lapply(seq_len(N_FILLER), function(i) make_filler(N_ROWS, FILLER_FILL_RATE)),
    sprintf("aux_field_%04d", seq_len(N_FILLER))
  )
)

dummy <- cbind(core, filler)
message(sprintf("Generated dummy data: %d rows x %d columns", nrow(dummy), ncol(dummy)))

if (requireNamespace("haven", quietly = TRUE)) {
  haven::write_sav(dummy, file.path(OUT_DIR, "dummy_source.sav"))
  message("Wrote ", file.path(OUT_DIR, "dummy_source.sav"))
} else {
  stop("Package 'haven' not installed. Run: install.packages('haven')")
}

if (requireNamespace("arrow", quietly = TRUE)) {
  arrow::write_parquet(dummy, file.path(OUT_DIR, "dummy_source.parquet"))
  message("Wrote ", file.path(OUT_DIR, "dummy_source.parquet"))
} else {
  stop("Package 'arrow' not installed. Run: install.packages('arrow')")
}

message("Done. NOTE: poc/data/full/ must NEVER be committed or published.")
