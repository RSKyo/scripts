



# key_type "hello"
# 回车
# key_press 36


key_type() {
  local text="$1"

  osascript <<EOF
tell application "System Events"
  keystroke "$text"
end tell
EOF
}

key_press() {
  local key="$1"

  osascript <<EOF
tell application "System Events"
  key code $key
end tell
EOF
}

copy() {
  cliclick kd:cmd t:c ku:cmd
}

paste() {
  cliclick kd:cmd t:v ku:cmd
}