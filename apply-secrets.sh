#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <recipe-dir> [secrets-file]"
  echo ""
  echo "Processes all *.tpl files in <recipe-dir>, replacing \${VAR} references"
  echo "with values from the secrets file. Output is written to the same path"
  echo "with the .tpl extension stripped."
  echo ""
  echo "Arguments:"
  echo "  recipe-dir    Path to the recipe directory (e.g. home-server)"
  echo "  secrets-file  Path to secrets env file (default: <recipe-dir>/secrets.env)"
  exit 1
}

[ $# -lt 1 ] && usage

RECIPE_DIR="$1"
SECRETS_FILE="${2:-${RECIPE_DIR}/secrets.env}"

if [ ! -d "$RECIPE_DIR" ]; then
  echo "Error: recipe directory '$RECIPE_DIR' not found"
  exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
  echo "Error: secrets file '$SECRETS_FILE' not found"
  echo "Copy secrets.env.example to secrets.env and fill in the values."
  exit 1
fi

# Build the list of variable names defined in the secrets file,
# so envsubst only replaces those (leaving other $VARs intact).
VARS=$(grep -v '^#' "$SECRETS_FILE" | grep -v '^$' | cut -d= -f1 | sed 's/^/$/g' | paste -sd' ')

set -a
# shellcheck disable=SC1090
source "$SECRETS_FILE"
set +a

FOUND=0
while IFS= read -r tpl; do
  out="${tpl%.tpl}"
  envsubst "$VARS" < "$tpl" > "$out"
  echo "  ${tpl} -> ${out}"
  FOUND=$((FOUND + 1))
done < <(find "$RECIPE_DIR" -name '*.tpl' -type f)

if [ "$FOUND" -eq 0 ]; then
  echo "No .tpl files found in '$RECIPE_DIR'"
else
  echo "Processed $FOUND template(s)."
fi
