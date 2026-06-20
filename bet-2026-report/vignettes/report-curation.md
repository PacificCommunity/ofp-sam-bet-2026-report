# Curating BET 2026 Report Figures And Tables

This report is designed so the computer does the bulk insertion work, then a
human makes the final editorial choices.

## Mental Model

The BET workflow has two separate jobs:

1. The plot task creates as many report-ready figures and tables as it can.
2. The report task decides where those files appear in the draft.

That means you usually do not need to rerun the plot task just to move a figure,
move a table, exclude something, or improve a caption. Edit the report curation
files, then rerun the report task.

## Recommended Workflow

1. Open the review page from the report output:

```text
outputs/curation/report-curation-review.html
```

2. Decide which figures belong in the main report, appendix, or excluded set.
3. Choose one editing style:

- For small changes, edit `catalog/curation.yml`.
- For full manual caption and ordering control, edit a QMD figure draft.

4. Rerun only the report task. The plot task does not need to run again unless
   the figure files themselves changed.

## Small Edits: Curation YAML

Use `catalog/curation.yml` when you only need to move, exclude, retitle, or
override the caption for selected items:

```yaml
catalog/curation.yml
```

The file has two sections:

```yaml
figures:
  - target_type: key
    target: spawning-biomass
    placement: main
    caption_override: "Spawning biomass trajectory for the diagnostic model set."

tables:
  - target_type: file
    target: model-summary.csv
    placement: appendix
```

Use `placement` to choose where an item goes:

- `main`: put it in the main report.
- `appendix`: move it to the supplemental appendix.
- `exclude`: leave it out of the report.

Use `target_type` to choose how the item is matched:

- `key`: match a row in `catalog/figures.csv` or `catalog/tables.csv`.
- `file`: match a generated filename, such as `foo.png` or `bar.csv`.

Optional fields:

- `section`: section heading for promoted generated assets.
- `title`: subsection title printed above the asset.
- `caption_override`: final human-written caption.
- `order`: numeric order within curated rows.
- `notes`: reviewer notes; these do not print in the report.

## Full Caption Edits: QMD Sections

Every report render also writes:

```text
outputs/curation/figure-caption-draft.qmd
```

This file is a plain Quarto section containing the generated figure blocks and the
current captions. It is useful when you want to read the selected figures in
report order and edit the caption text directly.

To use it:

1. Copy `outputs/curation/figure-caption-draft.qmd` to:

```yaml
bet-2026-report/sections/Figures_manual.qmd
```

2. Edit the headings, order, and caption text in `Figures_manual.qmd`.
3. Set this in `bet-2026-report/report-config.yml`:

```yaml
manual_figures_qmd: "sections/Figures_manual.qmd"
```

4. Rerun the report task.

When `manual_figures_qmd` is blank, the report uses automatic catalog insertion.
When it points to a non-empty QMD file, that QMD is used for the Figures section
instead. This lets a human fully control report wording without changing R code.

## Review Aids

The curation output folder also contains:

```text
outputs/curation/figure-curation-template.csv
outputs/curation/table-curation-template.csv
outputs/curation/curation-template.yml
```

These are review aids. Do not treat them as the final source of truth unless you
copy their contents into `catalog/curation.yml` or the manual QMD file.
