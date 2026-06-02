#!/usr/bin/env bash

# ============================================================
# 剧集-调时间.sh
# ============================================================
#
# 作用：
#
# 支持：
#   1. 调整单个 ASS 文件；
#   2. 调整指定目录下所有 ASS 文件；
#   3. delta 支持正负秒，例如：
#        -1.3  表示时间整体提前 1.3 秒
#         1.3  表示时间整体延后 1.3 秒
#   4. 支持 UTF-8 / UTF-16LE / UTF-16BE 编码；
#   5. 保持原文件编码输出；
#   6. 只修改 Dialogue 行开头的开始时间和结束时间；
#   7. 不修改字幕正文、中文、英文、样式标签、逗号等内容。
#
# 用法：
#   ./剧集-调时间.sh ass_shift_file <file.ass> <delta>
#   ./剧集-调时间.sh ass_shift_dir  <dir>      <delta>
#
# 示例：
#   ./剧集-调时间.sh ass_shift_file "a.ass" -1.3
#   ./剧集-调时间.sh ass_shift_dir "./Subs" -1.3
#
# 输出：
#   a.ass
#   =>
#   a_shifted.ass
#
# ============================================================


# ------------------------------------------------------------
# 输出用法说明
# ------------------------------------------------------------
usage() {
  echo "用法:"
  echo "  $0 ass_shift_file <file.ass> <delta>"
  echo "  $0 ass_shift_dir  <dir>      <delta>"
}


# ------------------------------------------------------------
# 判断 delta 是否是合法数字
#
# 允许：
#   1
#   -1
#   1.3
#   -1.3
#   .5
#   -.5
#
# 不允许：
#   abc
#   1.a
#   1.2.3
# ------------------------------------------------------------
is_delta() {
  [[ "$1" =~ ^[+-]?([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}


# ------------------------------------------------------------
# 检测字幕文件编码
#
# ASS 文件常见编码：
#   UTF-8
#   UTF-16LE with BOM
#   UTF-16BE with BOM
#
# BOM：
#   UTF-16LE: FF FE
#   UTF-16BE: FE FF
#
# 注意：
#   这里仅通过文件开头两个字节判断 UTF-16。
#   如果没有 UTF-16 BOM，则默认按 UTF-8 处理。
# ------------------------------------------------------------
detect_encoding() {
  local file="$1"
  local bom

  # 读取文件前 2 个字节，并转成十六进制字符串
  bom="$(LC_ALL=C dd if="$file" bs=2 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"

  case "$bom" in
    fffe)
      echo "UTF-16LE"
      ;;
    feff)
      echo "UTF-16BE"
      ;;
    *)
      echo "UTF-8"
      ;;
  esac
}


# ------------------------------------------------------------
# 将原字幕内容解码成 UTF-8 流
#
# 为什么要统一转成 UTF-8？
#   Bash 的逐行读取和正则匹配更适合处理 UTF-8 文本。
#
# 为什么 UTF-16LE / UTF-16BE 解码时使用 UTF-16？
#   iconv -f UTF-16 会根据 BOM 自动识别大小端，
#   并且会移除 BOM。
#
# 如果使用：
#   iconv -f UTF-16LE -t UTF-8
#
# 则 BOM 可能被当成普通字符保留下来，
# 后面再写回 UTF-16LE 时容易出现重复 BOM：
#   FF FE FF FE
#
# 这会导致播放器认为字幕格式非法。
# ------------------------------------------------------------
decode_to_utf8() {
  local file="$1"
  local encoding="$2"

  case "$encoding" in
    UTF-16LE|UTF-16BE)
      iconv -f UTF-16 -t UTF-8 "$file"
      ;;
    UTF-8)
      cat "$file"
      ;;
    *)
      echo "不支持的编码: $encoding" >&2
      return 1
      ;;
  esac
}


# ------------------------------------------------------------
# 将 UTF-8 流重新编码回原字幕编码
#
# 参数：
#   $1 encoding 原始编码
#   $2 output   输出文件路径
#
# 设计：
#   原文件是 UTF-16LE，则输出 UTF-16LE；
#   原文件是 UTF-16BE，则输出 UTF-16BE；
#   原文件是 UTF-8，则输出 UTF-8。
#
# 注意：
#   UTF-16LE / UTF-16BE 输出时手动写入 BOM，
#   这样播放器可以正确识别字幕编码。
# ------------------------------------------------------------
encode_from_utf8() {
  local encoding="$1"
  local output="$2"

  case "$encoding" in
    UTF-16LE)
      {
        # 写入 UTF-16LE BOM
        printf '\xFF\xFE'

        # 将后续 UTF-8 内容转为 UTF-16LE
        iconv -f UTF-8 -t UTF-16LE
      } > "$output"
      ;;
    UTF-16BE)
      {
        # 写入 UTF-16BE BOM
        printf '\xFE\xFF'

        # 将后续 UTF-8 内容转为 UTF-16BE
        iconv -f UTF-8 -t UTF-16BE
      } > "$output"
      ;;
    UTF-8)
      cat > "$output"
      ;;
    *)
      echo "不支持的编码: $encoding" >&2
      return 1
      ;;
  esac
}


# ------------------------------------------------------------
# 将 delta 秒数转换成 centisecond
#
# ASS 时间格式：
#   0:00:02.92
#
# 小数点后是百分之一秒，也就是 centisecond。
#
# 例子：
#   1.3  => 130
#   -1.3 => -130
#   .5   => 50
#
# 为什么不用浮点计算？
#   Bash 原生不支持浮点数。
#   ASS 只需要精确到百分之一秒，所以转成整数处理更稳定。
# ------------------------------------------------------------
parse_delta_cs() {
  local delta="$1"
  local sign=""
  local int=""
  local frac=""

  # 处理正负号
  if [[ "$delta" == -* ]]; then
    sign="-"
    delta="${delta#-}"
  elif [[ "$delta" == +* ]]; then
    delta="${delta#+}"
  fi

  # 拆分整数部分和小数部分
  if [[ "$delta" == .* ]]; then
    int="0"
    frac="${delta#.}"
  elif [[ "$delta" == *.* ]]; then
    int="${delta%%.*}"
    frac="${delta#*.}"
  else
    int="$delta"
    frac="0"
  fi

  # ASS 只保留两位小数。
  # 例如：
  #   1.3   => 1.30
  #   1.345 => 1.34
  #
  # 这里是截断，不是四舍五入。
  frac="${frac}00"
  frac="${frac:0:2}"

  # 10# 用来避免 08、09 这类数字被 Bash 当作八进制解析。
  local cs=$((10#$int * 100 + 10#$frac))

  if [[ "$sign" == "-" ]]; then
    echo "-$cs"
  else
    echo "$cs"
  fi
}


# ------------------------------------------------------------
# 将 ASS 时间拆分值转换为 centisecond
#
# 输入：
#   h  小时
#   m  分钟
#   s  秒
#   cs 百分之一秒
#
# 例：
#   0:00:02.92
#   =>
#   292
# ------------------------------------------------------------
time_to_cs() {
  local h="$1"
  local m="$2"
  local s="$3"
  local cs="$4"

  echo $((10#$h * 360000 + 10#$m * 6000 + 10#$s * 100 + 10#$cs))
}


# ------------------------------------------------------------
# 将 centisecond 转回 ASS 时间格式
#
# 输入：
#   292
#
# 输出：
#   0:00:02.92
#
# 如果偏移后小于 0，则归零：
#   -1 秒 => 0:00:00.00
# ------------------------------------------------------------
cs_to_time() {
  local total="$1"

  if (( total < 0 )); then
    total=0
  fi

  local h=$((total / 360000))
  local rest=$((total % 360000))
  local m=$((rest / 6000))
  rest=$((rest % 6000))
  local s=$((rest / 100))
  local cs=$((rest % 100))

  printf "%d:%02d:%02d.%02d" "$h" "$m" "$s" "$cs"
}


# ------------------------------------------------------------
# 调整单行 Dialogue 的开始时间和结束时间
#
# ASS Dialogue 基本格式：
#
#   Dialogue: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
#
# 示例：
#
#   Dialogue: 0,0:00:02.92,0:00:04.62,Default,NTP,0000,0000,0000,,孩子们...
#
# 本函数只处理：
#   Dialogue: 0,0:00:02.92,0:00:04.62,
#
# 后面的内容：
#   Default,NTP,0000,0000,0000,,孩子们...
#
# 全部原样保留。
#
# 这样不会受到字幕正文中的逗号、中文、英文、样式标签影响。
# ------------------------------------------------------------
shift_dialogue_line() {
  local line="$1"
  local delta_cs="$2"

  # 匹配 Dialogue 行开头的两个时间字段。
  #
  # 捕获组说明：
  #   1 prefix  : Dialogue: 0,
  #   2 sh      : start hour
  #   3 sm      : start minute
  #   4 ss      : start second
  #   5 scs     : start centisecond
  #   6 eh      : end hour
  #   7 em      : end minute
  #   8 es      : end second
  #   9 ecs     : end centisecond
  #   10 suffix : 从第二个时间后面的逗号开始，到行尾全部内容
  if [[ "$line" =~ ^(Dialogue:[^,]*,)([0-9]+):([0-9]{2}):([0-9]{2})\.([0-9]{2}),([0-9]+):([0-9]{2}):([0-9]{2})\.([0-9]{2})(,.*)$ ]]; then
    local prefix="${BASH_REMATCH[1]}"

    local sh="${BASH_REMATCH[2]}"
    local sm="${BASH_REMATCH[3]}"
    local ss="${BASH_REMATCH[4]}"
    local scs="${BASH_REMATCH[5]}"

    local eh="${BASH_REMATCH[6]}"
    local em="${BASH_REMATCH[7]}"
    local es="${BASH_REMATCH[8]}"
    local ecs="${BASH_REMATCH[9]}"

    local suffix="${BASH_REMATCH[10]}"

    local start_cs
    local end_cs

    # 原始开始 / 结束时间转换成 centisecond
    start_cs="$(time_to_cs "$sh" "$sm" "$ss" "$scs")"
    end_cs="$(time_to_cs "$eh" "$em" "$es" "$ecs")"

    # 应用偏移
    start_cs=$((start_cs + delta_cs))
    end_cs=$((end_cs + delta_cs))

    # 输出新 Dialogue 行。
    # 只有时间发生变化，其余内容原样保留。
    printf "%s%s,%s%s\n" \
      "$prefix" \
      "$(cs_to_time "$start_cs")" \
      "$(cs_to_time "$end_cs")" \
      "$suffix"
  else
    # 非标准 Dialogue 行，或普通头部行，原样输出。
    printf "%s\n" "$line"
  fi
}


# ------------------------------------------------------------
# 从标准输入读取 UTF-8 文本流，并逐行调整 Dialogue 时间
#
# 参数：
#   delta_cs 偏移量，单位 centisecond
#
# 这个函数只负责“文本流处理”，不关心文件路径和编码。
# ------------------------------------------------------------
shift_ass_stream() {
  local delta_cs="$1"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    shift_dialogue_line "$line" "$delta_cs"
  done
}


# ------------------------------------------------------------
#
# 参数：
#   file  ASS 文件路径
#   delta 偏移秒数，支持正负
#
# 输出：
#   原文件名_shifted.ass
#
# 示例：
#   a.ass
#   =>
#   a_shifted.ass
# ------------------------------------------------------------
ass_shift_file() {
  local file="$1"
  local delta="$2"

  if [[ ! -f "$file" ]]; then
    echo "文件不存在: $file" >&2
    return 1
  fi

  if [[ -z "$delta" ]]; then
    echo "缺少 delta，例如 -1.3 或 1.3" >&2
    return 1
  fi

  if ! is_delta "$delta"; then
    echo "delta 格式错误: $delta" >&2
    return 1
  fi

  local delta_cs
  local encoding
  local out
  local tmp

  delta_cs="$(parse_delta_cs "$delta")"
  encoding="$(detect_encoding "$file")"

  out="${file%.ass}_shifted.ass"

  # 使用 mktemp 避免固定 .tmp 文件名冲突。
  tmp="$(mktemp "${out}.XXXXXX")" || {
    echo "无法创建临时文件" >&2
    return 1
  }

  # 处理流程：
  #
  #   原文件
  #     ↓
  #   decode_to_utf8
  #     ↓
  #   shift_ass_stream
  #     ↓
  #   encode_from_utf8
  #     ↓
  #   临时输出文件
  #
  # 这样可以保持原编码输出，并避免 UTF-16 字幕在 Bash 中无法匹配。
  decode_to_utf8 "$file" "$encoding" |
    shift_ass_stream "$delta_cs" |
    encode_from_utf8 "$encoding" "$tmp"

  # 检查管道中任意一步是否失败。
  if [[ ${PIPESTATUS[0]} -ne 0 || ${PIPESTATUS[1]} -ne 0 || ${PIPESTATUS[2]} -ne 0 ]]; then
    rm -f "$tmp"
    echo "生成失败: $file" >&2
    return 1
  fi

  # 防止生成空文件。
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    echo "生成失败：输出为空" >&2
    return 1
  fi

  # 全部成功后再替换到最终输出路径。
  # 这样即使中途失败，也不会留下损坏的最终文件。
  if ! mv "$tmp" "$out"; then
    rm -f "$tmp"
    echo "写入失败: $out" >&2
    return 1
  fi

  echo "完成: $out"
}


# ------------------------------------------------------------
# 批量调整目录下所有 ASS 文件
#
# 参数：
#   dir   目录路径
#   delta 偏移秒数，支持正负
#
# 说明：
#   - 递归查找目录下所有 .ass 文件；
#   - 自动排除已经生成的 *_shifted.ass 文件；
#   - 每个文件调用 ass_shift_file 生成对应副本。
# ------------------------------------------------------------
ass_shift_dir() {
  local dir="$1"
  local delta="$2"

  if [[ ! -d "$dir" ]]; then
    echo "目录不存在: $dir" >&2
    return 1
  fi

  if [[ -z "$delta" ]]; then
    echo "缺少 delta，例如 -1.3 或 1.3" >&2
    return 1
  fi

  if ! is_delta "$delta"; then
    echo "delta 格式错误: $delta" >&2
    return 1
  fi

  find "$dir" -type f -iname "*.ass" ! -iname "*_shifted.ass" -print0 |
  while IFS= read -r -d '' file; do
    ass_shift_file "$file" "$delta"
  done
}


# ------------------------------------------------------------
# 命令入口
# ------------------------------------------------------------
case "$1" in
  file)
    ass_shift_file "$2" "$3"
    ;;

  dir)
    ass_shift_dir "$2" "$3"
    ;;

  *)
    usage
    exit 1
    ;;
esac