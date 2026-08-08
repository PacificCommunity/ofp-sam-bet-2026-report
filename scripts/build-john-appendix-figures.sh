#!/usr/bin/env bash

# Export the three publication PNGs from John Hampton's supplied Word
# appendix. Crops use the document's fixed A4 landscape layout at 300 dpi;
# the split SEAPODYM matrix is rejoined without resampling.

set -euo pipefail

report_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_doc="$report_root/sources/Appendix for bigeye.docx"
output_dir="$report_root/figures_new"
work_dir=$(mktemp -d -t bet-appendix.XXXXXX)

cleanup() {
  resolved=$(realpath -m "$work_dir")
  case "$resolved" in
    /tmp/bet-appendix.*) rm -rf -- "$resolved" ;;
    *) echo "Refusing to remove unexpected temporary path: $resolved" >&2 ;;
  esac
}
trap cleanup EXIT

test -s "$source_doc"
mkdir -p "$output_dir" "$work_dir/pdf" "$work_dir/pages"

libreoffice --headless --convert-to pdf --outdir "$work_dir/pdf" "$source_doc" >/dev/null
source_pdf="$work_dir/pdf/Appendix for bigeye.pdf"
test -s "$source_pdf"
pdftocairo -png -f 4 -l 7 -r 300 "$source_pdf" "$work_dir/pages/page"

convert "$work_dir/pages/page-4.png" \
  -crop 2910x1781+297+297 +repage \
  "$output_dir/appendix-mfcl-movement.png"

convert "$work_dir/pages/page-5.png" \
  -crop 2910x1448+297+447 +repage \
  "$work_dir/seap-top.png"
convert "$work_dir/pages/page-6.png" \
  -crop 2910x330+297+300 +repage \
  "$work_dir/seap-bottom.png"
convert "$work_dir/seap-top.png" "$work_dir/seap-bottom.png" -append \
  "$output_dir/appendix-seapodym-movement.png"

convert "$work_dir/pages/page-7.png" \
  -crop 2913x1691+273+305 +repage \
  "$output_dir/appendix-no-tag-model-comparison.png"

for figure in \
  appendix-mfcl-movement.png \
  appendix-seapodym-movement.png \
  appendix-no-tag-model-comparison.png; do
  test -s "$output_dir/$figure"
done

echo "Prepared supplied John Hampton appendix figures in $output_dir"
