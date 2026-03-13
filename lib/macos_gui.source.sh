#!/usr/bin/env bash
# Source-only library: lib/macos_gui

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
# [[ -n "${__MACOS_GUI_SOURCED+x}" ]] && return 0
# __MACOS_GUI_SOURCED=1

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

app_front() {
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
tell application "System Events"
  tell process "$app"
    if (count of windows) is 0 then return
    set bounds of front window to {$l, $t, $r, $b}
  end tell
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

browser_tabs_count() {
  local app="${1:?missing app}"

  osascript <<EOF
tell application "$app"
  if not running then return 0
  return (count of tabs of front window)
end tell
EOF
}

browser_tabs() {
  local app="${1:?browser_tabs: missing app}"
  local sep=$'\x1f'

  osascript <<EOF
tell application "$app"
  if not running then return ""

  set sep to "$sep"
  set out to ""
  set i to 1

  repeat with t in tabs of front window
    set tabTitle to title of t
    set tabURL to URL of t
    set tabLoading to loading of t
    set tabActive to active tab index of front window is i

    set out to out & i & sep & tabTitle & sep & tabURL & sep & tabLoading & sep & tabActive & "\n"
    set i to i + 1
  end repeat

  return out
end tell
EOF
}

browser_tabs_find() {
  local title url loading active

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title)   title="$2"; shift 2 ;;
      --url)     url="$2"; shift 2 ;;
      --loading) loading="$2"; shift 2 ;;
      --active)  active="$2"; shift 2 ;;
      *) return 2 ;;
    esac
  done

  local sep=$'\x1f'
  local idx tab_title tab_url tab_loading tab_active
  local found=0

  while IFS="$sep" read -r idx tab_title tab_url tab_loading tab_active; do
    [[ -n "$title"   && "$tab_title"   != *"$title"* ]] && continue
    [[ -n "$url"     && "$tab_url"     != "$url"*   ]] && continue
    [[ -n "$loading" && "$tab_loading" != "$loading" ]] && continue
    [[ -n "$active"  && "$tab_active"  != "$active"  ]] && continue

    printf '%s%s%s%s%s%s%s%s%s\n' \
      "$idx" "$sep" "$tab_title" "$sep" "$tab_url" "$sep" "$tab_loading" "$sep" "$tab_active"

    found=1
  done

  (( found ))
}

browser_tab_open() {
  local app="${1:?missing app}"
  local url="${2:-}"

  if ! win_exists "$app"; then
    open -a "$app" "$url"
    return
  fi

  browser_tab_new "$app" "$url"
}

browser_tab_new() {
  local app="${1:?missing app}"
  local url="${2:-}"

  osascript <<EOF
tell application "$app"
  tell front window to make new tab with properties {URL:"$url"}
end tell
EOF
}

browser_tab_close() {
  local app="${1:?missing app}"
  local idx="${2:?missing index}"

  osascript <<EOF
tell application "$app"
  tell front window
    close tab $idx
  end tell
end tell
EOF
}

browser_tab_activate() {
  local app="${1:?missing app}"
  local idx="${2:?missing index}"

  osascript <<EOF
tell application "$app"
  set active tab index of front window to $idx
end tell
EOF
}

browser_tab() {
  local app="${1:?browser_tab: missing app}"
  local idx="${2:?browser_tab: missing idx}"

  local line
  local i=1

  while IFS= read -r line; do
    (( i++ == idx )) && {
      printf '%s\n' "$line"
      return 0
    }
  done < <(browser_tabs "$app")

  return 1
}

