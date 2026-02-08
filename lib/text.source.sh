#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
#
# text.source.sh
#
# Line-based text helpers for filtering, splitting, and detection.
#

# Prevent multiple sourcing
[[ -n "${__TEXT_SOURCED+x}" ]] && return 0
__TEXT_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/num.source.sh"

# text_filter <regex>
#
# Filter stdin line by line using a Bash regex.
#
# - stdout: matched lines
# - return: always 0
text_filter() {
  local regex="$1"
  [[ -z "$regex" ]] && return 0

  while IFS= read -r line; do
    [[ "$line" =~ $regex ]] || continue
    printf '%s\n' "$line"
  done
}

# text_filter_parts <regex> [--sep SEP] [--window START END]
#
# Filter lines by regex and split each matched line into:
#   left | match | right
#
# - --sep SEP
#     Output field separator (default: ASCII Unit Separator \x1f)
#
# - --window START END
#     Restrict where a match may occur (relative range [0.0, 1.0])
#
# - stdout: left<sep>match<sep>right
# - return: always 0
#
# Notes:
# - Lines are trimmed before processing.
# - Only the first match is considered.
text_filter_parts() {
  local regex=
  local sep=$'\x1f'
  local win_start=
  local win_end=

  # first positional argument: regex
  regex="$1"
  shift || true
  [[ -z "$regex" ]] && return 0

  # parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sep)
        sep="$2"
        shift 2
        ;;
      --window)
        win_start="$2"
        win_end="$3"
        shift 3
        ;;
      --)
        shift
        break
        ;;
      *)
        # unknown option: ignore
        shift
        ;;
    esac
  done

  while IFS= read -r line; do
    line="$(string_trim "$line")"
    [[ -n "$line" ]] || continue

    # decide match window: full line or window slice
    local window="$line"
    local window_left=''
    local window_right=''

    # apply window only if explicitly provided
    if [[ -n "$win_start" && -n "$win_end" ]]; then
      local len=${#line}
      (( len > 0 )) || continue

      local start=$(( len * win_start ))
      local end=$(( len * win_end ))
      (( end > start )) || continue

      window="${line:start:end-start}"
      window_left="${line:0:start}"
      window_right="${line:end}"
    fi

    # match within window
    [[ "$window" =~ $regex ]] || continue

    # extract parts based on first full-line match
    local match="${BASH_REMATCH[0]}"
    local left="$window_left${window%%"$match"*}"
    local right="${window#*"$match"}$window_right"

    printf '%s%s%s%s%s\n' "$left" "$sep" "$match" "$sep" "$right"
  done

  return 0
}

# text_detect <regex> [--support RATIO] [--window START END]
#
# Detect whether a text exhibits a feature based on per-line match ratio.
#
# - --support RATIO
#     Minimum ratio of matched lines (default: 0.6)
#
# - --window START END
#     Restrict where a match may occur (relative range [0.0, 1.0])
#
# - return:
#     0 if matched line ratio >= support
#     1 otherwise
#
# Notes:
# - Lines are trimmed before evaluation.
# - Window semantics are consistent with text_filter_parts.
text_detect() {
  local regex=
  local support=0.6
  local win_start=
  local win_end=

  # first positional argument: regex
  regex="$1"
  shift || true
  [[ -z "$regex" ]] && return 1

  # parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --support)
        support="$2"
        shift 2
        ;;
      --window)
        win_start="$2"
        win_end="$3"
        shift 3
        ;;
      --)
        shift
        break
        ;;
      *)
        # unknown option: ignore
        shift
        ;;
    esac
  done

  local total=0
  local hits=0

  while IFS= read -r line; do
    line="$(string_trim "$line")"
    [[ -n "$line" ]] || continue

    # decide match window: full line or window slice
    local window="$line"

    ((total++))

    # apply window only if explicitly provided
    if [[ -n "$win_start" && -n "$win_end" ]]; then
      local len=${#line}
      (( len > 0 )) || continue

      local start=$(( len * win_start ))
      local end=$(( len * win_end ))
      (( end > start )) || continue

      window="${line:start:end-start}"
    fi

    [[ "$window" =~ $regex ]] || continue
    ((hits++))
  done

  [[ "$total" -eq 0 ]] && return 1

  num_ratio_ge "$hits" "$total" "$support"
}








