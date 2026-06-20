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

copy_tree <- function(source, dest) {
  if (!nzchar(source) || !dir.exists(source)) return(character())
  files <- list.files(source, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  files <- files[file.exists(files) & !dir.exists(files)]
  if (!length(files)) return(character())
  copied <- character()
  source_norm <- normalizePath(source, winslash = "/", mustWork = FALSE)
  for (file in files) {
    rel <- sub(paste0("^", regex_escape(source_norm), "/?"), "", normalizePath(file, winslash = "/", mustWork = FALSE))
    target <- file.path(dest, rel)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    file.copy(file, target, overwrite = TRUE)
    copied <- c(copied, target)
  }
  copied
}

qmd_reference_paths <- function(path) {
  if (!file.exists(path)) return(character())
  lines <- readLines(path, warn = FALSE)
  text <- paste(lines, collapse = "\n")
  matches <- gregexpr("\\]\\(([^)]+)\\)", text, perl = TRUE)
  refs <- regmatches(text, matches)[[1]]
  if (!length(refs) || identical(refs, character(0))) return(character())
  refs <- sub("^\\]\\(", "", refs)
  refs <- sub("\\)$", "", refs)
  refs <- sub("\\{.*$", "", refs)
  refs <- trimws(refs)
  refs <- refs[nzchar(refs) & !grepl("^(https?:|mailto:|#)", refs, ignore.case = TRUE)]
  refs
}

copy_report_generated_outputs <- function(source, dest) {
  if (!nzchar(source) || !dir.exists(source)) return(character())
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  copied <- character()

  report_ready <- file.path(source, "report-ready")
  for (name in c("figures.qmd", "tables.qmd")) {
    src <- file.path(report_ready, name)
    if (!file.exists(src)) next
    target <- file.path(dest, "report-ready", name)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    file.copy(src, target, overwrite = TRUE)
    copied <- c(copied, target)
  }

  refs <- unique(c(
    qmd_reference_paths(file.path(report_ready, "figures.qmd")),
    qmd_reference_paths(file.path(report_ready, "tables.qmd"))
  ))
  refs <- sub("^generated/outputs/", "", refs)
  refs <- refs[grepl("^(figures|tables)/", refs)]
  for (rel in refs) {
    src <- file.path(source, rel)
    if (!file.exists(src) || dir.exists(src)) next
    target <- file.path(dest, rel)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    file.copy(src, target, overwrite = TRUE)
    copied <- c(copied, target)
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

dedupe_index_rows <- function(x) {
  if (!is.data.frame(x) || !nrow(x)) return(x)
  key_cols <- intersect(c("figure", "table", "file", "relative_path", "label", "caption"), names(x))
  if (!length(key_cols)) return(unique(x))
  keys <- do.call(paste, c(lapply(x[key_cols], as.character), sep = "\r"))
  x[!duplicated(keys), , drop = FALSE]
}

is_internal_report_table <- function(path) {
  base <- tolower(basename(path))
  grepl(
    paste(
      "^(payload-index(-[0-9]+)?|model-index|plot-summary|report-files|",
      "report-input-.*|report-prep-summary|figure-index|table-index|",
      "generated-table-index|figure-optimization|curation-summary|",
      ".*provenance.*|",
      "report-selection|mfclshiny-.*|",
      ".*build-log.*|.*report-summary)[.]csv$",
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

clean_metadata_value <- function(x) {
  x <- trimws(as.character(x %||% ""))
  x <- x[nzchar(x) & !grepl("\\{\\{", x)]
  x
}

collapse_metadata <- function(x) {
  paste(unique(clean_metadata_value(x)), collapse = ",")
}

top_level_input_job_ids <- function(input_root) {
  if (!dir.exists(input_root)) return(character())
  dirs <- list.dirs(input_root, full.names = TRUE, recursive = FALSE)
  ids <- basename(dirs)
  keep <- grepl("^[0-9A-Fa-f]{8,}$", ids) | dir.exists(file.path(dirs, "outputs"))
  ids[keep]
}

metadata_field <- function(x, names) {
  if (!is.data.frame(x) || !nrow(x)) return(character())
  cols <- intersect(names, colnames(x))
  if (!length(cols)) return(character())
  unlist(x[cols], use.names = FALSE)
}

git_metadata <- function(args, path = getwd()) {
  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(path)
  value <- tryCatch(
    suppressWarnings(system2("git", args, stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  collapse_metadata(value[1])
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

find_outputs_bundle <- function(input_root) {
  if (!dir.exists(input_root)) return("")
  dirs <- list.dirs(input_root, recursive = TRUE, full.names = TRUE)
  dirs <- dirs[file.exists(file.path(dirs, "report-ready", "figures.qmd")) |
    file.exists(file.path(dirs, "report-ready", "tables.qmd"))]
  if (!length(dirs)) return("")
  file_counts <- vapply(dirs, function(dir) length(list.files(dir, recursive = TRUE, full.names = TRUE)), integer(1))
  dirs[order(file_counts, decreasing = TRUE)[[1]]]
}

seed_report_section <- function(report_path, name, source) {
  if (!file.exists(source)) return("missing-source")
  target <- file.path(report_path, "sections", paste0(name, ".qmd"))
  existing <- if (file.exists(target)) readLines(target, warn = FALSE) else character()
  should_seed <- !file.exists(target) || any(grepl("kflow-section-seed", existing, fixed = TRUE))
  if (!isTRUE(should_seed)) return("preserved")
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  file.copy(source, target, overwrite = TRUE)
  "seeded"
}

read_kflow_provenance <- function(path) {
  if (!file.exists(path) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(path, simplifyDataFrame = TRUE), error = function(e) list())
}

provenance_lineage_table <- function(provenance) {
  lineage <- provenance$lineage
  if (is.null(lineage)) return(data.frame())
  if (is.data.frame(lineage)) return(lineage)
  if (is.list(lineage) && length(lineage)) {
    return(bind_rows_fill(lapply(lineage, function(x) as.data.frame(x, stringsAsFactors = FALSE))))
  }
  data.frame()
}

root <- getwd()
input_dir <- env("INPUT_DIR", "inputs")
report_dir <- env("REPORT_DIR", "bet-2026-report")
report_path <- resolve_path(report_dir, root)

if (!dir.exists(report_path)) stop("Report directory not found: ", report_path, call. = FALSE)

figure_dest <- file.path(report_path, "Figures", "generated")
table_dest <- file.path(report_path, "tables", "generated")
pipeline_dest <- file.path(report_path, "pipeline-inputs")
generated_outputs_dest <- file.path(report_path, "generated", "outputs")
unlink(c(figure_dest, table_dest, pipeline_dest, generated_outputs_dest), recursive = TRUE, force = TRUE)
dir.create(figure_dest, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dest, recursive = TRUE, showWarnings = FALSE)
dir.create(pipeline_dest, recursive = TRUE, showWarnings = FALSE)
dir.create(generated_outputs_dest, recursive = TRUE, showWarnings = FALSE)

input_root <- resolve_path(input_dir, root)
all_files <- if (dir.exists(input_root)) list.files(input_root, recursive = TRUE, full.names = TRUE) else character()
if (!length(all_files)) warning("No Kflow input artifact files found at ", input_root)

outputs_bundle <- find_outputs_bundle(input_root)
copied_generated_outputs <- copy_report_generated_outputs(outputs_bundle, generated_outputs_dest)
figures_section_status <- seed_report_section(
  report_path,
  "Figures",
  file.path(generated_outputs_dest, "report-ready", "figures.qmd")
)
tables_section_status <- seed_report_section(
  report_path,
  "Tables",
  file.path(generated_outputs_dest, "report-ready", "tables.qmd")
)

figure_files <- all_files[grepl("[.](png|jpg|jpeg|webp|pdf)$", all_files, ignore.case = TRUE)]
table_files <- all_files[grepl("[.]csv$", all_files, ignore.case = TRUE)]
figure_index_files <- table_files[grepl("(^|/)figure-index[.]csv$|(^|/)mfclshiny-figure-index[.]csv$", table_files, ignore.case = TRUE)]
table_index_files <- table_files[grepl("(^|/)table-index[.]csv$|(^|/)mfclshiny-table-index[.]csv$|(^|/)generated-table-index[.]csv$", table_files, ignore.case = TRUE)]
provenance_files <- table_files[grepl("(^|/)provenance/.*provenance[.]csv$", table_files, ignore.case = TRUE)]

copied_figures <- copy_unique(figure_files, figure_dest)
report_table_files <- setdiff(table_files, c(figure_index_files, table_index_files))
report_table_files <- report_table_files[!is_internal_report_table(report_table_files)]
if (any(grepl("(^|/)(report|draft)/sections/", all_files, ignore.case = TRUE))) {
  report_table_files <- report_table_files[grepl("(^|/)tables/", relative_to_input(report_table_files, input_root), ignore.case = TRUE)]
}
copied_tables <- copy_unique(report_table_files, table_dest)

figure_index <- dedupe_index_rows(bind_rows_fill(lapply(figure_index_files, read_csv_safe)))
if (nrow(figure_index)) utils::write.csv(figure_index, file.path(figure_dest, "figure-index.csv"), row.names = FALSE)

table_index <- dedupe_index_rows(bind_rows_fill(lapply(table_index_files, read_csv_safe)))
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

input_job_ids <- top_level_input_job_ids(input_root)
upstream_provenance <- bind_rows_fill(lapply(provenance_files, read_csv_safe))
outputs_job_ids <- collapse_metadata(c(
  env("OUTPUTS_JOB_IDS", ""),
  env("OUTPUTS_JOB_ID", ""),
  metadata_field(upstream_provenance, c("outputs_job_ids", "upstream_job_ids"))
))
kflow_provenance_file <- env("KFLOW_PROVENANCE_FILE", file.path(input_root, "kflow-provenance.json"))
if (file.exists(kflow_provenance_file)) {
  file.copy(kflow_provenance_file, file.path(pipeline_dest, "kflow-provenance.json"), overwrite = TRUE)
}
kflow_provenance <- read_kflow_provenance(kflow_provenance_file)
kflow_lineage <- provenance_lineage_table(kflow_provenance)
if (nrow(kflow_lineage)) {
  utils::write.csv(kflow_lineage, file.path(pipeline_dest, "kflow-lineage.csv"), row.names = FALSE)
}
report_provenance <- data.frame(
  stage = "report",
  generated_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  report_job_id = env("KFLOW_JOB_ID", ""),
  report_input_job_ids = collapse_metadata(input_job_ids),
  outputs_job_ids = outputs_job_ids,
  outputs_bundle = if (nzchar(outputs_bundle)) relative_to_input(outputs_bundle, input_root) else "",
  generated_outputs_files = length(copied_generated_outputs),
  figures_section = figures_section_status,
  tables_section = tables_section_status,
  kflow_lineage_job_ids = if (nrow(kflow_lineage) && "job_id" %in% names(kflow_lineage)) collapse_metadata(kflow_lineage$job_id) else "",
  kflow_lineage_tasks = if (nrow(kflow_lineage) && "task" %in% names(kflow_lineage)) collapse_metadata(kflow_lineage$task) else "",
  report_repo_commit = git_metadata(c("rev-parse", "HEAD"), root),
  report_repo_remote = git_metadata(c("config", "--get", "remote.origin.url"), root),
  upstream_provenance_files = collapse_metadata(c(relative_to_input(provenance_files, input_root), basename(kflow_provenance_file))),
  copied_figures = length(copied_figures),
  copied_tables = length(copied_tables),
  figure_index_rows = nrow(figure_index),
  table_index_rows = nrow(table_index),
  input_files = length(all_files),
  stringsAsFactors = FALSE
)
utils::write.csv(report_provenance, file.path(pipeline_dest, "report-provenance.csv"), row.names = FALSE)
if (requireNamespace("jsonlite", quietly = TRUE)) {
  jsonlite::write_json(
    report_provenance,
    file.path(pipeline_dest, "report-provenance.json"),
    dataframe = "rows",
    auto_unbox = TRUE,
    pretty = TRUE
  )
}

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
message("Report sections: Figures=", figures_section_status, ", Tables=", tables_section_status, ".")
