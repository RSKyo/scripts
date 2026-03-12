#!/usr/bin/env bash

readonly GOOGLE_CHROME='Google Chrome'
readonly TARGET_URL='https://chatgpt.com/?temporary-chat=true'
readonly AUTO_TALK_SIGN='@kyo'

mouse_watch() {
  local last=""
  local pos

  echo "Watching mouse position... (Press Ctrl+C to stop)"

  while true; do
    pos="$(cliclick p)"

    if [[ "$pos" != "$last" ]]; then
      echo "$pos"
      last="$pos"
    fi

    sleep 0.05
  done
}

get_front_app() {
  sleep 3
  osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'
}

win_active() {
  local app="${1:?missing app name}"

  osascript <<EOF
tell application "$app"
  activate
end tell
EOF
}

screen_rect() {
  osascript -l JavaScript <<'EOF'
ObjC.import('AppKit')

function run() {
  const screen = $.NSScreen.mainScreen
  const frame = screen.frame
  const visible = screen.visibleFrame

  const x = Math.round(visible.origin.x)
  const y = Math.round(frame.size.height - visible.origin.y - visible.size.height)
  const w = Math.round(visible.size.width)
  const h = Math.round(visible.size.height)

  return [x, y, w, h].join(' ')
}
EOF
}

win_rect() {
  local app="${1:?missing app}"

  osascript <<EOF
tell application "System Events"
  tell process "$app"
    set p to position of front window
    set s to size of front window
    set out to (item 1 of p as text) & " " & (item 2 of p as text) & " " & (item 1 of s as text) & " " & (item 2 of s as text)
    return out
  end tell
end tell
EOF
}

win_set_rect() {
  local app="${1:?missing app name}"
  local l="${2:-0}"
  local t="${3:-0}"
  local w="${4:-1200}"
  local h="${5:-800}"

  osascript <<EOF
tell application "$app"
  activate
  set w1 to front window
  set bounds of w1 to {$l, $t, $((l+w)), $((t+h))}
end tell
EOF
}

win_move() {
  local app="${1:?missing app name}"
  local l="${2:-0}"
  local t="${3:-0}"

  local w h _
  read -r _ _ w h <<< "$(win_rect "$app")"
  win_set_rect "$app" "$l" "$t" "$w" "$h"
}

win_resize() {
  local app="${1:?missing app name}"
  local w="${2:-1200}"
  local h="${3:-800}"

  local l t _
  read -r l t _ _ <<< "$(win_rect "$app")"
  win_set_rect "$app" "$l" "$t" "$w" "$h"
}


xxx_check_browser() {
  local window_count

  window_count="$(osascript -e "
    tell application \"$GOOGLE_CHROME\"
      if it is running then
        return (count of windows)
      else
        return 0
      end if
    end tell
  ")"

  if (( window_count == 0 )); then
    echo "Launching $GOOGLE_CHROME..."
    open -a "$GOOGLE_CHROME"

    # 固定浏览器位置、大小
    xxx_fixed_browser
    # 复制网址到剪切板
    pbcopy <<< "$TARGET_URL"
    # 新开窗口光标默认在地址栏
    # 粘贴->回车
    cliclick kd:cmd t:v ku:cmd w:100 kp:enter w:1000
  else
    # 固定浏览器位置、大小
    xxx_fixed_browser

    local rect
    rect="$(win_rect "$GOOGLE_CHROME")"

    local l t w h input_xy
    read -r l t w h <<< "$rect"
    printf -v input_xy '%d,%d' $((l+w/2)) $((t+h-83))

    # 点击输入框
    cliclick c:"$input_xy" w:100

  fi
}


xxx_fixed_browser() {
  local sl st sw sh
  read -r sl st sw sh <<< "$(screen_rect)"

  local l t w=600 h=500
  l="$((sl+sw-w))"
  t="$st"
  
  win_set_rect "$GOOGLE_CHROME" "$l" "$t" "$w" "$h"
}

yt_video_title_prompt(){
  local id="$1"
  local title="$2"

  local prompt="重新给我一个中文标题，\
格式为: ${AUTO_TALK_SIGN} ID|歌名
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
  rect="$(win_rect "$GOOGLE_CHROME")"
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
  if [[ $result == "$AUTO_TALK_SIGN "* ]]; then
    printf '%s\n' "${result#"$AUTO_TALK_SIGN" }"
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
