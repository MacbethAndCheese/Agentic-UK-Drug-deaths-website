# =============================================================================
# poc/fulfilment/app.R
# -----------------------------------------------------------------------------
# Drug-related Deaths — Client Fulfilment Tool (internal use only)
#
# Run from repo root:
#   shiny::runApp("poc/fulfilment")
#
# Dependencies: shiny, arrow, dplyr, jsonlite
#   install.packages(c("shiny","arrow","dplyr","jsonlite"))
#
# Usage:
#   1. Upload the request.json the client sent you
#   2. Edit the parquet path if needed (default is pre-filled)
#   3. Click Download Full-Detail CSV
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(arrow)
  library(dplyr)
  library(jsonlite)
})

MISSING_STRINGS <- c("", "NA", "NULL", "null", "N/A", "n/a",
                     "Error", "error", "Inf", "-Inf")

normalise_cat <- function(x) {
  x[is.na(x) | trimws(x) %in% MISSING_STRINGS] <- "Missing"
  x
}

# Also normalise filter values from the JSON so "" matches "Missing" in data
norm_filter <- function(vals) normalise_cat(as.character(unlist(vals)))

FILTER_COLS <- c("sex", "location_of_death", "primary_substance",
                 "secondary_substances", "cause_of_death")

DEFAULT_PARQUET <- file.path("..", "data", "full", "full_restricted.parquet")

# =============================================================================
# UI
# =============================================================================
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; }
    .panel-box {
      background: #fff; border: 1px solid #dee2e6; border-radius: 6px;
      padding: 20px; margin-bottom: 16px;
    }
    .step-label {
      font-size: 0.75em; font-weight: 700; letter-spacing: 0.05em;
      text-transform: uppercase; color: #888; margin-bottom: 4px;
    }
    .summary-row { margin-bottom: 6px; }
    .summary-key { font-weight: 600; color: #444; min-width: 180px; display: inline-block; }
    .warn { color: #c0392b; font-weight: 600; }
    .ok   { color: #27ae60; font-weight: 600; }
  "))),

  titlePanel(
    div(
      h2("Drug-Related Deaths — Client Fulfilment Tool",
         style = "margin-bottom: 2px;"),
      p("Internal use only. Never share this app or its outputs publicly.",
        style = "color: #c0392b; font-size: 0.9em; font-weight: 600; margin-top: 0;")
    )
  ),

  fluidRow(
    # ---- Left: inputs --------------------------------------------------------
    column(4,
      div(class = "panel-box",
        div(class = "step-label", "Step 1 — Upload request file"),
        fileInput("req_file", NULL,
                  accept = ".json",
                  buttonLabel = "Browse…",
                  placeholder = "request.json"),

        hr(),
        div(class = "step-label", "Step 2 — Full-detail data path"),
        textInput("parquet_path", NULL,
                  value = DEFAULT_PARQUET,
                  placeholder = "path/to/full_restricted.parquet"),
        helpText("Path is relative to poc/fulfilment/. Edit if needed."),

        hr(),
        div(class = "step-label", "Step 3 — Download extract"),
        uiOutput("download_ui")
      )
    ),

    # ---- Right: summary ------------------------------------------------------
    column(8,
      div(class = "panel-box",
        div(class = "step-label", "Request summary"),
        uiOutput("req_summary")
      )
    )
  )
)

# =============================================================================
# Server
# =============================================================================
server <- function(input, output, session) {

  # --- Parse uploaded request.json -------------------------------------------
  req_data <- reactive({
    req(input$req_file)
    tryCatch(
      jsonlite::fromJSON(input$req_file$datapath, simplifyVector = FALSE),
      error = function(e) NULL
    )
  })

  # --- Show request summary --------------------------------------------------
  output$req_summary <- renderUI({
    rd <- req_data()
    if (is.null(rd)) {
      return(p("Upload a request.json to see the summary.", style = "color: #888;"))
    }

    filters  <- rd$filters
    cols     <- unlist(rd$columns_selected)
    n_public <- rd$n_records_public_subset
    schema   <- rd$schema_version
    gen_at   <- rd$generated_at

    tagList(
      div(class = "summary-row",
        span(class = "summary-key", "Schema version:"), schema),
      div(class = "summary-row",
        span(class = "summary-key", "Generated at:"), gen_at),
      div(class = "summary-row",
        span(class = "summary-key", "Public subset size:"),
        format(n_public, big.mark = ",")),
      hr(),
      div(class = "summary-row",
        span(class = "summary-key", "Year range:"),
        paste(unlist(filters$year_range), collapse = "–")),
      div(class = "summary-row",
        span(class = "summary-key", "Age range:"),
        paste(unlist(filters$age_range), collapse = "–")),
      div(class = "summary-row",
        span(class = "summary-key", "Sex:"),
        paste(unlist(filters$sex), collapse = ", ")),
      div(class = "summary-row",
        span(class = "summary-key", "Location of death:"),
        paste(unlist(filters$location_of_death), collapse = ", ")),
      div(class = "summary-row",
        span(class = "summary-key", "Primary substance:"),
        paste(unlist(filters$primary_substance), collapse = ", ")),
      div(class = "summary-row",
        span(class = "summary-key", "Cause of death:"),
        paste(unlist(filters$cause_of_death), collapse = ", ")),
      hr(),
      div(class = "summary-row",
        span(class = "summary-key", "Columns requested:"),
        length(cols)),
      div(class = "summary-row",
        tags$details(
          tags$summary("Show column list"),
          tags$code(paste(cols, collapse = ", "))
        )
      )
    )
  })

  # --- Show download button as soon as JSON + parquet path are ready ----------
  output$download_ui <- renderUI({
    rd <- req_data()
    if (is.null(rd)) {
      return(p("Upload a request.json first.", style = "color: #888;"))
    }
    parquet_path <- input$parquet_path
    if (!file.exists(parquet_path)) {
      return(p(class = "warn",
               paste("Parquet file not found:", parquet_path)))
    }
    downloadButton("dl_extract", "Download Full-Detail CSV",
                   class = "btn-success", width = "100%")
  })

  # --- Download handler — does all the work when clicked ---------------------
  output$dl_extract <- downloadHandler(
    filename = function() {
      paste0("full_extract_", format(Sys.time(), "%Y-%m-%d_%H-%M"), ".csv")
    },
    content = function(file) {
      rd           <- req_data()
      parquet_path <- isolate(input$parquet_path)
      filters      <- rd$filters

      df <- arrow::read_parquet(parquet_path) |>
        as.data.frame() |>
        mutate(
          death_year   = as.integer(substr(as.character(date_of_death), 1, 4)),
          age_at_death = suppressWarnings(as.numeric(age_at_death)),
          across(any_of(FILTER_COLS), normalise_cat)
        ) |>
        filter(
          death_year    >= as.integer(filters$year_range[[1]]),
          death_year    <= as.integer(filters$year_range[[2]]),
          age_at_death  >= as.numeric(filters$age_range[[1]]),
          age_at_death  <= as.numeric(filters$age_range[[2]]),
          sex               %in% norm_filter(filters$sex),
          location_of_death %in% norm_filter(filters$location_of_death),
          primary_substance %in% norm_filter(filters$primary_substance),
          cause_of_death    %in% norm_filter(filters$cause_of_death)
        ) |>
        select(-death_year)

      req_cols       <- unlist(rd$columns_selected)
      available_cols <- intersect(req_cols, names(df))
      write.csv(df[, available_cols, drop = FALSE], file, row.names = FALSE)
    }
  )
}

# =============================================================================
shinyApp(ui, server)
