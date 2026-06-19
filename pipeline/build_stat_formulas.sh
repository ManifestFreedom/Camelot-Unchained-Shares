#!/bin/env sh
# build_stat_formulas.sh
#
# Usage: ./build_stat_formulas.sh [output_path]
#
# Reads:   stats.json       (API stats array, already extracted)
#          stat_ui_config.json   (editorial display config: groups, labels, formats)
# Writes:  $OUTPUT               (default: ../statcalc/github-pages/public/stat_formulas.json)
#
# This script is the build step between the CU API pull and the SPA.
# Run it whenever only_stats.json is updated (after the API diff pipeline).
# The SPA fetches stat_formulas.json at runtime; no code changes are needed
# when formulas change — just run this script and push the output.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="${1:-$SCRIPT_DIR/../stat_formulas.json}"
VERSION="$(date -u +%Y-%m-%d)"

echo "Building stat_formulas.json (version: $VERSION)..."

jq \
  --from-file "$SCRIPT_DIR/build_stat_formulas.jq" \
  --argjson ui "$(cat "$SCRIPT_DIR/stat_ui_config.json")" \
  --arg version "$VERSION" \
  "$SCRIPT_DIR/stats.json" \
  > "$OUTPUT"

echo "Written to: $OUTPUT"

# Sanity check: confirm all UI-referenced stat ids are present in formulas
echo "Validating UI group references..."
jq -e '
  (.ui.groups | map(.stats[]) | unique) as $ui_ids |
  (.formulas | keys) as $formula_ids |
  ($ui_ids | map(select(. as $id | ($formula_ids | index($id)) == null))) |
  if length > 0
  then error("UI group references stats with no formula: \(.)")
  else "All UI stat references resolved OK"
  end
' "$OUTPUT" -r

echo "Done."
