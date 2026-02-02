#!/usr/bin/env bash
# Source-only library: YouTube playlist fetch utilities
#
# Functions:
# - yt_fetch_list <url>
#     Fetch videos from a YouTube playlist URL and output canonical video URLs.
#
# Behavior:
# - Accepts any URL containing a playlist (list=...).
# - Resolves playlistId via URL utilities.
# - Enumerates playlist items via yt-dlp.
# - Outputs canonical watch URLs:
#     https://www.youtube.com/watch?v=<videoId>
#
# Dependencies:
# - resolve_source (infra)
# - resolve_yt_dlp (infra)
# - yt_playlist_id (lib)
# - yt_url_canonical (lib)
#
# stderr: diagnostics only
# return: always 0 (check stdout)

# Prevent multiple sourcing
[[ -n "${__wEZ1hgUD+x}" ]] && return 0
__wEZ1hgUD=1

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/../infra/bootstrap.source.sh"
# shellcheck source=/dev/null
source "$INFRA_DIR/resolve_bin.source.sh"
# shellcheck source=/dev/null
source "$INFRA_DIR/resolve_source.source.sh"

resolve_source yt.url

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_fetch_list() {
  local url="$1"
  local playlist_id=""
  local playlist_url=""
  local yt_dlp=""
  local vid=""

  [[ -n "$url" ]] || return 0

  # Resolve playlist ID from URL
  playlist_id="$(yt_playlist_id "$url")"
  [[ -n "$playlist_id" ]] || return 0

  playlist_url="https://www.youtube.com/playlist?list=$playlist_id"

  # Resolve yt-dlp binary
  yt_dlp="$(resolve_yt_dlp)" || return 0

  # Enumerate playlist video IDs and emit canonical URLs
  "$yt_dlp" --flat-playlist --print id "$playlist_url" 2>/dev/null |
  while read -r vid; do
    [[ -n "$vid" ]] || continue
    printf 'https://www.youtube.com/watch?v=%s\n' "$vid"
  done

  return 0
}
