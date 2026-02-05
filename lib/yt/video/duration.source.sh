#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.duration
#
# Semantics:
# - Fetch YouTube video duration (seconds) via yt-dlp
#
# stdout: duration in seconds
# stderr: none
# return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__YT_VIDEO_DURATION_SOURCED+x}" ]] && return 0
__YT_VIDEO_DURATION_SOURCED=1

# -------------------------------------------------
# Dependencies
# -------------------------------------------------
# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../../infra/bootstrap.source.sh"
# 要求 bootstrap 在入口 source，这里只做断言
: "${yt_dlp:?yt_dlp not set (did you source bootstrap?)}"
: "${LIB_DIR:?LIB_DIR not set (did you source bootstrap?)}"

source "$LIB_DIR/yt/video/canonical.source.sh"

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_duration() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  local canonical_url
  canonical_url="$(yt_video_canonical "$input")"

  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --print "duration" \
    "$canonical_url" 2>/dev/null

  return 0
}
