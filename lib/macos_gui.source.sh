#!/usr/bin/env bash
# Source-only library: lib/macos_gui

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__MACOS_GUI_SOURCED+x}" ]] && return 0
__MACOS_GUI_SOURCED=1

# --- Constants ---------------------------------------------------------------

readonly CHROME_TABS_WAIT_STABLE_MAX_TRY=50
readonly CHROME_TABS_WAIT_STABLE_SLEEP_TIME=0.1
readonly CHROME_TABS_WAIT_STABLE_THRESHOLD=3
readonly CHROME_TAB_WAIT_LOAD_MAX_TRY=100
readonly CHROME_TAB_WAIT_LOAD_SLEEP_TIME=0.1

###############################################################################
# cliclick: macOS CLI tool for mouse and keyboard automation
# https://github.com/BlueM/cliclick
###############################################################################

# cliclick c:200,300        # 左键单击 (click)
# cliclick dc:200,300       # 左键双击 (double click)
# cliclick tc:200,300       # 左键三击 (triple click)
# cliclick rc:200,300       # 右键单击 (right click)
# cliclick mc:200,300       # 中键单击 (middle click)

# cliclick m:500,400        # 移动鼠标到指定坐标 (move)
# cliclick m:+100,+50       # 相对当前位置移动 (右100 下50)

# cliclick dd:100,100       # 按下鼠标左键 (drag start)
# cliclick du:500,400       # 在指定位置松开鼠标 (drag end)

# cliclick m:200,200 c:.    # 移动到200,200并点击 ('.'表示当前位置)
# cliclick m:200,200 dc:.   # 移动并双击
# cliclick m:200,200 dd:. m:600,200 du:.   # 从200,200拖到600,200

# cliclick p                # 输出当前鼠标坐标

# cliclick t:hello          # 输入字符串 "hello"
# cliclick kp:enter         # 按 Enter 键
# cliclick kp:tab           # 按 Tab 键
# cliclick kp:space         # 按 Space 键

# cliclick kd:cmd           # 按下 Command 键
# cliclick ku:cmd           # 释放 Command 键

# cliclick kd:cmd kp:c ku:cmd   # Command+C (复制)
# cliclick kd:cmd kp:v ku:cmd   # Command+V (粘贴)

# cliclick w:500            # 等待500毫秒

###############################################################################

mouse_crosshair() {
  printf 'Move mouse... (Ctrl+C to stop)\n'

  while :; do
    printf '\r%s' "$(cliclick p)"
    sleep 0.05
  done
}

screen_workarea() {
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

front_app() {
  local delay="${1:-0}"
  (( delay > 0 )) && sleep "$delay"

  osascript <<'EOF'
tell application "System Events"
  name of first process whose frontmost is true
end tell
EOF
}

app_activate() {
  local app="${1:?app_activate: missing app name}"

  osascript <<EOF
tell application "$app" to activate

tell application "System Events"
  tell process "$app"
    try
      set frontmost to true
      if (count of windows) > 0 then
        set value of attribute "AXMinimized" of window 1 to false
      end if
    end try
  end tell
end tell
EOF
}

win_count() {
  local app="${1:?win_count: missing app}"

  osascript -e "
    tell application \"$app\"
      if it is running then
        return (count of windows)
      else
        return 0
      end if
    end tell
  " 2>/dev/null
}

win_exists() {
  local app="${1:?win_exists: missing app}"

  (( $(win_count "$app") > 0 ))
}

win_focus() {
  local app="${1:?win_focus: missing app}"

  osascript <<EOF
tell application "System Events"
  tell process "$app"
    if (count of windows) is 0 then return
    set frontmost to true
  end tell
end tell
EOF
}

win_frame() {
  local app="${1:?missing app}"

  osascript <<EOF
tell application "System Events"
  tell process "$app"
    if (count of windows) is 0 then return ""
    set {x, y} to position of front window
    set {w, h} to size of front window
    set AppleScript's text item delimiters to " "
    return {x, y, w, h} as text
  end tell
end tell
EOF
}

win_frame_set() {
  local app="${1:?missing app}"
  local l="${2:-0}"
  local t="${3:-0}"
  local w="${4:-1200}"
  local h="${5:-800}"

  local r=$((l + w))
  local b=$((t + h))

  osascript <<EOF
tell application "$app"
  if (count of windows) = 0 then return
  set bounds of window 1 to {$l, $t, $r, $b}
end tell
EOF
}

win_move() {
  local app="${1:?missing app}"
  local l="${2:-0}"
  local t="${3:-0}"

  local frame
  frame="$(win_frame "$app")" || return

  local _ _ w h
  read -r _ _ w h <<< "$frame"

  win_frame_set "$app" "$l" "$t" "$w" "$h"
}

win_place() {
  local app="${1:?missing app}"
  local pos="${2:?missing position}"

  local sl st sw sh
  read -r sl st sw sh <<< "$(screen_workarea)"

  local l t w h
  read -r l t w h <<< "$(win_frame "$app")"

  case "$pos" in
    center)
      l=$((sl + (sw - w) / 2))
      t=$((st + (sh - h) / 2))
      ;;

    left)
      l="$sl"
      t=$((st + (sh - h) / 2))
      ;;

    right)
      l=$((sl + sw - w))
      t=$((st + (sh - h) / 2))
      ;;

    top)
      l=$((sl + (sw - w) / 2))
      t="$st"
      ;;

    bottom)
      l=$((sl + (sw - w) / 2))
      t=$((st + sh - h))
      ;;

    topleft)
      l="$sl"
      t="$st"
      ;;

    topright)
      l=$((sl + sw - w))
      t="$st"
      ;;

    bottomleft)
      l="$sl"
      t=$((st + sh - h))
      ;;

    bottomright)
      l=$((sl + sw - w))
      t=$((st + sh - h))
      ;;

    left-half)
      l="$sl"
      t="$st"
      w=$((sw / 2))
      h="$sh"
      ;;

    right-half)
      l=$((sl + sw / 2))
      t="$st"
      w=$((sw / 2))
      h="$sh"
      ;;

    top-half)
      l="$sl"
      t="$st"
      w="$sw"
      h=$((sh / 2))
      ;;

    bottom-half)
      l="$sl"
      t=$((st + sh / 2))
      w="$sw"
      h=$((sh / 2))
      ;;

    fullscreen)
      l="$sl"
      t="$st"
      w="$sw"
      h="$sh"
      ;;

    *)
      printf 'invalid position: %s\n' "$pos" >&2
      return 1
      ;;
  esac

  win_frame_set "$app" "$l" "$t" "$w" "$h"
}

win_resize() {
  local app="${1:?missing app}"
  local w="${2:-1200}"
  local h="${3:-800}"

  local frame
  frame="$(win_frame "$app")" || return

  local l t _ _
  read -r l t _ _ <<< "$frame"

  win_frame_set "$app" "$l" "$t" "$w" "$h"
}

###############################################################################
# Google Chrome
###############################################################################

chrome_tabs_count() {
  osascript <<EOF
if application "Google Chrome" is running then
  tell application "Google Chrome"
    if (count of windows) = 0 then return 0
    return count of tabs of front window
  end tell
else
  return 0
end if
EOF
}

chrome_tabs_wait_stable() {
  local last=-1
  local count
  local stable=0
  local i

  for ((i=0; i<CHROME_TABS_WAIT_STABLE_MAX_TRY; i++)); do
    count="$(chrome_tabs_count)" || return 1

    if (( count == last )); then
      ((stable++))
      (( stable >= CHROME_TABS_WAIT_STABLE_THRESHOLD )) && {
        printf '%s\n' "$count"
        return 0
      }
    else
      stable=0
      last="$count"
    fi

    sleep "$CHROME_TABS_WAIT_STABLE_SLEEP_TIME"
  done

  return 1
}

chrome_tab_wait_loaded() {
  local idx="${1:?chrome_tab_wait_loaded: missing idx}"
  local i

  for ((i=0; i<CHROME_TAB_WAIT_LOAD_MAX_TRY; i++)); do
    chrome_tab_is_loaded "$idx" && return 0
    sleep "$CHROME_TAB_WAIT_LOAD_SLEEP_TIME"
  done

  return 1
}

chrome_tab() {
  local idx="${1:?chrome_tab: missing idx}"
  local sep=$'\x1f'

  osascript <<EOF
tell application "Google Chrome"
  if not running then return

  set sep to "$sep"
  set t to tab $idx of front window
  set activeIdx to active tab index of front window

  set tabTitle to title of t
  set tabURL to URL of t
  set tabLoading to loading of t
  set tabActive to (activeIdx is $idx)

  return "$idx" & sep & tabTitle & sep & tabURL & sep & (tabLoading as text) & sep & (tabActive as text)
end tell
EOF
}

__chrome_tab_loading() {
  local idx="$1"

  osascript <<EOF
tell application "Google Chrome"
  if not running then return
  loading of tab $idx of front window
end tell
EOF
}

chrome_tab_is_loaded() {
  local idx="${1:?chrome_tab_is_loaded: missing idx}"
  local count loading

  loading="$(__chrome_tab_loading "$idx")" || return 1
  [[ "$loading" == "false" ]]
}

chrome_tab_active_index() {
  osascript <<'EOF'
tell application "Google Chrome"
  active tab index of front window
end tell
EOF
}

chrome_tab_activate() {
  local idx="${1:?chrome_tab_activate: missing idx}"

  osascript <<EOF
tell application "Google Chrome"
  activate
  set active tab index of front window to $idx
end tell
EOF
}

chrome_tab_open() {
  local url="${1:-}"
  local sep=$'\x1f'
  local idx

  if ! win_exists "Google Chrome"; then
    open -a "Google Chrome" "$url" || return 1

    local count
    count="$(chrome_tabs_wait_stable)" || return 1
    if chrome_tab_wait_loaded "$count"; then
      return 0
    else
      loge "chrome tab failed to load: idx=$count url=$url"
      return 1
    fi
  fi

  idx="$(chrome_tab_index_by_url "$url")"

  if [[ -n "$idx" ]]; then
    chrome_tab_activate "$idx" || return 1
  else
    chrome_tab_new "$url" || return 1
  fi
}

chrome_tab_new() {
  local url="${1:-about:blank}"
  osascript <<EOF
tell application "Google Chrome"
  if not running then return
  tell front window
    make new tab with properties {URL:"$url"}
  end tell
end tell
EOF
}

chrome_tab_close() {
  local input="${1:?chrome_tab_close: missing input}"
  local idx

  if [[ "$input" =~ ^[0-9]+$ ]]; then
    idx="$input"
  else
    idx="$(chrome_tab_index_by_url "$input")" || return 1
  fi

  osascript <<EOF
tell application "Google Chrome"
  if not running then return
  tell front window
    close tab $idx
  end tell
end tell
EOF
}

__chrome_tab_index_by_url() {
  local url="$1"

  osascript <<EOF
tell application "Google Chrome"
  if not running then return
  set i to 1
  repeat with t in tabs of front window
    if URL of t contains "$url" then return i
    set i to i + 1
  end repeat
  return
end tell
EOF
}

chrome_tab_index_by_url() {
  local url="${1:-about:blank}"
  local idx

  idx="$(__chrome_tab_index_by_url "$url")"

  [[ -n "$idx" ]] || return 1
  printf '%s\n' "$idx"
}
