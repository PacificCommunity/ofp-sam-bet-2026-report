`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

env <- function(name, default = "") {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) default else value
}

copy_unique <- function(files, dest) {
  files <- files[file.exists(files)]
  if (!length(files)) return(character())
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  copied <- character()
  seen <- character()
  for (file in files) {
    base <- basename(file)
    stem <- tools::file_path_sans_ext(base)
    ext <- tools::file_ext(base)
    target <- file.path(dest, base)
    n <- 2L
    while (target %in% seen || file.exists(target)) {
      target <- file.path(dest, sprintf("%s-%02d.%s", stem, n, ext))
      n <- n + 1L
    }
    file.copy(file, target, overwrite = TRUE)
    copied <- c(copied, target)
    seen <- c(seen, target)
  }
  copied
}

read_csv_safe <- function(path) {
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
}

bind_rows_fill <- function(rows) {
  rows <- rows[vapply(rows, function(x) is.data.frame(x) && nrow(x), logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    for (name in setdiff(cols, names(x))) x[[name]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, rows)
}

is_internal_report_table <- function(path) {
  base <- tolower(basename(path))
  grepl(
    paste(
      "^(payload-index(-[0-9]+)?|model-index|plot-summary|report-files|",
      "report-input-.*|report-prep-summary|figure-index|table-index|",
      "generated-table-index|mfclshiny-.*|.*build-log.*|.*report-summary)[.]csv$",
      sep = ""
    ),
    base
  )
}

regex_escape <- function(x) {
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
}

is_absolute_path <- function(path) {
  grepl("^(/|[A-Za-z]:[\\\\/])", path)
}

resolve_path <- function(path, root = getwd()) {
  path <- as.character(path %||% "")
  if (!nzchar(path)) return(root)
  if (is_absolute_path(path)) {
    return(normalizePath(path, winslash = "/", mustWork = FALSE))
  }
  normalizePath(file.path(root, path), winslash = "/", mustWork = FALSE)
}

relative_to_input <- function(paths, input_root) {
  sub(paste0("^", regex_escape(normalizePath(input_root, mustWork = FALSE)), "/?"), "", normalizePath(paths, mustWork = FALSE))
}

update_report_config <- function(path) {
  if (!file.exists(path)) return(invisible(FALSE))
  lines <- readLines(path, warn = FALSE)
  replacements <- c(
    species = env("FLOW_SPECIES", ""),
    species_code = env("FLOW_SPECIES", ""),
    species_label = env("FLOW_SPECIES_LABEL", ""),
    assessment_year = env("FLOW_ASSESSMENT_YEAR", "")
  )
  for (name in names(replacements)) {
    value <- replacements[[name]]
    if (!nzchar(value)) next
    rendered <- if (grepl("year", name)) value else paste0("\"", value, "\"")
    hit <- grepl(paste0("^", name, "\\s*:"), lines)
    if (any(hit)) lines[which(hit)[[1]]] <- paste0(name, ": ", rendered)
  }
  writeLines(lines, path)
  invisible(TRUE)
}

root <- getwd()
input_dir <- env("INPUT_DIR", "inputs")
report_dir <- env("REPORT_DIR", "bet-2026-report")
report_path <- resolve_path(report_dir, root)

if (!dir.exists(report_path)) stop("Report directory not found: ", report_path, call. = FALSE)

figure_dest <- file.path(report_path, "Figures", "generated")
table_dest <- file.path(report_path, "tables", "generated")
pipeline_dest <- file.path(report_path, "pipeline-inputs")
unlink(c(figure_dest, table_dest, pipeline_dest), recursive = TRUE, force = TRUE)
dir.create(figure_dest, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dest, recursive = TRUE, showWarnings = FALSE)
dir.create(pipeline_dest, recursive = TRUE, showWarnings = FALSE)

input_root <- resolve_path(input_dir, root)
all_files <- if (dir.exists(input_root)) list.files(input_root, recursive = TRUE, full.names = TRUE) else character()
if (!length(all_files)) warning("No Kflow input artifact files found at ", input_root)

figure_files <- all_files[grepl("[.](png|jpg|jpeg|pdf)$", all_files, ignore.case = TRUE)]
table_files <- all_files[grepl("[.]csv$", all_files, ignore.case = TRUE)]
figure_index_files <- table_files[grepl("(^|/)figure-index[.]csv$|(^|/)mfclshiny-figure-index[.]csv$", table_files, ignore.case = TRUE)]
table_index_files <- table_files[grepl("(^|/)table-index[.]csv$|(^|/)mfclshiny-table-index[.]csv$|(^|/)generated-table-index[.]csv$", table_files, ignore.case = TRUE)]

copied_figures <- copy_unique(figure_files, figure_dest)
report_table_files <- setdiff(table_files, c(figure_index_files, table_index_files))
report_table_files <- report_table_files[!is_internal_report_table(report_table_files)]
copied_tables <- copy_unique(report_table_files, table_dest)

figure_index <- bind_rows_fill(lapply(figure_index_files, read_csv_safe))
if (nrow(figure_index)) utils::write.csv(figure_index, file.path(figure_dest, "figure-index.csv"), row.names = FALSE)

table_index <- bind_rows_fill(lapply(table_index_files, read_csv_safe))
if (nrow(table_index)) utils::write.csv(table_index, file.path(table_dest, "table-index.csv"), row.names = FALSE)

summary_files <- table_files[grepl("summary[.]csv$|model-index[.]csv$|plot-summary[.]csv$|report-files[.]csv$", table_files, ignore.case = TRUE)]
summary_rows <- lapply(summary_files, function(file) {
  x <- read_csv_safe(file)
  if (!nrow(x)) return(data.frame())
  x$source_file <- relative_to_input(file, input_root)
  x
})
summaries <- bind_rows_fill(summary_rows)
if (nrow(summaries)) utils::write.csv(summaries, file.path(pipeline_dest, "report-input-summaries.csv"), row.names = FALSE)

registry <- data.frame(
  input_file = if (length(all_files)) relative_to_input(all_files, input_root) else character(),
  kind = ifelse(all_files %in% figure_files, "figure", ifelse(all_files %in% table_files, "table", "file")),
  size_bytes = suppressWarnings(file.info(all_files)$size),
  stringsAsFactors = FALSE
)
utils::write.csv(registry, file.path(pipeline_dest, "report-input-registry.csv"), row.names = FALSE)

prep_summary <- data.frame(
  copied_figures = length(copied_figures),
  copied_tables = length(copied_tables),
  figure_index_rows = nrow(figure_index),
  table_index_rows = nrow(table_index),
  input_files = length(all_files),
  stringsAsFactors = FALSE
)
utils::write.csv(prep_summary, file.path(pipeline_dest, "report-prep-summary.csv"), row.names = FALSE)

update_report_config(file.path(report_path, "report-config.yml"))
message("Prepared report inputs: ", length(copied_figures), " figures, ", length(copied_tables), " tables.")
