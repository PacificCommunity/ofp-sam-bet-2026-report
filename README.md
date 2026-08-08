# BET 2026 assessment manuscript

[![Render Quarto PDF](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml/badge.svg?branch=rev1)](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml)

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
- `figures/` retains the original report figure assets.
- `figures_new/` contains Rev.01 replacement and additional figures, with
  provenance recorded in `figures_new/README.md`.
- `sources/` retains the supplied source document for the no-tagging and
  alternative-movement appendix.
- `references/references.bib` contains the bibliography.
- `references/apa.csl` contains the report's reference style.

## Review changes from `draft`

`WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf` is the tracked-change version of
Rev.01 relative to `origin/draft` at commit `abd2ec7c472d380ebeddf4bebf615fc8d56a649e`.
Added text is blue and underlined, deleted text is red and struck through, and
changed figures are outlined. Its editable LaTeX source is `main-diff.tex`.
The publication PDF remains `WCPFC-SC22-2026-SA-WP-06.pdf` without change
markup. A concise change inventory is in `REVISION_CHANGES.md`.

## Upstream figure synchronization

The report remains self-contained because every publication figure is checked
in. To refresh figures owned by the diagnostic repository from a local build,
run:

```bash
bash scripts/sync-diagnostic-figures.sh \
  ../ofp-sam-bet-2026-diagnostic/diagnostic-report-output \
  "$(git -C ../ofp-sam-bet-2026-diagnostic rev-parse HEAD)"
```

The diagnostic repository's Pages workflow can also send a
`diagnostic-report-updated` repository dispatch after deployment. Configure its
`REPORT_REPO_DISPATCH_TOKEN` secret with permission to dispatch workflows in
this repository; the Rev.01 workflow then synchronizes the published assets,
commits changed diagnostic assets and rebuilds both PDFs. A six-hour scheduled
check provides a token-free fallback and only commits when the pinned source
commit or synchronized files change. The no-tagging and alternative-movement
appendix and its figures are retained from the supplied Word note.
