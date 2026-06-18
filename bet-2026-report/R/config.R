read_simple_yaml_scalars <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  if (requireNamespace("yaml", quietly = TRUE)) {
    return(yaml::read_yaml(path) %||% list())
  }
  lines <- readLines(path, warn = FALSE)
  hits <- regexec("^([A-Za-z_][A-Za-z0-9_-]*)\\s*:\\s*[\"']?([^\"'#]+)[\"']?\\s*(#.*)?$", lines)
  parsed <- regmatches(lines, hits)
  out <- list()
  for (item in parsed[lengths(parsed) >= 3]) {
    out[[item[[2]]]] <- trimws(item[[3]])
  }
  out
}

metadata_value <- function(name, default = "") {
  for (source in list(report_config, knitr_metadata, quarto_metadata)) {
    value <- source[[name]]
    if (!is.null(value) && length(value) > 0 && !is.na(value[[1]]) && nzchar(as.character(value[[1]]))) {
      return(as.character(value[[1]]))
    }
  }
  default
}

load_report_context <- function(config_file = "report-config.yml") {
  assign("report_config", read_simple_yaml_scalars(config_file), envir = .GlobalEnv)
  assign("knitr_metadata", tryCatch(knitr::metadata, error = function(e) list()), envir = .GlobalEnv)
  assign("quarto_metadata", tryCatch(quarto::quarto_metadata(), error = function(e) list()), envir = .GlobalEnv)

  species_code <- metadata_value("species_code", metadata_value("species", "TUNA"))
  species_label <- metadata_value("species_label", "selected tuna stock")
  species_scientific <- metadata_value("species_scientific", "Thunnus spp.")
  assessment_year <- metadata_value("assessment_year", format(Sys.Date(), "%Y"))

  values <- list(
    species_code = species_code,
    species_label = species_label,
    species_scientific = species_scientific,
    assessment_year = assessment_year,
    assessment_area = metadata_value("assessment_area", "the WCPO"),
    previous_assessment_year = metadata_value("previous_assessment_year", "the previous assessment"),
    model_region_count = metadata_value("model_region_count", "TODO"),
    latest_data_year = metadata_value("latest_data_year", "TODO"),
    recent_period = metadata_value("recent_period", "TODO"),
    no_fishing_reference_period = metadata_value("no_fishing_reference_period", "TODO"),
    report_status = metadata_value("report_status", "Draft"),
    draft_watermark = tolower(metadata_value("draft_watermark", "true")) %in% c("true", "yes", "1", "on"),
    watermark_text = metadata_value("watermark_text", "DRAFT - DO NOT CITE OR REDISTRIBUTE"),
    figure_catalog = metadata_value("figure_catalog", "catalog/figures.csv"),
    table_catalog = metadata_value("table_catalog", "catalog/tables.csv"),
    figure_roots = metadata_value("figure_roots", "Figures/generated;Figures/static;Figures"),
    extra_figure_roots = metadata_value("extra_figure_roots", "Figures/generated"),
    table_roots = metadata_value("table_roots", "tables/generated;tables;Tables"),
    extra_table_roots = metadata_value("extra_table_roots", ""),
    assessment_name = paste(species_label, assessment_year, "assessment")
  )

  for (name in names(values)) {
    assign(name, values[[name]], envir = .GlobalEnv)
  }

  invisible(values)
}
