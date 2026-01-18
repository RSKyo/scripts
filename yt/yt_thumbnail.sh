#!/usr/bin/env bash
# =============================================================================
# SHID: R0BCnzp6
# DO NOT REMOVE OR MODIFY THIS BLOCK.
# Used for script identity / indexing.
# =============================================================================

IFS=$'\n\t'
set -Eeuo pipefail
trap 'echo "[ERROR] line $LINENO: $BASH_COMMAND" >&2' ERR

# =============================================================================
# yt_thumbnail.sh
#
# 从 i.ytimg.com 获取 YouTube 官方视频缩略图
#
# 输入方式：
#   - argv：一个或多个 YouTube URL
#   - stdin：多行 URL（每行一个）
#
# 输出约定：
#   - stdout：最终下载得到的缩略图绝对路径（统一在末尾输出）
#   - stderr：处理过程中的日志 / 警告信息
# =============================================================================

# ---------------------------------------------------------------------------
# 路径
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null && pwd)"

# ---------------------------------------------------------------------------
# 依赖模块
# ---------------------------------------------------------------------------
source "$ROOT_DIR/source/sanitize_string.source.sh"
source "$ROOT_DIR/source/yt_extract_id.source.sh"
source "$ROOT_DIR/source/yt_fetch_title.source.sh"

# ---------------------------------------------------------------------------
# 业务常量
# ---------------------------------------------------------------------------
SIZES=(maxresdefault sddefault hqdefault)
EXTS=(jpg webp)

# ---------------------------------------------------------------------------
# optional dependency
# ---------------------------------------------------------------------------
HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# ---------------------------------------------------------------------------
# usage
# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage:
  yt_thumbnail.sh [options] URL [URL ...]
  yt_thumbnail.sh [options] < urls.txt

Options:
  --out DIR       Output directory (default: ./thumbnail)
  --with-title    Include sanitized video title in filename
  --force         Overwrite existing files
  -h, --help      Show this help
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

[[ -z "$OUT_DIR" ]] && OUT_DIR="$SCRIPT_DIR/thumbnail"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" >/dev/null && pwd)"

# ---------------------------------------------------------------------------
# 业务逻辑：处理单个 URL
#
# 约定：
#   - 不向 stdout 输出任何内容
#   - 成功时通过变量回写结果路径
# ---------------------------------------------------------------------------
download_thumbnail() {
  local url="$1"
  local __result_var="$2"   # 传入一个变量名，用于回写结果
  local id title safe_title
  local base outfile size ext img_url

  if ! id="$(yt_extract_id "$url")"; then
    echo "[WARN] invalid url: $url" >&2
    return 1
  fi

  if [[ $WITH_TITLE -eq 1 && $HAS_JQ -eq 1 ]]; then
    title="$(yt_fetch_title "$url" || true)"
    [[ -n "$title" ]] && safe_title="$(sanitize_string "$title")"
  fi

  if [[ -n "${safe_title:-}" ]]; then
    base="$OUT_DIR/$safe_title [$id]"
  else
    base="$OUT_DIR/[$id]"
  fi

  if [[ $FORCE -eq 0 ]]; then
    for ext in "${EXTS[@]}"; do
      if [[ -f "$base.$ext" ]]; then
        echo "[SKIP] $id -> $base.$ext" >&2
        printf -v "$__result_var" '%s' "$base.$ext"
        return 0
      fi
    done
  fi

  for size in "${SIZES[@]}"; do
    for ext in "${EXTS[@]}"; do
      img_url="https://i.ytimg.com/vi/$id/$size.$ext"
      outfile="$base.$ext"

      if curl -fsL --connect-timeout 5 --max-time 15 "$img_url" -o "$outfile"; then
        echo "[OK] $id $size.$ext -> $outfile" >&2
        printf -v "$__result_var" '%s' "$outfile"
        return 0
      fi
    done
  done

  echo "[WARN] thumbnail not found: $id" >&2
  return 1
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

  # 没有 argv，stdin 又是终端 → 没有输入
  if [[ ${#URL_ARGS[@]} -eq 0 && -t 0 ]]; then
    usage
    exit 1
  fi

  while IFS= read -r url; do
    [[ -z "$url" ]] && continue

    result=""
    if download_thumbnail "$url" result; then
      [[ -n "$result" ]] && results+=("$result")
    fi
  done < <(collect_urls)

  # 最终统一输出结果（可能为空，这是合法的）
  printf '%s\n' "${results[@]}"
}

main
