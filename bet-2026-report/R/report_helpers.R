`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

read_report_csv <- function(path) {
  if (!file.exists(path)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

bind_report_rows <- function(rows) {
  rows <- rows[vapply(rows, function(x) is.data.frame(x) && nrow(x), logical(1))]
  if (!length(rows)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    missing <- setdiff(cols, names(x))
    for (name in missing) x[[name]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, rows)
}

split_catalog_paths <- function(x) {
  x <- as.character(x %||% "")
  x <- unlist(strsplit(x, ";", fixed = TRUE), use.names = FALSE)
  x <- trimws(x)
  x[nzchar(x)]
}

slug_id <- function(x) {
  x <- tolower(as.character(x %||% "item"))
  x <- gsub("[^a-z0-9]+", "-", x)
  x <- gsub("(^-+|-+$)", "", x)
  if (!nzchar(x)) "item" else x
}

render_report_text <- function(x) {
  x <- as.character(x %||% "")
  values <- list(
    species = get0("species_code", ifnotfound = "TUNA"),
    species_code = get0("species_code", ifnotfound = "TUNA"),
    species_label = get0("species_label", ifnotfound = "selected tuna stock"),
    species_scientific = get0("species_scientific", ifnotfound = "Thunnus spp."),
    assessment_year = get0("assessment_year", ifnotfound = format(Sys.Date(), "%Y")),
    assessment_area = get0("assessment_area", ifnotfound = "the WCPO"),
    previous_assessment_year = get0("previous_assessment_year", ifnotfound = "the previous assessment"),
    model_region_count = get0("model_region_count", ifnotfound = "TODO"),
    latest_data_year = get0("latest_data_year", ifnotfound = "TODO"),
    recent_period = get0("recent_period", ifnotfound = "TODO"),
    no_fishing_reference_period = get0("no_fishing_reference_period", ifnotfound = "TODO")
  )
  for (name in names(values)) {
    x <- gsub(paste0("{", name, "}"), as.character(values[[name]]), x, fixed = TRUE)
  }
  x
}

latex_escape <- function(x) {
  x <- as.character(x %||% "")
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([#$%&_{}])", "\\\\\\1", x)
  x
}

html_escape <- function(x) {
  x <- as.character(x %||% "")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x <- gsub("'", "&#39;", x, fixed = TRUE)
  x
}

markdown_path <- function(path) {
  gsub(" ", "%20", gsub("\\\\", "/", path))
}

report_paths <- function(name, default = character()) {
  value <- get0(name, ifnotfound = paste(default, collapse = ";"))
  out <- split_catalog_paths(value)
  if (!length(out)) default else out
}

find_report_assets <- function(candidates, roots = c("Figures/generated", "Figures/static", "Figures")) {
  candidates <- split_catalog_paths(candidates)
  if (!length(candidates)) {
    return(character())
  }

  found <- candidates[file.exists(candidates)]

  roots <- roots[dir.exists(roots)]
  for (root in roots) {
    direct <- file.path(root, candidates)
    found <- c(found, direct[file.exists(direct)])
  }

  all_files <- unique(unlist(lapply(roots, function(root) {
    list.files(root, recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE))
  if (length(all_files)) {
    all_base <- tolower(basename(all_files))
    candidate_base <- tolower(basename(candidates))
    hit <- match(candidate_base, all_base, nomatch = 0L)
    if (any(hit > 0L)) {
      found <- c(found, all_files[hit[hit > 0L]])
    }

    candidate_stems <- tools::file_path_sans_ext(candidate_base)
    all_stems <- tools::file_path_sans_ext(all_base)
    hit <- match(candidate_stems, all_stems, nomatch = 0L)
    if (any(hit > 0L)) {
      found <- c(found, all_files[hit[hit > 0L]])
    }
  }

  unique(found)
}

find_report_asset <- function(candidates, roots = c("Figures/generated", "Figures/static", "Figures")) {
  assets <- find_report_assets(candidates, roots = roots)
  if (length(assets)) assets[[1]] else ""
}

read_figure_metadata <- function(roots = c("Figures/generated", "Figures/static", "Figures")) {
  roots <- roots[dir.exists(roots)]
  files <- unique(unlist(lapply(roots, function(root) {
    list.files(root, pattern = "figure-index[.]csv$|mfclshiny-figure-index[.]csv$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE))
  if (!length(files)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  rows <- lapply(files, function(file) {
    x <- read_report_csv(file)
    if (!nrow(x)) {
      return(x)
    }
    x$metadata_file <- file
    x
  })
  out <- bind_report_rows(rows)
  if (is.null(out) || !nrow(out)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  out
}

figure_metadata_row <- function(file, metadata) {
  if (is.null(metadata) || !nrow(metadata)) {
    return(NULL)
  }
  file_base <- tolower(basename(file))
  candidates <- character()
  for (name in intersect(c("file", "relative_path"), names(metadata))) {
    candidates <- c(candidates, tolower(basename(metadata[[name]])))
  }
  hit <- match(file_base, candidates, nomatch = 0L)
  if (!hit) {
    return(NULL)
  }
  source_col <- rep(seq_len(nrow(metadata)), length(intersect(c("file", "relative_path"), names(metadata))))
  metadata[source_col[[hit]], , drop = FALSE]
}

figure_caption <- function(file, default, metadata = data.frame()) {
  row <- figure_metadata_row(file, metadata)
  if (!is.null(row) && "caption" %in% names(row)) {
    caption <- render_report_text(row$caption[[1]])
    if (nzchar(trimws(caption))) {
      return(caption)
    }
  }
  render_report_text(default)
}

read_table_metadata <- function(roots = c("tables/generated", "tables", "Tables")) {
  roots <- roots[dir.exists(roots)]
  files <- unique(unlist(lapply(roots, function(root) {
    list.files(
      root,
      pattern = "table-index[.]csv$|mfclshiny-table-index[.]csv$|generated-table-index[.]csv$",
      recursive = TRUE,
      full.names = TRUE,
      ignore.case = TRUE
    )
  }), use.names = FALSE))
  if (!length(files)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  rows <- lapply(files, function(file) {
    x <- read_report_csv(file)
    if (!nrow(x)) {
      return(x)
    }
    x$metadata_file <- file
    x
  })
  out <- bind_report_rows(rows)
  if (is.null(out) || !nrow(out)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  out
}

table_metadata_row <- function(file, metadata) {
  if (is.null(metadata) || !nrow(metadata)) {
    return(NULL)
  }
  file_base <- tolower(basename(file))
  candidates <- character()
  source_rows <- integer()
  for (name in intersect(c("file", "relative_path"), names(metadata))) {
    values <- tolower(basename(metadata[[name]]))
    candidates <- c(candidates, values)
    source_rows <- c(source_rows, seq_len(nrow(metadata)))
  }
  hit <- match(file_base, candidates, nomatch = 0L)
  if (!hit) {
    return(NULL)
  }
  metadata[source_rows[[hit]], , drop = FALSE]
}

table_caption <- function(file, default, metadata = data.frame()) {
  row <- table_metadata_row(file, metadata)
  if (!is.null(row) && "caption" %in% names(row)) {
    caption <- render_report_text(row$caption[[1]])
    if (nzchar(trimws(caption))) {
      return(caption)
    }
  }
  render_report_text(default)
}

prepare_report_table <- function(x,
                                 max_rows = 30,
                                 max_cols = 10,
                                 max_cell_chars = 80) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  original_rows <- nrow(x)
  original_cols <- ncol(x)
  omitted_rows <- 0L
  omitted_cols <- character()

  if (is.finite(max_cols) && original_cols > max_cols) {
    omitted_cols <- names(x)[seq.int(max_cols + 1L, original_cols)]
    x <- x[, seq_len(max_cols), drop = FALSE]
  }
  if (is.finite(max_rows) && original_rows > max_rows) {
    omitted_rows <- original_rows - max_rows
    x <- utils::head(x, max_rows)
  }

  for (name in names(x)) {
    if (is.character(x[[name]]) || is.factor(x[[name]])) {
      values <- as.character(x[[name]])
      long <- nchar(values, type = "width", allowNA = FALSE) > max_cell_chars
      values[long] <- paste0(substr(values[long], 1L, max_cell_chars - 1L), "...")
      x[[name]] <- values
    }
  }

  list(
    data = x,
    original_rows = original_rows,
    original_cols = original_cols,
    omitted_rows = omitted_rows,
    omitted_cols = omitted_cols
  )
}

emit_todo <- function(text, title = "TODO") {
  text <- trimws(render_report_text(text %||% "Add the assessment material here."))
  if (!nzchar(text)) {
    text <- "Add the assessment material here."
  }
  title <- trimws(as.character(title %||% "TODO"))
  if (!nzchar(title)) {
    title <- "TODO"
  }
  cat("::: {.callout-important appearance=\"simple\" icon=false}\n")
  cat("## ", title, "\n\n", sep = "")
  cat(text, "\n")
  cat(":::\n\n")
}

emit_config_todo <- function(field, guidance) {
  emit_todo(
    sprintf("Set `%s` in `report-config.yml`: %s", field, guidance),
    title = sprintf("CONFIG TODO: %s", field)
  )
}

configured_metadata_value <- function(name) {
  for (source_name in c("report_config", "knitr_metadata", "quarto_metadata")) {
    source <- get0(source_name, ifnotfound = list())
    value <- source[[name]]
    if (!is.null(value) && length(value) > 0 && !is.na(value[[1]]) && nzchar(as.character(value[[1]]))) {
      return(as.character(value[[1]]))
    }
  }
  ""
}

metadata_missing <- function(x, field = "") {
  x <- as.character(x %||% "")
  value <- trimws(x)
  if (!nzchar(value)) {
    return(TRUE)
  }
  if (grepl("TODO|TBD|FIXME|CHANGE[ -]?ME|REPLACE", value, ignore.case = TRUE)) {
    return(TRUE)
  }
  placeholders <- list(
    title = c("tuna assessment report template"),
    species_code = c("tuna", "species", "species_code"),
    species_label = c("selected tuna stock", "selected stock", "tuna stock"),
    species_scientific = c("thunnus spp.", "thunnus spp"),
    assessment_year = c("yyyy", "year"),
    assessment_area = c("the wcpo"),
    previous_assessment_year = c("the previous assessment"),
    model_region_count = c("number of model regions"),
    latest_data_year = c("latest data year"),
    recent_period = c("recent period"),
    no_fishing_reference_period = c("reference period")
  )
  choices <- placeholders[[field]]
  length(choices) > 0 && tolower(value) %in% choices
}

emit_config_warnings <- function() {
  checks <- list(
    title = "report title",
    species_code = "short species code used in file names and captions",
    species_label = "common species name used in report text and captions",
    species_scientific = "scientific name used in the introduction",
    assessment_year = "assessment year",
    assessment_area = "assessment area",
    previous_assessment_year = "previous assessment year for comparisons",
    model_region_count = "number of model regions",
    latest_data_year = "latest data year in the accepted input files",
    recent_period = "recent period used for stock-status summaries",
    no_fishing_reference_period = "reference period for SB[F=0] calculations"
  )
  values <- stats::setNames(lapply(names(checks), configured_metadata_value), names(checks))
  missing <- names(checks)[vapply(names(checks), function(field) {
    metadata_missing(values[[field]], field)
  }, logical(1))]
  if (!length(missing)) {
    return(invisible(FALSE))
  }
  for (field in missing) {
    emit_config_todo(field, checks[[field]])
  }
  invisible(TRUE)
}

emit_catalog_figures <- function(catalog,
                                 roots = c("Figures/generated", "Figures/static", "Figures")) {
  if (!nrow(catalog)) {
    emit_todo("Add figure catalog rows to catalog/figures.csv.")
    return(invisible(FALSE))
  }

  catalog <- complete_catalog(catalog, "figures")
  metadata <- read_figure_metadata(roots)

  last_section <- ""
  for (i in seq_len(nrow(catalog))) {
    section <- render_report_text(catalog$section[[i]])
    title <- render_report_text(catalog$title[[i]])
    key <- slug_id(catalog$key[[i]])
    caption <- render_report_text(catalog$caption[[i]])
    todo <- render_report_text(catalog$todo[[i]])
    files <- find_report_assets(catalog$file_candidates[[i]], roots = roots)

    if (!identical(section, last_section) && nzchar(section)) {
      cat("\n## ", section, "\n\n", sep = "")
      last_section <- section
    }

    cat("### ", title, "\n\n", sep = "")
    if (length(files)) {
      for (j in seq_along(files)) {
        figure_id <- if (length(files) == 1L) key else paste(key, j, sep = "-")
        figure_caption <- if (length(files) == 1L) {
          figure_caption(files[[j]], caption, metadata)
        } else {
          figure_caption(files[[j]], sprintf("%s (panel %d of %d).", caption, j, length(files)), metadata)
        }
        cat(sprintf("![%s](%s){#fig-%s fig-align=\"center\" width=100%%}\n\n",
                    figure_caption, markdown_path(files[[j]]), figure_id))
      }
    } else {
      emit_todo(todo)
    }
  }

  invisible(TRUE)
}

emit_extra_generated_figures <- function(catalog,
                                         roots = c("Figures/generated")) {
  roots <- roots[dir.exists(roots)]
  files <- unique(unlist(lapply(roots, function(root) {
    list.files(root, pattern = "[.](png|jpg|jpeg|pdf)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE))
  if (!length(files)) {
    return(invisible(FALSE))
  }

  catalog_candidates <- unique(unlist(strsplit(paste(catalog$file_candidates, collapse = ";"), ";", fixed = TRUE), use.names = FALSE))
  catalog_candidates <- trimws(tolower(basename(catalog_candidates)))
  catalog_stems <- tools::file_path_sans_ext(catalog_candidates)
  file_stems <- tools::file_path_sans_ext(tolower(basename(files)))
  extra <- files[!file_stems %in% catalog_stems]
  if (!length(extra)) {
    return(invisible(FALSE))
  }
  metadata <- read_figure_metadata(roots)

  cat("\n## Additional Generated Figures\n\n")
  for (file in extra) {
    label <- tools::file_path_sans_ext(basename(file))
    title <- gsub("[-_]+", " ", label)
    title <- paste0(toupper(substr(title, 1, 1)), substr(title, 2, nchar(title)))
    cat("### ", title, "\n\n", sep = "")
    caption <- figure_caption(file, paste("Additional generated figure:", title), metadata)
    cat(sprintf("![%s](%s){#fig-extra-%s fig-align=\"center\" width=100%%}\n\n",
                caption, markdown_path(file), slug_id(label)))
  }

  invisible(TRUE)
}

emit_kable <- function(x,
                       caption = NULL,
                       max_rows = 30,
                       max_cols = 10,
                       max_cell_chars = 80) {
  if (!nrow(x)) {
    return(invisible(FALSE))
  }
  table <- prepare_report_table(
    x,
    max_rows = max_rows,
    max_cols = max_cols,
    max_cell_chars = max_cell_chars
  )
  note <- character()
  if (table$omitted_rows > 0L) {
    note <- c(note, sprintf("%d rows omitted from the displayed preview.", table$omitted_rows))
  }
  if (length(table$omitted_cols)) {
    note <- c(note, sprintf("%d columns omitted: %s.", length(table$omitted_cols), paste(table$omitted_cols, collapse = ", ")))
  }
  if (length(note)) {
    cat("*Note: ", paste(note, collapse = " "), "*\n\n", sep = "")
  }
  if (requireNamespace("knitr", quietly = TRUE)) {
    format <- if (knitr::is_latex_output()) "latex" else "html"
    output <- knitr::kable(
      table$data,
      format = format,
      caption = render_report_text(caption),
      label = NA,
      booktabs = identical(format, "latex"),
      longtable = identical(format, "latex"),
      escape = TRUE
    )
    if (requireNamespace("kableExtra", quietly = TRUE)) {
      if (identical(format, "latex")) {
        output <- kableExtra::kable_styling(
          output,
          latex_options = c("repeat_header", "scale_down"),
          font_size = 8
        )
      } else {
        output <- kableExtra::kable_styling(
          output,
          full_width = FALSE,
          bootstrap_options = c("striped", "condensed", "responsive")
        )
      }
    }
    print(output)
  } else {
    cat("\n")
    print(table$data)
    cat("\n")
  }
  invisible(TRUE)
}

emit_catalog_tables <- function(catalog,
                                roots = c("pipeline-inputs", "tables/generated", "tables", "Tables")) {
  if (!nrow(catalog)) {
    emit_todo("Add table catalog rows to catalog/tables.csv.")
    return(invisible(FALSE))
  }

  catalog <- complete_catalog(catalog, "tables")
  metadata <- read_table_metadata(roots)

  last_section <- ""
  for (i in seq_len(nrow(catalog))) {
    section <- render_report_text(catalog$section[[i]])
    title <- render_report_text(catalog$title[[i]])
    caption <- render_report_text(catalog$caption[[i]])
    todo <- render_report_text(catalog$todo[[i]])
    file <- find_report_asset(catalog$file_candidates[[i]], roots = roots)

    if (!identical(section, last_section) && nzchar(section)) {
      cat("\n## ", section, "\n\n", sep = "")
      last_section <- section
    }

    cat("### ", title, "\n\n", sep = "")
    if (nzchar(file)) {
      data <- read_report_csv(file)
      if (nrow(data)) {
        emit_kable(data, caption = table_caption(file, caption, metadata))
        cat("\n\n")
      } else {
        emit_todo(paste("Table file exists but has no rows:", file))
      }
    } else {
      emit_todo(todo)
    }
  }

  invisible(TRUE)
}

emit_extra_generated_tables <- function(catalog,
                                        roots = c("tables/generated")) {
  roots <- roots[dir.exists(roots)]
  files <- unique(unlist(lapply(roots, function(root) {
    list.files(root, pattern = "[.]csv$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE))
  files <- files[!grepl("(^|/)(mfclshiny-)?table-index[.]csv$|(^|/)generated-table-index[.]csv$", files, ignore.case = TRUE)]
  if (!length(files)) {
    return(invisible(FALSE))
  }

  catalog_candidates <- unique(unlist(strsplit(paste(catalog$file_candidates, collapse = ";"), ";", fixed = TRUE), use.names = FALSE))
  catalog_candidates <- trimws(tolower(basename(catalog_candidates)))
  catalog_stems <- tools::file_path_sans_ext(catalog_candidates)
  file_stems <- tools::file_path_sans_ext(tolower(basename(files)))
  extra <- files[!file_stems %in% catalog_stems]
  if (!length(extra)) {
    return(invisible(FALSE))
  }
  metadata <- read_table_metadata(roots)

  cat("\n## Additional Generated Tables\n\n")
  for (file in extra) {
    label <- tools::file_path_sans_ext(basename(file))
    title <- gsub("[-_]+", " ", label)
    title <- paste0(toupper(substr(title, 1, 1)), substr(title, 2, nchar(title)))
    cat("### ", title, "\n\n", sep = "")
    data <- read_report_csv(file)
    if (nrow(data)) {
      emit_kable(data, caption = table_caption(file, paste("Additional generated table:", title), metadata))
      cat("\n\n")
    } else {
      emit_todo(paste("Table file exists but has no rows:", file))
    }
  }

  invisible(TRUE)
}
