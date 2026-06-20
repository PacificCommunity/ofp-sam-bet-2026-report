# BET 2026 Assessment Draft

This repository contains the automatic BET 2026 report draft in
`bet-2026-report/`. The draft is set up for automated insertion of
curated report-ready figures and tables from the BET 2026 assessment workflow,
while leaving interpretation, final values, and management advice clearly
marked for analyst review.

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

The outputs task creates the broad figure/table bundle. The curation task then
selects and orders the generated assets and writes draft-ready QMD sections.
This draft task consumes those curated sections. When curated QMD is present in
the Kflow input artifact, it is copied into `bet-2026-report/sections/` and
used in preference to the automatic catalogs.

Each render writes `outputs/curation/report-curation-review.html` and
`outputs/curation/figure-caption-draft.qmd`. Open the review page first. For
small edits, update `catalog/curation.yml` with `placement`, `section`, `title`,
or `caption_override`. For hands-on report editing, copy
`figure-caption-draft.qmd` to `bet-2026-report/sections/Figures_manual.qmd`,
edit the QMD captions or order directly, and set `manual_figures_qmd` in
`bet-2026-report/report-config.yml`. The next render will use that QMD Figures
section instead of the automatic figure catalog. See
`bet-2026-report/vignettes/report-curation.md` for the beginner workflow.

For file size, plot jobs create optimized PNGs for PDF output and WebP sidecars
for HTML output. The report automatically uses JPEG sidecars for PDF when they
are smaller, WebP sidecars for HTML when available, and the original optimized
PNG as the fallback.

Later, the final human-owned `ofp-sam-bet-2026-report` repository can be
created by copying this draft source. The curation contract is intentionally the
same, so `curation -> draft` can be changed to `curation -> report` when the
manual report replaces the draft.
