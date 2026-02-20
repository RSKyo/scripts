#!/usr/bin/env bash
# text.source.sh
# Line-based text utilities.
# - _text_* : array-based primitives (nameref output)
# - text_*  : stream wrappers (stdin → stdout)
# - Internal field separator: __TEXT_SEP

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

# _text_expand <out_ref> <regex> [from_ratio] [to_ratio]
# Apply _string_expand to each stdin line.
# Result written to <out_ref> (array).
_text_expand() {
  local -n out_ref="$1"
  local regex="${2:?_text_expand: missing regex}"
  local win_from_ratio="${3:-0}"
  local win_to_ratio="${4:-1}"

  out_ref=()
  local line line_expanded

  while IFS= read -r line; do
    _string_expand line_expanded \
      "$line" "$regex" "$win_from_ratio" "$win_to_ratio"

    out_ref+=("$line_expanded")
  done

  return 0
}

# text_expand <regex> [from_ratio] [to_ratio]
# Expand each stdin line and print results.
text_expand() {
  local -a result=()
  _text_expand result "$@"
  printf '%s\n' "${result[@]}"
}

# _text_filter <out_ref> <regex> [from_ratio] [to_ratio] [expand]
# Keep lines whose windowed match is non-empty.
# If expand=1, store expanded form; otherwise store original line.
# Result written to <out_ref> (array).
_text_filter() {
  local -n out_ref="$1"
  local regex="${2:?_text_filter: missing regex}"
  local win_from_ratio="${3:-0}"
  local win_to_ratio="${4:-1}"
  local expand="${5:-0}"

  out_ref=()
  local line line_expanded
  local left match right

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue

    _string_expand line_expanded \
      "$line" "$regex" "$win_from_ratio" "$win_to_ratio"

    IFS="$__TEXT_SEP" read -r left match right <<< "$line_expanded"
    [[ -n "$match" ]] || continue

    if (( expand )); then
      out_ref+=("$line_expanded")
    else
      out_ref+=("$line")
    fi
  done

  return 0
}

# text_filter <regex> [from_ratio] [to_ratio] [expand]
# Filter stdin lines by match condition.
text_filter() {
  local -a result=()
  _text_filter result "$@"
  printf '%s\n' "${result[@]}"
}

# text_supports <regex> [from_ratio] [to_ratio] [support]
# Return 0 if match ratio >= support threshold.
# No stdout.
text_supports() {
  local regex="${1:?text_supports: missing regex}"
  local win_from_ratio="${2:-0}"
  local win_to_ratio="${3:-1}"
  local support="${4:-0.6}"
 
  # --- Process lines ---
  local total=0 hits=0
  local line line_expanded
  local left match right

  while IFS= read -r line; do
    (( total++ ))
    [[ -n "$line" ]] || continue

    _string_expand line_expanded \
      "$line" "$regex" "$win_from_ratio" "$win_to_ratio"

    IFS="$__TEXT_SEP" read -r left match right <<< "$line_expanded"
    [[ -n "$match" ]] || continue
    (( hits++ ))
  done

  (( total == 0 )) && return 1

  # support ratio check
  # hits / total >= support
  num_ratio_cmp "$hits" "$total" ge "$support"
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

# array_unique_count <arr_ref>
# Print number of unique elements in array.
array_unique_count() {
  local -n arr_ref="$1"
  local -A seen=()
  local v
  for v in "${arr_ref[@]}"; do
    seen["$v"]=1
  done
  printf '%s\n' "${#seen[@]}"
}

# text_to_array <out_ref> [sep] [col]
# Read stdin into array.
# Without sep/col: each line is an element.
# With sep + col (1-based): extract specified column.
# Out-of-range column yields empty string.
# Result written to <out_ref>.
text_to_array() {
  local -n out_ref="$1"
  local sep="$2"
  local col="$3"

  local -a original=()
  local line
  while IFS= read -r line; do
    original+=("$line")
  done

  [[ -n "$sep" && -n "$col" ]] || { 
    out_ref=("${original[@]}"); 
    return 0; 
  }

  num_is_int "$col" || return 1
  (( col >= 1 )) || return 1

  local idx=$((col - 1))
  local -a fields=()
  
  out_ref=()
  for line in "${original[@]}"; do
    IFS="$sep" read -r -a fields <<< "$line"
    if (( idx < ${#fields[@]} )); then
      out_ref+=("${fields[idx]}")
    else
      out_ref+=('')
    fi
  done

  return 0
}
