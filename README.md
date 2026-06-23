# BET 2026 Assessment Report

<p align="right">
  <a href="kflow.yaml"><img src="kflow-ready.svg" alt="Kflow ready task"></a>
</p>

![Report status: NOT FINAL draft scaffold](https://img.shields.io/badge/report%20status-NOT%20FINAL%20draft%20scaffold-d97706)
![Generated inputs: placeholders](https://img.shields.io/badge/generated%20inputs-placeholder%20figures%20%26%20captions-64748b)

> [!WARNING]
> **Draft scaffold, not the final 2026 assessment report.**
> Figures, tables, captions, and narrative text still need analyst review before
> this can be treated as the final BET 2026 assessment report.

This repository contains the Quarto source for the BET 2026 report. It is
designed to work in Kflow, but the report folder can also be rendered locally
after generated inputs have been committed.

## Workflow

The active Kflow chain is:

```text
ofp-sam-bet-2026-stepwise -> ofp-sam-bet-2026-results -> ofp-sam-bet-2026-report
```

The report task:

- reads the latest results artifact, or the job selected by `RESULTS_JOB_ID`;
- copies generated figures, tables, and QMD seeds into
  `bet-2026-report/generated/outputs/`;
- carries the Shiny curation files `report-selection.json` and
  `analysis-manifest.json` forward when they are present;
- seeds `sections/Figures.qmd` and `sections/Tables.qmd` only when those files
  are missing or still contain the initial placeholder;
- records Kflow lineage in `outputs/provenance/`;
- commits the report-ready generated inputs back to this repo when publishing is
  enabled.

## Edit Here

Most manual report work should happen in:

- `bet-2026-report/sections/*.qmd` for narrative, figure order, table order, and
  caption edits;
- `bet-2026-report/report-config.yml` for species, year, authors, meeting
  details, and draft-watermark settings;
- `bet-2026-report/catalog/curation.yml` for small placement overrides when a
  generated figure or table should be included, excluded, moved, or renamed;
- `bet-2026-report/references.bib` for citations.

Keep `bet-2026-report/assessment-report.qmd` as the main entrypoint unless a
job explicitly uses another file.

## Generated Inputs

Useful generated files are kept in:

```text
bet-2026-report/generated/outputs/report-ready/figures.qmd
bet-2026-report/generated/outputs/report-ready/tables.qmd
bet-2026-report/generated/outputs/report-ready/report-map.html
bet-2026-report/generated/outputs/figures/
bet-2026-report/generated/outputs/tables/
bet-2026-report/pipeline-inputs/
```

Open `report-map.html` first when deciding which generated figures or tables to
keep. Generated `sections/Figures.qmd` and `sections/Tables.qmd` are reseeded
from the latest results by default so stale fishery labels cannot point at
missing files. Set `KFLOW_REPORT_RESEED_GENERATED_SECTIONS=false` only when
deliberately preserving manually curated figure/table sections across runs.

When a results job was curated in MFCL Shiny, the generated QMD files already
reflect the saved selection: included or excluded items, main or appendix
placement, captured model/overlay controls, and caption overrides. The report
author can still edit the seeded QMD by hand before final rendering.

Large review HTML and diagnostics stay in Kflow artifacts. This repo keeps only
the files needed to render the report as a standalone checkout.

## Run

Kflow uses:

```bash
bash run.sh
```

After generated inputs exist, the report can also be rendered from the report
folder:

```bash
cd bet-2026-report
quarto render assessment-report.qmd --to pdf
```

## Common Kflow Config

| Field | Typical value | Purpose |
| --- | --- | --- |
| `RESULTS_JOB_ID` | `256` | Use one specific results artifact. |
| `RESULTS_JOB_IDS` | `256,260` | Combine multiple results artifacts. |
| `REPORT_QMD` | `assessment-report.qmd` | Quarto entrypoint inside `bet-2026-report/`. |
| `REPORT_FILE_STEM` | `bet-2026-report` | Output filename stem. |
| `REPORT_RENDER_HTML` | `false` | Also render the final HTML report. PDF-only is the default to save space. |
| `KFLOW_REPORT_COMMIT_GENERATED` | `true` | Commit generated report inputs after a successful run. |
| `KFLOW_REPORT_PUSH_GENERATED` | `true` | Push that generated-input commit. |
