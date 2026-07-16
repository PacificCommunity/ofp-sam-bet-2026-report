#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${REPORT_DIR:-bet-2026-report}"
REPORT_QMD="${REPORT_QMD:-assessment-report.qmd}"
REPORT_FILE_STEM="${REPORT_FILE_STEM:-bet-2026-report}"
REPORT_RENDER_HTML="${REPORT_RENDER_HTML:-true}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/outputs}"
REPORT_PATH="${ROOT_DIR}/${REPORT_DIR}"
FIGURE_DIR="${REPORT_PATH}/generated/outputs/figures"
FINAL_DIR="${OUTPUT_DIR}/final-report"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v quarto >/dev/null 2>&1 || fail "Quarto is not available in the selected runtime image."
[[ -d "${REPORT_PATH}" ]] || fail "Report directory not found: ${REPORT_PATH}"
[[ -f "${REPORT_PATH}/${REPORT_QMD}" ]] || fail "Report source not found: ${REPORT_PATH}/${REPORT_QMD}"
[[ -d "${FIGURE_DIR}" ]] || fail "Committed figure directory not found: ${FIGURE_DIR}"

figure_count="$(find "${FIGURE_DIR}" -type f -name '*.png' | wc -l | tr -d ' ')"
[[ "${figure_count}" -gt 0 ]] || fail "No committed PNG figures were found."

rm -rf "${OUTPUT_DIR}"
mkdir -p "${FINAL_DIR}"

cd "${REPORT_PATH}"
rm -f "${REPORT_FILE_STEM}.pdf" "${REPORT_FILE_STEM}.html"

printf 'Rendering PDF from %s committed figures...\n' "${figure_count}"
quarto render "${REPORT_QMD}" --to pdf --output "${REPORT_FILE_STEM}.pdf"
[[ -s "${REPORT_FILE_STEM}.pdf" ]] || fail "PDF render did not create ${REPORT_FILE_STEM}.pdf"
install -m 0644 "${REPORT_FILE_STEM}.pdf" "${FINAL_DIR}/${REPORT_FILE_STEM}.pdf"

case "${REPORT_RENDER_HTML,,}" in
  1|true|yes|on)
    printf 'Rendering self-contained HTML...\n'
    quarto render "${REPORT_QMD}" --to html --output "${REPORT_FILE_STEM}.html"
    [[ -s "${REPORT_FILE_STEM}.html" ]] || fail "HTML render did not create ${REPORT_FILE_STEM}.html"
    install -m 0644 "${REPORT_FILE_STEM}.html" "${FINAL_DIR}/${REPORT_FILE_STEM}.html"
    ;;
esac

commit="$(git -C "${ROOT_DIR}" rev-parse HEAD 2>/dev/null || printf 'unknown')"
branch="${GITHUB_BRANCH:-$(git -C "${ROOT_DIR}" branch --show-current 2>/dev/null || true)}"
printf 'source_commit,source_branch,figure_count\n%s,%s,%s\n'   "${commit}" "${branch:-detached}" "${figure_count}" > "${OUTPUT_DIR}/render-manifest.csv"

printf 'Report outputs written to %s\n' "${FINAL_DIR}"
