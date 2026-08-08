#!/usr/bin/env bash

# Synchronise figures that are owned by the public BET 2026 diagnostic report.
# Every download is staged and validated before any checked-in report asset is
# replaced, so a partial Pages deployment cannot corrupt the report checkout.

set -euo pipefail

diagnostic_pages_root=${1:-https://pacificcommunity.github.io/ofp-sam-bet-2026-diagnostic}
diagnostic_source_sha=${2:-unknown}
report_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT

asset_map=(
  "figures/aspm-comparison.png|figures_new/aspm-comparison.png"
  "figures/cpue-fit-residuals.png|figures_new/cpue-fit-residuals.png"
  "figures/diagnostic-population-dynamics.png|figures_new/diagnostic-population-dynamics.png"
  "figures/hessian-parameter-scales.png|figures_new/hessian-parameter-scales.png"
  "figures/likelihood-profile-caal-region-detail.png|figures_new/likelihood-profile-caal-region-detail.png"
  "figures/likelihood-profile-components.png|figures_new/likelihood-profile-components.png"
  "figures/likelihood-profile-cpue-detail.png|figures_new/likelihood-profile-cpue-detail.png"
  "figures/likelihood-profile-lf-detail.png|figures_new/likelihood-profile-lf-detail.png"
  "figures/likelihood-profile-penalty-detail.png|figures_new/likelihood-profile-penalty-detail.png"
  "figures/likelihood-profile-tag-detail.png|figures_new/likelihood-profile-tag-detail.png"
  "figures/retrospective-diagnostics.png|figures_new/retrospective-diagnostics.png"
  "figures/self-test-diagnostics.png|figures_new/self-test-diagnostics.png"
  "mfclshiny/figures/age-data-fit-by-region.png|figures_new/age-data-fit-by-region.png"
  "mfclshiny/figures/f-juvenile-adult-by-area.png|figures_new/f-juvenile-adult-by-area-2col.png"
  "mfclshiny/figures/fishery-process.png|figures_new/fishery-process.png"
  "mfclshiny/figures/fishery-selectivity-length.png|figures_new/fishery-selectivity-length.png"
  "mfclshiny/figures/growth-curve.png|figures_new/growth-curve.png"
  "mfclshiny/figures/length-frequency.png|figures_new/length-frequency-fit-by-fishery.png"
  "mfclshiny/figures/recruitment-by-area.png|figures_new/recruitment-by-area-2col.png"
  "mfclshiny/figures/region-map.png|figures_new/region-map.png"
  "mfclshiny/figures/regional-movement.png|figures_new/regional-movement.png"
  "mfclshiny/figures/tag-attrition-by-program.png|figures_new/tag-attrition-by-program.png"
  "mfclshiny/figures/tag-reporting-rates-active.png|figures_new/tag-reporting-rates-active.png"
  "mfclshiny/figures/total-biomass-with-without-fishing.png|figures_new/total-biomass-with-without-fishing-2col.png"
)

data_map=(
  "tables/tag-reporting-rate-groups.csv|tables/source/tag-reporting-rate-groups.csv"
)

for mapping in "${asset_map[@]}"; do
  source_path=${mapping%%|*}
  destination_path=${mapping#*|}
  staged_path="$stage_dir/$destination_path"
  mkdir -p "$(dirname "$staged_path")"
  if [[ -d "$diagnostic_pages_root" ]]; then
    local_source="$diagnostic_pages_root/$source_path"
    test -s "$local_source"
    install -m 0644 "$local_source" "$staged_path"
  else
    curl --fail --location --retry 3 --retry-delay 2 \
      "$diagnostic_pages_root/$source_path" \
      --output "$staged_path"
  fi
  test -s "$staged_path"
  png_signature=$(od -An -tx1 -N8 "$staged_path" | tr -d ' \n')
  if [[ "$png_signature" != "89504e470d0a1a0a" ]]; then
    echo "Downloaded asset is not a PNG: $source_path" >&2
    exit 1
  fi
done

for mapping in "${data_map[@]}"; do
  source_path=${mapping%%|*}
  destination_path=${mapping#*|}
  staged_path="$stage_dir/$destination_path"
  mkdir -p "$(dirname "$staged_path")"
  if [[ -d "$diagnostic_pages_root" ]]; then
    local_source="$diagnostic_pages_root/$source_path"
    test -s "$local_source"
    install -m 0644 "$local_source" "$staged_path"
  else
    curl --fail --location --retry 3 --retry-delay 2 \
      "$diagnostic_pages_root/$source_path" \
      --output "$staged_path"
  fi
  test -s "$staged_path"
  grep -q '^"Group","Tag programmes","Pooled matrix row"' "$staged_path"
done

for mapping in "${asset_map[@]}"; do
  destination_path=${mapping#*|}
  install -D -m 0644 "$stage_dir/$destination_path" "$report_root/$destination_path"
done

for mapping in "${data_map[@]}"; do
  destination_path=${mapping#*|}
  install -D -m 0644 "$stage_dir/$destination_path" "$report_root/$destination_path"
done

manifest_path="$report_root/figures_new/UPSTREAM_DIAGNOSTIC.txt"
{
  printf 'source_url=%s\n' "$diagnostic_pages_root"
  printf 'source_commit=%s\n' "$diagnostic_source_sha"
  printf 'synced_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for mapping in "${asset_map[@]}"; do
    destination_path=${mapping#*|}
    sha256sum "$report_root/$destination_path"
  done
  for mapping in "${data_map[@]}"; do
    destination_path=${mapping#*|}
    sha256sum "$report_root/$destination_path"
  done
} > "$manifest_path"

echo "Synchronized ${#asset_map[@]} figures and ${#data_map[@]} source tables from $diagnostic_source_sha"
