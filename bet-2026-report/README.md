# BET 2026 report source

This directory contains the complete Quarto source for the 2026 bigeye tuna
assessment report. It is self-contained and has no Results-job dependency.

## Writing

Edit narrative text in <code>sections/</code>. The report entry point is
<code>assessment-report.qmd</code>.

A small example image set is committed directly in <code>Figures/</code>. Upload
or replace files there, then edit <code>sections/Figures.qmd</code> when a file
name, caption, order, or figure selection changes. Tables are in
<code>tables/</code>.

## Render

From this directory in the Kflow RStudio Terminal:

~~~bash
quarto render assessment-report.qmd --to pdf --output bet-2026-report.pdf
~~~

From the repository root, <code>bash run.sh</code> renders the same source and
writes only <code>outputs/bet-2026-report.pdf</code>.

The writing tasks use the pinned <code>tuna-flow v2.4</code> environment.
