#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OUT_DIR="${OUTPUT_DIR:-outputs}"
INPUT_DIR="${INPUT_DIR:-inputs}"
REPORT_DIR="${REPORT_DIR:-bet-2026-report}"
REPORT_QMD="${REPORT_QMD:-assessment-report.qmd}"

runtime_packages_enabled() {
  case "${KFLOW_RUNTIME_PACKAGES:-}" in
    ""|0|false|FALSE|no|NO|off|OFF|none|NONE|skip|SKIP) return 1 ;;
    *) return 0 ;;
  esac
}

prepare_runtime_packages() {
  runtime_packages_enabled || return 0
  export R_LIBS_USER="${R_LIBS_USER:-${ROOT}/.R-library}"
  export KFLOW_RUNTIME_LIBRARY="${KFLOW_RUNTIME_LIBRARY:-${R_LIBS_USER}}"
  export KFLOW_RUNTIME_STATE_DIR="${KFLOW_RUNTIME_STATE_DIR:-${ROOT}/.kflow-runtime-cache}"
  mkdir -p "${R_LIBS_USER}" "${KFLOW_RUNTIME_STATE_DIR}"
  if [[ -x /usr/local/bin/30-update-kflow-runtime-packages ]]; then
    bash /usr/local/bin/30-update-kflow-runtime-packages
  else
    echo "[kflow-runtime-update] Runtime updater not found; using bundled packages." >&2
  fi
}

mkdir -p "${OUT_DIR}"

echo "BET 2026 report task"
echo "Input artifacts: ${INPUT_DIR}"
echo "Report directory: ${REPORT_DIR}"
echo "Report entrypoint: ${REPORT_QMD}"

prepare_runtime_packages
Rscript R/prepare_report_inputs.R

cd "${REPORT_DIR}"
quarto render "${REPORT_QMD}" --to html --output bet-2026-report.html
cd "${ROOT}"

cp "${REPORT_DIR}/bet-2026-report.html" "${OUT_DIR}/bet-2026-report.html"
mkdir -p "${OUT_DIR}/report" "${OUT_DIR}/figures" "${OUT_DIR}/tables"
cp "${REPORT_DIR}/bet-2026-report.html" "${OUT_DIR}/report/bet-2026-report.html"

if [[ -d "${REPORT_DIR}/Figures/generated" ]]; then
  find "${REPORT_DIR}/Figures/generated" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.pdf' -o -name '*.csv' \) -exec cp {} "${OUT_DIR}/figures/" \;
fi
if [[ -d "${REPORT_DIR}/tables/generated" ]]; then
  find "${REPORT_DIR}/tables/generated" -maxdepth 1 -type f -name '*.csv' -exec cp {} "${OUT_DIR}/tables/" \;
fi
if [[ -d "${REPORT_DIR}/pipeline-inputs" ]]; then
  find "${REPORT_DIR}/pipeline-inputs" -maxdepth 1 -type f -name '*.csv' -exec cp {} "${OUT_DIR}/tables/" \;
fi

Rscript - <<'RS'
out <- Sys.getenv("OUTPUT_DIR", "outputs")
files <- list.files(out, recursive = TRUE, full.names = FALSE)
summary <- data.frame(
  output = files,
  type = ifelse(grepl("[.]html$", files), "html", ifelse(grepl("[.](png|jpg|jpeg|pdf)$", files, ignore.case = TRUE), "figure", "table")),
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(out, "report-output-index.csv"), row.names = FALSE)
RS
