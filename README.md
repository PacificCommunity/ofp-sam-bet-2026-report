# BET 2026 Assessment Report

![Report status: draft scaffold](https://img.shields.io/badge/report%20status-draft%20scaffold-f59e0b)
![Generated inputs: placeholders](https://img.shields.io/badge/generated%20inputs-placeholder%20figures%20%26%20captions-64748b)

> **Current status:** this repository is a draft report scaffold, not the final
> 2026 assessment report. Many figures, tables, captions, and narrative blocks
> are generated placeholders or review seeds from the current workflow. Treat
> them as material to check, edit, replace, or remove before release. When the
> assessment is finalized, update this badge and note to mark the repository as
> the final report source.

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

The results task creates the broad figure/table bundle and writes report-ready
QMD seeds:

- `generated/outputs/report-ready/figures.qmd`
- `generated/outputs/report-ready/tables.qmd`
- `generated/outputs/report-ready/report-map.html`

During a Kflow report render, `R/prepare_report_inputs.R` copies the results
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
or `outputs/report-ready/report-map.html` from a results job, to browse the
generated figure/table map before editing the QMD.

For file size, results jobs create optimized PNGs for PDF output and WebP sidecars
for HTML output. The report automatically uses JPEG sidecars for PDF when they
are smaller, WebP sidecars for HTML when available, and the original optimized
PNG as the fallback.

Each Kflow render writes `outputs/provenance/report-provenance.csv`, including
the report job, upstream results jobs, and full Kflow lineage as task-aware job
refs such as `ofp-sam-bet-2026-stepwise Job 247 (...)`. It also records the
copied results bundle and report repo commit. This replaces the need for git
submodules while keeping the artifact chain reproducible.

## Common Job Config

These fields are the useful ones to change from Kflow:

| Field | Example | Meaning |
| --- | --- | --- |
| `RESULTS_JOB_ID` | `245` | Use one specific results job artifact. |
| `RESULTS_JOB_IDS` | `245,250` | Use multiple results jobs when combining model sets. |
| `REPORT_QMD` | `assessment-report.qmd` | Quarto entrypoint inside `bet-2026-report/`. |
| `REPORT_FILE_STEM` | `bet-2026-report` | Report output filename stem. |
| `REPORT_RENDER_HTML` | `false` | Also render/copy the final HTML report. The default keeps Kflow report artifacts PDF-only to save space. |
| `FLOW_GROUP` | `bet-2026-base` | Short label shared by the chain in Kflow. |
| `JOB_TITLE` | `BET report` | Human title shown in Kflow. |
| `FLOW_SPECIES` | `BET` | Species code written into `report-config.yml`. |
| `FLOW_SPECIES_LABEL` | `bigeye tuna` | Species label written into `report-config.yml`. |
| `FLOW_ASSESSMENT_YEAR` | `2026` | Assessment year written into `report-config.yml`. |
| `KFLOW_REPORT_COMMIT_GENERATED` | `true` | Commit generated QMD/assets back to this repo. |
| `KFLOW_REPORT_PUSH_GENERATED` | `true` | Push that generated-input commit after a successful render. |
