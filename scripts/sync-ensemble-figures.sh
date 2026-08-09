#!/usr/bin/env bash

# Synchronise report-ready figures owned by the public BET 2026 ensemble report.

set -euo pipefail

ensemble_pages_root=${1:-https://pacificcommunity.github.io/ofp-sam-bet-2026-ensemble}
ensemble_source_sha=${2:-unknown}
report_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT

asset_map=(
  "figures/natural-mortality-evidence.png|figures_new/natural-mortality-evidence.png"
  "figures/projection-stock-trajectories.png|figures_new/projection-stock-trajectories.png"
)

for mapping in "${asset_map[@]}"; do
  source_path=${mapping%%|*}
  destination_path=${mapping#*|}
  staged_path="$stage_dir/$destination_path"
  mkdir -p "$(dirname "$staged_path")"
  if [[ -d "$ensemble_pages_root" ]]; then
    local_source="$ensemble_pages_root/$source_path"
    test -s "$local_source"
    install -m 0644 "$local_source" "$staged_path"
  else
    curl --fail --location --retry 3 --retry-delay 2 \
      "$ensemble_pages_root/$source_path" --output "$staged_path"
  fi
  test -s "$staged_path"
  test "$(od -An -tx1 -N8 "$staged_path" | tr -d ' \n')" = "89504e470d0a1a0a"
done

for mapping in "${asset_map[@]}"; do
  destination_path=${mapping#*|}
  install -D -m 0644 "$stage_dir/$destination_path" "$report_root/$destination_path"
done

manifest_path="$report_root/figures_new/UPSTREAM_ENSEMBLE.txt"
{
  printf 'source_url=%s\n' "$ensemble_pages_root"
  printf 'source_commit=%s\n' "$ensemble_source_sha"
  for mapping in "${asset_map[@]}"; do
    destination_path=${mapping#*|}
    checksum=$(sha256sum "$report_root/$destination_path" | cut -d' ' -f1)
    printf '%s  %s\n' "$checksum" "$destination_path"
  done
} > "$manifest_path"

echo "Synchronized ${#asset_map[@]} ensemble figures from $ensemble_source_sha"
