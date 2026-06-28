#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OUT_DIR="${OUTPUT_DIR:-outputs}"
INPUT_DIR="${INPUT_DIR:-inputs}"
REPORT_DIR="${REPORT_DIR:-bet-2026-report}"
REPORT_QMD="${REPORT_QMD:-assessment-report.qmd}"
REPORT_FILE_STEM="${REPORT_FILE_STEM:-bet-2026-report}"

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

runtime_updates_direct() {
  case "${KFLOW_RUNTIME_UPDATE:-auto}" in
    direct|DIRECT|url|URL|download|DOWNLOAD) return 0 ;;
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

truthy_value() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON|always|ALWAYS) return 0 ;;
    *) return 1 ;;
  esac
}

truthy_env() {
  local name="$1"
  local default="${2:-false}"
  local value="${!name:-$default}"
  truthy_value "$value"
}

publish_required() {
  truthy_env KFLOW_REPORT_PUBLISH_REQUIRED true
}

publish_fail() {
  local message="$1"
  if publish_required; then
    echo "[kflow-report-publish] ${message}" >&2
    return 1
  fi
  echo "[kflow-report-publish] ${message}; continuing because publish is not required." >&2
  return 0
}

first_runtime_token() {
  local name
  for name in GITHUB_PAT GIT_PAT GH_TOKEN KFLOW_GITHUB_TOKEN KFLOW_PERSONAL_TOKEN; do
    if [[ -n "${!name:-}" ]]; then
      printf "%s" "${!name}"
      return 0
    fi
  done
  return 1
}

kflow_provenance_path() {
  local path="${KFLOW_PROVENANCE_FILE:-}"
  if [[ -z "$path" ]]; then
    path="${INPUT_DIR}/kflow-provenance.json"
  fi
  printf "%s" "$path"
}

kflow_job_ref() {
  local job_id="${1:-}"
  local job_number="${2:-}"
  if [[ -n "$job_number" ]]; then
    if [[ -n "$job_id" ]]; then
      printf "Job %s (%s)" "$job_number" "$job_id"
    else
      printf "Job %s" "$job_number"
    fi
    return 0
  fi
  if [[ -z "$job_id" ]]; then
    printf "unknown"
    return 0
  fi

  local provenance
  provenance="$(kflow_provenance_path)"
  if [[ -f "$provenance" ]] && command -v python3 >/dev/null 2>&1; then
    local label
    label="$(
      python3 - "$provenance" "$job_id" <<'PY' 2>/dev/null || true
import json
import sys

path, target = sys.argv[1:3]
try:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    data = {}

records = []
for key in ("job", "inputs", "lineage"):
    value = data.get(key)
    if isinstance(value, dict):
        records.append(value)
    elif isinstance(value, list):
        records.extend(item for item in value if isinstance(item, dict))

for record in records:
    if str(record.get("job_id", "")) != target:
        continue
    task = str(record.get("task") or record.get("task_name") or "").strip()
    label = str(record.get("job_label") or "").strip()
    number = str(record.get("job_number") or "").strip()
    if not label and number:
        label = f"Job {number}"
    if label:
        ref = f"{label} ({target})"
    else:
        ref = target
    print(f"{task} {ref}" if task else ref)
    break
PY
    )"
    if [[ -n "$label" ]]; then
      printf "%s" "$label"
      return 0
    fi
  fi

  printf "%s" "$job_id"
}

kflow_job_refs() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    printf "unknown"
    return 0
  fi
  local -a parts labels
  local part
  IFS=',' read -r -a parts <<< "$raw"
  for part in "${parts[@]}"; do
    part="${part#"${part%%[![:space:]]*}"}"
    part="${part%"${part##*[![:space:]]}"}"
    [[ -n "$part" ]] || continue
    labels+=("$(kflow_job_ref "$part")")
  done
  if [[ "${#labels[@]}" -eq 0 ]]; then
    printf "unknown"
    return 0
  fi
  local joined="${labels[0]}"
  local i
  for ((i = 1; i < ${#labels[@]}; i++)); do
    joined+=", ${labels[$i]}"
  done
  printf "%s" "$joined"
}

kflow_input_job_ids() {
  local provenance
  provenance="$(kflow_provenance_path)"
  if [[ ! -f "$provenance" ]] || ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  python3 - "$provenance" <<'PY' 2>/dev/null || true
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    data = {}

items = data.get("inputs") or []
if isinstance(items, dict):
    items = [items]
ids = []
for item in items:
    if isinstance(item, dict):
        job_id = str(item.get("job_id") or "").strip()
        if job_id and job_id not in ids:
            ids.append(job_id)
print(",".join(ids))
PY
}

kflow_lineage_refs() {
  local provenance
  provenance="$(kflow_provenance_path)"
  if [[ ! -f "$provenance" ]] || ! command -v python3 >/dev/null 2>&1; then
    printf "unknown"
    return 0
  fi
  python3 - "$provenance" <<'PY' 2>/dev/null || printf "unknown"
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    data = {}

items = data.get("lineage") or []
if isinstance(items, dict):
    items = [items]
labels = []
for item in items:
    if not isinstance(item, dict):
        continue
    task = str(item.get("task") or item.get("task_name") or "").strip()
    job_id = str(item.get("job_id") or "").strip()
    label = str(item.get("job_label") or "").strip()
    number = str(item.get("job_number") or "").strip()
    if not label and number:
        label = f"Job {number}"
    if label and job_id:
        ref = f"{label} ({job_id})"
    elif label:
        ref = label
    elif job_id:
        ref = job_id
    else:
        ref = ""
    if ref:
        labels.append(f"{task} {ref}" if task else ref)
print(", ".join(labels) if labels else "unknown")
PY
}

publish_generated_report_inputs() {
  truthy_env KFLOW_REPORT_COMMIT_GENERATED false || return 0
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    publish_fail "Cannot commit generated report inputs because this is not a git checkout."
    return $?
  fi

  local branch="${GITHUB_BRANCH:-}"
  if [[ -z "$branch" ]]; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    publish_fail "Cannot publish generated report inputs because the target branch is unknown."
    return $?
  fi

  git config user.name >/dev/null 2>&1 || git config user.name "${KFLOW_GIT_AUTHOR_NAME:-Kflow Bot}"
  git config user.email >/dev/null 2>&1 || git config user.email "${KFLOW_GIT_AUTHOR_EMAIL:-kflow@localhost}"
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    git remote set-url origin "https://github.com/${GITHUB_REPOSITORY}.git" >/dev/null 2>&1 || true
  fi

  local stage_paths=()
  local path
  for path in \
    "${REPORT_DIR}/generated/outputs/report-ready/figures.qmd" \
    "${REPORT_DIR}/generated/outputs/report-ready/tables.qmd" \
    "${REPORT_DIR}/generated/outputs/figures" \
    "${REPORT_DIR}/generated/outputs/tables" \
    "${REPORT_DIR}/pipeline-inputs" \
    "${REPORT_DIR}/sections/Figures.qmd" \
    "${REPORT_DIR}/sections/Tables.qmd" \
    "${REPORT_DIR}/report-config.yml"; do
    [[ -e "$path" ]] && stage_paths+=("$path")
  done
  if [[ "${#stage_paths[@]}" -eq 0 ]]; then
    publish_fail "No generated report inputs were found to commit."
    return $?
  fi

  git add -A -- "${stage_paths[@]}"
  if git diff --cached --quiet; then
    echo "[kflow-report-publish] Generated report inputs are already committed."
    return 0
  fi

  local changed_paths
  changed_paths="$(
    git diff --cached --name-status -- "${stage_paths[@]}" |
      awk -F '\t' '
        BEGIN { limit = 80 }
        {
          total++
          if (total > limit) next
          status = $1
          label = status
          if (status == "A") label = "added"
          else if (status == "M") label = "modified"
          else if (status == "D") label = "removed"
          else if (status ~ /^R/) label = "renamed"
          else if (status ~ /^C/) label = "copied"
          if (NF >= 3) print "- " label ": " $2 " -> " $3
          else print "- " label ": " $2
        }
        END {
          if (total > limit) print "- ... " (total - limit) " more changed path(s)"
          if (total == 0) print "- no path-level changes detected"
        }
      '
  )"

  local report_job="manual"
  if [[ -n "${KFLOW_JOB_ID:-}${KFLOW_JOB_NUMBER:-}" ]]; then
    report_job="$(kflow_job_ref "${KFLOW_JOB_ID:-}" "${KFLOW_JOB_NUMBER:-}")"
  fi
  local report_job_subject="${report_job%% (*}"
  local results_jobs="${RESULTS_JOB_IDS:-${RESULTS_JOB_ID:-${OUTPUTS_JOB_IDS:-${OUTPUTS_JOB_ID:-}}}}"
  if [[ -z "$results_jobs" ]]; then
    results_jobs="$(kflow_input_job_ids)"
  fi
  results_jobs="$(kflow_job_refs "$results_jobs")"
  local lineage_jobs
  lineage_jobs="$(kflow_lineage_refs)"
  local subject="Update generated report inputs from Kflow ${report_job_subject}"
  local body
  body=$(
    cat <<EOF
Kflow:
- report task: ${KFLOW_REPORT_CODE:-${GITHUB_REPOSITORY:-unknown}}
- report job: ${report_job}
- results job(s): ${results_jobs:-unknown}
- upstream lineage: ${lineage_jobs:-unknown}
- branch: ${branch}

Changed generated inputs:
${changed_paths}
EOF
  )
  git commit -m "$subject" -m "$body"

  truthy_env KFLOW_REPORT_PUSH_GENERATED true || {
    echo "[kflow-report-publish] Generated report inputs committed locally; push disabled."
    return 0
  }

  local token=""
  token="$(first_runtime_token || true)"
  if [[ -z "$token" ]]; then
    publish_fail "Cannot push generated report inputs because no GitHub token is available."
    return $?
  fi

  local askpass
  askpass="$(mktemp)"
  cat > "$askpass" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf "%s\n" "x-access-token" ;;
  *Password*) printf "%s\n" "${KFLOW_REPORT_GIT_TOKEN:-}" ;;
  *) printf "\n" ;;
esac
EOF
  chmod 700 "$askpass"
  if KFLOW_REPORT_GIT_TOKEN="$token" GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0 git push origin "HEAD:${branch}"; then
    rm -f "$askpass"
    echo "[kflow-report-publish] Pushed generated report inputs to ${GITHUB_REPOSITORY:-origin}:${branch}."
    return 0
  fi
  rm -f "$askpass"
  publish_fail "Generated report input commit was created, but git push failed."
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
desc_field <- function(desc, name) {
  value <- tryCatch(desc[[name]], error = function(e) "")
  if (is.null(value) || !length(value) || is.na(value[[1L]])) "" else as.character(value[[1L]])
}
installed_desc <- function(package) {
  desc <- tryCatch(
    suppressWarnings(utils::packageDescription(package, lib.loc = lib)),
    error = function(e) NULL
  )
  if (length(desc) == 1L && is.na(desc[[1L]])) NULL else desc
}
needs_install <- function(spec) {
  desc <- installed_desc(spec$package)
  if (is.null(desc)) return(TRUE)
  installed_sha <- desc_field(desc, "RemoteSha")
  installed_ref <- desc_field(desc, "RemoteRef")
  ref_is_sha <- grepl("^[0-9a-f]{7,40}$", spec$ref, ignore.case = TRUE)
  if (ref_is_sha) {
    return(!nzchar(installed_sha) || !startsWith(tolower(installed_sha), tolower(spec$ref)))
  }
  !identical(installed_ref, spec$ref)
}
missing <- specs[vapply(specs, needs_install, logical(1))]
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
download_github_archive <- function(repo, ref) {
  archive <- tempfile(pattern = "kflow-runtime-", fileext = ".tar.gz")
  url <- sprintf("https://codeload.github.com/%s/tar.gz/%s", repo, ref)
  curl <- Sys.which("curl")
  if (nzchar(curl)) {
    args <- c("-fsSL", "--retry", "3", "--retry-delay", "2", "-o", archive)
    if (nzchar(token)) {
      args <- c("-H", paste("Authorization: Bearer", token), args)
    }
    status <- system2(curl, c(args, url), stdout = FALSE, stderr = FALSE)
    if (!identical(status, 0L)) {
      stop("download failed from ", url)
    }
  } else {
    headers <- if (nzchar(token)) c(Authorization = paste("Bearer", token)) else NULL
    status <- utils::download.file(url, archive, mode = "wb", quiet = TRUE, method = "libcurl", headers = headers)
    if (!identical(status, 0L)) {
      stop("download failed from ", url)
    }
  }
  archive
}
for (spec in missing) {
  message("[kflow-runtime-update] Installing missing runtime package ", spec$package, " from ", spec$repo, "@", spec$ref, ".")
  err <- tryCatch({
    archive <- download_github_archive(spec$repo, spec$ref)
    on.exit(unlink(archive), add = TRUE)
    remotes::install_local(
      archive,
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
  if runtime_updates_direct; then
    install_missing_runtime_packages
    drop_runtime_tokens
    return 0
  fi
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
}

mkdir -p "${OUT_DIR}"

echo "BET 2026 report task"
echo "Input artifacts: ${INPUT_DIR}"
echo "Report directory: ${REPORT_DIR}"
echo "Report entrypoint: ${REPORT_QMD}"
echo "Report file stem: ${REPORT_FILE_STEM}"
echo "Render HTML: ${REPORT_RENDER_HTML:-false}"

prepare_runtime_packages
Rscript R/prepare_report_inputs.R

cd "${REPORT_DIR}"
rm -f "${REPORT_FILE_STEM}.html" "${REPORT_FILE_STEM}.pdf"
if truthy_env REPORT_RENDER_HTML false; then
  quarto render "${REPORT_QMD}" --to html --output "${REPORT_FILE_STEM}.html"
else
  echo "Skipping HTML report render; set REPORT_RENDER_HTML=true to enable it."
fi
quarto render "${REPORT_QMD}" --to pdf --output "${REPORT_FILE_STEM}.pdf"
cd "${ROOT}"

Rscript - <<'RS'
env <- function(name, default = "") {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) default else value
}

truthy <- function(value) {
  tolower(trimws(as.character(value %||% ""))) %in% c("1", "true", "yes", "y", "on", "always")
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

slug <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("[^a-z0-9]+", "-", x)
  x <- gsub("(^-+|-+$)", "", x)
  ifelse(nzchar(x), x, "item")
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame())
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
}

bind_rows_fill <- function(rows) {
  rows <- rows[vapply(rows, function(x) is.data.frame(x) && nrow(x), logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    for (name in setdiff(cols, names(x))) x[[name]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, rows)
}

is_internal_report_table <- function(path) {
  base <- tolower(basename(path))
  grepl(
    paste(
      "^(payload-index(-[0-9]+)?|model-index|plot-summary|report-files|report-ready-files|",
      "report-input-.*|report-prep-summary|figure-index|table-index|",
      "generated-table-index|figure-optimization|mfclshiny-.*|",
      ".*build-log.*|.*report-summary)[.]csv$",
      sep = ""
    ),
    base
  )
}

polish_output_caption <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\\s+", " ", x)
  x <- gsub(
    "\\s+(for|in|from|of|used in) the [0-9]{4}\\s+bigeye tuna\\s*(\\(BET\\))?\\s+assessment\\b",
    "",
    x,
    ignore.case = TRUE,
    perl = TRUE
  )
  x <- gsub(
    "^the [0-9]{4}\\s+bigeye tuna\\s*(\\(BET\\))?\\s+assessment\\s+",
    "",
    x,
    ignore.case = TRUE,
    perl = TRUE
  )
  x <- gsub(
    "\\bthe [0-9]{4}\\s+bigeye tuna\\s*(\\(BET\\))?\\s+assessment\\b",
    "",
    x,
    ignore.case = TRUE,
    perl = TRUE
  )
  x <- gsub("\\s+([.,;:])", "\\1", x, perl = TRUE)
  x <- trimws(gsub("\\s+", " ", x))
  ifelse(nzchar(x), paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x))), x)
}

polish_output_metadata <- function(x) {
  if (!is.data.frame(x) || !nrow(x)) return(x)
  text_cols <- unique(c(
    grep("caption", names(x), ignore.case = TRUE, value = TRUE),
    intersect(c("alt_text", "description"), names(x))
  ))
  for (col in text_cols) {
    x[[col]] <- polish_output_caption(x[[col]])
  }
  x
}

is_default_excluded_figure <- function(path) {
  stem <- tools::file_path_sans_ext(tolower(basename(path)))
  stem <- gsub("_", "-", stem, fixed = TRUE)
  stem %in% c(
    "hessian-diagnostics",
    "tag-recapture-pressure-release-group",
    "tag-recapture-pressure-release-group-by-fishery"
  )
}

write_sidecar <- function(folder, row, caption_field = "caption") {
  if (is.data.frame(row) && nrow(row)) {
    row <- polish_output_metadata(row)
    utils::write.csv(row, file.path(folder, "metadata.csv"), row.names = FALSE)
    caption <- row[[caption_field]]
    if (!is.null(caption) && length(caption) && nzchar(as.character(caption[[1]]))) {
      writeLines(as.character(caption[[1]]), file.path(folder, "caption.txt"))
    }
  }
}

copy_file <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  file.copy(from, to, overwrite = TRUE)
}

copy_figure_for_output <- function(file, folder) {
  if (!file.exists(file)) return("")
  to <- file.path(folder, basename(file))
  copy_file(file, to)
  to
}

match_index_row <- function(index, file, id_col) {
  if (!is.data.frame(index) || !nrow(index)) return(index[0, , drop = FALSE])
  base <- basename(file)
  candidates <- unique(c("file", "relative_path", "path", "output", "table", "figure"))
  candidates <- intersect(candidates, names(index))
  for (col in candidates) {
    hit <- basename(as.character(index[[col]])) == base
    if (any(hit, na.rm = TRUE)) return(index[which(hit)[[1]], , drop = FALSE])
  }
  if (id_col %in% names(index)) {
    stem <- tools::file_path_sans_ext(base)
    hit <- slug(index[[id_col]]) == slug(stem)
    if (any(hit, na.rm = TRUE)) return(index[which(hit)[[1]], , drop = FALSE])
  }
  index[0, , drop = FALSE]
}

out <- env("OUTPUT_DIR", "outputs")
report_dir <- env("REPORT_DIR", "bet-2026-report")
report_file_stem <- env("REPORT_FILE_STEM", "bet-2026-report")
render_html <- truthy(env("REPORT_RENDER_HTML", "false"))

dirs <- file.path(out, c("final-report", "figures", "tables", "indices", "provenance", "generated"))
unlink(dirs, recursive = TRUE, force = TRUE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))

final_ext <- if (render_html) c(".pdf", ".html") else ".pdf"
final_files <- file.path(report_dir, paste0(report_file_stem, final_ext))
final_files <- final_files[file.exists(final_files)]
for (file in final_files) {
  copy_file(file, file.path(out, "final-report", basename(file)))
}

pipeline_dir <- file.path(report_dir, "pipeline-inputs")
if (dir.exists(pipeline_dir)) {
  provenance_files <- list.files(pipeline_dir, pattern = "provenance[.](csv|json)$", full.names = TRUE, ignore.case = TRUE)
  for (file in provenance_files) {
    copy_file(file, file.path(out, "provenance", basename(file)))
  }
}

generated_outputs_dir <- file.path(report_dir, "generated", "outputs")
if (dir.exists(generated_outputs_dir)) {
  generated_files <- list.files(generated_outputs_dir, recursive = TRUE, full.names = TRUE)
  for (file in generated_files) {
    rel <- sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", generated_outputs_dir), "/?"), "", file)
    if (grepl("^(report-ready/|figure-index[.]csv$|table-index[.]csv$|plot-summary[.]csv$)", rel, ignore.case = TRUE)) {
      copy_file(file, file.path(out, "generated", "outputs", rel))
    }
  }
}

figure_dir <- file.path(report_dir, "Figures", "generated")
figure_index_path <- file.path(figure_dir, "figure-index.csv")
figure_index <- read_csv_safe(figure_index_path)
if (file.exists(figure_index_path)) {
  if (is.data.frame(figure_index) && nrow(figure_index)) {
    path_cols <- intersect(c("file", "relative_path", "path", "output", "figure"), names(figure_index))
    if (length(path_cols)) {
      excluded <- Reduce(`|`, lapply(path_cols, function(col) is_default_excluded_figure(figure_index[[col]])))
      figure_index <- figure_index[!excluded, , drop = FALSE]
    }
  }
  if (is.data.frame(figure_index) && nrow(figure_index)) {
    figure_index <- polish_output_metadata(figure_index)
    utils::write.csv(figure_index, file.path(out, "indices", "figure-index.csv"), row.names = FALSE)
  } else {
    utils::write.csv(figure_index, file.path(out, "indices", "figure-index.csv"), row.names = FALSE)
  }
}
figure_files <- if (dir.exists(figure_dir)) {
  list.files(figure_dir, pattern = "[.](png|jpg|jpeg|pdf)$", full.names = TRUE, ignore.case = TRUE)
} else {
  character()
}
figure_files <- figure_files[!is_default_excluded_figure(figure_files)]
for (file in figure_files) {
  row <- match_index_row(figure_index, file, "figure")
  id <- if (nrow(row) && "figure" %in% names(row) && nzchar(as.character(row$figure[[1]]))) {
    slug(row$figure[[1]])
  } else {
    slug(tools::file_path_sans_ext(basename(file)))
  }
  folder <- file.path(out, "figures", id)
  copy_figure_for_output(file, folder)
  write_sidecar(folder, row, "caption")
}

table_dirs <- c(file.path(report_dir, "tables", "generated"), file.path(report_dir, "tables"), file.path(report_dir, "Tables"))
table_files <- unlist(lapply(table_dirs[dir.exists(table_dirs)], function(dir) {
  list.files(dir, pattern = "[.]csv$", full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE)
table_index_files <- table_files[basename(table_files) %in% c("table-index.csv", "generated-table-index.csv", "mfclshiny-table-index.csv")]
table_index <- bind_rows_fill(lapply(table_index_files, read_csv_safe))
if (length(table_index_files)) {
  copy_file(table_index_files[[1]], file.path(out, "indices", "table-index.csv"))
}
report_table_files <- setdiff(table_files, table_index_files)
report_table_files <- report_table_files[!is_internal_report_table(report_table_files)]
for (file in report_table_files) {
  base <- basename(file)
  row <- match_index_row(table_index, file, "table")
  id <- if (nrow(row) && "table" %in% names(row) && nzchar(as.character(row$table[[1]]))) {
    slug(row$table[[1]])
  } else {
    slug(tools::file_path_sans_ext(base))
  }
  folder <- file.path(out, "tables", id)
  copy_file(file, file.path(folder, base))
  write_sidecar(folder, row, "caption")
}

files <- list.files(out, recursive = TRUE, full.names = FALSE)
summary <- data.frame(
  output = files,
  type = ifelse(
    grepl("^final-report/.*[.](html|pdf)$", files, ignore.case = TRUE),
    "final-report",
    ifelse(grepl("^generated/", files), "generated",
    ifelse(grepl("^provenance/", files), "provenance",
      ifelse(grepl("^figures/", files), "figure",
      ifelse(grepl("^tables/", files), "table", "index")
      )
      )
    )
  ),
  size_bytes = suppressWarnings(file.info(file.path(out, files))$size),
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(out, "indices", "report-output-index.csv"), row.names = FALSE)
message("Organized report outputs under ", out, ": ",
        sum(summary$type == "final-report"), " final files, ",
        length(unique(dirname(summary$output[summary$type == "figure"]))), " figure folders, ",
        length(unique(dirname(summary$output[summary$type == "table"]))), " table folders, ",
        sum(summary$type == "provenance"), " provenance files, ",
        sum(summary$type == "generated"), " generated-map files.")
RS

publish_generated_report_inputs
drop_runtime_tokens
