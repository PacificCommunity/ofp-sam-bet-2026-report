#!/usr/bin/env Rscript
# Replot the verified native-run calculation without rerunning MFCL.
# Requires mfclshiny commit 9d8eab27696b6f72dabb25dfe2fc68fc296294ee or later.
library(mfclshiny)
args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[[1L]]) else normalizePath(".")
out <- file.path(root, "figures_new", "fishery-impact")
x <- readRDS(file.path(out, "fishery-impact.rds"))
build_fishery_impact_report(x, out)
print(subset(x$totals, year == max(year), select = c(year, region, impact_percent)))
