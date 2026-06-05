# =============================================================================
# poc/app/app.R
# -----------------------------------------------------------------------------
# Drug-related Deaths — Public Data Explorer (POC Shiny app)
#
# Run from repo root:
#   shiny::runApp("poc/app")
#
# Dependencies: shiny, dplyr, ggplot2, DT, jsonlite
#   install.packages(c("shiny","dplyr","ggplot2","DT","jsonlite"))
#
# Shinylive note: arrow has not yet been validated in webR. If export to
# Shinylive is needed, swap arrow::read_parquet() for nanoparquet or ship the
# data as a compressed RDS/CSV instead.
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(dplyr)
  library(ggplot2)
  library(DT)
  library(jsonlite)
})

DATA_PATH <- "public_slim.csv"

# Sentinel strings that all mean "no usable value".
# NOTE (Decision 012): these are collapsed to "Missing" for display only.
# The source distinctions (blank vs NULL vs "NA" string etc.) are preserved
# in the .sav and full_restricted.parquet — never alter those upstream files.
MISSING_STRINGS <- c("", "NA", "NULL", "null", "N/A", "n/a",
                     "Error", "error", "Inf", "-Inf")

normalise_cat <- function(x) {
  x[is.na(x) | trimws(x) %in% MISSING_STRINGS] <- "Missing"
  x
}

FILTER_COLS <- c("sex", "location_of_death", "primary_substance",
                 "secondary_substances", "cause_of_death")

# Load once at startup and derive year from the "YYYY-MM" date_of_death string
df_raw <- read.csv(DATA_PATH, stringsAsFactors = FALSE) |>
  mutate(
    death_year    = as.integer(substr(date_of_death, 1, 4)),
    age_at_death  = suppressWarnings(as.numeric(age_at_death)),
    across(any_of(FILTER_COLS), normalise_cat)
  )

year_range  <- range(df_raw$death_year,    na.rm = TRUE)
age_range   <- range(df_raw$age_at_death,  na.rm = TRUE)
locations   <- sort(unique(df_raw$location_of_death))
substances  <- sort(unique(df_raw$primary_substance))
sexes       <- sort(unique(df_raw$sex))
causes      <- sort(unique(df_raw$cause_of_death))

core_cols      <- c("date_of_death", "age_at_death", "sex",
                    "location_of_death", "primary_substance",
                    "secondary_substances", "cause_of_death",
                    "residence_postcode")
all_public_cols <- setdiff(names(df_raw), "death_year")

# =============================================================================
# UI
# =============================================================================
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; }
    .stat-box {
      background: #fff; border: 1px solid #dee2e6; border-radius: 6px;
      padding: 14px 10px; margin-bottom: 12px; text-align: center;
    }
    .stat-box .big   { font-size: 2em; font-weight: bold; color: #2c7bb6; line-height: 1.1; }
    .stat-box .label { font-size: 0.85em; color: #666; margin-top: 2px; }
    .filter-head { font-weight: 600; margin-bottom: 8px; color: #444; }
    hr { margin: 10px 0; }
  "))),

  titlePanel(
    div(
      h2("Drug-Related Deaths — Public Data Explorer", style = "margin-bottom: 2px;"),
      p("Anonymised data. Use the filters to explore, then download your selection.",
        style = "color: #666; font-size: 0.9em; margin-top: 0;")
    )
  ),

  sidebarLayout(
    # ------------------------------------------------------------------
    sidebarPanel(
      width = 3,

      div(class = "filter-head", "Filters"),

      sliderInput("year_range", "Year of death",
                  min = year_range[1], max = year_range[2],
                  value = year_range, sep = ""),

      sliderInput("age_range", "Age at death",
                  min = age_range[1], max = age_range[2],
                  value = age_range),

      checkboxGroupInput("sex_sel", "Sex",
                         choices = sexes, selected = sexes),

      checkboxGroupInput("location_sel", "Location of death",
                         choices = locations, selected = locations),

      checkboxGroupInput("substance_sel", "Primary substance",
                         choices = substances, selected = substances),

      checkboxGroupInput("cause_sel", "Cause of death",
                         choices = causes, selected = causes),

      hr(),

      actionButton("reset_filters", "Reset all filters",
                   class = "btn-sm btn-outline-secondary", width = "100%"),
      br(), br(),
      actionButton("deselect_filters", "Deselect all filters",
                   class = "btn-sm btn-outline-secondary", width = "100%")
    ),

    # ------------------------------------------------------------------
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs",

        # ---- Overview ------------------------------------------------
        tabPanel(
          "Overview",
          br(),
          fluidRow(
            column(3, div(class = "stat-box",
              div(class = "big",   textOutput("stat_n")),
              div(class = "label", "Records in selection"))),
            column(3, div(class = "stat-box",
              div(class = "big",   textOutput("stat_years")),
              div(class = "label", "Year range"))),
            column(3, div(class = "stat-box",
              div(class = "big",   textOutput("stat_locations")),
              div(class = "label", "Locations"))),
            column(3, div(class = "stat-box",
              div(class = "big",   textOutput("stat_substances")),
              div(class = "label", "Substances")))
          ),
          fluidRow(
            column(6, plotOutput("plot_time",     height = "270px")),
            column(6, plotOutput("plot_substance", height = "270px"))
          ),
          fluidRow(
            column(6, plotOutput("plot_location",  height = "270px")),
            column(6, plotOutput("plot_age",       height = "270px"))
          )
        ),

        # ---- Data Table ----------------------------------------------
        tabPanel(
          "Data",
          br(),
          div(style = "margin-bottom: 6px;",
            actionButton("select_all_cols",   "Select all",   class = "btn-sm btn-outline-secondary"),
            actionButton("deselect_all_cols", "Deselect all", class = "btn-sm btn-outline-secondary",
                         style = "margin-left: 6px;")
          ),
          checkboxGroupInput("col_select", "Columns to show:",
                             choices  = all_public_cols,
                             selected = all_public_cols,
                             inline   = TRUE),
          br(),
          div(style = "overflow-x: auto; width: 100%;",
            DTOutput("data_table")
          )
        ),

        # ---- Download ------------------------------------------------
        tabPanel(
          "Download",
          br(),
          fluidRow(
            column(6,
              div(class = "stat-box",
                h4("Anonymised CSV"),
                p("Download the filtered records as a CSV (public columns only)."),
                br(),
                downloadButton("dl_csv", "Download CSV", class = "btn-primary")
              )
            ),
            column(6,
              div(class = "stat-box",
                h4("Request file"),
                p("Download a JSON file that captures your exact filter selection.
                   Send this to the data owner to request the full-detail extract."),
                br(),
                downloadButton("dl_json", "Download request.json",
                               class = "btn-outline-primary")
              )
            )
          )
        )
      )
    )
  )
)

# =============================================================================
# Server
# =============================================================================
server <- function(input, output, session) {

  # --- Filtered data ---------------------------------------------------------
  df_filtered <- reactive({
    df_raw |>
      filter(
        death_year    >= input$year_range[1],
        death_year    <= input$year_range[2],
        age_at_death  >= input$age_range[1],
        age_at_death  <= input$age_range[2],
        sex               %in% input$sex_sel,
        location_of_death %in% input$location_sel,
        primary_substance %in% input$substance_sel,
        cause_of_death    %in% input$cause_sel
      )
  })

  # --- Column select / deselect all ------------------------------------------
  observeEvent(input$select_all_cols, {
    updateCheckboxGroupInput(session, "col_select", selected = all_public_cols)
  })
  observeEvent(input$deselect_all_cols, {
    updateCheckboxGroupInput(session, "col_select", selected = character(0))
  })

  # --- Reset all filters -----------------------------------------------------
  observeEvent(input$reset_filters, {
    updateSliderInput(session, "year_range",   value = year_range)
    updateSliderInput(session, "age_range",    value = age_range)
    updateCheckboxGroupInput(session, "sex_sel",       selected = sexes)
    updateCheckboxGroupInput(session, "location_sel",  selected = locations)
    updateCheckboxGroupInput(session, "substance_sel", selected = substances)
    updateCheckboxGroupInput(session, "cause_sel",     selected = causes)
  })

  # --- Deselect all filters --------------------------------------------------
  observeEvent(input$deselect_filters, {
    updateCheckboxGroupInput(session, "sex_sel",       selected = character(0))
    updateCheckboxGroupInput(session, "location_sel",  selected = character(0))
    updateCheckboxGroupInput(session, "substance_sel", selected = character(0))
    updateCheckboxGroupInput(session, "cause_sel",     selected = character(0))
  })

  # --- Summary stats ---------------------------------------------------------
  output$stat_n <- renderText({
    format(nrow(df_filtered()), big.mark = ",")
  })

  output$stat_years <- renderText({
    yrs <- df_filtered()$death_year
    if (length(yrs) == 0 || all(is.na(yrs))) return("—")
    paste0(min(yrs, na.rm = TRUE), "–", max(yrs, na.rm = TRUE))
  })

  output$stat_locations <- renderText({
    length(unique(na.omit(df_filtered()$location_of_death)))
  })

  output$stat_substances <- renderText({
    length(unique(na.omit(df_filtered()$primary_substance)))
  })

  # --- Shared plot theme -----------------------------------------------------
  base_theme <- theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor  = element_blank(),
      plot.title        = element_text(size = 12, face = "bold"),
      axis.title        = element_text(size = 10),
      plot.margin       = margin(8, 12, 8, 8)
    )

  empty_plot <- function(msg = "No data in current selection") {
    ggplot() +
      annotate("text", x = 0.5, y = 0.5, label = msg, size = 4.5, colour = "grey55") +
      theme_void()
  }

  # --- Deaths over time ------------------------------------------------------
  output$plot_time <- renderPlot({
    df <- df_filtered() |>
      count(death_year) |>
      filter(!is.na(death_year))
    if (nrow(df) == 0) return(empty_plot())

    ggplot(df, aes(death_year, n)) +
      geom_line(colour = "#2c7bb6", linewidth = 0.9) +
      geom_point(colour = "#2c7bb6", size = 2) +
      scale_x_continuous(breaks = function(x) pretty(x, 6)) +
      scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
      labs(title = "Deaths per year", x = NULL, y = "Count") +
      base_theme
  })

  # --- Primary substance -----------------------------------------------------
  output$plot_substance <- renderPlot({
    df <- df_filtered() |>
      count(primary_substance, sort = TRUE) |>
      filter(!is.na(primary_substance)) |>
      mutate(primary_substance = reorder(primary_substance, n))
    if (nrow(df) == 0) return(empty_plot())

    ggplot(df, aes(n, primary_substance)) +
      geom_col(fill = "#2c7bb6", alpha = 0.8) +
      scale_x_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
      labs(title = "Primary substance", x = "Count", y = NULL) +
      base_theme
  })

  # --- Location of death -----------------------------------------------------
  output$plot_location <- renderPlot({
    df <- df_filtered() |>
      count(location_of_death, sort = TRUE) |>
      filter(!is.na(location_of_death)) |>
      mutate(location_of_death = reorder(location_of_death, n))
    if (nrow(df) == 0) return(empty_plot())

    ggplot(df, aes(n, location_of_death)) +
      geom_col(fill = "#5ab4ac", alpha = 0.8) +
      scale_x_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
      labs(title = "Location of death", x = "Count", y = NULL) +
      base_theme
  })

  # --- Age distribution ------------------------------------------------------
  output$plot_age <- renderPlot({
    df <- df_filtered() |> filter(!is.na(age_at_death))
    if (nrow(df) == 0) return(empty_plot())

    ggplot(df, aes(age_at_death)) +
      geom_histogram(binwidth = 5, fill = "#d7191c", alpha = 0.75,
                     colour = "white") +
      scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
      labs(title = "Age at death distribution", x = "Age (years)", y = "Count") +
      base_theme
  })

  # --- Data table ------------------------------------------------------------
  output$data_table <- renderDT({
    cols <- intersect(input$col_select, names(df_filtered()))
    df_filtered() |>
      select(all_of(cols)) |>
      datatable(
        rownames  = FALSE,
        filter    = "top",
        options   = list(
          pageLength = 25,
          scrollX    = TRUE,
          dom        = "frtip"
        )
      )
  }, server = TRUE)

  # --- Download: CSV ---------------------------------------------------------
  output$dl_csv <- downloadHandler(
    filename = function() {
      paste0("drug_deaths_", format(Sys.time(), "%Y-%m-%d_%H-%M"), ".csv")
    },
    content = function(file) {
      out_cols <- intersect(input$col_select, names(df_filtered()))
      if (length(out_cols) == 0) out_cols <- intersect(all_public_cols, names(df_filtered()))
      write.csv(df_filtered()[, out_cols, drop = FALSE], file, row.names = FALSE)
    }
  )

  # --- Download: request JSON ------------------------------------------------
  output$dl_json <- downloadHandler(
    filename = function() paste0("request_", format(Sys.time(), "%Y-%m-%d_%H-%M"), ".json"),
    content = function(file) {
      selected_cols <- input$col_select
      if (length(selected_cols) == 0) selected_cols <- all_public_cols
      payload <- list(
        schema_version            = "1.1",
        generated_at              = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        n_records_public_subset   = nrow(df_filtered()),
        filters = list(
          year_range        = as.list(input$year_range),
          age_range         = as.list(input$age_range),
          sex               = as.list(input$sex_sel),
          location_of_death = as.list(input$location_sel),
          primary_substance = as.list(input$substance_sel),
          cause_of_death    = as.list(input$cause_sel)
        ),
        columns_selected = as.list(selected_cols),
        note = paste(
          "This file captures the filter selection and column selection applied to the anonymised public dataset.",
          "Send to the data owner to request the corresponding full-detail extract."
        )
      )
      writeLines(jsonlite::toJSON(payload, pretty = TRUE, auto_unbox = TRUE), file)
    }
  )
}

# =============================================================================
shinyApp(ui, server)
