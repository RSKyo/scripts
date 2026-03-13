#!/usr/bin/env bash
# Source-only library: lib/clichatgpt

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__CLICHATGPT_SOURCED+x}" ]] && return 0
__CLICHATGPT_SOURCED=1

# shellcheck disable=SC2034
readonly CLICHATGPT_BROWSER='Google Chrome'
readonly CLICHATGPT_URL='https://chatgpt.com/?temporary-chat=true'
readonly CLICHATGPT_SIGN='@clichatgpt'

# --- Dependencies ------------------------------------------------------------
# shellcheck disable=SC1091

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/macos_gui.source.sh"

# --- Public API --------------------------------------------------------------

xxx_check_browser() {
  local window_count

  window_count="$(osascript -e "
    tell application \"$CLICHATGPT_BROWSER\"
      if it is running then
        return (count of windows)
      else
        return 0
      end if
    end tell
  ")"

  if win_exists "$CLICHATGPT_BROWSER"; then
    echo "Launching $CLICHATGPT_BROWSER..."
    open -a "$CLICHATGPT_BROWSER" "$CLICHATGPT_URL"

    # 固定浏览器位置、大小
    xxx_fixed_browser
    # 复制网址到剪切板
    pbcopy <<< "$CLICHATGPT_URL"
    # 新开窗口光标默认在地址栏
    # 粘贴->回车
    cliclick kd:cmd t:v ku:cmd w:100 kp:enter w:1000
  else
    # 固定浏览器位置、大小
    xxx_fixed_browser

    local rect
    rect="$(win_frame "$CLICHATGPT_BROWSER")"

    local l t w h input_xy
    read -r l t w h <<< "$rect"
    printf -v input_xy '%d,%d' $((l+w/2)) $((t+h-83))

    # 点击输入框
    cliclick c:"$input_xy" w:100

  fi
}


xxx_fixed_browser() {
  local sl st sw sh
  read -r sl st sw sh <<< "$(screen_workarea)"

  local l t w=600 h=500
  l="$((sl+sw-w))"
  t="$st"
  
  win_frame_set "$CLICHATGPT_BROWSER" "$l" "$t" "$w" "$h"
}

yt_video_title_prompt(){
  local id="$1"
  local title="$2"

  local prompt="重新给我一个中文标题，\
格式为: ${CLICHATGPT_SIGN} ID|歌名
要求: 不要符号、图标、emoji; 不要音乐、歌单等说明; 画面感、文艺; 仅输出格式化后的内容; 
原标题: ${title}
ID: ${id}"

  printf '%s\n' "$prompt"
}

test1() {
  
  # local id="$2"
  # local title="$3"

  local title="Cafe Playlist 퇴근길 버스 창가에서 🌅 | 노을 보며 듣는 감성 인디 음악 플레이리스트[indie music]"
  local id="FG3qREIls3"

  local prompt
  prompt="$(yt_video_title_prompt "$id" "$title")"
  
  # 检查并准备好浏览器
  xxx_check_browser

  

  # 复制内容到剪切板
  pbcopy <<< "$prompt"
  # 粘贴->回车
  cliclick kd:cmd t:v ku:cmd w:100 kp:enter
  # 清空剪切板
  pbcopy <<< ''
  
  # 页面空白处坐标，用于页面向下滚动，途径复制按钮
  local rect l t w h blank_xy
  rect="$(win_frame "$CLICHATGPT_BROWSER")"
  read -r l t w h <<< "$rect"
  printf -v blank_xy '%d,%d' $((l+25)) $((t+h-225))

  # 点击空白处
  cliclick c:"$blank_xy" w:100
  
  # 等待捕获结果
  local i count timeout=20000 interval=500
  count=$((timeout / interval))

  for ((i=1; i<=count; i++)); do
    # 点击下箭头
    cliclick kp:arrow-down w:"$((interval/2))"
    # 点击空白处（可能命中复制按钮）
    cliclick c:"$blank_xy" w:"$((interval/2))"
    # 尝试捕获
    xxx_catch_result && return 0
  done

  # 保底尝试
  # tab到复制按钮->回车
  cliclick kp:tab w:100 kp:enter w:"$((interval/2))"
  # 尝试捕获
  xxx_catch_result && return 0
  
  return 1
}

xxx_catch_result() {
  local result
  result="$(pbpaste)"
  if [[ $result == "$CLICHATGPT_SIGN "* ]]; then
    printf '%s\n' "${result#"$CLICHATGPT_SIGN" }"
    return 0
  fi

  pbcopy <<< ''
  return 1
}

test3() {
  # 点击空白处
  cliclick c:1420,360 w:100
  # 滚动到最底部
  cliclick \
    kp:arrow-down w:100 \
    kp:arrow-down w:100 \
    kp:arrow-down w:100 \
    kp:arrow-down w:100 \
    kp:arrow-down w:100

  # tab到复制按钮->点击
  cliclick kp:tab w:100 c:. w:100
}
