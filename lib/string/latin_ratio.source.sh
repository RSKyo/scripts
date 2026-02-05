#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Source-only library: latin ratio
#
# This module provides utilities based on character composition.
# It computes the ratio of Latin letters (A–Z, a–z) among all
# alphabetic characters in a given string.
#
# Notes:
#   - This is NOT language detection.
#   - This does NOT imply the text is English.
#   - It only measures character-set composition.
#
# -----------------------------------------------------------------------------

# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../../infra/bootstrap.source.sh"

# Prevent multiple sourcing
[[ -n "${__STRING_LATIN_RATIO_SOURCED+x}" ]] && return 0
__STRING_LATIN_RATIO_SOURCED=1

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced, not executed." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# string_latin_ratio
#
# Calculate the ratio of Latin letters (A–Z, a–z) among all alphabetic characters.
#
# Input:
#   $1 - str string
#
# Output:
#   - A floating-point ratio in range [0, 1], with 3 decimal precision
#   - Prints 0 when there are no alphabetic characters
#
# Example:
#   string_latin_ratio "Hello世界"   -> 0.714
#   string_latin_ratio "世界你好"     -> 0.000
#   string_latin_ratio "HelloWorld"  -> 1.000
# -----------------------------------------------------------------------------
string_latin_ratio() {
  local str="$1"
  local letters latin total_count latin_count

  # 母集：Unicode 字母（包括中文/日文/韩文/希腊/西里尔/带重音拉丁字母等）
  # printf '%s' "$str" 原样输出字符串（比 echo 安全）
  # sed 's/[^[:alpha:]]//g' 删除所有 非Unicode 字母 字符
  # [:alpha:] 的定义是 “当前 locale 认为是字母的字符”
  # [:alpha:] 默认在 UTF-8 locale 下，不要使用 LC_ALL=C 来强制改为 C locale，否则几乎约等于 A-Za-z
  letters="$(printf '%s' "$str" | sed 's/[^[:alpha:]]//g')"
  total_count="${#letters}"
  (( total_count == 0 )) && { printf '0.000\n'; return 0; }

  # 子集：ASCII 拉丁字母（A-Za-z）
  latin="$(LC_ALL=C printf '%s' "$letters" | sed 's/[^A-Za-z]//g')"
  latin_count="${#latin}"

  printf '%.3f\n' "$(awk -v a="$latin_count" -v b="$total_count" 'BEGIN { print a / b }')"
}

string_latin_ratio() {
  local str="$1"
  local letters latin total_count latin_count

  # Extract alphabetic characters (locale-stable)
  # LC_ALL=C 强制使用 C locale，保证 [:alpha:] 的行为稳定（ASCII 语义）
  # printf '%s' "$str" 原样输出字符串（比 echo 安全）
  # sed 's/[^[:alpha:]]//g' 删除所有 非字母 字符，保留下来 A–Z / a–z，以及在 C locale 下被认为是字母的字符
  # 结果：letters 只包含“字母”，数字、空格、符号、emoji 全部被移除
  letters="$(LC_ALL=C printf '%s' "$str" | sed 's/[^[:alpha:]]//g')"
  total_count="${#letters}"
  (( total_count == 0 )) && { printf '0.000\n'; return 0; }

  # Extract Latin letters only
  latin="$(LC_ALL=C printf '%s' "$letters" | sed 's/[^A-Za-z]//g')"
  latin_count="${#latin}"

  # Compute ratio with fixed precision (avoid bc)
  # ratio = latin_count / total_count
  printf '%.3f\n' "$(awk -v a="$latin_count" -v b="$total_count" 'BEGIN { print a / b }')"
}

# -----------------------------------------------------------------------------
# Comparators for string_latin_ratio
# -----------------------------------------------------------------------------

# string_latin_ratio_gt <string> <threshold>
# Return 0 if ratio > threshold, else 1.
string_latin_ratio_gt() {
  local str="$1"
  local threshold="${2:-0}"

  awk -v r="$(string_latin_ratio "$str")" -v t="$threshold" 'BEGIN { exit !(r > t) }'
}

# string_latin_ratio_lt <string> <threshold>
# Return 0 if ratio < threshold, else 1.
string_latin_ratio_lt() {
  local str="$1"
  local threshold="${2:-0}"

  awk -v r="$(string_latin_ratio "$str")" -v t="$threshold" 'BEGIN { exit !(r < t) }'
}

# string_latin_ratio_eq <string> <threshold> [epsilon]
# Return 0 if |ratio - threshold| <= epsilon, else 1.
# Default epsilon is 0.0005 (works well with 3-decimal ratio output).
string_latin_ratio_eq() {
  local str="$1"
  local threshold="${2:-0}"
  local eps="${3:-0.0005}"

  awk -v r="$(string_latin_ratio "$str")" -v t="$threshold" -v e="$eps" \
    'BEGIN { d = r - t; if (d < 0) d = -d; exit !(d <= e) }'
}
