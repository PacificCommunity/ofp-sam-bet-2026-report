# BET 2026 assessment manuscript

This directory is the editable, modular Quarto source for the 2026 bigeye tuna
assessment report. The source is deliberately self-contained: all chapter
files, figures, tables and bibliography needed to render the report live below
this directory.

## Render locally

Install Quarto (version 1.7 or newer) and a LaTeX distribution with `pdflatex`,
then run from this directory:

```bash
quarto render index.qmd --to pdf
```

The rendered PDF is written to `_render/WCPFC-SC22-2026-SA-WP-06.pdf`; the
retained intermediate LaTeX is written to `index.tex` beside `index.qmd`. The
Quarto files are the canonical editable manuscript. Release source bundles can
also include the generated `.tex` file for inspection or a direct LaTeX build.

## Structure

- `index.qmd` assembles the report in publication order.
- `sections/` contains one editable Quarto file per narrative section.
- `tables/` contains report tables.
- `figures/` contains the referenced figure assets.
- `references/references.bib` contains the bibliography.
