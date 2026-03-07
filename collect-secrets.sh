#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <secrets.env.example>"
  echo ""
  echo "Interactively prompts for each variable defined in the example file"
  echo "and writes the filled values to secrets.env in the same directory."
  echo ""
  echo "Features:"
  echo "  - Comments above variables are shown as descriptions"
  echo "  - Default values (VAR=default) are offered and accepted with Enter"
  echo "  - Existing values in secrets.env are preserved as defaults"
  echo "  - Password-like variables (containing PASS, SECRET, TOKEN) use hidden input"
  exit 1
}

[ $# -lt 1 ] && usage

EXAMPLE_FILE="$1"

if [ ! -f "$EXAMPLE_FILE" ]; then
  echo "Error: example file '$EXAMPLE_FILE' not found"
  exit 1
fi

SECRETS_DIR="$(dirname "$EXAMPLE_FILE")"
SECRETS_FILE="$SECRETS_DIR/secrets.env"

# Load existing secrets for pre-filling
declare -A EXISTING=()
if [ -f "$SECRETS_FILE" ]; then
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    EXISTING["$key"]="$val"
  done < "$SECRETS_FILE"
fi

# Parse the example file and collect secrets
OUTPUT=""
PENDING_COMMENTS=""

while IFS= read -r line; do
  # Blank line: pass through and reset pending comments
  if [[ -z "$line" ]]; then
    OUTPUT+=$'\n'
    PENDING_COMMENTS=""
    continue
  fi

  # Comment line: accumulate for display, pass through
  if [[ "$line" =~ ^[[:space:]]*# ]]; then
    PENDING_COMMENTS+="${line#"${line%%[! ]*}"}"$'\n'  # strip leading spaces
    OUTPUT+="$line"$'\n'
    continue
  fi

  # Variable line: extract key and example default
  key="${line%%=*}"
  example_default="${line#*=}"

  # Determine the best default: existing value > example default
  default="${EXISTING[$key]:-$example_default}"

  # Show accumulated comments as context
  if [ -n "$PENDING_COMMENTS" ]; then
    echo ""
    echo "$PENDING_COMMENTS" | sed 's/^/  /'
  fi
  PENDING_COMMENTS=""

  # Decide if input should be hidden (password-like fields)
  hide=false
  upper_key="${key^^}"
  if [[ "$upper_key" == *PASS* || "$upper_key" == *SECRET* || "$upper_key" == *TOKEN* ]]; then
    hide=true
  fi

  # Build the prompt
  if [ -n "$default" ]; then
    if $hide; then
      prompt="  $key [****]: "
    else
      prompt="  $key [$default]: "
    fi
  else
    prompt="  $key: "
  fi

  # Read the value
  if $hide; then
    read -r -s -p "$prompt" value
    echo ""  # newline after hidden input
  else
    read -r -p "$prompt" value
  fi

  # Use default if empty
  value="${value:-$default}"

  OUTPUT+="$key=$value"$'\n'

done < "$EXAMPLE_FILE"

# Write the secrets file
echo "$OUTPUT" > "$SECRETS_FILE"
echo ""
echo "Secrets written to $SECRETS_FILE"
