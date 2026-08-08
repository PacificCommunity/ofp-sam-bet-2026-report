#!/usr/bin/env Rscript

# Verify that the publication reporting-rate table remains synchronized with
# the table generated directly from final.par and tag_rep_map.R.

args <- commandArgs(trailingOnly = TRUE)
report_root <- if (length(args)) normalizePath(args[[1L]], mustWork = TRUE) else normalizePath(".", mustWork = TRUE)
source_file <- file.path(report_root, "tables", "source", "tag-reporting-rate-groups.csv")
table_file <- file.path(report_root, "tables", "Assessment-tables.qmd")

source <- utils::read.csv(source_file, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(
  identical(source$Group, 1:30),
  nrow(source) == 30L,
  sum(source$Estimated == "Yes") == 12L,
  !31L %in% source$Group,
  identical(source$`Fitted RR`[source$Group == 23L], "0.990")
)

lines <- readLines(table_file, warn = FALSE)
caption_line <- grep("label\\{tbl-tag-definitions\\}", lines)
if (length(caption_line) != 1L) stop("Could not identify the publication reporting-rate table.", call. = FALSE)
end_candidates <- which(seq_along(lines) > caption_line & grepl("^\\\\end\\{longtable\\}$", lines))
if (!length(end_candidates)) stop("Could not identify the end of the publication reporting-rate table.", call. = FALSE)
table_lines <- lines[caption_line:min(end_candidates)]
row_lines <- grep("^[0-9]+[[:space:]]+&", table_lines, value = TRUE)
if (length(row_lines) != 30L) stop("The publication reporting-rate table must contain Groups 1--30.", call. = FALSE)

parse_row <- function(line) {
  values <- trimws(strsplit(line, "&", fixed = TRUE)[[1L]])
  values[[length(values)]] <- sub("[[:space:]]*\\\\\\\\[[:space:]]*$", "", values[[length(values)]])
  values
}
rows <- lapply(row_lines, parse_row)
if (any(lengths(rows) != 8L)) stop("A publication reporting-rate row does not have eight columns.", call. = FALSE)
published <- data.frame(
  Group = as.integer(vapply(rows, `[[`, character(1L), 1L)),
  Estimated = vapply(rows, `[[`, character(1L), 7L),
  `Fitted RR` = vapply(rows, `[[`, character(1L), 8L),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

if (!identical(published$Group, source$Group) ||
    !identical(published$Estimated, source$Estimated) ||
    !identical(published$`Fitted RR`, source$`Fitted RR`)) {
  stop("The publication reporting-rate table does not match the generated final.par source table.", call. = FALSE)
}
if (!any(grepl("Group 31", table_lines, fixed = TRUE)) ||
    !any(grepl("inactive technical placeholder", table_lines, fixed = TRUE))) {
  stop("The publication table must explain the inactive Group 31 Index-fishery assignment.", call. = FALSE)
}

cat("Assessment-value audit passed: Groups 1--30 and 12 fitted reporting rates match the final.par source table.\n")
