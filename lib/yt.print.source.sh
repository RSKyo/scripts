#!/usr/bin/env bash
# Source-only library: YouTube metadata printer (yt-dlp wrapper)
#
# Core primitive:
# - yt_print <url> <field>
#     Print a yt-dlp metadata field for a YouTube URL.
#
# Convenience wrappers:
# - yt_print_title <url>
# - yt_print_description <url>
# - yt_print_duration <url>
# - yt_print_duration_string <url>
#
# Behavior:
# - URL normalization is delegated to yt_url_canonical.
# - yt-dlp is used as the authoritative metadata source.
#
# Output:
# - stdout: requested value (raw; wrappers may post-process)
# - stderr: diagnostics only (suppressed by default)
# - return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__K3M8fR2Q+x}" ]] && return 0
__K3M8fR2Q=1

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
yt_print() {
  local url="$1"
  local field="$2"
  local canonical=""
  local yt_dlp=""

  [[ -n "$url" ]] || return 0
  [[ -n "$field" ]] || return 0

  canonical="$(yt_url_canonical "$url")"
  [[ -n "$canonical" ]] || return 0

  yt_dlp="$(resolve_yt_dlp)" || return 0

  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --print "$field" \
    "$canonical" 2>/dev/null

  return 0
}

yt_print_title() {
  yt_print "$1" title | head -n 1
}

yt_print_description() {
  yt_print "$1" description
}

yt_print_duration() {
  yt_print "$1" duration | head -n 1
}

yt_print_duration_string() {
  yt_print "$1" duration_string | head -n 1
}
