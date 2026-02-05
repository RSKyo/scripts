#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.description
#
# Semantics:
# - Fetch YouTube video description via yt-dlp
#
# stdout: video description
# stderr: none
# return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_DESCRIPTION_SOURCED+x}" ]] && return 0
# __YT_VIDEO_DESCRIPTION_SOURCED=1

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
yt_video_description() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  local canonical_url
  canonical_url="$(yt_video_canonical "$input")"

  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --print "description" \
    "$canonical_url" 2>/dev/null

  return 0
}
