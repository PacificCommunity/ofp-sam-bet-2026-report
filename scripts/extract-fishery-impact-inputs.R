#!/usr/bin/env Rscript
# Optional provenance step for custodians of the original native MFCL outputs.
# Rscript scripts/extract-fishery-impact-inputs.R <report-root> <impact-audit-dir>
# Uses the original FLR4MFCL 1.7.2 reader; ordinary reproduction uses the CSVs.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L, packageVersion("FLR4MFCL") == "1.7.2")
root <- normalizePath(args[[1L]])
native <- normalizePath(args[[2L]])
input <- file.path(root, "figures_new/fishery-impact/inputs")
source(file.path(root, "scripts/vendor/mfclshiny/fishery-impact.R"))
provenance <- jsonlite::read_json(file.path(input, "provenance.json"))
for (name in names(provenance$native_report_sha256)) {
  path <- if (name == "reference") file.path(native, "diagnostic-plot.rep") else
    file.path(native, "native_runs", name, "plot-evaluated.par.rep")
  stopifnot(digest::digest(file = path, algo = "sha256") == provenance$native_report_sha256[[name]])
  frame <- mfclshiny_impact_frame(FLR4MFCL::read.MFCLRep(path), name)
  write.csv(frame, file.path(input, paste0(name, ".csv")), row.names = FALSE)
}
figure29_path <- file.path(native, "ofp-sam-bet-2026-jitter", provenance$figure29_source$path)
stopifnot(digest::digest(file = figure29_path, algo = "sha256") == provenance$figure29_source$sha256)
figure29 <- readRDS(figure29_path)
figure29 <- subset(figure29, is_reference & quantity == "Regional depletion",
                    select = c(year, region, value))
stopifnot(nrow(figure29) == 438L)
write.csv(figure29, file.path(input, "figure29-diagnostic-depletion.csv"), row.names = FALSE)
