#!/usr/bin/env bash

# Build the tracked-change PDF against the preserved draft branch without
# modifying that branch or the current checkout. Longtable and figure
# environments are rendered as complete current-version blocks so complex
# table layouts, replaced graphics and clickable caption links remain valid;
# narrative changes retain word-level markup.

set -euo pipefail

report_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
base_ref=${1:-origin/draft}
base_commit=$(git -C "$report_root" rev-parse "$base_ref^{commit}")
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
base_root="$temporary_root/draft"
mkdir -p "$base_root"

git -C "$report_root" archive "$base_commit" | tar -x -C "$base_root"
(
  cd "$base_root"
  quarto render main.qmd --to pdf
)

test -s "$report_root/main.tex"
test -s "$base_root/main.tex"
latexdiff \
  --type=UNDERLINE \
  --add-to-config 'VERBATIMENV=longtable,PICTUREENV=figure[\w\d*@]*' \
  --graphics-markup=1 \
  --visible-label \
  "$base_root/main.tex" \
  "$report_root/main.tex" \
  > "$report_root/main-diff.tex"

# Deleted draft prose still refers to labels of figures that were consolidated
# in rev1. Point those legacy labels at the corresponding current figure so
# struck-through references remain readable instead of appearing as “??”.
perl -0pi -e '
  s/\\label\{fig-cpue-fit-residuals\}/$&\\label{fig-cpue-fit-1-5}\\label{fig-cpue-resids-1-5}/g;
  s/\\label\{fig-length-fit-by-fishery\}/$&\\label{fig-length-fit-aggregated-ll}\\label{fig-length-fit-aggregated-dompl}\\label{fig-length-fit-aggregated-ps}/g;
  s/\\label\{fig-tag-attrition-programmes\}/$&\\label{fig-tag-attrition-all}/g;
  s/\\label\{fig-tag-reporting-rates-active\}/$&\\label{fig-tag-report-rates-rttp-pttp}\\label{fig-tag-report-rates-jtpt}/g;
  s/\\label\{fig-selftest-diagnostics\}/$&\\label{fig-selftest-recovery}\\label{fig-selftest-time-series}/g;
  s/\\label\{fig-diag-profile-data-tag-prog\}/$&\\label{fig-diag-profile-data-tag-prog-grps}/g;
' "$report_root/main-diff.tex"

(
  cd "$report_root"
  pdflatex \
    -interaction=nonstopmode \
    -halt-on-error \
    -jobname=WCPFC-SC22-2026-SA-WP-06-draft-diff \
    main-diff.tex
  pdflatex \
    -interaction=nonstopmode \
    -halt-on-error \
    -jobname=WCPFC-SC22-2026-SA-WP-06-draft-diff \
    main-diff.tex
)

test -s "$report_root/WCPFC-SC22-2026-SA-WP-06-draft-diff.pdf"
echo "Built tracked changes against $base_ref ($base_commit)"
