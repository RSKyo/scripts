#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.playlist.canonical
#
# Semantics:
# - Build canonical playlist URL from playlistId or playlist input
# - Canonical form:
#   https://www.youtube.com/playlist?list=<playlistId>
#
# stdout: canonical playlist URL
# stderr: none
# return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__YT_PLAYLIST_CANONICAL_SOURCED+x}" ]] && return 0
__YT_PLAYLIST_CANONICAL_SOURCED=1

# -------------------------------------------------
# Dependencies
# -------------------------------------------------
# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../../infra/bootstrap.source.sh"
# 要求 bootstrap 在入口 source，这里可以只断言而不再次 source
: "${LIB_DIR:?LIB_DIR not set (did you source bootstrap?)}"

source "$LIB_DIR/yt/playlist/id.source.sh"

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_playlist_canonical() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  local pid=""
  pid="$(yt_playlist_id "$input")"
  [[ -n "$pid" ]] || return 0

  printf 'https://www.youtube.com/playlist?list=%s\n' "$pid"
  return 0
}
