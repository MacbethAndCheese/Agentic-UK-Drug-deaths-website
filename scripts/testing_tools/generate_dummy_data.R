# =============================================================================
# generate_dummy_data.R
# -----------------------------------------------------------------------------
# Creates a SYNTHETIC dataset that matches the *shape* of the real
# drug-related-deaths data (~700 columns x ~60,000 rows, mostly empty, with
# ~50 meaningful columns) so the whole pipeline can be built and tested with
# ZERO real data.
#
# All values here are randomly generated. Names are explicitly synthetic
# ("Synthetic Person 00001"). No real people are represented.
#
# Output: writes a .sav (and a parquet copy) to data/full/ so the ETL can be
# developed against it.
#
# Run:  source("etl/generate_dummy_data.R")
# =============================================================================

# --- Config (reduce these for a faster POC) ----------------------------------
N_ROWS    <- 60000   # real data is ~60k rows
N_FILLER  <- 650     # sparse filler columns to mimic the ~700-wide, mostly-empty shape
FILLER_FILL_RATE <- 0.03   # ~3% non-NA in filler cols (i.e. mostly empty)
SEED      <- 42
OUT_DIR   <- "data/full"

set.seed(SEED)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# --- Small synthetic value pools (not sensitive; purely illustrative) --------
sexes        <- c("Female", "Male", "Other", NA)
regions      <- c("North", "South", "East", "West", "Central", "Coastal")
postcodes    <- sprintf("Z%02d %dZZ", 1:40, sample(1:9, 40, replace = TRUE))
substances   <- c("Opioid", "Stimulant", "Depressant", "Cannabinoid",
                  "Hallucinogen", "Mixed", "Unknown", "Alcohol-related")
causes       <- c("Accidental overdose", "Intentional", "Undetermined",
                  "Medical complication", "Combined toxicity")

rand_date <- function(n, from = as.Date("2005-01-01"), to = as.Date("2024-12-31")) {
  as.Date(runif(n, as.numeric(from), as.numeric(to)), origin = "1970-01-01")
}

# --- The ~50 meaningful columns ----------------------------------------------
id <- seq_len(N_ROWS)
dob <- rand_date(N_ROWS, from = as.Date("1930-01-01"), to = as.Date("2006-01-01"))
dod <- dob + as.integer(runif(N_ROWS, 365 * 18, 365 * 80))  # age 18-80ish

core <- data.frame(
  case_id              = sprintf("CASE-%06d", id),
  deceased_name        = sprintf("Synthetic Person %05d", id),   # clearly fake
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

# A handful more numeric/categorical core fields to reach a realistic ~50.
for (i in seq_len(50 - ncol(core))) {
  if (i %% 2 == 0) {
    core[[sprintf("metric_%02d", i)]] <- round(rnorm(N_ROWS, 50, 15), 1)
  } else {
    core[[sprintf("flag_%02d", i)]] <- sample(c("Y", "N", NA), N_ROWS, TRUE)
  }
}

# --- The ~650 sparse filler columns (mostly NA) ------------------------------
make_filler <- function(n, fill_rate) {
  x <- rep(NA_real_, n)
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

# --- Write outputs ------------------------------------------------------------
# .sav to mimic the real input the ETL will consume.
if (requireNamespace("haven", quietly = TRUE)) {
  haven::write_sav(dummy, file.path(OUT_DIR, "dummy_source.sav"))
  message("Wrote ", file.path(OUT_DIR, "dummy_source.sav"))
} else {
  message("Package 'haven' not installed; skipping .sav. Install with install.packages('haven').")
}

# parquet copy so the pipeline can also be exercised without haven.
if (requireNamespace("arrow", quietly = TRUE)) {
  arrow::write_parquet(dummy, file.path(OUT_DIR, "dummy_source.parquet"))
  message("Wrote ", file.path(OUT_DIR, "dummy_source.parquet"))
} else {
  message("Package 'arrow' not installed; skipping parquet. Install with install.packages('arrow').")
}

message("Done. NOTE: data/full/ must NEVER be committed or published.")
