#!/usr/bin/env bash
# fix_permissions.sh
#
# Fix executable permissions for the scripts repository.
#
# Scope:
# - All non-hidden files under bin/*/*
# - All *.sh files under scripts/ (including source-only libraries)
#
# This script is safe to run multiple times (idempotent).
#
# Usage:
#   bash scripts/core/fix_permissions.sh

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[INFO] Fixing executable permissions under: $BASE_DIR"
echo

fixed=0

# -------------------------------------------------
# 1. Fix binaries under bin/<platform>/
#    Rule: all non-hidden files
# -------------------------------------------------

if [ -d "$BASE_DIR/bin" ]; then
  while IFS= read -r -d '' file; do
    if [ ! -x "$file" ]; then
      chmod +x "$file"
      echo "[FIXED] +x binary: $file"
      fixed=$((fixed + 1))
    fi
  done < <(
    find "$BASE_DIR/bin" \
      -mindepth 2 -maxdepth 2 \
      -type f \
      ! -name '.*' \
      -print0
  )
fi

# -------------------------------------------------
# 2. Fix all .sh files (including source-only)
#    Rule: *.sh everywhere except bin/
# -------------------------------------------------

while IFS= read -r -d '' file; do
  if [ ! -x "$file" ]; then
    chmod +x "$file"
    echo "[FIXED] +x script: $file"
    fixed=$((fixed + 1))
  fi
done < <(
  find "$BASE_DIR" \
    -type f -name '*.sh' \
    ! -path "$BASE_DIR/bin/*" \
    -print0
)

echo

if [ "$fixed" -eq 0 ]; then
  echo "[INFO] No changes needed. All permissions already correct."
else
  echo "[INFO] Fixed permissions on $fixed file(s)."
fi
