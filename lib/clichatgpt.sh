#!/usr/bin/env bash
# Source-only library: lib/clichatgpt

# 禁用 history expansion（避免 ! 被 bash 解释）
set +o histexpand

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__CLICHATGPT_SOURCED+x}" ]] && return 0
__CLICHATGPT_SOURCED=1

# shellcheck disable=SC2034
readonly CLICHATGPT_URL='https://chatgpt.com/?temporary-chat=true'
readonly CHROME_CHATGPT_WAIT_REPLY_TIMEOUT=10
readonly CHROME_CHATGPT_WAIT_REPLY_SLEEP=0.2
readonly CHROME_CHATGPT_WAIT_REPLY_COMPLETE_TIMEOUT=60
readonly CHROME_CHATGPT_WAIT_REPLY_COMPLETE_SLEEP=1

# --- Dependencies ------------------------------------------------------------
# shellcheck disable=SC1091

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/macos_gui.source.sh"

# --- Public API --------------------------------------------------------------

clichatgpt_talk() {
  local text
  text="$(cat)"

  chrome_tab_open "$CLICHATGPT_URL" || return 1
  app_activate "Google Chrome"

  local old_num
  old_num="$(chrome_chatgpt_reply_num)" || return 1

  chrome_chatgpt_input "$text" || return 1
  chrome_chatgpt_submit || return 1

  chrome_chatgpt_wait_reply "$old_num" || return 1
  chrome_chatgpt_wait_reply_complete || return 1

  chrome_chatgpt_last_reply
}

chrome_chatgpt_input() {
  local text="$1"

  osascript <<EOF >/dev/null
tell application "Google Chrome"
  tell active tab of front window
    execute javascript "
      var e=document.querySelector('[contenteditable]');
      if(e){
        e.focus();
        e.innerText='$text';
        e.dispatchEvent(new Event('input',{bubbles:true}));
      }
    "
  end tell
end tell
EOF
}

chrome_chatgpt_submit() {
  osascript <<EOF >/dev/null
tell application "Google Chrome"
  tell active tab of front window
    execute javascript "
      var b=document.querySelector('[data-testid=\"send-button\"]');
      if(b) b.click();
      true;
    "
  end tell
end tell
EOF
}

chrome_chatgpt_last_reply() {
  osascript <<'EOF'
tell application "Google Chrome"
  tell active tab of front window
    execute javascript "
      var m=document.querySelectorAll('[data-message-author-role=\"assistant\"]');
      if(m.length){
        m[m.length-1].scrollIntoView({block:'end'});
        m[m.length-1].innerText;
      }
    "
  end tell
end tell
EOF
}

chrome_chatgpt_reply_num() {
  osascript <<'EOF'
tell application "Google Chrome"
  tell active tab of front window
    execute javascript "
      document.querySelectorAll('[data-message-author-role=\"assistant\"]').length
    "
  end tell
end tell
EOF
}

chrome_chatgpt_wait_reply() {
  local old_num="$1"
  local num
  local start

  start=$SECONDS

  while :; do
    num="$(chrome_chatgpt_reply_num)" || num=

    if [[ -n "$num" && "$num" -gt "$old_num" ]]; then
      return 0
    fi

    if(( SECONDS - start >= CHROME_CHATGPT_WAIT_REPLY_TIMEOUT )); then
      loge "wait reply timeout (${CHROME_CHATGPT_WAIT_REPLY_TIMEOUT}s)"
     return 1
    fi

    sleep "$CHROME_CHATGPT_WAIT_REPLY_SLEEP"
  done
}

chrome_chatgpt_wait_reply_complete() {
  local last prev=""
  local start

  start=$SECONDS

  while :; do
    last="$(chrome_chatgpt_last_reply)" || last=""

    if [[ -n "$last" && "$last" == "$prev" ]]; then
      return 0
    fi

    prev="$last"

    (( SECONDS - start >= CHROME_CHATGPT_WAIT_REPLY_COMPLETE_TIMEOUT )) && {
      loge "wait reply complete timeout (${CHROME_CHATGPT_WAIT_REPLY_COMPLETE_TIMEOUT}s)"
      return 1
    }

    sleep "$CHROME_CHATGPT_WAIT_REPLY_COMPLETE_SLEEP"
  done
}