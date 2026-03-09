#!/usr/bin/env bash
# Source-only library: lib/yt/video/meta
# shellcheck disable=SC1091,SC2154,SC2016

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
__YT_VIDEO_META_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/text.source.sh"

source "$LIB_DIR/yt/video/url.source.sh"

# --- Constants ---------------------------------------------------------------

declare -Ar YT_VIDEO_META_FILTER_MAP=(
  [id]='.id // empty'
  [title]='.title // empty'
  [title_en]='.title_en // empty'
  [duration]='.duration // 0'
  [description]='.description // empty'
)

# --- Internal Helpers --------------------------------------------------------

__yt_video_meta_title_en() {
  local file_path="$1"

  local title filter title_en
  filter="${YT_VIDEO_META_FILTER_MAP[title]}"
  title=$("$jq_bin" -r "$filter" "$file_path")  || return 1
  title_en=$(string_translate_to_en "$title")
  title_en=$(letter_demath "$title_en")
  title_en=$(string_normalize "$title_en" -)

  local -a segments
  readarray -t segments < <(letter_split_segments "$title_en") || return 1

  
  local seg title_en_trimmed=''
  for seg in "${segments[@]}"; do
    seg=$(letter_trim "$seg" "0123456789-【[（()）]】")
    [[ -n "$seg" ]] || continue
    title_en_trimmed+="${title_en_trimmed:+ }$seg"
  done

  local tmp
  tmp="${file_path}.tmp"

  "$jq_bin" \
    --arg title_en "$title_en_trimmed" \
    '.title_en = $title_en' \
    "$file_path" > "$tmp" || return 1

  mv "$tmp" "$file_path"
}

__yt_video_meta_cache_build() {
  local url="$1"
  local file_path="$2"

  logi "fetch video meta: $url"

  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --dump-json \
    "$url" 2>/dev/null |
  text_file "$file_path" || {
    loge "failed to download video meta: $url"
    return 1
  }

  __yt_video_meta_title_en "$file_path"

  logi "meta cache saved: $file_path"
}

# --- Public API --------------------------------------------------------------

yt_video_meta_download() {
  local input="${1:?yt_video_meta_download: missing url}"
  local dir="${2:-"$YT_CACHE_DIR"}"

  local id url meta_name meta_path
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2
  meta_name="${id}.${YT_CACHE_META_NAME}"
  meta_path="${dir%/}/${YT_CACHE_META_FOLDER}/${meta_name}"
  
  if [[ -s "$meta_path" ]]; then
    __yt_video_meta_cache_build "$url" "$meta_path" || return 1
  else
    logi "meta cache: $meta_path"
  fi
  
  return 0
}

yt_video_meta() {
  local input="${1:?yt_video_meta: missing url}"
  local field="${2:?yt_video_meta: missing meta field}"
  local dir="${3:-"$YT_CACHE_DIR"}"

  local filter
  filter="${YT_VIDEO_META_FILTER_MAP[$field]}"
  [[ -n "$filter" ]] || return 2

  local id url meta_name meta_path
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2
  meta_name="${id}.${YT_CACHE_META_NAME}"
  meta_path="${dir%/}/${YT_CACHE_META_FOLDER}/${meta_name}"
  
  if [[ ! -s "$meta_path" ]]; then
    __yt_video_meta_cache_build "$url" "$meta_path" || return 1
  fi

  # shellcheck disable=SC2154
  "$jq_bin" -r "$filter" "$meta_path" || return 1
}

