# Report Catalogs And Curation

The report has two layers:

- `figures.csv` and `tables.csv`: stable automatic report slots.
- `curation.yml`: the small human-editable overlay for final placement,
  headings, caption overrides, ordering, and exclusions.

Most of the time, edit `curation.yml` only. Keep the CSV catalogs for the
standard report structure.

Useful catalog columns:

- `section`: the report section heading.
- `title`: the subsection title printed above the asset.
- `file_candidates`: possible file names, separated by semicolons. The first
  matching file wins.
- `caption`: the default report caption. Placeholders such as `{species_label}`
  and `{assessment_year}` are filled from `report-config.yml`.
- `todo`: the message shown when the file is missing.

Useful `curation.yml` fields:

- `target_type`: `key` for a row in `figures.csv` or `tables.csv`, or `file`
  for a generated filename.
- `target`: the catalog key or generated filename/stem to match.
- `placement`: `main`, `appendix`, or `exclude`.
- `section` and `title`: optional report headings for promoted generated files.
- `caption_override`: optional caption that wins over generated metadata and
  the base catalog caption.
- `order`: optional number for ordering curated rows.

Generated mfclshiny outputs are expected under `Figures/generated` and
`tables/generated`. Extra generated files that are not listed in the catalog are
still included at the end of the relevant section, so exploratory Kflow runs are
easy to inspect before choosing the final report set.

Every report render writes:

- `curation/report-curation-review.html`: visual review page for figures and
  tables.
- `curation/figure-curation-template.csv`: complete figure target list.
- `curation/table-curation-template.csv`: complete table target list.
- `curation/curation-template.yml`: starter YAML generated from notable rows.

Open the HTML review page first. Copy the target you want from the templates
into `catalog/curation.yml`, then render the report again.
