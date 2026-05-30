#!/usr/bin/env bash

set -euo pipefail

COMMAND="${1:-}"

shift || true

usage() {
  echo "usage:"
  echo "  $0 remove-line <keyword>"
}

cmd_remove_line() {
  local keyword="${1:-}"

  if [[ -z "$keyword" ]]; then
    usage
    exit 1
  fi

 find . \
    -type f \
    -name "*.ass" \
    ! -name "._*" \
  | while IFS= read -r file; do

    local tmp_file
    tmp_file="$(mktemp)"

    grep -vF "$keyword" "$file" \
    | sed '/^[[:space:]]*$/d' \
    > "$tmp_file"

    mv "$tmp_file" "$file"

    # echo "cleaned: $file"
  done
}

cmd_replace() {
  local search
  local replace

  printf "search: "
  IFS= read -r search

  printf "replace: "
  IFS= read -r replace

  local count=0

find . \
  -type f \
  -name "*.ass" \
  ! -name "._*" \
| while IFS= read -r file; do
    local escaped_search
    local escaped_replace

    escaped_search="$(printf '%s\n' "$search" | sed 's/[\/&]/\\&/g')"
    escaped_replace="$(printf '%s\n' "$replace" | sed 's/[\/&]/\\&/g')"

    LC_ALL=C sed -i '' \
      "s/${escaped_search}/${escaped_replace}/g" \
      "$file"

    count=$((count + 1))

    printf "\r\033[Kprocessing (%d): %s" \
      "$count" \
      "$(basename "$file")"
  done

  echo
  echo "done"
}

cmd_reset_header() {
  local count=0

  find . \
    -type f \
    -name "*.ass" \
    ! -name "._*" \
  | while IFS= read -r file; do

    local tmp_file
    tmp_file="$(mktemp)"

    cat > "$tmp_file" <<'EOF'
[Script Info]
ScriptType: v4.00+
Collisions: Normal
PlayResX: 384
PlayResY: 288
Timer: 100.0000
WrapStyle: 0
ScaledBorderAndShadow: no

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Source Han Sans SC,16,&H00FFFFFF,&H000000FF,&H00000000,&H32000000,0,0,0,0,100,100,0,0,1,2,1,2,8,8,10,134
Style: Eng,Arial,15,&H0078D7FF,&H000000FF,&H00000000,&H28000000,0,0,0,0,100,100,0,0,1,1,0,2,8,8,6,0

EOF

    awk '
      found {
        print
      }

      /^\[Events\]/ {
        found = 1
        print
      }
    ' "$file" >> "$tmp_file"

    mv "$tmp_file" "$file"

    count=$((count + 1))

    printf "\r\033[Kprocessing (%d): %s" \
      "$count" \
      "$(basename "$file")"
  done

  echo
  echo "done"
}

case "$COMMAND" in
  remove-line)
    cmd_remove_line "$@"
    ;;
    replace)
    cmd_replace "$@"
    ;;
    reset-header)
  cmd_reset_header
  ;;
  *)
    usage
    exit 1
    ;;
esac