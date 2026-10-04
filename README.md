[![Preservation checks](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/verify-preserved-results.yml/badge.svg?branch=rev2)](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/actions/workflows/verify-preserved-results.yml?query=branch%3Arev2)

# BET 2026 assessment manuscript

<a id="clone-and-build"></a>
<a id="rstudio-or-local-command-line"></a>
<a id="docker"></a>
<a id="structure"></a>
<a id="review-changes-from-draft"></a>
<a id="upstream-figure-synchronization"></a>

[Read the assessment](https://pacificcommunity.github.io/ofp-sam-bet-2026-report/WCPFC-SC22-2026-SA-WP-06.pdf)
· [Download Rev.02](https://raw.githubusercontent.com/PacificCommunity/ofp-sam-bet-2026-report/rev2/WCPFC-SC22-2026-SA-WP-06.pdf).

This repository contains the self-contained Quarto source, figures, tables and
references for WCPFC-SC22-2026-SA-WP-06. Revision 2, issued 1 October 2026,
corrects the regional and overall fishery-impact plots in Figure 66.
The default branch is `rev2`.

From a clone of `rev2`, run the checks and build:

```sh
make help
make verify
make rerun CASE=all OUT=/tmp/bet-figure66
make build OUT=/tmp/bet-report-build
```

`make rerun` reproduces the eight original Figure 66 REP reports on Linux
x86-64. `make build` works in a new directory outside the checkout.
Use the pinned runtime and PyMuPDF 1.28.2 in
[build instructions](docs/reproduction.md) for matching publication layout.
The checked-in figures allow a build without cloning the analysis repositories.

[Revision changes](REVISION_CHANGES.md),
[Figure 66 inputs](figures_new/fishery-impact/README.md) and the
[archived Rev.01 comparison](https://raw.githubusercontent.com/PacificCommunity/ofp-sam-bet-2026-report/rev1/WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf)
provide the review trail. The detailed instructions retain the source repository
links and manual figure-synchronisation commands for future assessment revisions.

Compact native source files for Figure 66 are documented in
[reproduction inputs](reproduce/README.md); the publication PDF and existing
figure links are retained.
