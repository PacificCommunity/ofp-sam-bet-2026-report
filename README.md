# BET 2026 assessment manuscript

[![Render Quarto PDF](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml/badge.svg?branch=rev2)](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/render-quarto.yml)

[Open WCPFC-SC22-2026-SA-WP-06 in the browser](https://pacificcommunity.github.io/ofp-sam-bet-2026-report/WCPFC-SC22-2026-SA-WP-06.pdf)

This repository is the editable, modular Quarto source for the 2026 bigeye tuna
assessment report. The source is deliberately self-contained: all chapter
files, figures, tables and bibliography needed to render the report are stored
here.

**Revision 2, issued 1 October 2026:** Corrected and replaced the regional and overall fishery-impact plots (Figure 66).

[Download Rev.02 directly](https://raw.githubusercontent.com/PacificCommunity/ofp-sam-bet-2026-report/rev2/WCPFC-SC22-2026-SA-WP-06.pdf).

## Clone and build

The checked-in figures make the report self-contained: cloning this repository
is sufficient to build the current report without cloning the source-analysis
repositories.

```bash
git clone --branch rev2 \
  https://github.com/PacificCommunity/ofp-sam-bet-2026-report.git
cd ofp-sam-bet-2026-report
```

### RStudio or local command line

Use the pinned Docker environment below for a publication-identical build.
Other Quarto/Pandoc versions can change citation formatting and the table of
contents. PDF verification also requires Python and `PyMuPDF==1.28.2`.
From the repository root, the preflight and build sequence is:

```bash
Rscript scripts/audit-cross-references.R .
Rscript scripts/audit-assessment-values.R .
quarto render main.qmd --to pdf
python3 scripts/finalize-rev2-cover.py
python3 scripts/verify-rev2.py
```

In RStudio, open `main.qmd` and click **Render** (or press
`Ctrl+Shift+K`) to build the publication PDF, then run the finalization and
verification commands. Finalization retains the official cover at its exact
original size instead of LaTeX's slightly scaled PDF-page embedding.
The official Rev.01 is archived in `sources/`; the verifier checks its SHA-256
before comparison. It can download the official file if the archive is absent.

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
       quarto render main.qmd --to pdf'
```

The build creates `WCPFC-SC22-2026-SA-WP-06.pdf` and its retained LaTeX source
`main.tex`. Run `python3 scripts/finalize-rev2-cover.py` and then
`python3 scripts/verify-rev2.py` afterwards. The older
`WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf` and `main-diff.tex` remain the
archived Rev.01 comparison against the draft; they are not a Rev.02 comparison.

## Structure

- `main.qmd` assembles the report in publication order.
- `sections/` contains one editable Quarto file per narrative section.
- `tables/` contains report tables.
- `figures/` retains the original report figure assets.
- `figures_new/` contains revision replacement and additional figures, with
  provenance recorded in `figures_new/README.md`.
- `sources/` retains the source document for the no-tagging and
  alternative-movement appendix, the official WCPFC Rev.01 PDF, and the
  updated WCPFC cover used in Rev.02.
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

The Rev.02 workflow validates and publishes the clean PDF without making
automatic commits. Figure 66 data and reproduction instructions are in
`figures_new/fishery-impact/README.md`; the reusable functions are in
[`PacificCommunity/mfclshiny`](https://github.com/PacificCommunity/mfclshiny/commit/9d8eab27696b6f72dabb25dfe2fc68fc296294ee).

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

These synchronization commands are retained for future assessment revisions.
Rev.02 freezes the published Rev.01 assets except for Figure 66 and does not
automatically synchronize newer upstream figures. The no-tagging and
alternative-movement appendix and its figures are retained from the original
Word document.
