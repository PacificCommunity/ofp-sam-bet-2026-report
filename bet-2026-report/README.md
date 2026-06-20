# BET 2026 Report Source

Use `assessment-report.qmd` as the main Quarto document for the BET 2026
assessment report. The folder contains the BET 2026 report configuration,
assessment narrative, catalogs, references, and helper code used to insert
workflow-generated figures and tables.

Edit these first as 2026 results become available:

- `report-config.yml`: species code, species label, assessment year, title,
  assessment area, model-region count, authors, meeting metadata, bibliography,
  CSL file, catalog paths, figure roots, table roots, and draft watermark.
- `sections/*.qmd`: assessment narrative. Keep final stock-status numbers out
  of reusable text until they are produced by the accepted 2026 model workflow.
- `catalog/figures.csv`: figure order, matching filenames, captions, and TODO
  text. Captions can use placeholders such as `{species_label}`,
  `{assessment_year}`, `{assessment_area}`, `{recent_period}`, and
  `{previous_assessment_year}`.
- `catalog/curation.yml`: small overlay for moving generated figures to the main
  report, appendix, or excluded set, and for overriding captions without
  rewriting the generated figure index.
- `catalog/tables.csv`: table order, matching CSV filenames, captions, and TODO
  text.
- `references.bib`: report references for the BET assessment.

Draft protection is on by default through `draft_watermark` and
`watermark_text` in `report-config.yml`. Keep it enabled until the report is
approved for wider release.

Main report components:

- `report-config.yml`: project metadata and draft-watermark settings.
- `catalog/figures.csv`: figure order, filenames, captions, TODO text.
- `catalog/curation.yml`: final figure/table placement and caption overrides.
- `catalog/tables.csv`: table order, filenames, captions, TODO text.
- `sections/`: human-written narrative.
- `R/config.R`: loads config values into render-time variables.
- `R/catalog.R`: reads and validates figure/table catalogs.
- `R/report_helpers.R`: renders TODO blocks, figures, captions, and tables.

To add figures:

1. Add the generated file to the pipeline figure bundle, or place a checked
   static file under `Figures/static/`.
2. Add a row to `catalog/figures.csv` when the figure should appear in a
   specific report location with a curated caption.
3. Put multiple semicolon-separated filenames in `file_candidates` when a report
   item has several panels or companion figures. Matching files are inserted in
   that order.
4. Leave it out of the catalog for a quick review figure; uncatalogued
   generated figures are rendered in the appendix so they are still visible
   during drafting without crowding the main figure catalog.

To curate generated figures and tables after an outputs run:

1. Open `outputs/curation/curation-board.html` from the curation job.
2. For small edits, use the curation repo `catalog/curation.yml` to set `placement` to `main`,
   `appendix`, or `exclude`, and use `caption_override` for final report wording.
3. Rerun curation. It writes `outputs/report/sections/Figures.qmd` and
   `outputs/report/sections/Tables.qmd`.
4. Rerender the report from the curation job. The curated QMD sections are copied
   into `sections/` and used directly.

To add tables, write the table as CSV under `tables/` or `Tables/` and add a
row to `catalog/tables.csv`.

Pipeline-generated outputs:

- The pipeline copies report-ready mfclshiny figures into the configured figure
  folder.
- The pipeline copies compact input registries and summaries into the configured
  input-summary folder.
- `sections/Figures.qmd` and `sections/Tables.qmd` read the catalogs and insert
  matching files automatically. Missing files render as TODO placeholders.

Configurable paths in `report-config.yml`:

- `figure_catalog` and `table_catalog`: CSV catalogs to read.
- `figure_roots`: semicolon-separated folders searched for curated figures.
- `extra_figure_roots`: folders searched for uncatalogued generated figures.
- `table_roots`: folders searched for CSV tables and pipeline summaries.

Avoid putting BET-specific text in `assessment-report.qmd` or
`report-body.qmd`; those files are intended to stay reusable. Use
`sections/`, `catalog/`, `tables/`, and `report-config.yml` for report edits.
