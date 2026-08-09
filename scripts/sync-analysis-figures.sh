#!/usr/bin/env bash

# Synchronise publication figures owned by the jitter, self-test,
# retrospective and one-off-sensitivity reports. Every asset is staged and
# validated before the checked-in report copy is replaced.

set -euo pipefail

jitter_pages_root=${1:-${JITTER_PAGES_ROOT:-https://pacificcommunity.github.io/ofp-sam-bet-2026-jitter}}
selftest_pages_root=${2:-${SELFTEST_PAGES_ROOT:-https://pacificcommunity.github.io/ofp-sam-bet-2026-selftest}}
retrospective_pages_root=${3:-${RETROSPECTIVE_PAGES_ROOT:-https://pacificcommunity.github.io/ofp-sam-bet-2026-retrospective}}
sensitivity_pages_root=${4:-${SENSITIVITY_PAGES_ROOT:-https://pacificcommunity.github.io/ofp-sam-bet-2026-sensitivity}}
jitter_source_sha=${5:-${JITTER_SOURCE_SHA:-unknown}}
selftest_source_sha=${6:-${SELFTEST_SOURCE_SHA:-unknown}}
retrospective_source_sha=${7:-${RETROSPECTIVE_SOURCE_SHA:-unknown}}
sensitivity_source_sha=${8:-${SENSITIVITY_SOURCE_SHA:-unknown}}

report_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT

asset_map=(
  "jitter|results/figures/jitter-diagnostics-diagnostic-model.png|figures_new/jitter-diagnostics-diagnostic-model.png"
  "jitter|results/figures/jitter-derived-diagnostic-model.png|figures_new/jitter-derived-diagnostic-model.png"
  "jitter|results/figures/jitter-regional-depletion-diagnostic-model.png|figures_new/jitter-regional-depletion-diagnostic-model.png"
  "selftest|results/figures/selftest-key-recovery-diagnostic.png|figures_new/selftest-key-recovery-diagnostic.png"
  "selftest|results/figures/selftest-recovery-diagnostic.png|figures_new/selftest-recovery-diagnostic.png"
  "retrospective|results/figures/retrospective-diagnostics-diagnostic-model.png|figures_new/retrospective-diagnostics.png"
  "sensitivity|results/figures/sensitivity-steepness.png|figures_new/sensitivity-steepness.png"
  "sensitivity|results/figures/sensitivity-natural-mortality.png|figures_new/sensitivity-natural-mortality.png"
  "sensitivity|results/figures/sensitivity-conditional-age-at-length.png|figures_new/sensitivity-conditional-age-at-length.png"
  "sensitivity|results/figures/sensitivity-effort-creep.png|figures_new/sensitivity-effort-creep.png"
  "sensitivity|results/figures/sensitivity-regional-scaling.png|figures_new/sensitivity-regional-scaling.png"
  "sensitivity|results/figures/sensitivity-tag-mixing-periods-ks-d-statistic-cutoff.png|figures_new/sensitivity-tag-mixing-periods-ks-d-statistic-cutoff.png"
  "sensitivity|results/figures/sensitivity-pre-mixing-tag-reporting.png|figures_new/sensitivity-pre-mixing-tag-reporting.png"
  "sensitivity|results/figures/sensitivity-tag-overdispersion.png|figures_new/sensitivity-tag-overdispersion.png"
)

source_root_for() {
  case "$1" in
    jitter) printf '%s' "$jitter_pages_root" ;;
    selftest) printf '%s' "$selftest_pages_root" ;;
    retrospective) printf '%s' "$retrospective_pages_root" ;;
    sensitivity) printf '%s' "$sensitivity_pages_root" ;;
    *) return 1 ;;
  esac
}

for mapping in "${asset_map[@]}"; do
  owner=${mapping%%|*}
  remainder=${mapping#*|}
  source_path=${remainder%%|*}
  destination_path=${remainder#*|}
  source_root=$(source_root_for "$owner")
  staged_path="$stage_dir/$destination_path"
  mkdir -p "$(dirname "$staged_path")"

  if [[ -d "$source_root" ]]; then
    local_source="$source_root/$source_path"
    test -s "$local_source"
    install -m 0644 "$local_source" "$staged_path"
  else
    published_path=${source_path#results/}
    curl --fail --location --retry 3 --retry-delay 2 \
      "$source_root/$published_path" --output "$staged_path"
  fi

  test -s "$staged_path"
  test "$(od -An -tx1 -N8 "$staged_path" | tr -d ' \n')" = "89504e470d0a1a0a"
done

for mapping in "${asset_map[@]}"; do
  destination_path=${mapping##*|}
  install -D -m 0644 "$stage_dir/$destination_path" "$report_root/$destination_path"
done

manifest_path="$report_root/figures_new/UPSTREAM_ANALYSES.txt"
{
  printf 'jitter_url=%s\n' "$jitter_pages_root"
  printf 'jitter_commit=%s\n' "$jitter_source_sha"
  printf 'selftest_url=%s\n' "$selftest_pages_root"
  printf 'selftest_commit=%s\n' "$selftest_source_sha"
  printf 'retrospective_url=%s\n' "$retrospective_pages_root"
  printf 'retrospective_commit=%s\n' "$retrospective_source_sha"
  printf 'sensitivity_url=%s\n' "$sensitivity_pages_root"
  printf 'sensitivity_commit=%s\n' "$sensitivity_source_sha"
  for mapping in "${asset_map[@]}"; do
    destination_path=${mapping##*|}
    checksum=$(sha256sum "$report_root/$destination_path" | cut -d' ' -f1)
    printf '%s  %s\n' "$checksum" "$destination_path"
  done
} > "$manifest_path"

echo "Synchronized ${#asset_map[@]} jitter, self-test, retrospective and sensitivity figures"
