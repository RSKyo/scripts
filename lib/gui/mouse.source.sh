# mouse_move 500 300
# mouse_click 500 300

mouse_move() {
  local x="$1"
  local y="$2"

  cliclick m:"$x","$y"
}

mouse_click() {
  local x="$1"
  local y="$2"

  cliclick c:"$x","$y"
}

mouse_double_click() {
  local x="$1"
  local y="$2"

  cliclick dc:"$x","$y"
}

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