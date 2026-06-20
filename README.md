# BET 2026 Assessment Report

This repository contains the BET 2026 report source in `bet-2026-report/`.
The report is set up for automated insertion of
report-ready figures and tables from the BET 2026 assessment workflow,
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
into `generated/outputs/` and `Figures/generated/`. The report can also be
rendered directly if those files already exist.

`bet-2026-report/bet-2026.qmd` is kept only as a compatibility entrypoint for
older BET jobs. New renders should use
`bet-2026-report/assessment-report.qmd`.

## Output Sections

The outputs task creates the broad figure/table bundle and writes report-ready
QMD seeds:

- `generated/outputs/report-ready/figures.qmd`
- `generated/outputs/report-ready/tables.qmd`
- `generated/outputs/report-ready/report-map.html`

During a Kflow report render, `R/prepare_report_inputs.R` copies the outputs
bundle into `bet-2026-report/generated/outputs/`. If `sections/Figures.qmd` or
`sections/Tables.qmd` is missing, or still contains the initial
`kflow-section-seed` placeholder, it is seeded from the generated QMD. Once the
section has been seeded, edit the section directly to include, remove, reorder,
or rewrite captions. Later renders preserve existing section files.

By default the Kflow report job commits and pushes only the generated files
needed to render the report back to this repository:

- `bet-2026-report/generated/outputs/report-ready/figures.qmd`
- `bet-2026-report/generated/outputs/report-ready/tables.qmd`
- `bet-2026-report/generated/outputs/figures/`
- `bet-2026-report/generated/outputs/tables/`, only when referenced by QMD
- `bet-2026-report/pipeline-inputs/`
- `bet-2026-report/sections/Figures.qmd`
- `bet-2026-report/sections/Tables.qmd`

Large review HTML files and diagnostics are kept in Kflow artifacts, not in the
report repository. This keeps the report checkout standalone without committing
unneeded output clutter after each successful workflow run.
Set `KFLOW_REPORT_COMMIT_GENERATED=false` for local renders that should not
write a generated-input commit.

Open `outputs/generated/outputs/report-ready/report-map.html` from a report job,
or `outputs/report-ready/report-map.html` from an outputs job, to browse the
generated figure/table map before editing the QMD.

For file size, plot jobs create optimized PNGs for PDF output and WebP sidecars
for HTML output. The report automatically uses JPEG sidecars for PDF when they
are smaller, WebP sidecars for HTML when available, and the original optimized
PNG as the fallback.

Each Kflow render writes `outputs/provenance/report-provenance.csv`, including
the report job id, upstream output job ids, copied output bundle, Kflow lineage,
and report repo commit. This replaces the need for git submodules while keeping
the artifact chain reproducible.
