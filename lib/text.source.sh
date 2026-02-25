#!/usr/bin/env bash
# text.source.sh
# text utilities module.

# shellcheck disable=SC1091,SC2016

# Prevent multiple sourcing
[[ -n "${__TEXT_SOURCED+x}" ]] && return 0
__TEXT_SOURCED=1

# Internal field separator.
readonly __TEXT_SEP=$'\x1f'

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/string.source.sh"

# text_expand <regex> [--window from to]
# Structured expand of input lines by regex.
text_expand() {
  local regex="${1:?text_expand: missing regex}"
  shift
  local ratio_start=''
  local ratio_end=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  local line

  while IFS= read -r line; do
    string_expand "$line" "$regex" "$ratio_start" "$ratio_end"
  done
}

# text_filter <regex> [--window from to]
# Filter input lines by regex (optionally within a ratio window).
text_filter() {
  local regex="${1:?text_filter: missing regex}"
  shift
  local ratio_start=''
  local ratio_end=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  local line match

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue

    match=$(string_match "$line" "$regex" "$ratio_start" "$ratio_end")
    [[ -n "$match" ]] || continue

    printf '%s\n' "$line"
  done
}

# text_filter_expand <regex> [--window from to]
# Filter lines by regex and output structured expand results.
text_filter_expand() {
  local regex="${1:?text_filter_expand: missing regex}"
  shift
  local ratio_start=''
  local ratio_end=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

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

# text_supports <regex> [--window from to] [--support value]
# Check whether matching lines meet the required support ratio.
text_supports() {
  local regex="${1:?text_supports: missing regex}"
  shift
  local ratio_start=''
  local ratio_end=''
  local support='0.6'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --support)
        shift
        support="$1"
        shift
        ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
 
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

# Normalize Unicode text by compatibility decomposition.
# - Applies NFKD normalization.
# - Removes all combining marks (\p{M}).
# - Preserves original line structure.
# - Works as a stream filter (reads from stdin, writes to stdout).
text_demath() {
  __perl '
    use strict;
    use warnings;
    use Unicode::Normalize;

    while (<>) {
      $_ = NFKD($_);
      s/\p{M}//g;
      print;
    }
  '
}