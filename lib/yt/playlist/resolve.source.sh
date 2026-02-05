#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.playlist.resolve
#
# Semantics:
# - Resolve a canonical YouTube playlist into canonical video watch URLs
# - Output order follows the playlist order at resolution time
#
# stdout: canonical video URLs (one per line)
# stderr: diagnostics only (suppressed by default)
# return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__YT_PLAYLIST_RESOLVE_SOURCED+x}" ]] && return 0
__YT_PLAYLIST_RESOLVE_SOURCED=1

# -------------------------------------------------
# Dependencies
# -------------------------------------------------
# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../../infra/bootstrap.source.sh"
# 要求 bootstrap 在入口 source，这里可以只断言而不再次 source
: "${yt_dlp:?yt_dlp not set (did you source bootstrap?)}"
: "${LIB_DIR:?LIB_DIR not set (did you source bootstrap?)}"

source "$LIB_DIR/yt/playlist/canonical.source.sh"
source "$LIB_DIR/yt/video/canonical.source.sh"

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_playlist_resolve() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  # Always resolve from canonical playlist URL
  local playlist_url=""
  playlist_url="$(yt_playlist_canonical "$input")"
  [[ -n "$playlist_url" ]] || return 0

  # Resolve playlist to video IDs, then canonicalize each video
  "$yt_dlp" \
    --no-warnings \
    --flat-playlist \
    --skip-download \
    --print "id" \
    "$playlist_url" 2>/dev/null \
  | while IFS= read -r vid; do
      [[ -n "$vid" ]] || continue
      yt_video_canonical "$vid"
    done

  return 0
}
