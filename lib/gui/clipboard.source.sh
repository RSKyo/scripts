



# text="$(clipboard_read)"
# clipboard_write <<< "hello"

clipboard_read() {
  pbpaste
}

clipboard_write() {
  pbcopy
}