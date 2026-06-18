# BET 2026 Assessment Report

This repository contains the working BET 2026 report draft in
`bet-2026-report/`. It is based on the generic tuna assessment report template
at <https://github.com/PacificCommunity/ofp-sam-tuna-report> and seeded with
reusable background, methods, and references from the 2023 BET assessment
writeup.

The BET draft keeps assessment-year results and management advice as TODO items
until they are regenerated from the accepted 2026 model outputs. Draft sharing
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

## Kflow Task

`run.sh` prepares upstream plot outputs for the report, renders
`assessment-report.qmd` to HTML/PDF, and writes organized deliverables under
`outputs/`:

- `outputs/final-report/bet-2026-report.pdf`
- `outputs/final-report/bet-2026-report.html`
- `outputs/figures/<figure-id>/`: one folder per report figure, with the
  figure file plus `caption.txt` and `metadata.csv` when available.
- `outputs/tables/<table-id>/`: one folder per generated/report table.
- `outputs/indices/`: figure/table indices and `report-output-index.csv`.

The report render still uses the normal Quarto folders inside
`bet-2026-report/`; the organized `outputs/` layout is for Kflow browsing and
downloads.
