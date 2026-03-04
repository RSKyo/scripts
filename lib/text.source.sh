#!/usr/bin/env bash
# text.source.sh
# text utilities module.

# shellcheck disable=SC1091,SC2016

# Prevent multiple sourcing
[[ -n "${__TEXT_SOURCED+x}" ]] && return 0
__TEXT_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/string.source.sh"

# text_expand <regex> [--window from to]
# Structured expand of input lines by regex.
text_expand() {
  # --- Params ---
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
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  local line

  while IFS= read -r line; do
    string_expand "$line" "$regex" \
        ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}}
  done
}

# text_expand_side <regex> [--window from to] [--side left|right]
# Expand input lines by regex and output only the selected side.
text_expand_side() {
  # --- Params ---
  local regex="${1:?text_expand_side: missing regex}"
  shift
  local ratio_start=''
  local ratio_end=''
  local side='left'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --side) 
        shift
        [[ $# -ge 1 ]] || return 2
        case "$1" in
          left|right) side="$1" ;;
          *) return 2 ;;
        esac
        shift
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  local line

  while IFS= read -r line; do
    string_expand_side "$line" "$regex" \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
      --side "$side"
  done
}

# text_filter <regex> [--window from to]
# Filter input lines by regex (optionally within a ratio window).
text_filter() {
  # --- Params ---
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
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  local line

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    string_match "$line" "$regex" \
        ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} || continue

    printf '%s\n' "$line"
  done
}

# text_supports <regex> [--window from to] [--support value]
# Check whether matching lines meet the required support ratio.
text_supports() {
  # --- Params ---
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
        [[ $# -ge 1 ]] || return 2
        support="$1"
        shift
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done
 
  local total=0 hits=0
  local line

  while IFS= read -r line; do
    # total includes empty lines
    (( total++ ))
    [[ -z "$line" ]] && continue

    string_match "$line" "$regex" \
        ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} || continue

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