#!/usr/bin/env bash
set -e

MKVEXTRACT="/Applications/MKVToolNix.app/Contents/MacOS/mkvextract"
MKVMERGE="/Applications/MKVToolNix.app/Contents/MacOS/mkvmerge"
TRASH="$HOME/.Trash"

usage() {
  echo
  echo "Usage:"
  echo "$0 <目录> --en \"language_ietf=en,track_name=SDH\" --zh \"track_name=Simplified\""
  echo
  exit 1
}

[[ $# -lt 5 ]] && usage

DIR="$1"
shift

EN_RULE=""
ZH_RULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --en)
      EN_RULE="$2"
      shift 2
      ;;
    --zh)
      ZH_RULE="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[[ -z "$EN_RULE" ]] && usage
[[ -z "$ZH_RULE" ]] && usage

match_track() {
  local track_json="$1"
  local rule="$2"
  IFS=',' read -ra pairs <<< "$rule"
  for pair in "${pairs[@]}"; do
    local key="${pair%%=*}"
    local expected="${pair#*=}"
    local actual
    actual=$(jq -r ".properties.${key} // empty" <<< "$track_json")
    if [[ "${actual,,}" != "${expected,,}" ]]; then
      return 1
    fi
  done
  return 0
}

find_track_id() {
  local json="$1"
  local rule="$2"
  while IFS= read -r track_json; do
    if match_track "$track_json" "$rule"; then
      jq -r '.id' <<< "$track_json"
      return 0
    fi
  done < <(jq -c '.tracks[] | select(.type=="subtitles")' <<< "$json")
  return 1
}

TOTAL=$(find "$DIR" -maxdepth 1 -type f -name "*.mkv" ! -name "._*" | wc -l | tr -d ' ')
[[ "$TOTAL" -eq 0 ]] && { echo "No mkv files found."; exit 1; }

COUNT=0

for MKV in "$DIR"/*.mkv; do
  [[ -f "$MKV" ]] || continue

  BASE="$(basename "$MKV")"

  echo
  echo "[$((COUNT+1))/$TOTAL] Scanning:"
  echo "$BASE"
  echo "Reading track info..."

  JSON="$("$MKVMERGE" -J "$MKV")"

  echo "Matching subtitle tracks..."
  EN_ID="$(find_track_id "$JSON" "$EN_RULE")" || { echo "Cannot find EN subtitle for $BASE"; continue; }
  ZH_ID="$(find_track_id "$JSON" "$ZH_RULE")" || { echo "Cannot find ZH subtitle for $BASE"; continue; }

  DIRNAME="$(dirname "$MKV")"
  NAME="${BASE%.*}"
  EN_OUT="$DIRNAME/${NAME}.en.srt"
  ZH_OUT="$DIRNAME/${NAME}.zh.srt"

  # 提取英文轨道，实时显示 mkvextract 输出
  echo "EN_ID=$EN_ID"
  if [[ ! -f "$EN_OUT" ]]; then
    "$MKVEXTRACT" tracks "$MKV" "$EN_ID:$EN_OUT"
  else
    echo "EN_ID=$EN_ID SKIP"
  fi

  # 提取中文字幕轨道
  echo "ZH_ID=$ZH_ID"
  if [[ ! -f "$ZH_OUT" ]]; then
    "$MKVEXTRACT" tracks "$MKV" "$ZH_ID:$ZH_OUT"
  else
    echo "ZH_ID=$ZH_ID SKIP"
  fi

  COUNT=$((COUNT+1))
  echo "------------------------------------------------------------"
done

# ZIP 打包
ZIP_NAME="$(basename "$DIR").srt.zip"
ZIP_PATH="$DIR/$ZIP_NAME"

if [[ ! -f "$ZIP_PATH" ]]; then
  find "$DIR" -maxdepth 1 -type f \( -name "*.en.srt" -o -name "*.zh.srt" \) ! -name "._*" -print0 | xargs -0 zip -j "$ZIP_PATH" >/dev/null
  echo
  echo "All subtitles zipped to:"
  echo "$ZIP_PATH"
else
  echo
  echo "ZIP exists, skipped:"
  echo "$ZIP_PATH"
fi

# 移动 srt 到废纸篓
find "$DIR" -maxdepth 1 -type f \( -name "*.en.srt" -o -name "*.zh.srt" \) ! -name "._*" -exec mv {} "$TRASH/" \;
echo
echo "All SRT files moved to Trash:"
echo "$TRASH"