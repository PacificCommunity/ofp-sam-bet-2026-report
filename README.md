# BET 2026 Assessment Report

This repository contains the working BET 2026 report draft in
`bet-2026-report/`. The draft is set up for automated insertion of
report-ready figures and tables from the BET 2026 assessment workflow, while
leaving interpretation, final values, and management advice clearly marked for
analyst review.

The BET draft keeps assessment-year results and management advice as TODO items
until they are generated from the accepted 2026 assessment model set. Draft sharing
protection is controlled by `draft_watermark` and `watermark_text` in
`bet-2026-report/report-config.yml`.

## Editing

Most BET-specific edits should be made in
`bet-2026-report/report-config.yml`, `bet-2026-report/sections/`, and the
figure/table catalogs. Keep `bet-2026-report/assessment-report.qmd` as the main
Quarto entrypoint unless a render job explicitly points somewhere else.

For another species or assessment year, start from the generic template repo
rather than copying this BET-specific draft.

## Rendering Inputs

When rendered from a model workflow, selected upstream registry and summary
files are copied into `pipeline-inputs/`, and report-ready figures are copied
into `Figures/generated/`. The report can also be rendered directly if those
files already exist.

`bet-2026-report/bet-2026.qmd` is kept only as a compatibility entrypoint for
older BET jobs. New renders should use
`bet-2026-report/assessment-report.qmd`.

## Report Curation

The plot task should create the broad figure/table bundle. The report task then
uses `bet-2026-report/catalog/curation.yml` to decide which generated assets go
in the main report, appendix, or excluded set.

Each render writes `outputs/curation/report-curation-review.html` and
`outputs/curation/figure-caption-draft.qmd`. Open the review page first. Use
`catalog/curation.yml` for small placement/caption overrides, or use the QMD
draft when the Figures section needs full manual caption and ordering control.
See `bet-2026-report/vignettes/report-curation.md` for the beginner workflow.

For file size, plot jobs create optimized PNGs for PDF output and WebP sidecars
for HTML output. The report automatically uses JPEG sidecars for PDF when they
are smaller, WebP sidecars for HTML when available, and the original optimized
PNG as the fallback.
