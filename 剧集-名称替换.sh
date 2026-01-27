#!/usr/bin/env bash

# usage:
#   rename_by_replace.sh <dir> <ext> <search> <replace>
#
# search supports:
#   TEXT   : string replace
#   n-n    : range replace (1-based, inclusive)
#   -n     : before n
#   +n     : after n

set -euo pipefail

# ---- positional args ----
DIR="${1:?missing directory}"
EXT="${2:?missing extension}"
SEARCH="${3:?missing search text}"

# REPLACE may be empty, but must be provided
if [[ $# -lt 4 ]]; then
  echo "missing replace text" >&2
  exit 1
fi
REPLACE="$4"

shopt -s nullglob

# ---- parse SEARCH mode ----
MODE="search"
START=""
END=""

if [[ "$SEARCH" =~ ^([0-9]+)-([0-9]+)$ ]]; then
  MODE="range"
  START="${BASH_REMATCH[1]}"
  END="${BASH_REMATCH[2]}"
elif [[ "$SEARCH" =~ ^-([0-9]+)$ ]]; then
  MODE="before"
  START="1"
  END="${BASH_REMATCH[1]}"
elif [[ "$SEARCH" =~ ^\+([0-9]+)$ ]]; then
  MODE="after"
  START="${BASH_REMATCH[1]}"
fi

for file in "$DIR"/*."$EXT"; do
  name="$(basename "$file")"
  new="$name"

  case "$MODE" in
    search)
      new="${name//$SEARCH/$REPLACE}"
      ;;
    range)
      # 1-based → 0-based
      s0=$((START - 1))
      len=$((END - START + 1))
      new="${name:0:s0}${REPLACE}${name:s0+len}"
      ;;
    before)
      n="$END"
      new="${REPLACE}${name:n}"
      ;;
    after)
      n="$START"
      new="${name:0:n}${REPLACE}"
      ;;
  esac

  # 文件名未变化则跳过
  [[ "$name" == "$new" ]] && continue

  echo "rename:"
  echo "  $name"
  echo "  -> $new"

  mv -n -- "$file" "$DIR/$new"
done
