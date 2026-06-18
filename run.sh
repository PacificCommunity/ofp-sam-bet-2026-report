#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OUT_DIR="${OUTPUT_DIR:-outputs}"
INPUT_DIR="${INPUT_DIR:-inputs}"
REPORT_DIR="${REPORT_DIR:-bet-2026-report}"
REPORT_QMD="${REPORT_QMD:-assessment-report.qmd}"

runtime_packages_disabled() {
  case "${KFLOW_RUNTIME_PACKAGES:-}" in
    ""|0|false|FALSE|no|NO|off|OFF|none|NONE|skip|SKIP) return 0 ;;
    *) return 1 ;;
  esac
}

runtime_updates_disabled() {
  case "${KFLOW_RUNTIME_UPDATE:-auto}" in
    ""|0|false|FALSE|no|NO|off|OFF|none|NONE|skip|SKIP|never|NEVER) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_runtime_library() {
  local preferred="${R_LIBS_USER:-${KFLOW_RUNTIME_LIBRARY:-}}"
  local fallback="${ROOT}/.R-library"
  if [[ -z "$preferred" ]]; then
    preferred="$fallback"
  fi
  if mkdir -p "$preferred" 2>/dev/null && [[ -w "$preferred" ]]; then
    export R_LIBS_USER="$preferred"
  else
    export R_LIBS_USER="$fallback"
    mkdir -p "$R_LIBS_USER"
  fi
  export KFLOW_RUNTIME_LIBRARY="$R_LIBS_USER"
  export KFLOW_RUNTIME_STATE_DIR="${KFLOW_RUNTIME_STATE_DIR:-${ROOT}/.kflow-runtime-cache}"
  mkdir -p "$KFLOW_RUNTIME_STATE_DIR" 2>/dev/null || true
}

runtime_private_packages_required() {
  case "${KFLOW_RUNTIME_REQUIRE_PRIVATE_PACKAGES:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

drop_runtime_tokens() {
  unset GIT_PAT GITHUB_PAT GH_TOKEN KFLOW_GITHUB_TOKEN KFLOW_PERSONAL_TOKEN
}

install_missing_runtime_packages() {
  runtime_packages_disabled && return 0
  runtime_updates_disabled && return 0
  ensure_runtime_library
  Rscript - <<'RS'
truthy <- function(value) tolower(value) %in% c("1", "true", "yes", "y", "on", "always")
spec_text <- Sys.getenv("KFLOW_RUNTIME_PACKAGES", "")
parts <- trimws(strsplit(spec_text, ",", fixed = TRUE)[[1]])
parts <- parts[nzchar(parts) & grepl("=", parts, fixed = TRUE)]
if (!length(parts)) quit(save = "no", status = 0)
specs <- lapply(parts, function(part) {
  eq <- regexpr("=", part, fixed = TRUE)[1]
  package <- trimws(substr(part, 1, eq - 1))
  repo_ref <- trimws(substr(part, eq + 1, nchar(part)))
  at <- regexpr("@", repo_ref, fixed = TRUE)[1]
  if (at > 0) {
    repo <- substr(repo_ref, 1, at - 1)
    ref <- substr(repo_ref, at + 1, nchar(repo_ref))
  } else {
    repo <- repo_ref
    ref <- "main"
  }
  list(package = package, repo = repo, ref = ref)
})
lib <- Sys.getenv("R_LIBS_USER", "")
if (!nzchar(lib)) quit(save = "no", status = 43)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(unique(c(lib, .libPaths())))
missing <- specs[!vapply(specs, function(spec) requireNamespace(spec$package, quietly = TRUE), logical(1))]
if (!length(missing)) quit(save = "no", status = 0)
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("remotes", quietly = TRUE)) {
  utils::install.packages("remotes", lib = lib, dependencies = TRUE, repos = getOption("repos"))
}
token <- ""
for (name in c("GITHUB_PAT", "GIT_PAT", "GH_TOKEN", "KFLOW_GITHUB_TOKEN", "KFLOW_PERSONAL_TOKEN")) {
  value <- Sys.getenv(name, "")
  if (nzchar(value)) {
    token <- value
    break
  }
}
for (spec in missing) {
  message("[kflow-runtime-update] Installing missing runtime package ", spec$package, " from ", spec$repo, "@", spec$ref, ".")
  err <- tryCatch({
    remotes::install_github(
      spec$repo,
      ref = spec$ref,
      auth_token = if (nzchar(token)) token else NULL,
      lib = lib,
      upgrade = "never",
      force = TRUE,
      quiet = TRUE
    )
    NULL
  }, error = function(e) e)
  if (inherits(err, "error")) {
    message("[kflow-runtime-update] Runtime package install failed for ", spec$package, ": ", conditionMessage(err))
  }
}
missing_after <- specs[!vapply(specs, function(spec) requireNamespace(spec$package, quietly = TRUE), logical(1))]
if (length(missing_after) && truthy(Sys.getenv("KFLOW_RUNTIME_REQUIRE_PRIVATE_PACKAGES", "false"))) {
  message("[kflow-runtime-update] Required runtime package(s) unavailable: ",
          paste(vapply(missing_after, function(spec) spec$package, character(1)), collapse = ", "))
  quit(save = "no", status = 44)
}
quit(save = "no", status = 0)
RS
}

prepare_runtime_packages() {
  if [[ -n "${TUNA_FLOW_RUNTIME_UPDATE:-}" ]]; then
    export KFLOW_RUNTIME_UPDATE="${TUNA_FLOW_RUNTIME_UPDATE}"
  fi
  runtime_packages_disabled && return 0
  ensure_runtime_library
  if [[ -x /usr/local/bin/30-update-kflow-runtime-packages ]]; then
    if bash /usr/local/bin/30-update-kflow-runtime-packages; then
      :
    else
      update_status=$?
      if runtime_private_packages_required || [[ "$update_status" -eq 42 || "$update_status" -eq 43 ]]; then
        exit "$update_status"
      fi
      echo "[kflow-runtime-update] Runtime package update failed; continuing with bundled packages." >&2
    fi
  else
    echo "[kflow-runtime-update] Runtime updater not found; using bundled packages." >&2
  fi
  install_missing_runtime_packages
  drop_runtime_tokens
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
quarto render "${REPORT_QMD}" --to pdf --output bet-2026-report.pdf
cd "${ROOT}"

mkdir -p "${OUT_DIR}/report" "${OUT_DIR}/figures" "${OUT_DIR}/tables"
cp "${REPORT_DIR}/bet-2026-report.html" "${OUT_DIR}/report/bet-2026-report.html"
cp "${REPORT_DIR}/bet-2026-report.pdf" "${OUT_DIR}/report/bet-2026-report.pdf"

if [[ -d "${REPORT_DIR}/Figures/generated" ]]; then
  find "${REPORT_DIR}/Figures/generated" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.pdf' \) -exec cp {} "${OUT_DIR}/figures/" \;
  if [[ -f "${REPORT_DIR}/Figures/generated/figure-index.csv" ]]; then
    cp "${REPORT_DIR}/Figures/generated/figure-index.csv" "${OUT_DIR}/tables/figure-index.csv"
  fi
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
  type = ifelse(grepl("^report/.*[.](html|pdf)$", files, ignore.case = TRUE), "report", ifelse(grepl("[.](png|jpg|jpeg|pdf)$", files, ignore.case = TRUE), "figure", "table")),
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(out, "report-output-index.csv"), row.names = FALSE)
RS
