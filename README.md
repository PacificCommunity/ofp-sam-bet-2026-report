# BET 2026 assessment manuscript

[![Render Quarto PDF](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml/badge.svg?branch=main)](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml)

[Open WCPFC-SC22-2026-SA-WP-06 in the browser](https://pacificcommunity.github.io/ofp-sam-bet-2026-report/WCPFC-SC22-2026-SA-WP-06.pdf)

This repository is the editable, modular Quarto source for the 2026 bigeye tuna
assessment report. The source is deliberately self-contained: all chapter
files, figures, tables and bibliography needed to render the report are stored
here.

## Render locally

Install Quarto (version 1.7 or newer) and a LaTeX distribution with `pdflatex`,
then run from this directory:

```bash
quarto render main.qmd --to pdf
```

- ✅ Local render: Quarto and `pdflatex` are available.
- ✅ Docker fallback: use the pinned TunaFlow v2.7 image below if local
  compilation fails.

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$PWD:/work" \
  --workdir /work \
  --entrypoint /bin/bash \
  ghcr.io/pacificcommunity/tuna-flow-private:v2.7@sha256:4fee4c40cb6439ff920b1dd233a84bf19d5cc0e37278c99ceff3fd79cb9c8852 \
  -lc 'quarto render main.qmd --to pdf'
```

The rendered PDF and retained LaTeX are written to
`WCPFC-SC22-2026-SA-WP-06.pdf` and `main.tex`.

## Structure

- `main.qmd` assembles the report in publication order.
- `sections/` contains one editable Quarto file per narrative section.
- `tables/` contains report tables.
- `figures/` contains the referenced figure assets.
- `references/references.bib` contains the bibliography.
- `references/apa.csl` contains the report's reference style.
