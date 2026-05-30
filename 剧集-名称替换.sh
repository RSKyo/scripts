#!/usr/bin/env bash

set -euo pipefail

# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../../infra/bootstrap.source.sh"

#
# 用法：
#
# 1、按 SxxExx 重建文件名
#
# ./rename.sh episode "." "mkv" "Better.Call.Saul" "2160p.NF.WEB-DL"
#
#
# 2、普通字符串替换
#
# ./rename.sh replace "." "mkv" "WEB-DL" "BluRay"
#
#
# 3、字幕跟随 mkv
#
# ./rename.sh subtitle-sync "."
#

usage() {
  echo "usage:"
  echo
  echo "  $0 episode <dir> <exts> <prefix> <suffix>"
  echo "  $0 replace <dir> <exts> <search> <replace>"
  echo "  $0 subtitle-sync <dir>"
  echo
  echo "examples:"
  echo
  echo "  $0 episode \".\" \"mkv\" \"Better.Call.Saul\" \"2160p.NF.WEB-DL\""
  echo
  echo "  $0 replace \".\" \"mkv\" \"WEB-DL\" \"BluRay\""
  echo
  echo "  $0 subtitle-sync \".\""
}

build_find_args() {
  local exts="$1"

  IFS=',' read -ra items <<< "$exts"

  FIND_ARGS=()

  for ext in "${items[@]}"; do
    if [[ ${#FIND_ARGS[@]} -gt 0 ]]; then
      FIND_ARGS+=(-o)
    fi

    FIND_ARGS+=(-name "*.${ext}")
  done
}

rename_episode() {
  local root="${1:-}"
  local exts="${2:-}"
  local prefix="${3:-}"
  local suffix="${4:-}"

  if [[ -z "$root" || -z "$exts" || -z "$prefix" || -z "$suffix" ]]; then
    usage
    exit 1
  fi

  build_find_args "$exts"

  local count=0

  find "$root" \
    -type f \
    \( "${FIND_ARGS[@]}" \) \
    ! -name "._*" \
  | while IFS= read -r file; do

    local filename
    filename="$(basename "$file")"

    local dir
    dir="$(dirname "$file")"

    #
    # 只要包含 SxxExx 即可
    #
    if [[ ! "$filename" =~ (S[0-9]{2}E[0-9]{2}) ]]; then
      continue
    fi

    local episode="${BASH_REMATCH[1]}"

    local ext
    ext="${filename##*.}"

    local new_name="${prefix}.${episode}.${suffix}.${ext}"
    local new_path="$dir/$new_name"

    if [[ "$file" == "$new_path" ]]; then
      continue
    fi

    if [[ -e "$new_path" ]]; then
      continue
    fi

    mv "$file" "$new_path"

    count=$((count + 1))

    printf "\r\033[Kepisode (%d): %s" \
      "$count" \
      "$new_name"
  done

  echo
  echo "done"
}

replace_name() {
  local root="${1:-}"
  local exts="${2:-}"
  local search="${3:-}"
  local replace="${4:-}"

  if [[ -z "$root" || -z "$exts" || -z "$search" ]]; then
    usage
    exit 1
  fi

  build_find_args "$exts"

  local count=0

  find "$root" \
    -type f \
    \( "${FIND_ARGS[@]}" \) \
    ! -name "._*" \
  | while IFS= read -r file; do

    local filename
    filename="$(basename "$file")"

    local dir
    dir="$(dirname "$file")"

    if [[ "$filename" != *"$search"* ]]; then
      continue
    fi

    local new_name
    new_name="${filename//$search/$replace}"

    local new_path="$dir/$new_name"

    if [[ "$file" == "$new_path" ]]; then
      continue
    fi

    if [[ -e "$new_path" ]]; then
      continue
    fi

    mv "$file" "$new_path"

    count=$((count + 1))

    printf "\r\033[Kreplace (%d): %s" \
      "$count" \
      "$new_name"
  done

  echo
  echo "done"
}

sync_subtitle() {
  local root="${1:-}"

  if [[ -z "$root" ]]; then
    usage
    exit 1
  fi

  local count=0

  find "$root" \
    -type f \
    \( -name "*.ass" -o -name "*.srt" \) \
    ! -name "._*" \
  | while IFS= read -r file; do

    local filename
    filename="$(basename "$file")"

    local dir
    dir="$(dirname "$file")"

    if [[ ! "$filename" =~ (S[0-9]{2}E[0-9]{2}) ]]; then
      continue
    fi

    local episode="${BASH_REMATCH[1]}"

    local mkv_file
    mkv_file="$(
      find "$root" \
        -type f \
        -name "*${episode}*.mkv" \
        ! -name "._*" \
      | head -n 1
    )"

    if [[ -z "$mkv_file" ]]; then
      continue
    fi

    local mkv_name
    mkv_name="$(basename "$mkv_file")"

    local base_name
    base_name="${mkv_name%.*}"

    local ext
    ext="${filename##*.}"

    local new_name="${base_name}.${ext}"
    local new_path="$dir/$new_name"

    if [[ "$file" == "$new_path" ]]; then
      continue
    fi

    if [[ -e "$new_path" ]]; then
      continue
    fi

    mv "$file" "$new_path"

    count=$((count + 1))

    printf "\r\033[Ksubtitle (%d): %s" \
      "$count" \
      "$new_name"
  done

  echo
  echo "done"
}

main() {
  local method="${1:-}"

  shift || true

  case "$method" in
    episode)
      rename_episode "$@"
      ;;

    replace)
      replace_name "$@"
      ;;

    subtitle-sync)
      sync_subtitle "$@"
      ;;

    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"