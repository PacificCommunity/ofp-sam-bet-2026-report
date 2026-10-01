#!/usr/bin/env Rscript
# Recalculate Figure 66 from archived seasonal SB, without an installed mfclshiny.
# Use the digest-pinned report container for identical fonts and PNG pixels.
args <- commandArgs(trailingOnly = TRUE)
check_only <- "--check" %in% args
args <- args[args != "--check"]
root <- normalizePath(if (length(args)) args[[1L]] else ".")
published <- file.path(root, "figures_new/fishery-impact")
input <- file.path(published, "inputs")
out <- if (check_only) tempfile("figure66-check-") else published
for (package in c("ggplot2", "ragg", "jsonlite", "digest")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Missing package: ", package)
}
checksums <- read.csv(file.path(input, "checksums.csv"), stringsAsFactors = FALSE)
actual_hash <- vapply(file.path(root, checksums$path), digest::digest, character(1),
                      algo = "sha256", file = TRUE)
stopifnot(identical(unname(actual_hash), checksums$sha256))
source(file.path(root, "scripts/vendor/mfclshiny/fishery-impact.R"))
source(file.path(root, "scripts/fishery-impact-style.R"))
groups <- jsonlite::read_json(file.path(input, "groups.json"), simplifyVector = TRUE)
labels <- c("Longline", "Pole-and-line", "PS (unspecified)", "PS-associated", "PS-unassociated", "Miscellaneous")
stopifnot(identical(names(groups), c("longline", "pole_line", "ps", "ps_associated",
                                    "ps_unassociated", "miscellaneous")),
          identical(sort(as.integer(unlist(groups))), 1:28))
for (name in c(names(groups), "all_off")) {
  controls <- read.table(file.path(input, "controls", paste0(name, ".txt")))
  disabled <- -controls$V1[controls$V1 < 0 & controls$V2 == 55 & controls$V3 == 1]
  # MFCL's -999 selector applies fishery flag 55 to every fishery.
  expected <- if (name == "all_off") 999L else c(groups[[name]], 29:33)
  stopifnot(identical(sort(as.integer(disabled)), sort(as.integer(expected))),
            any(controls$V1 == 2 & controls$V2 == 171 & controls$V3 == 1))
}
read_sb <- function(name) read.csv(file.path(input, paste0(name, ".csv")),
                                  stringsAsFactors = FALSE)
reference <- read_sb("reference")
stopifnot(identical(reference, read_sb("all_off")))
runs <- setNames(lapply(names(groups), read_sb), labels)
x <- calculate_fishery_impact(reference, runs, seasons_per_year = 4)
x$sources$path <- file.path("inputs", paste0(c("reference", names(groups)), ".csv"))

# Figure 29's independently archived diagnostic trajectory is the external check.
figure29 <- read.csv(file.path(input, "figure29-diagnostic-depletion.csv"))
totals <- x$totals
totals$region <- ifelse(totals$region == "All regions", totals$region,
                        paste("Region", totals$region))
matched <- merge(totals, figure29, by = c("year", "region"))
stopifnot(nrow(matched) == 438L, nrow(x$groups) == 2628L,
          max(abs(matched$depletion - matched$value)) < 1e-12,
          x$checks$max_allocation_sum_error < 1e-10,
          all(x$checks$max_fitted_sb_error_by_group == 0))
terminal <- subset(x$totals, year == 2024)
stopifnot(nrow(terminal) == 6L, all(terminal$impact_percent > 70))

# Match the regional-depletion figure: RGB PNG, 300 dpi, white, serif text.
# Keep the established Figure 66 aspect ratio and three-column facet layout.
export <- do.call(build_fishery_impact_report, c(
  list(x = x, output_dir = out, width = 11.5, height = 7.5, dpi = 300),
  bet_fishery_impact_style()))
area <- ggplot2::ggplot_build(export$plot)$data[[1L]]
stopifnot(max(area$x) == 2024, !any(area$x > 2024),
          max(abs(tapply(area$ymax[area$x == 2024], area$PANEL[area$x == 2024], max) -
                    terminal$impact_percent)) < 1e-10)
if (check_only) {
  for (name in c("fishery-impact-totals.csv", "fishery-impact-groups.csv")) {
    stopifnot(isTRUE(all.equal(read.csv(file.path(out, name)),
                               read.csv(file.path(published, name)), tolerance = 1e-12)))
  }
  png_hash <- function(folder) digest::digest(file = file.path(folder, "fishery-impact.png"),
                                             algo = "sha256")
  if (!identical(png_hash(out), png_hash(published))) {
    stop("Rebuilt PNG differs. Rebuild using the digest-pinned report container.")
  }
  unlink(out, recursive = TRUE)
}
print(terminal[c("year", "region", "impact_percent")], row.names = FALSE)
cat(if (check_only) "Figure 66 calculation and PNG exactly reproduced.\n" else
      "Figure 66 recalculated from seasonal inputs and exported.\n")
