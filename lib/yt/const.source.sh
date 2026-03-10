#!/usr/bin/env bash
# Source-only library: lib/yt/const
# shellcheck disable=SC2034

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_CONST_SOURCED+x}" ]] && return 0
__YT_CONST_SOURCED=1

# --- Constants ---------------------------------------------------------------

readonly TIMESTAMP_REGEX='[0-9]+[[:space:]]*:[[:space:]]*[0-5][0-9]([[:space:]]*:[[:space:]]*[0-5][0-9])?'

readonly YT_VIDEO_ID_REGEX='[A-Za-z0-9_-]{11}'
readonly YT_VIDEO_URL_YOUTU_BE_REGEX="youtu\.be/($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_WATCH_REGEX="[\?&]v=($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_EMBED_REGEX="/embed/($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_SHORT_REGEX="/shorts/($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_PREFIX='https://www.youtube.com/watch?v='

declare -Ar YT_VIDEO_META_FILTER_MAP=(
  [id]='.id // empty'
  [title]='.title // empty'
  [title_en]='.title_en // empty'
  [duration]='.duration // 0'
  [description]='.description // empty'
)

# Separator regex priority list (first match wins)
readonly YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES=(
  dash_sp
  dash
  pipe_sp
  pipe
  slash_sp
  slash
  dot
)

declare -Ar YT_VIDEO_TRACKLIST_TITLE_SEP_MAP=(
  [dash_sp]='[[:space:]]+[-–—－][[:space:]]+'
  [dash]='[-–—－]'
  [pipe_sp]='[[:space:]]+\|[[:space:]]+'
  [pipe]='\|'
  [slash_sp]='[[:space:]]+\/[[:space:]]+'
  [slash]='\/'
  [dot]='·'
)

readonly YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT=0.6
readonly YT_VIDEO_TRACKLIST_END_TOL_PCT=30
readonly YT_VIDEO_TRACKLIST_REPEAT_RATIO=1.5
readonly YT_VIDEO_TRACKLIST_REPEAT_REGEX='(repeat|repetition|loop|looping|go on|^$)'

readonly YT_CACHE_DIR="${YT_CACHE_DIR:-$HOME/Downloads/yt}"
readonly YT_CACHE_META_FOLDER="${YT_CACHE_META_FOLDER:-.cache/meta}"
readonly YT_CACHE_TRACKLIST_FOLDER="${YT_CACHE_TRACKLIST_FOLDER:-.cache/tracklist}"
readonly YT_CACHE_META_NAME='meta.json'
readonly YT_CACHE_TRACKLIST_NAME='tracklist.txt'

readonly YT_COOKIE_FILE="$INFRA_DIR/cookies.txt"
readonly YT_COOKIE_VALID_URL='https://www.youtube.com/watch?v=dQw4w9WgXcQ'
