#!/usr/bin/env bash
# Source-only library: lib/file

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__FILE_SOURCED+x}" ]] && return 0
__FILE_SOURCED=1

# --- Public API --------------------------------------------------------------

file_write() {
  local file_path="${1:?file_write: missing file path}"
  shift
  local append=0
  local tee=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --append) shift; append=1; ;;
      --tee) shift; tee=1; ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local dir="${file_path%/*}"
  mkdir -p "$dir" || {
    loge "Cannot create directory: $dir"
    return 1
  }

  if (( tee )); then
    if (( append )); then
      tee -a "$file_path"
    else
      tee "$file_path"
    fi
    return
  fi

  if (( append )); then
    cat >> "$file_path"
  else
    cat > "$file_path"
  fi
}
