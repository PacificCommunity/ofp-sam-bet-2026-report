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
  metadata_sources <- c(source, file.path(source, "metadata"))
  for (name in c("report-selection.json", "report-selection.csv", "analysis-manifest.json", "analysis-manifest.csv")) {
    src <- file.path(metadata_sources, name)
    src <- src[file.exists(src)][1] %||% ""
    if (!nzchar(src)) next
    target <- file.path(dest, "metadata", name)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    file.copy(src, target, overwrite = TRUE)
    copied <- c(copied, target)
  }
  for (name in c("figure-index.csv", "table-index.csv", "payload-index.csv", "plot-summary.csv", "figure-optimization.csv")) {
    src <- file.path(c(file.path(source, "indices"), source), name)
    src <- src[file.exists(src)][1] %||% ""
    if (!nzchar(src)) next
    target <- file.path(dest, "indices", name)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    file.copy(src, target, overwrite = TRUE)
    copied <- c(copied, target)
  }
  for (name in c("figures.qmd", "tables.qmd", "report-ready-files.csv")) {
    src <- file.path(report_ready, name)
    if (!file.exists(src)) next
    target <- file.path(dest, "report-ready", name)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    file.copy(src, target, overwrite = TRUE)
    copied <- c(copied, target)
  }
  overview <- file.path(source, "overview")
  for (name in c("report-ready-figures.html", "report-map.html")) {
    src <- file.path(overview, name)
    if (!file.exists(src)) next
    target <- file.path(dest, "overview", name)
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
      "^(payload-index(-[0-9]+)?|model-index|plot-summary|report-files|report-ready-files|",
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

split_metadata <- function(x) {
  unique(clean_metadata_value(unlist(strsplit(paste(x, collapse = ","), ",", fixed = TRUE), use.names = FALSE)))
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

find_results_bundle <- function(input_root) {
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
  reseed_generated <- tolower(env("KFLOW_REPORT_RESEED_GENERATED_SECTIONS", "true")) %in% c("true", "yes", "1", "on")
  generated_markers <- c(
    "kflow-section-seed",
    "Auto-generated by the BET results task.",
    "generated/outputs/report-ready/"
  )
  generated_existing <- any(vapply(
    generated_markers,
    function(marker) any(grepl(marker, existing, fixed = TRUE)),
    logical(1)
  ))
  should_seed <- !file.exists(target) || (isTRUE(reseed_generated) && generated_existing)
  if (!isTRUE(should_seed)) return("preserved")
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  status <- if (file.exists(target)) "reseeded" else "seeded"
  file.copy(source, target, overwrite = TRUE)
  status
}

stabilize_pdf_figure_section <- function(path, every = 1L) {
  if (!file.exists(path)) return(FALSE)
  lines <- readLines(path, warn = FALSE)
  marker <- "<!-- kflow-pdf-float-barriers -->"
  break_lines <- c("\\FloatBarrier", "\\clearpage")
  vspace_line <- "\\vspace*{0.04\\textheight}"
  generated_layout_lines <- c(break_lines, vspace_line)
  latex_break_block_end <- function(index) {
    if (!identical(trimws(lines[[index]]), "```{=latex}")) return(NA_integer_)
    closing <- which(seq_along(lines) > index & trimws(lines) == "```")
    if (!length(closing)) return(NA_integer_)
    end <- closing[[1L]]
    body <- if (end > index + 1L) trimws(lines[seq.int(index + 1L, end - 1L)]) else character()
    if (!length(body) || all(body %in% c("", generated_layout_lines))) end else NA_integer_
  }

  out <- c(marker, "", "\\clearpage", "")
  i <- 1L
  while (i <= length(lines)) {
    line <- lines[[i]]
    if (identical(line, marker)) {
      i <- i + 1L
      next
    }
    block_end <- latex_break_block_end(i)
    if (!is.na(block_end)) {
      i <- block_end + 1L
      next
    }
    if (trimws(line) %in% generated_layout_lines) {
      i <- i + 1L
      next
    }
    if (grepl("^!\\[", line) && grepl("\\{#fig-", line)) {
      out <- c(out, "", vspace_line, "")
    }
    out <- c(out, line)
    if (grepl("^!\\[", line) && grepl("\\{#fig-", line)) {
      out <- c(out, "", "```{=latex}", "\\FloatBarrier", "\\clearpage", "```", "")
    }
    i <- i + 1L
  }
  if (identical(lines, out)) return(FALSE)
  writeLines(out, path)
  TRUE
}

stabilize_quarto_pipe_labels <- function(path) {
  if (!file.exists(path)) return(FALSE)
  lines <- readLines(path, warn = FALSE)
  out <- lines
  i <- 1L
  while (i <= length(lines)) {
    line <- lines[[i]]
    header <- regexec("^(```\\{r)\\s+([^,}\\s]+)(\\s*(?:,.*)?\\})$", line, perl = TRUE)
    match <- regmatches(line, header)[[1]]
    if (!length(match)) {
      i <- i + 1L
      next
    }
    closing <- which(seq_along(lines) > i & trimws(lines) == "```")
    if (!length(closing)) {
      i <- i + 1L
      next
    }
    end <- closing[[1L]]
    body <- if (end > i + 1L) lines[seq.int(i + 1L, end - 1L)] else character()
    if (any(grepl("^#\\|\\s*label\\s*:", body))) {
      suffix <- match[[4]]
      out[[i]] <- if (identical(trimws(suffix), "}")) paste0(match[[2]], "}") else paste0(match[[2]], suffix)
    }
    i <- end + 1L
  }
  if (identical(lines, out)) return(FALSE)
  writeLines(out, path)
  TRUE
}

read_kflow_provenance <- function(path) {
  if (!file.exists(path) || !requireNamespace("jsonlite", quietly = TRUE)) return(list())
  tryCatch(jsonlite::fromJSON(path, simplifyDataFrame = TRUE), error = function(e) list())
}

provenance_section_table <- function(provenance, name) {
  section <- provenance[[name]]
  if (is.null(section)) return(data.frame(stringsAsFactors = FALSE))
  if (is.data.frame(section)) return(section)
  if (is.list(section) && length(section)) {
    if (!all(vapply(section, is.list, logical(1)))) {
      return(as.data.frame(section, stringsAsFactors = FALSE, check.names = FALSE))
    }
    return(bind_rows_fill(lapply(section, function(x) as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE))))
  }
  data.frame(stringsAsFactors = FALSE)
}

provenance_lineage_table <- function(provenance) {
  provenance_section_table(provenance, "lineage")
}

kflow_job_ref <- function(job_id = "", job_number = "", job_label = "") {
  job_id <- clean_metadata_value(job_id)[1] %||% ""
  job_number <- clean_metadata_value(job_number)[1] %||% ""
  job_label <- clean_metadata_value(job_label)[1] %||% ""
  if (!nzchar(job_label) && nzchar(job_number)) job_label <- paste("Job", job_number)
  if (nzchar(job_label) && nzchar(job_id)) return(paste0(job_label, " (", job_id, ")"))
  if (nzchar(job_label)) return(job_label)
  if (nzchar(job_id)) return(job_id)
  ""
}

kflow_record_refs <- function(records) {
  if (!is.data.frame(records) || !nrow(records)) return(character())
  vapply(seq_len(nrow(records)), function(i) {
    kflow_job_ref(
      if ("job_id" %in% names(records)) records$job_id[[i]] else "",
      if ("job_number" %in% names(records)) records$job_number[[i]] else "",
      if ("job_label" %in% names(records)) records$job_label[[i]] else ""
    )
  }, character(1))
}

kflow_record_tasks <- function(records) {
  if (!is.data.frame(records) || !nrow(records)) return(character())
  vapply(seq_len(nrow(records)), function(i) {
    task <- ""
    if ("task" %in% names(records)) task <- records$task[[i]]
    if (!nzchar(clean_metadata_value(task)[1] %||% "") && "task_name" %in% names(records)) {
      task <- records$task_name[[i]]
    }
    clean_metadata_value(task)[1] %||% ""
  }, character(1))
}

kflow_record_task_refs <- function(records) {
  refs <- kflow_record_refs(records)
  tasks <- kflow_record_tasks(records)
  if (!length(refs)) return(character())
  ifelse(nzchar(tasks) & nzchar(refs), paste(tasks, refs), refs)
}

kflow_record_match <- function(records, id) {
  if (!is.data.frame(records) || !nrow(records)) return(integer())
  id <- as.character(id %||% "")
  hits <- integer()
  if ("job_id" %in% names(records)) {
    hits <- union(hits, which(as.character(records$job_id) == id))
  }
  if ("job_number" %in% names(records)) {
    hits <- union(hits, which(as.character(records$job_number) == id))
  }
  hits
}

kflow_job_refs_for_ids <- function(ids, records) {
  ids <- split_metadata(ids)
  if (!length(ids)) return("")
  refs <- vapply(ids, function(id) {
    hit <- kflow_record_match(records, id)
    if (length(hit)) return(kflow_record_refs(records[hit[[1]], , drop = FALSE]))
    id
  }, character(1))
  collapse_metadata(refs)
}

kflow_job_task_refs_for_ids <- function(ids, records) {
  ids <- split_metadata(ids)
  if (!length(ids)) return("")
  refs <- vapply(ids, function(id) {
    hit <- kflow_record_match(records, id)
    if (length(hit)) return(kflow_record_task_refs(records[hit[[1]], , drop = FALSE]))
    id
  }, character(1))
  collapse_metadata(refs)
}

root <- getwd()
input_dir <- env("INPUT_DIR", "inputs")
report_dir <- env("REPORT_DIR", "bet-2026-report")
report_path <- resolve_path(report_dir, root)

if (!dir.exists(report_path)) stop("Report directory not found: ", report_path, call. = FALSE)

pipeline_dest <- file.path(report_path, "pipeline-inputs")
generated_outputs_dest <- file.path(report_path, "generated", "outputs")
preserve_generated_outputs <- tolower(
  env("KFLOW_REPORT_PRESERVE_GENERATED_OUTPUTS", "false")
) %in% c("true", "yes", "1", "on")

unlink(pipeline_dest, recursive = TRUE, force = TRUE)
if (!isTRUE(preserve_generated_outputs)) {
  unlink(generated_outputs_dest, recursive = TRUE, force = TRUE)
}
dir.create(pipeline_dest, recursive = TRUE, showWarnings = FALSE)
dir.create(generated_outputs_dest, recursive = TRUE, showWarnings = FALSE)

input_root <- resolve_path(input_dir, root)
all_files <- if (dir.exists(input_root)) list.files(input_root, recursive = TRUE, full.names = TRUE) else character()
if (!length(all_files)) warning("No Kflow input artifact files found at ", input_root)

results_bundle <- find_results_bundle(input_root)
copied_generated_outputs <- copy_report_generated_outputs(results_bundle, generated_outputs_dest)
stabilize_quarto_pipe_labels(file.path(generated_outputs_dest, "report-ready", "tables.qmd"))
figures_section_status <- seed_report_section(
  report_path,
  "Figures",
  file.path(generated_outputs_dest, "report-ready", "figures.qmd")
)
if (figures_section_status %in% c("seeded", "reseeded")) {
  if (stabilize_pdf_figure_section(file.path(report_path, "sections", "Figures.qmd"))) {
    figures_section_status <- paste0(figures_section_status, "+pdf-float-barriers")
  }
}
tables_section_status <- seed_report_section(
  report_path,
  "Tables",
  file.path(generated_outputs_dest, "report-ready", "tables.qmd")
)
if (stabilize_quarto_pipe_labels(file.path(report_path, "sections", "Tables.qmd"))) {
  tables_section_status <- paste0(tables_section_status, "+pipe-labels")
}

figure_files <- all_files[grepl("[.](png|jpg|jpeg|webp|pdf)$", all_files, ignore.case = TRUE)]
table_files <- all_files[grepl("[.]csv$", all_files, ignore.case = TRUE)]
figure_index_files <- table_files[grepl("(^|/)figure-index[.]csv$|(^|/)mfclshiny-figure-index[.]csv$", table_files, ignore.case = TRUE)]
table_index_files <- table_files[grepl("(^|/)table-index[.]csv$|(^|/)mfclshiny-table-index[.]csv$|(^|/)generated-table-index[.]csv$", table_files, ignore.case = TRUE)]
provenance_files <- table_files[grepl("(^|/)provenance/.*provenance[.]csv$", table_files, ignore.case = TRUE)]

copied_generated_rel <- sub(
  paste0("^", regex_escape(normalizePath(generated_outputs_dest, winslash = "/", mustWork = FALSE)), "/?"),
  "",
  normalizePath(copied_generated_outputs, winslash = "/", mustWork = FALSE)
)
copied_figures <- copied_generated_outputs[grepl("^figures/", copied_generated_rel)]
copied_tables <- copied_generated_outputs[grepl("^tables/", copied_generated_rel)]

figure_index <- dedupe_index_rows(bind_rows_fill(lapply(figure_index_files, read_csv_safe)))
if (nrow(figure_index)) {
  dir.create(file.path(generated_outputs_dest, "indices"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(figure_index, file.path(generated_outputs_dest, "indices", "figure-index.csv"), row.names = FALSE)
}

table_index <- dedupe_index_rows(bind_rows_fill(lapply(table_index_files, read_csv_safe)))
if (nrow(table_index)) {
  dir.create(file.path(generated_outputs_dest, "indices"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(table_index, file.path(generated_outputs_dest, "indices", "table-index.csv"), row.names = FALSE)
}

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
results_job_ids <- collapse_metadata(c(
  env("RESULTS_JOB_IDS", ""),
  env("RESULTS_JOB_ID", ""),
  env("OUTPUTS_JOB_IDS", ""),
  env("OUTPUTS_JOB_ID", ""),
  metadata_field(upstream_provenance, c("results_job_ids", "outputs_job_ids", "upstream_job_ids"))
))
kflow_provenance_file <- env("KFLOW_PROVENANCE_FILE", file.path(input_root, "kflow-provenance.json"))
if (file.exists(kflow_provenance_file)) {
  file.copy(kflow_provenance_file, file.path(pipeline_dest, "kflow-provenance.json"), overwrite = TRUE)
}
kflow_provenance <- read_kflow_provenance(kflow_provenance_file)
kflow_job <- provenance_section_table(kflow_provenance, "job")
kflow_inputs <- provenance_section_table(kflow_provenance, "inputs")
kflow_lineage <- provenance_lineage_table(kflow_provenance)
kflow_records <- bind_rows_fill(list(kflow_job, kflow_inputs, kflow_lineage))
if (!nzchar(results_job_ids)) {
  results_job_ids <- collapse_metadata(c(metadata_field(kflow_inputs, "job_id"), input_job_ids))
}
if (nrow(kflow_lineage)) {
  utils::write.csv(kflow_lineage, file.path(pipeline_dest, "kflow-lineage.csv"), row.names = FALSE)
}
report_provenance <- data.frame(
  stage = "report",
  generated_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  report_job_id = env("KFLOW_JOB_ID", ""),
  report_job_number = env("KFLOW_JOB_NUMBER", collapse_metadata(metadata_field(kflow_job, "job_number"))),
  report_job_ref = kflow_job_ref(
    env("KFLOW_JOB_ID", collapse_metadata(metadata_field(kflow_job, "job_id"))),
    env("KFLOW_JOB_NUMBER", collapse_metadata(metadata_field(kflow_job, "job_number"))),
    collapse_metadata(metadata_field(kflow_job, "job_label"))
  ),
  report_input_job_ids = collapse_metadata(input_job_ids),
  results_job_ids = results_job_ids,
  results_job_refs = kflow_job_task_refs_for_ids(results_job_ids, kflow_records),
  results_bundle = if (nzchar(results_bundle)) relative_to_input(results_bundle, input_root) else "",
  outputs_job_ids = results_job_ids,
  outputs_bundle = if (nzchar(results_bundle)) relative_to_input(results_bundle, input_root) else "",
  generated_outputs_files = length(copied_generated_outputs),
  figures_section = figures_section_status,
  tables_section = tables_section_status,
  kflow_lineage_job_ids = if (nrow(kflow_lineage) && "job_id" %in% names(kflow_lineage)) collapse_metadata(kflow_lineage$job_id) else "",
  kflow_lineage_job_numbers = if (nrow(kflow_lineage) && "job_number" %in% names(kflow_lineage)) collapse_metadata(kflow_lineage$job_number) else "",
  kflow_lineage_job_refs = collapse_metadata(kflow_record_refs(kflow_lineage)),
  kflow_lineage_task_refs = collapse_metadata(kflow_record_task_refs(kflow_lineage)),
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
