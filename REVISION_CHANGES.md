# Rev.01 changes from `draft`

Comparison baseline: `origin/draft` commit
`abd2ec7c472d380ebeddf4bebf615fc8d56a649e`.

- Preserved the report's section order, tone and main line of interpretation.
- Retained every original asset in `figures/`; replacement and additional
  assets are stored separately in `figures_new/`. The original three-part
  jitter presentation remains in the report.
- Updated model-fit, likelihood-profile and population-dynamics figures;
  added Hessian, ASPM and ensemble-projection figures; and aligned captions
  and nearby interpretation with the displayed results.
- Added the fishery-definition, eight-group Dirichlet--multinomial and MFCL
  reporting-rate tables using the final model controls.
- Added the supplied no-tagging and alternative-movement appendix, including
  its table-based figures at publication resolution.
- Completed concise diagnostic, stock-status, projection, discussion and
  supporting-resource text, aligning numerical values, terminology and
  cross-references with the final model outputs.
- Checked all linked interactive reports and documented the available
  drill-down levels. The final MFCL fit uses length-frequency data and no
  weight-frequency profile is presented.
- Added a pinned build environment, upstream diagnostic-asset synchronisation,
  clean and marked-difference PDFs, and source tables/scripts needed to rebuild
  the revised report.

Review `WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf` for marked narrative and
figure changes. Tables are rendered as complete current tables in the diff PDF
to preserve stable `longtable` layout; their source-level changes remain
visible with `git diff origin/draft -- tables/Assessment-tables.qmd`.
