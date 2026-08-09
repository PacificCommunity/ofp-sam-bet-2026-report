# BET 2026 assessment manuscript

[![Render Quarto PDF](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml/badge.svg?branch=rev1)](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml)

[Open WCPFC-SC22-2026-SA-WP-06 in the browser](https://pacificcommunity.github.io/ofp-sam-bet-2026-report/WCPFC-SC22-2026-SA-WP-06.pdf)

This repository is the editable, modular Quarto source for the 2026 bigeye tuna
assessment report. The source is deliberately self-contained: all chapter
files, figures, tables and bibliography needed to render the report are stored
here.

## Clone and build

The checked-in figures make the report self-contained: cloning this repository
is sufficient to build the current report without cloning the source-analysis
repositories.

```bash
git clone --branch rev1 \
  https://github.com/PacificCommunity/ofp-sam-bet-2026-report.git
cd ofp-sam-bet-2026-report
git fetch --no-tags origin draft:refs/remotes/origin/draft
```

### RStudio or local command line

Install Quarto 1.7 or newer, R, a LaTeX distribution containing `pdflatex`,
`latexdiff`, Ghostscript and `pdfinfo` (Poppler). From the repository root,
the same preflight and build sequence used by GitHub Actions is:

```bash
Rscript scripts/audit-cross-references.R .
Rscript scripts/audit-assessment-values.R .
quarto render main.qmd --to pdf
bash scripts/build-draft-diff.sh origin/draft
```

In RStudio, open `main.qmd` and click **Render** (or press
`Ctrl+Shift+K`) to build the clean publication PDF. The RStudio Render button
does not build the tracked-change copy; run the final `build-draft-diff.sh`
command in the RStudio Terminal when that copy is also required.

### Docker

The pinned TunaFlow image reproduces the GitHub Actions environment. Access to
the SPC GitHub Container Registry image is required.

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$PWD:/work" \
  --workdir /work \
  --entrypoint /bin/bash \
  ghcr.io/pacificcommunity/tuna-flow-private:v2.7@sha256:4fee4c40cb6439ff920b1dd233a84bf19d5cc0e37278c99ceff3fd79cb9c8852 \
  -lc 'Rscript scripts/audit-cross-references.R . && \
       Rscript scripts/audit-assessment-values.R . && \
       quarto render main.qmd --to pdf && \
       bash scripts/build-draft-diff.sh origin/draft'
```

Both methods create the clean
`WCPFC-SC22-2026-SA-WP-06.pdf`, the review
`WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf`, and their retained LaTeX sources
`main.tex` and `main-diff.tex`.

## Structure

- `main.qmd` assembles the report in publication order.
- `sections/` contains one editable Quarto file per narrative section.
- `tables/` contains report tables.
- `figures/` retains the original report figure assets.
- `figures_new/` contains Rev.01 replacement and additional figures, with
  provenance recorded in `figures_new/README.md`.
- `sources/` retains the source document for the no-tagging and
  alternative-movement appendix.
- `references/references.bib` contains the bibliography.
- `references/apa.csl` contains the report's reference style.

## Review changes from `draft`

[Download the Rev.01 tracked-change PDF directly](https://raw.githubusercontent.com/PacificCommunity/ofp-sam-bet-2026-report/rev1/WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf).
This direct link bypasses GitHub's large-PDF preview. The same file is also
available in the latest **WCPFC-SC22-2026-SA-WP-06** workflow artifact.

`WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf` is the tracked-change version of
Rev.01 relative to `origin/draft` at commit `abd2ec7c472d380ebeddf4bebf615fc8d56a649e`.
Added text is blue and underlined, deleted text is red and struck through, and
changed figures are outlined. Its editable LaTeX source is `main-diff.tex`.
The publication PDF remains `WCPFC-SC22-2026-SA-WP-06.pdf` without change
markup. A concise change inventory is in `REVISION_CHANGES.md`.

Tagged GitHub releases publish both the clean and tracked-change PDFs, their
LaTeX sources, a self-contained Quarto source archive and `SHA256SUMS`.

## Upstream figure synchronization

The report remains self-contained because every publication figure is checked
in. Revision figures are synchronized from the source reports that own them:
Diagnostic, stepwise development, uncertainty ensemble, jitter, self-test,
retrospective analysis and one-off sensitivities. For local sibling clones,
run:

```bash
bash scripts/sync-diagnostic-figures.sh \
  ../ofp-sam-bet-2026-diagnostic/diagnostic-report-output \
  "$(git -C ../ofp-sam-bet-2026-diagnostic rev-parse HEAD)"

bash scripts/sync-stepwise-figures.sh \
  ../ofp-sam-bet-2026-stepwise/results/stepwise-report \
  "$(git -C ../ofp-sam-bet-2026-stepwise rev-parse HEAD)"

bash scripts/sync-ensemble-figures.sh \
  ../ofp-sam-bet-2026-ensemble/results \
  "$(git -C ../ofp-sam-bet-2026-ensemble rev-parse HEAD)"

JITTER_PAGES_ROOT=../ofp-sam-bet-2026-jitter \
SELFTEST_PAGES_ROOT=../ofp-sam-bet-2026-selftest \
RETROSPECTIVE_PAGES_ROOT=../ofp-sam-bet-2026-retrospective \
SENSITIVITY_PAGES_ROOT=../ofp-sam-bet-2026-sensitivity \
JITTER_SOURCE_SHA="$(git -C ../ofp-sam-bet-2026-jitter rev-parse HEAD)" \
SELFTEST_SOURCE_SHA="$(git -C ../ofp-sam-bet-2026-selftest rev-parse HEAD)" \
RETROSPECTIVE_SOURCE_SHA="$(git -C ../ofp-sam-bet-2026-retrospective rev-parse HEAD)" \
SENSITIVITY_SOURCE_SHA="$(git -C ../ofp-sam-bet-2026-sensitivity rev-parse HEAD)" \
bash scripts/sync-analysis-figures.sh
```

Each source repository's Pages workflow may send its corresponding
`*-report-updated` repository dispatch after deployment. The Rev.01 workflow
then synchronizes all published assets, records source commits and checksums,
and rebuilds both PDFs. A six-hour scheduled check provides a token-free
fallback. The no-tagging and alternative-movement appendix and its figures are
retained from the original Word document.
