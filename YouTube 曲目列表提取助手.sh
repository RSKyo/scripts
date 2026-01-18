#!/usr/bin/env bash

IFS=$'\n\t'
set -Eeuo pipefail
trap 'echo "[ERROR] line $LINENO: $BASH_COMMAND" >&2' ERR


# =============================================================================
# YouTube 曲目列表提取助手.sh
#
# 功能定位：
#   YouTube Tracklist 批量提取的调度入口脚本
#
# 职责边界：
#   - 负责输入解析（URL / 文件 / 目录）
#   - 负责参数整理与转发
#   - 实际 Tracklist 提取由 yt_tracklist.sh 完成
# =============================================================================


# -----------------------------------------------------------------------------
# 路径
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT_DIR="$SCRIPT_DIR"

# -----------------------------------------------------------------------------
# 依赖注入
# -----------------------------------------------------------------------------
source "$ROOT_DIR/source/resolve_deps.source.sh"

resolve_deps \
  ROOT_DIR="$ROOT_DIR" \
  YT_URLS_CMD=Yjd7EHuw \
  YT_TRACKLIST_CMD=71Dp6FlP


# -----------------------------------------------------------------------------
# usage
# -----------------------------------------------------------------------------
usage() {
  local cmd
  cmd="$(basename "$0")"

  cat >&2 <<EOF
用法：
  $cmd <input> [yt_tracklist.sh 的参数...]

<input>：
  - 单个 YouTube URL
  - URL 列表文件（.txt）
  - 单个已下载的视频文件
  - 指定目录（仅当前层）

说明：
  - 除 --out 外，其余参数将原样传递给 yt_tracklist.sh
  - 未指定 --out 时，将自动推导输出目录
EOF
}


# -----------------------------------------------------------------------------
# 参数解析（只解析，不执行业务）
# -----------------------------------------------------------------------------
parse_args() {
  [[ $# -ge 1 ]] || { usage; exit 1; }

  INPUT="$1"
  shift

  SUBCOMMAND_ARGS=( "$@" )
}


# -----------------------------------------------------------------------------
# --out 兜底逻辑（唯一的参数干预点）
# -----------------------------------------------------------------------------
prepare_out_dir() {
  local has_out=0
  for arg in "${SUBCOMMAND_ARGS[@]}"; do
    [[ "$arg" == "--out" ]] && has_out=1 && break
  done

  [[ $has_out -eq 1 ]] && return 0

  if [[ -d "$INPUT" ]]; then
    OUT_DIR="$INPUT/tracklist"
  elif [[ -f "$INPUT" ]]; then
    OUT_DIR="$(cd "$(dirname "$INPUT")" >/dev/null && pwd)/tracklist"
  else
    OUT_DIR="$SCRIPT_DIR/tracklist"
  fi

  SUBCOMMAND_ARGS=( --out "$OUT_DIR" "${SUBCOMMAND_ARGS[@]}" )
}


# -----------------------------------------------------------------------------
# URL 收集
# -----------------------------------------------------------------------------
collect_urls() {
  "$YT_URLS_CMD" "$INPUT"
}


# -----------------------------------------------------------------------------
# 调度执行（带进度提示）
# -----------------------------------------------------------------------------
dispatch_tracklist() {
  local urls=()
  mapfile -t urls < <(collect_urls)

  local total=${#urls[@]}
  [[ $total -eq 0 ]] && {
    echo "[WARN] 未解析到任何有效的 YouTube URL" >&2
    return 0
  }

  local idx=0
  for url in "${urls[@]}"; do
    idx=$((idx + 1))
    echo "[$idx/$total] $url" >&2
    "$YT_TRACKLIST_CMD" "$url" "${SUBCOMMAND_ARGS[@]}"
  done
}


# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------
main() {
  parse_args "$@"
  prepare_out_dir
  dispatch_tracklist
}

main "$@"
