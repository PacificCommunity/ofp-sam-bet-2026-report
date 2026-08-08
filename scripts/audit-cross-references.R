#!/usr/bin/env Rscript

# Fail the report build when a publication figure/table is missing, duplicated
# or not discussed in the narrative.  Quarto performs its own final reference
# resolution; this earlier audit produces a shorter, report-specific error.

args <- commandArgs(trailingOnly = TRUE)
report_root <- if (length(args)) normalizePath(args[[1L]], mustWork = TRUE) else normalizePath(".", mustWork = TRUE)
qmd_files <- c(
  file.path(report_root, "main.qmd"),
  list.files(file.path(report_root, "sections"), pattern = "[.]qmd$", full.names = TRUE),
  list.files(file.path(report_root, "tables"), pattern = "[.]qmd$", full.names = TRUE)
)
text <- paste(unlist(lapply(qmd_files, readLines, warn = FALSE)), collapse = "\n")

extract_matches <- function(pattern, value) {
  match <- gregexpr(pattern, value, perl = TRUE)
  found <- regmatches(value, match)[[1L]]
  if (identical(found, character(0L)) || identical(found, "")) character() else found
}

markdown_ids <- sub(
  "^\\{#", "",
  extract_matches("\\{#(?:fig|tbl)-[A-Za-z0-9_-]+", text)
)
latex_ids <- extract_matches("\\\\label\\{(?:fig|tbl)-[A-Za-z0-9_-]+\\}", text)
latex_ids <- sub("^\\\\label\\{", "", latex_ids)
latex_ids <- sub("\\}$", "", latex_ids)
ids <- c(markdown_ids, latex_ids)
references <- sub(
  "^@", "",
  extract_matches("@(?:fig|tbl)-[A-Za-z0-9_-]+", text)
)

problems <- character()
duplicate_ids <- unique(ids[duplicated(ids)])
if (length(duplicate_ids)) {
  problems <- c(problems, paste("Duplicate identifiers:", paste(duplicate_ids, collapse = ", ")))
}
missing_ids <- setdiff(unique(references), unique(ids))
if (length(missing_ids)) {
  problems <- c(problems, paste("References without definitions:", paste(missing_ids, collapse = ", ")))
}
unreferenced_ids <- setdiff(unique(ids), unique(references))
if (length(unreferenced_ids)) {
  problems <- c(problems, paste("Figures/tables not discussed in the text:", paste(unreferenced_ids, collapse = ", ")))
}

## Match the image destination adjacent to its figure identifier rather than
## trying to parse the whole caption. Captions may themselves contain linked
## text, so a simple first-closing-bracket expression is not sufficient.
image_markup <- extract_matches(
  "\\]\\((?:figures|figures_new)/[^)]+\\)\\{#fig-[A-Za-z0-9_-]+",
  text
)
image_paths <- sub("^\\]\\(", "", image_markup)
image_paths <- sub("\\)\\{#fig-[A-Za-z0-9_-]+$", "", image_paths)
missing_images <- image_paths[!file.exists(file.path(report_root, image_paths))]
if (length(missing_images)) {
  problems <- c(problems, paste("Missing local image assets:", paste(unique(missing_images), collapse = ", ")))
}

empty_caption_markup <- extract_matches("!\\[\\]\\([^)]+\\)", text)
if (length(empty_caption_markup)) {
  problems <- c(problems, paste("Figures with empty captions:", length(empty_caption_markup)))
}

if (length(problems)) {
  stop(paste(c("Report cross-reference audit failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
}

cat(sprintf(
  "Cross-reference audit passed: %d unique figure/table identifiers, %d references and %d local image uses.\n",
  length(unique(ids)), length(references), length(image_paths)
))
