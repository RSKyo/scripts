# 英语标题中可接受的字符集合
# _EN_CHARS='A-Za-z0-9[:space:][:punct:]' 
_EN_CHARS='A-Za-z0-9[:space:]'

# 横线类分隔符（作者意图一致）
DASH_SEPS=(
  ' - '
  ' – '
  ' — '
)

PIPE_SEPS=(
  ' | '
  ' │ '
)

SLASH_SEPS=(
  ' / '
)


trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}


__time_to_seconds() {
  local t="$1"
  local IFS=":"
  local h m s

  # 支持 mm:ss / hh:mm:ss，统一转换为秒
  read -r h m s <<< "$t"

  if [[ -z "${s:-}" ]]; then
    # mm:ss
    printf '%d' $((10#$h * 60 + 10#$m))
  else
    # hh:mm:ss
    printf '%d' $((10#$h * 3600 + 10#$m * 60 + 10#$s))
  fi
}

__strip_track_number() {
  local raw="$1"

  # 移除标题开头的曲目序号（如 "01 - "、"3) "、"12. "）
  # 并顺带清理首尾多余空白
  printf '%s' "$raw" \
    | LC_ALL=C sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*[-\)\.:][[:space:]]+//' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

__is_english_chunk() {
  local raw="$1"
  local letters english

  # 仅保留字母字符（用于判断是否有语言信息）
  letters="${raw//[^[:alpha:]]/}"
  (( ${#letters} == 0 )) && return 1

  # 统计英文字母占比，超过一半则视为英语片段
  english="${letters//[^A-Za-z]/}"
  (( ${#english} * 2 > ${#letters} ))
}

__detect_language_layout() {
  local title="$1"
  local cleaned head tail
  local head_is_en=0 tail_is_en=0

  # 清理首尾无语义字符（空白/标点）
  cleaned="$(printf '%s' "$title" \
    | sed -E 's/^[[:space:][:punct:]]+//; s/[[:space:][:punct:]]+$//')"
  [[ -n "$cleaned" ]] || { printf '0\n'; return 0; }

  # 取首尾窗口进行语言取样
  head="${cleaned:0:12}"
  tail="${cleaned: -12}"

  __is_english_chunk "$head" && head_is_en=1
  __is_english_chunk "$tail" && tail_is_en=1

  # 非双语：首尾语言一致
  if (( head_is_en == tail_is_en )); then
    printf '0\n'
    return 0
  fi

  # 双语：根据英语所在位置返回
  if (( head_is_en )); then
    printf '1\n'   # 英语在前
  else
    printf '2\n'   # 英语在后
  fi
}

__split_en_left() {
  local title="$1"
  local en other

  en="$(printf '%s' "$title" | sed -E "s/^([$_EN_CHARS]+).*/\1/")"
  other="${title#"$en"}"

  # 清理分隔符噪声
  en="$(printf '%s' "$en" | sed -E 's/[[:space:][:punct:]]+$//')"
  other="$(printf '%s' "$other" | sed -E 's/^[[:space:][:punct:]]+//')"

  printf '%s\x1f%s\n' "$en" "$other"
}

__split_en_right() {
  local title="$1"
  local en other

  en="$(printf '%s' "$title" | sed -E "s/.*([$_EN_CHARS]+)$/\1/")"
  other="${title%"$en"}"

  en="$(printf '%s' "$en" | sed -E 's/^[[:space:][:punct:]]+//')"
  other="$(printf '%s' "$other" | sed -E 's/[[:space:][:punct:]]+$//')"

  printf '%s\x1f%s\n' "$other" "$en"
}

__split_bilingual_title() {
  local title="$1"
  local type="$2"   # 1=英语在左, 2=英语在右

  case "$type" in
    1) __split_en_left "$title" ;;
    2) __split_en_right "$title" ;;
    *) printf '%s\x1f\n' "$title" ;;  # 非双语兜底
  esac
}

__detect_separator_group() {
  local title="$1"
  local sep

  for sep in "${DASH_SEPS[@]}"; do
    [[ "$title" == *"$sep"* ]] && { printf 'DASH\n'; return 0; }
  done

  for sep in "${PIPE_SEPS[@]}"; do
    [[ "$title" == *"$sep"* ]] && { printf 'PIPE\n'; return 0; }
  done

  for sep in "${SLASH_SEPS[@]}"; do
    [[ "$title" == *"$sep"* ]] && { printf 'SLASH\n'; return 0; }
  done

  return 1
}

__split_with_dash_fallback() {
  local title="$1"
  local side="$2"   # 1 = 英语在左, 2 = 英语在右
  local sep left right

  for sep in "${DASH_SEPS[@]}"; do
    [[ "$title" != *"$sep"* ]] && continue

    left="${title%%"$sep"*}"
    right="${title#*"$sep"}"

    # 清理空白
    left="$(printf '%s' "$left" | sed -E 's/[[:space:][:punct:]]+$//')"
    right="$(printf '%s' "$right" | sed -E 's/^[[:space:][:punct:]]+//')"

    # 拆分成功判定：左右都非空
    if [[ -n "$left" && -n "$right" ]]; then
      if (( side == 1 )); then
        printf '%s\n' "$left"
      else
        printf '%s\n' "$right"
      fi
      return 0
    fi
  done

  return 1
}




# -----------------------------------------------------------------------------
# yt_extract_tracklist
#
# 输入：
#   $1 - YouTube 视频 description 原文（完整文本，包含换行）
#
# 当前阶段职责：
#   从 description 中识别“原始 tracklist 行”，仅做边界判定：
#     - 哪些行属于 tracklist
#     - tracklist 从哪里开始，到哪里结束
#
# 明确不做的事情（留给后续阶段）：
#   - 不清洗标题文本
#   - 不拆分 title / time / duration
#   - 不做 fallback 或条数校验
#   - 不做任何格式化输出
#
# 核心判定规则：
#   1) 只考虑包含时间戳的行；
#   2) tracklist 必须从 0 秒开始（取最后一个 0 秒作为起点）；
#   3) 从起点向后，时间戳必须严格递增，一旦不递增即终止。
# -----------------------------------------------------------------------------
yt_extract_tracklist() {
  local description="$1"

  # -----------------------------------------------------------------------------
  # 解析 description 获取 tracklist 结构化数据
  # -----------------------------------------------------------------------------
  local TIME_REGEX='([0-9]{1,2}:[0-9]{2}(:[0-9]{2})?)'
  local SEP=$'\x1f'   # 建议用 US 分隔符，比 \t 更稳妥
  local -a rows=()
  local zero_idx=-1

  # 扫描 description：提取含时间戳的行，并拆分出 sec/ts/left/right
  while IFS= read -r line; do
    if [[ "$line" =~ $TIME_REGEX ]]; then
      local ts="${BASH_REMATCH[1]}"
      local sec="$(__time_to_seconds "$ts")"

      # 以“首次出现的 ts”为切分点，得到左右文本（保留原始装饰符）
      local left="${line%%"$ts"*}"
      local right="${line#*"$ts"}"

      rows+=( "${sec}${SEP}${ts}${SEP}${left}${SEP}${right}" )

      # 记录最后一个 0 秒所在位置（用于确定 tracklist 起点）
      (( sec == 0 )) && zero_idx=$((${#rows[@]} - 1))
    fi
  done <<< "$description"

  (( "${#rows[@]}" == 0 )) && return 0
  (( zero_idx < 0 )) && return 0

  # 裁剪到 tracklist 起点：rows[0] 对应 sec==0 的那一行
  rows=( "${rows[@]:zero_idx}" )

  # 解包 rows[0]，拿到起始 prev_sec
  local prev_sec prev_ts prev_left prev_right
  IFS="$SEP" read -r prev_sec prev_ts prev_left prev_right <<< "${rows[0]}"

  local end_idx=1

  for (( i=1; i<"${#rows[@]}"; i++ )); do
    local cur_sec cur_ts cur_left cur_right
    IFS="$SEP" read -r cur_sec cur_ts cur_left cur_right <<< "${rows[i]}"

    if (( cur_sec > prev_sec )); then
      prev_sec="$cur_sec"
      end_idx=$((i + 1))
    else
      break
    fi
  done

  rows=( "${rows[@]:0:end_idx}" )
  local total="${#rows[@]}"

  # -----------------------------------------------------------------------------
  # 解析 tracklist 结构化数据
  # -----------------------------------------------------------------------------
  # 计算左右结构
  local sum_score=0

  for (( i=0; i<total; i++ )); do
    local sec ts left right
    IFS="$SEP" read -r sec ts left right <<< "${rows[i]}"

    # 单行 score：左长度 - 右长度
    sum_score=$(( sum_score + ${#left} - ${#right} ))
  done

  # 获取曲目信息
  for (( i=0; i<total; i++ )); do
    local sec ts left right title

    IFS="$SEP" read -r sec ts left right <<< "${rows[i]}"

    if (( sum_score > 0 )); then
      # 时间戳靠右：曲目信息在 left
      title="$(printf '%s' "$left" \
        | LC_ALL=C sed -E 's/[[:space:]]+[^[:alnum:]]+$//' \
        | sed -E 's/[[:space:]]+$//')"
    else
      # 时间戳靠左：曲目信息在 right
      title="$(printf '%s' "$right" \
        | LC_ALL=C sed -E 's/^[^[:alnum:]]+[[:space:]]+//' \
        | sed -E 's/^[[:space:]]+//')"
    fi

    # 清理序号（改为方法调用）
    title="$(__strip_track_number "$title")"

    # 回写 rows：只需要 ts 和 title 列
    rows[i]="${ts}${SEP}${title}"
  done

  # -----------------------------------------------------------------------------
  # 判断是否为双语歌单
  # -----------------------------------------------------------------------------
  local bilingual_left=0
  local bilingual_right=0
  local threshold=$(( (total + 1) / 2 ))  # 多数即成立（向上取整）

  local bilingual_type=0
  # 0 = 非双语
  # 1 = 英语在左
  # 2 = 英语在右

  for (( i=0; i<total; i++ )); do
    local ts title
    IFS="$SEP" read -r ts title <<< "${rows[i]}"

    case "$(__detect_language_layout "$title")" in
      1)
        bilingual_left=$((bilingual_left + 1))
        if (( bilingual_left >= threshold )); then
          bilingual_type=1
          break
        fi
        ;;
      2)
        bilingual_right=$((bilingual_right + 1))
        if (( bilingual_right >= threshold )); then
          bilingual_type=2
          break
        fi
        ;;
    esac
  done


  # -----------------------------------------------------------------------------
  # 最终输出
  # -----------------------------------------------------------------------------
  for (( i=0; i<total; i++ )); do
    local sec ts left right title
    IFS="$SEP" read -r ts title <<< "${rows[i]}"

    if (( bilingual_type > 0 )); then
      if group="$(__detect_separator_group "$title")"; then
        if [[ "$group" == "DASH" ]]; then
          if result="$(__split_with_dash_fallback "$title" "$bilingual_type")"; then
            printf '%s %s\n' "$ts" "$result"
            continue
          fi
        fi
      else
        # 弱结构兜底
        if (( bilingual_type == 1 )); then
          IFS=$'\x1f' read -r en _ <<< "$(__split_en_left "$title")"
          printf '%s %s\n' "$ts" "$en"
        else
          IFS=$'\x1f' read -r _ en <<< "$(__split_en_right "$title")"
          printf '%s %s\n' "$ts" "$en"
        fi
      fi
    else
      printf '%s %s\n' "$ts" "$title"
    fi
  done

}
