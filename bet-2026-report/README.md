# BET 2026 Report Source

Use `assessment-report.qmd` as the main Quarto document for the BET 2026
assessment report. The folder contains the report configuration, assessment
narrative, references, generated-output staging area, and helper code.

Edit these first as 2026 results become available:

- `sections/*.qmd`: assessment narrative and the generated figure/table sections.
- `report-config.yml`: species/year metadata, authors, meeting metadata,
  bibliography, and draft-watermark settings.
- `references.bib`: report references for the BET assessment.

The workflow-generated output bundle is copied into:

```text
generated/outputs/
```

In Kflow, the report job also commits and pushes the generated QMD plus the
figure/table files referenced by that QMD back to this repository, together with
`pipeline-inputs/` and the seeded `sections/Figures.qmd` and
`sections/Tables.qmd` when they change. Review HTML and diagnostics stay in
Kflow artifacts. That means a fresh checkout can be rendered locally without
needing Kflow artifacts.

The files that usually need human editing are:

```text
sections/Figures.qmd
sections/Tables.qmd
```

If either section is missing, or still contains the initial
`kflow-section-seed` placeholder, the next report render seeds it from:

```text
generated/outputs/report-ready/figures.qmd
generated/outputs/report-ready/tables.qmd
```

After a section has been seeded, edit it directly to remove blocks, reorder
figures or tables, move appendix material, or rewrite captions. Later renders
preserve existing section files.

Open the generated map when deciding what to edit:

```text
generated/outputs/report-ready/report-map.html
```

Draft protection is on by default through `draft_watermark` and
`watermark_text` in `report-config.yml`. Keep it enabled until the report is
approved for wider release.

Avoid putting BET-specific text in `assessment-report.qmd` or
`report-body.qmd`; those files are intended to stay reusable. Use `sections/`,
`report-config.yml`, and `references.bib` for report edits.
