#!/usr/bin/env bash
# text.source.sh
# text utilities module.

# shellcheck disable=SC1091

# Prevent multiple sourcing
[[ -n "${__TEXT_SOURCED+x}" ]] && return 0
__TEXT_SOURCED=1

# Internal field separator.
readonly __TEXT_SEP=$'\x1f'

# Dependencies (bootstrap must be sourced by the entry script)
source "$INFRA_DIR/options.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/num.source.sh"

# text_expand <regex> [ratio_start] [ratio_end]
# Expand each line within ratio window (0–1).
text_expand() {
  local regex="${1:?text_expand: missing regex}"
  local ratio_start="${2:-0}"
  local ratio_end="${3:-1}"
  local line

  while IFS= read -r line; do
    string_expand "$line" "$regex" "$ratio_start" "$ratio_end"
  done
}

# text_filter <regex> [ratio_start] [ratio_end]
# Output original lines whose match is non-empty within ratio window (0–1).
text_filter() {
  local regex="${1:?text_filter: missing regex}"
  local ratio_start="${2:-0}"
  local ratio_end="${3:-1}"

  local line match

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue

    match=$(string_match "$line" "$regex" "$ratio_start" "$ratio_end")
    [[ -n "$match" ]] || continue

    printf '%s\n' "$line"
  done
}

# text_filter_expand <regex> [ratio_start] [ratio_end]
# Output expanded lines whose match is non-empty within ratio window (0–1).
text_filter_expand() {
  local regex="${1:?text_filter: missing regex}"
  local ratio_start="${2:-0}"
  local ratio_end="${3:-1}"

  local line line_expanded
  local match _

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue

    line_expanded=$(string_expand "$line" "$regex" "$ratio_start" "$ratio_end")
    IFS="$STRING_SEP" read -r _ match _ <<< "$line_expanded"
    [[ -n "$match" ]] || continue

    printf '%s\n' "$line_expanded"
  done
}

# text_supports <regex> [ratio_start] [ratio_end] [support]
# Return 0 if hit ratio ≥ support (default 0.6).
# Hit ratio is based on all input lines.
text_supports() {
  local regex="${1:?text_supports: missing regex}"
  local ratio_start="${2:-0}"
  local ratio_end="${3:-1}"
  local support="${4:-0.6}"
 
  local total=0 hits=0
  local line match

  while IFS= read -r line; do
    # total includes empty lines
    (( total++ ))
    [[ -n "$line" ]] || continue

    match=$(string_match "$line" "$regex" "$ratio_start" "$ratio_end")
    [[ -n "$match" ]] || continue

    (( hits++ ))
  done

  local hits_ratio
  hits_ratio=$(num_quotient "$hits" "$total") || return 1
  num_cmp "$hits_ratio" ge "$support"
}

# text_lines_count
# Print number of stdin lines.
text_lines_count() {
  local n
  n=$(wc -l)
  printf '%s\n' "${n//[[:space:]]/}"
}

# text_unique_count
# Print number of unique stdin lines.
text_unique_count() {
  local n
  n=$(sort -u | wc -l)
  printf '%s\n' "${n//[[:space:]]/}"
}
