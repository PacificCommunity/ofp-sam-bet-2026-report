# BET 2026 Report Source

<p align="right">
  <a href="../kflow.yaml"><img src="../kflow-ready.svg" alt="Kflow ready task"></a>
</p>

![Report status: NOT FINAL draft scaffold](https://img.shields.io/badge/report%20status-NOT%20FINAL%20draft%20scaffold-d97706)

> [!WARNING]
> **Draft scaffold, not the final 2026 assessment report.**
> Treat generated figures, captions, tables, and result text as review material
> until the assessment is finalized.

This folder is the Quarto report source. Use `assessment-report.qmd` as the main
entrypoint.

## Edit First

- `sections/*.qmd`: report text, figure/table placement, captions, and appendix
  material.
- `report-config.yml`: species/year metadata, authors, meeting details,
  bibliography settings, and draft watermark.
- `catalog/curation.yml`: small overrides for generated figures and tables.
- `references.bib`: citations.

Avoid putting BET-specific narrative in `assessment-report.qmd` or
`report-body.qmd`; keep those files reusable.

## Generated Inputs

Kflow copies results artifacts into:

```text
generated/outputs/
pipeline-inputs/
```

The key review map is:

```text
generated/outputs/report-ready/report-map.html
```

If `sections/Figures.qmd` or `sections/Tables.qmd` is missing, or still contains
the initial `kflow-section-seed` placeholder, the next report run seeds it from:

```text
generated/outputs/report-ready/figures.qmd
generated/outputs/report-ready/tables.qmd
```

After that, edit the section files directly. Later Kflow runs preserve existing
manual sections.

## Render

```bash
quarto render assessment-report.qmd --to pdf
```

Keep the draft watermark enabled in `report-config.yml` until the report is
approved for wider release.

## References

This folder uses:

```text
references.bib
```

The cleanest workflow is to keep a Zotero collection for the report and export
it to this file. Prefer Better BibTeX / Better BibLaTeX automatic export when
available because it keeps citation keys stable. For a manual export from
Zotero, run this from the repository root:

```bash
bash scripts/import-zotero-bib.sh /path/to/exported.bib
```
