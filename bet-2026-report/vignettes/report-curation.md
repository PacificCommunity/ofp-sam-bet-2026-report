# Curating BET 2026 Report Figures And Tables

This report is designed so the computer does the bulk insertion work, then a
human makes the final editorial choices.

## Mental Model

The BET workflow has two separate jobs:

1. The plot task creates as many report-ready figures and tables as it can.
2. The report task decides where those files appear in the draft.

That means you usually do not need to rerun the plot task just to move a figure,
move a table, exclude something, or improve a caption. Edit
`catalog/curation.yml`, then rerun the report task.

## The Main File To Edit

Use:

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

## Review Page

Every report render writes:

```text
outputs/curation/report-curation-review.html
```

Open that page first. It shows figures, tables, current placement, current
caption, and the target value to copy into `catalog/curation.yml`.

The same folder also contains:

```text
outputs/curation/figure-curation-template.csv
outputs/curation/table-curation-template.csv
outputs/curation/curation-template.yml
```

These are review aids. Do not treat them as the source of truth; the source of
truth is `catalog/curation.yml`.

## File Size Optimization

The plot task writes optimized report assets:

- PDF renders use optimized PNGs, or JPEG sidecars when they are smaller.
- HTML renders use WebP sidecars when they are available.
- Original generated filenames still appear in the catalog and review page so
  curation remains simple.

If the report is still too large, make the plot task more aggressive before
rerunning plot and report:

```yaml
PLOT_PNGQUANT_QUALITY: "55-82"
PLOT_JPEG_QUALITY: "78"
PLOT_WEBP_QUALITY: "68"
```

Lower numbers make smaller files with more visible loss. The defaults are set
for a light but still report-quality draft.
