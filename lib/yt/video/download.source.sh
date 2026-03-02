#!/usr/bin/env bash
# Source-only library: yt.video.formats
# shellcheck disable=SC1091

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_DOWNLOAD_SOURCED+x}" ]] && return 0
__YT_VIDEO_DOWNLOAD_SOURCED=1


yt_video_download() {
    local url="$1"
    
    start="3"
    end="5"

    "$yt_dlp" \
    -f "bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
    --download-sections "*${start}-${end}" \
    --force-keyframes-at-cuts \
    -o "segment.%(ext)s" \
    "$url"
}
