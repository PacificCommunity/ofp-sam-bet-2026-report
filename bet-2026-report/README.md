# BET 2026 report source

This directory contains the complete Quarto source for the 2026 bigeye tuna assessment report. Reviewed figures and tables are committed under <code>generated/outputs</code>, so rendering does not require a Kflow input dependency.

## Writing

Edit narrative text in <code>sections/</code>. The report entry point is <code>assessment-report.qmd</code>, which includes <code>report-body.qmd</code> and the ordered section files.

Put new manually supplied figures in <code>Figures/static/</code>. Replace generated figures or tables only after review, and commit the corresponding index or section reference in the same change.

## Render

From this directory in the Kflow RStudio Terminal:

~~~bash
quarto render assessment-report.qmd --to pdf --output bet-2026-report.pdf
quarto render assessment-report.qmd --to html --output bet-2026-report.html
~~~

From the repository root, <code>bash run.sh</code> performs both renders and writes deliverables to <code>outputs/final-report/</code>.

The writing task uses the pinned <code>tuna-flow v2.4</code> environment. No result-job archive, runtime package update, or generated-section reseeding is required.
