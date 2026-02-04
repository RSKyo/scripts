#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.canonical
#
# Semantics:
# - Build canonical watch URL for a YouTube video
# - Canonical form:
#   https://www.youtube.com/watch?v=<videoId>
#
# stdout: canonical watch URL
# stderr: none
# return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__sKE5VnUD+x}" ]] && return 0
__sKE5VnUD=1

# -------------------------------------------------
# Dependencies
# -------------------------------------------------
# 要求 bootstrap 在入口 source，这里可以只断言而不再次 source
: "${LIB_DIR:?LIB_DIR not set (did you source bootstrap?)}"
# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../../infra/bootstrap.source.sh"
source "$LIB_DIR/yt/video/id.source.sh"

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_canonical() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  local vid=""
  vid="$(yt_video_id "$input")"
  [[ -n "$vid" ]] || return 0

  printf 'https://www.youtube.com/watch?v=%s\n' "$vid"
  return 0
}
