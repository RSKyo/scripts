#!/usr/bin/env bash
# file.source.sh

# Prevent multiple sourcing
[[ -n "${__FILE_SOURCED+x}" ]] && return 0
__FILE_SOURCED=1

file_tee() {
  local dir="$1"
  local file_name="$2"
  shift 2

  # Fallback: stdout only
  if [[ -z "$dir" || -z "$file_name" ]]; then
    logi "Missing directory or file name, fallback to stdout only."
    cat
    return 0
  fi

  mkdir -p "$dir"
  local path="$dir/$file_name"

  local append=0
  [[ "${1:-}" == "--append" ]] && append=1 && shift

  if (( append )); then
    tee -a "$path"
  else
    tee "$path"
  fi
}

file_write() {
  local dir="$1"
  local file_name="$2"
  shift 2

  if [[ -z "$dir" || -z "$file_name" ]]; then
    logi "Missing directory or file name, nothing written."
    cat >/dev/null
    return 0
  fi

  mkdir -p "$dir"
  local path="$dir/$file_name"

  local append=0
  [[ "${1:-}" == "--append" ]] && append=1 && shift

  if (( append )); then
    cat >> "$path"
  else
    cat > "$path"
  fi
}