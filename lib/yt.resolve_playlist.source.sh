#!/usr/bin/env bash
# Source-only library: YouTube playlist resolver (stable playlists only)
#
# Core primitive:
# - yt_resolve_playlist <url>
#     Resolve a stable YouTube playlist (PL / OL / UU / FL only)
#     and output each video's canonical watch URL.
#
# Behavior:
# - Playlist id is extracted via yt_playlist_id (which enforces
#   PL / OL / UU / FL whitelist).
# - Algorithmic / radio-generated lists (e.g. RD) are ignored.
#
# Output:
# - stdout: https://www.youtube.com/watch?v=<videoId> (one per line)
# - stderr: diagnostics only (suppressed by default)
# - return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__nDflLTRC+x}" ]] && return 0
__nDflLTRC=1

# -------------------------------------------------
# Bootstrap infra
# -------------------------------------------------
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/../infra/bootstrap.source.sh"
# shellcheck source=/dev/null
source "$INFRA_DIR/resolve_bin.source.sh"
# shellcheck source=/dev/null
source "$INFRA_DIR/resolve_source.source.sh"

# -------------------------------------------------
# Load URL utilities
# -------------------------------------------------
resolve_source yt.url

# -------------------------------------------------
# Public API
# -------------------------------------------------

yt_resolve_playlist() {
  local url="$1"
  local pid=""
  local yt_dlp=""
  local playlist_url=""

  [[ -n "$url" ]] || return 0

  # Extract stable playlist id (PL / OL / UU / FL only)
  # yt_playlist_id 内部已过滤 RD 等非稳定列表
  pid="$(yt_playlist_id "$url" | head -n 1)"
  [[ -n "$pid" ]] || return 0

  yt_dlp="$(resolve_yt_dlp)" || return 0
  playlist_url="https://www.youtube.com/playlist?list=$pid"

  # Emit canonical watch URLs for each video in playlist
  "$yt_dlp" \
    --no-warnings \
    --flat-playlist \
    --skip-download \
    --print "id" \
    "$playlist_url" 2>/dev/null \
  | while IFS= read -r vid; do
      [[ -n "$vid" ]] || continue
      printf 'https://www.youtube.com/watch?v=%s\n' "$vid"
    done

  return 0
}
