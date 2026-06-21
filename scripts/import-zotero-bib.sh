#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/import-zotero-bib.sh /path/to/exported.bib [destination]

Default destination:
  bet-2026-report/references.bib

Export the Zotero collection first, preferably as Better BibLaTeX when Better
BibTeX is installed. This script validates that the export looks like a BibTeX
or BibLaTeX file, then copies it into the report bibliography path.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

source_bib="${1:-}"
destination="${2:-bet-2026-report/references.bib}"

if [[ -z "$source_bib" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "$source_bib" ]]; then
  echo "Source .bib file not found: $source_bib" >&2
  exit 2
fi

if ! grep -Eq '^[[:space:]]*@[A-Za-z]+' "$source_bib"; then
  echo "Source file does not look like a BibTeX/BibLaTeX export: $source_bib" >&2
  exit 2
fi

mkdir -p "$(dirname "$destination")"
cp "$source_bib" "$destination"

entry_count="$(grep -Ec '^[[:space:]]*@[A-Za-z]+' "$destination" || true)"
echo "Imported ${entry_count} bibliography entries into ${destination}."
echo "Review with: git diff -- ${destination}"
