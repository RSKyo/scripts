#!/usr/bin/env bash
# Source-only library: YouTube URL utilities
#
# Functions:
# - yt_url_id <url>
#     Extract YouTube videoId from various URL forms.
#     stdout: videoId if found
#
# - yt_playlist_id <url>
#     Extract YouTube playlistId (list=...) from a URL.
#     stdout: playlistId if found
#
# - yt_url_canonical <url>
#     Convert a YouTube URL to its canonical watch URL (video-only).
#     stdout: https://www.youtube.com/watch?v=<videoId>
#
# Notes:
# - Video and playlist semantics are handled independently.
# - Playlist (list/index) information is intentionally ignored by yt_url_canonical.
# - No output means no valid videoId or playlistId was resolved.
#
# stderr: diagnostics only
# return: always 0 (check stdout)

# Prevent multiple sourcing
[[ -n "${__sB6IJl88+x}" ]] && return 0
__sB6IJl88=1

yt_url_id() {
  local url="$1"
  [[ -n "$url" ]] || return 0

  local id=""
  local video_id_re='[A-Za-z0-9_-]{11}'

  local re_youtu_be='youtu\.be/('"$video_id_re"')'
  local re_embed='/embed/('"$video_id_re"')'
  local re_shorts='/shorts/('"$video_id_re"')'
  local re_watch='[?&]v=('"$video_id_re"')'

  if [[ "$url" =~ $re_youtu_be ]]; then
    id="${BASH_REMATCH[1]}"
  elif [[ "$url" =~ $re_embed ]]; then
    id="${BASH_REMATCH[1]}"
  elif [[ "$url" =~ $re_shorts ]]; then
    id="${BASH_REMATCH[1]}"
  elif [[ "$url" =~ $re_watch ]]; then
    id="${BASH_REMATCH[1]}"
  fi

  [[ -n "$id" ]] && printf '%s\n' "$id"
  return 0
}

yt_playlist_id() {
  local url="$1"
  [[ -n "$url" ]] || return 0

  local pid=""
  local playlist_re='[?&]list=([A-Za-z0-9_-]+)'

  if [[ "$url" =~ $playlist_re ]]; then
    pid="${BASH_REMATCH[1]}"
  fi

  # RD → radio / mix（RD 不是 playlist，它只是以某个视频为种子的算法广播，不可复现）
  # PL → 用户 / 系统播放列表
  # OL → 专辑 / 官方列表
  # UU → channel uploads（稳定映射）
  # FL → Favorites / Like（老体系）
  # 只接受稳定 playlist id：PL / OL / UU / FL
  case "$pid" in
    PL*|OL*|UU*|FL*) ;;
    *) pid="" ;;
  esac

  [[ -n "$pid" ]] && printf '%s\n' "$pid"
  return 0
}

# Convert any YouTube URL to canonical watch URL (video-only)
yt_url_canonical() {
  local url="$1"
  local id=""

  [[ -n "$url" ]] || return 0

  # 复用现有能力：只关心 videoId
  id="$(yt_url_id "$url")"

  # 无 videoId：可能是纯 playlist / 无效 URL
  [[ -n "$id" ]] || return 0

  printf 'https://www.youtube.com/watch?v=%s\n' "$id"
}
