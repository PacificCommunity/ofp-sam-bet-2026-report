catalog_file <- function(name) {
  if (identical(name, "figures")) {
    return(get0("figure_catalog", ifnotfound = file.path("catalog", "figures.csv")))
  }
  if (identical(name, "tables")) {
    return(get0("table_catalog", ifnotfound = file.path("catalog", "tables.csv")))
  }
  file.path("catalog", paste0(name, ".csv"))
}

read_catalog <- function(name) {
  read_report_csv(catalog_file(name))
}

figure_curation_file <- function() {
  get0("figure_curation", ifnotfound = get0("curation", ifnotfound = file.path("catalog", "curation.yml")))
}

table_curation_file <- function() {
  get0("table_curation", ifnotfound = get0("curation", ifnotfound = file.path("catalog", "curation.yml")))
}

figure_curation_columns <- function() {
  c("target_type", "target", "placement", "section", "title", "caption_override", "order", "notes")
}

table_curation_columns <- function() {
  c("target_type", "target", "placement", "section", "title", "caption_override", "order", "notes")
}

read_curation_yaml <- function(path, section) {
  if (!file.exists(path)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  if (!requireNamespace("yaml", quietly = TRUE)) {
    warning("YAML curation file found but the yaml package is unavailable: ", path)
    return(data.frame(stringsAsFactors = FALSE))
  }
  x <- yaml::read_yaml(path)
  items <- x[[section]] %||% list()
  if (!length(items)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  if (is.data.frame(items)) {
    return(as.data.frame(items, stringsAsFactors = FALSE, check.names = FALSE))
  }
  rows <- lapply(items, function(item) {
    if (is.null(item)) {
      return(NULL)
    }
    if (!is.list(item)) {
      item <- list(target = as.character(item))
    }
    as.data.frame(item, stringsAsFactors = FALSE, check.names = FALSE)
  })
  bind_report_rows(rows)
}

read_curation_section <- function(path, section, columns) {
  ext <- tolower(tools::file_ext(path))
  curation <- if (ext %in% c("yml", "yaml")) {
    read_curation_yaml(path, section)
  } else {
    read_report_csv(path)
  }
  needed <- columns()
  if (!is.data.frame(curation) || !nrow(curation)) {
    out <- as.data.frame(stats::setNames(rep(list(character()), length(needed)), needed), stringsAsFactors = FALSE)
    return(out[, needed, drop = FALSE])
  }
  for (name in setdiff(needed, names(curation))) {
    curation[[name]] <- ""
  }
  curation[, needed, drop = FALSE]
}

read_figure_curation <- function(path = figure_curation_file()) {
  read_curation_section(path, "figures", figure_curation_columns)
}

read_table_curation <- function(path = table_curation_file()) {
  read_curation_section(path, "tables", table_curation_columns)
}

catalog_columns <- function(type = c("figures", "tables")) {
  type <- match.arg(type)
  if (identical(type, "figures")) {
    return(c("key", "placement", "section", "title", "file_candidates", "caption", "caption_override", "todo", "notes"))
  }
  c("key", "placement", "section", "title", "file_candidates", "caption", "caption_override", "todo", "notes")
}

complete_catalog <- function(catalog, type = c("figures", "tables")) {
  type <- match.arg(type)
  needed <- catalog_columns(type)
  for (name in setdiff(needed, names(catalog))) {
    catalog[[name]] <- ""
  }
  catalog
}
