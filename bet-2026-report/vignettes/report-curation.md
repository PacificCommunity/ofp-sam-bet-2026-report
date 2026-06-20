# Editing Generated Figures And Tables

The current BET workflow does not use a separate curation task. The outputs task
creates the figure/table bundle and the report task copies it into the report.

## What The Outputs Job Provides

After `ofp-sam-bet-2026-outputs` runs, open:

```text
outputs/report-ready/report-map.html
```

That read-only map shows every generated figure and table, the default section
placement, the item id, and the marker to search for in QMD.

The same outputs job also writes:

```text
outputs/report-ready/figures.qmd
outputs/report-ready/tables.qmd
```

These are generated seeds, not the final hand-edited report source.

## What The Report Job Does

When `ofp-sam-bet-2026-report` runs, it copies the outputs bundle into:

```text
bet-2026-report/generated/outputs/
```

Then it checks:

```text
bet-2026-report/sections/Figures.qmd
bet-2026-report/sections/Tables.qmd
```

If a section file is missing, or still has the initial `kflow-section-seed`
placeholder, the report job seeds it from the generated QMD. If the section file
already exists without that placeholder, the report job preserves it.

The Kflow report job then commits and pushes the generated report inputs back to
the report repository. The commit includes the generated figure/table QMD, the
figure/table files referenced by that QMD, `pipeline-inputs/`, and the generated
figure/table section files when they changed. Review HTML and diagnostic files
stay in the Kflow artifacts. This is what makes the report repository usable
later as a standalone Quarto project without filling Git history with files that
are not used by the report.

## Normal Editing Workflow

1. Run outputs.
2. Open `outputs/report-ready/report-map.html`.
3. Run report once to seed `sections/Figures.qmd` and `sections/Tables.qmd`.
4. Edit those two section files directly.
5. Commit the edited report repo.
6. Rerun report. The edited sections are kept, while the generated staging area
   is refreshed and committed by the report job.

To remove a figure or table, delete its block in the section QMD. To change
order, move the block. To change wording, edit the caption inside the image
markdown or the table chunk caption.

If you want to regenerate a clean section from outputs, delete the section file
and rerun the report job.

## Reproducibility

The report job writes:

```text
outputs/provenance/report-provenance.csv
```

That file records the report job id, upstream outputs job id, copied output
bundle, Kflow lineage, and report repository commit.
