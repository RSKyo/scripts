#!/usr/bin/env bash
# file.source.sh

# Prevent multiple sourcing
[[ -n "${__FILE_SOURCED+x}" ]] && return 0
__FILE_SOURCED=1

file_write() {
  local file_name="${1:?file_write: missing file name}"
  shift
  local dir="$YT_CACHE_DIR"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) 
        shift
        [[ $# -ge 1 ]] || return 2
        dir="$1"
        shift
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done
  
  local append=0
  local tee=0
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --append)
        shift
        append=1
        ;;
      --tee)
        shift
        tee=1
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  mkdir -p "$dir" || {
    loge "Cannot create directory: $dir"
    return 1
  }

  local file_path="$dir/$file_name"

  if (( tee )); then
    if (( append )); then
      tee -a "$file_path"
    else
      tee "$file_path"
    fi
    return $?
  fi

  if (( append )); then
    cat >> "$file_path"
  else
    cat > "$file_path"
  fi
}