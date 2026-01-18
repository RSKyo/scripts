#!/usr/bin/env bash
# =============================================================================
# SHID: 71Dp6FlP
# DO NOT REMOVE OR MODIFY THIS BLOCK.
# Used for script identity / indexing.
# =============================================================================

IFS=$'\n\t'
set -Eeuo pipefail
trap 'echo "[ERROR] line $LINENO: $BASH_COMMAND" >&2' ERR

# =============================================================================
# yt_tracklist.sh
#
# 从 YouTube 视频描述中提取并保存曲目列表（tracklist）
#
# 输入方式：
#   - argv：单个 URL
#   - stdin：多行 URL（一行一个）
#
# 输出约定：
#   - stdout：最终生成的 tracklist 文件路径（统一在最后输出）
#   - stderr：处理过程中的日志 / 警告
# =============================================================================

# ---------------------------------------------------------------------------
# 路径
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null && pwd)"

# ---------------------------------------------------------------------------
# 依赖模块
# ---------------------------------------------------------------------------
source "$ROOT_DIR/source/yt_extract_id.source.sh"
source "$ROOT_DIR/source/yt_fetch_title.source.sh"
source "$ROOT_DIR/source/yt_fetch_description.source.sh"
source "$ROOT_DIR/source/yt_extract_tracklist.source.sh"
source "$ROOT_DIR/source/sanitize_string.source.sh"

# ---------------------------------------------------------------------------
# 业务常量
# ---------------------------------------------------------------------------
MIN_TRACK_LINES=5        # 至少需要识别出的曲目行数
ENABLE_LAST_LINE_LOOP=1 # 是否对最后一行标记 @loop

# ---------------------------------------------------------------------------
# usage
# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage:
  yt_tracklist.sh [options] URL
  yt_tracklist.sh [options] < urls.txt

Options:
  --out DIR       输出目录（默认：./tracklist）
  --with-title    文件名中包含清洗后的标题
  --force         覆盖已存在文件
  -h, --help      显示帮助
EOF
}

# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------
OUT_DIR=""
WITH_TITLE=0
FORCE=0
URL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      OUT_DIR="$2"
      shift 2
      ;;
    --with-title)
      WITH_TITLE=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 1
      ;;
    *)
      URL_ARGS+=("$1")
      shift
      ;;
  esac
done

[[ -z "$OUT_DIR" ]] && OUT_DIR="$SCRIPT_DIR/tracklist"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" >/dev/null && pwd)"

# ---------------------------------------------------------------------------
# 业务逻辑：处理单个 URL
#
# 约定：
#   - 不向 stdout 输出任何内容
#   - 成功时通过变量回写结果路径
# ---------------------------------------------------------------------------
extract_tracklist() {
  local url="$1"
  local __result_var="$2"

  local id title safe_title outfile
  local description
  local tracks=()

  # 提取 videoId
  if ! id="$(yt_extract_id "$url")"; then
    echo "[WARN] invalid url: $url" >&2
    return 1
  fi

  # 构造文件名（可选包含标题）
  if [[ $WITH_TITLE -eq 1 ]]; then
    title="$(yt_fetch_title "$url" || true)"
    [[ -n "$title" ]] && safe_title="$(sanitize_string "$title")"
  fi

  if [[ -n "${safe_title:-}" ]]; then
    outfile="$OUT_DIR/$safe_title [$id].txt"
  else
    outfile="$OUT_DIR/[$id].txt"
  fi

  # 已存在文件处理
  if [[ $FORCE -eq 0 && -f "$outfile" ]]; then
    echo "[SKIP] $id -> $outfile" >&2
    printf -v "$__result_var" '%s' "$outfile"
    return 0
  fi

  # 获取视频描述
  description="$(yt_fetch_description "$url" || true)"
  [[ -z "$description" ]] && return 1

  # 从描述中提取曲目列表
  mapfile -t tracks < <(yt_extract_tracklist "$description")
  (( ${#tracks[@]} < MIN_TRACK_LINES )) && return 1

  # 可选：最后一行标记 @loop
  if (( ENABLE_LAST_LINE_LOOP == 1 )); then
    local last_idx=$((${#tracks[@]} - 1))
    if [[ "${tracks[$last_idx]}" =~ ([0-9]{1,2}:[0-9]{2}(:[0-9]{2})?) ]]; then
      tracks[$last_idx]="${BASH_REMATCH[1]} @loop"
    fi
  fi

  # 写入文件
  printf '%s\n' "${tracks[@]}" >"$outfile"
  echo "[OK] $id -> $outfile" >&2

  # 回写结果路径
  printf -v "$__result_var" '%s' "$outfile"
  return 0
}

# ---------------------------------------------------------------------------
# URL 收集：argv 优先，其次 stdin
# ---------------------------------------------------------------------------
collect_urls() {
  if [[ ${#URL_ARGS[@]} -gt 0 ]]; then
    printf '%s\n' "${URL_ARGS[@]}"
  else
    cat
  fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  local url result
  local results=()

  # 无 argv 且 stdin 为终端，视为无输入
  if [[ ${#URL_ARGS[@]} -eq 0 && -t 0 ]]; then
    usage
    exit 1
  fi

  # 统一 URL 流处理
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue

    result=""
    if extract_tracklist "$url" result; then
      [[ -n "$result" ]] && results+=("$result")
    fi
  done < <(collect_urls)

  # 最终统一输出结果，供下游使用
  printf '%s\n' "${results[@]}"
}

main
