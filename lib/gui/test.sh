

source "$LIB_DIR/gui/clipboard.source.sh"
source "$LIB_DIR/gui/keyboard.source.sh"
source "$LIB_DIR/gui/mouse.source.sh"

xxx() {
  mouse_move 1252 935
  key_press 36
  # clipboard_write <<< "回车的 key type"
  # paste
  # mouse_move 1744 935
  # key_press 36
}