#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.playlist.id
#
# Semantics:
# - Extract stable YouTube playlistId from URL input
# - Only accepts reproducible playlists:
#   PL / OL / UU / FL
#
# stdout: playlistId
# stderr: none
# return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__vGrb7zCA+x}" ]] && return 0
__vGrb7zCA=1

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_playlist_id() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  local pid=""
  local re_pid='[A-Za-z0-9_-]+'
  local re_list='[?&]list=('"$re_pid"')'

  if [[ "$input" =~ ^$re_pid$ ]]; then
    pid="$input"
  elif [[ "$input" =~ $re_list ]]; then
    pid="${BASH_REMATCH[1]}"
  fi

  # Accept stable playlist prefixes only
  # PL → user/system playlists
  # OL → official albums
  # UU → channel uploads (stable mapping)
  # FL → legacy favorites
  case "$pid" in
    PL*|OL*|UU*|FL*) ;;
    *) pid="" ;;
  esac

  [[ -n "$pid" ]] && printf '%s\n' "$pid"
  return 0
}
