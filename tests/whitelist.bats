load helpers

setup_osascript() {
  stub osascript 'if [[ "$*" == *"background only is false"* ]]; then echo "com.apple.Safari, com.mitchellh.ghostty"; else echo false; fi'
}

@test "apps are left running by default" {
  setup_osascript
  llm-mode on --dry-run
  grep -q '"apps": \[\]' "$LLM_MODE_DIR/state.json"
}

@test "Finder is whitelisted" {
  stub osascript 'if [[ "$*" == *"background only is false"* ]]; then echo "com.apple.finder, com.apple.Safari"; else echo false; fi'
  echo 'CFG_QUIT_APPS=1' > "$LLM_MODE_DIR/config"
  llm-mode on --dry-run
  run grep -q 'com.apple.finder' "$LLM_MODE_DIR/state.json"
  [ "$status" -ne 0 ]
}

@test "iTerm2 is whitelisted by bundle id" {
  stub osascript 'if [[ "$*" == *"background only is false"* ]]; then echo "com.googlecode.iterm2, com.apple.Safari"; else echo false; fi'
  echo 'CFG_QUIT_APPS=1' > "$LLM_MODE_DIR/config"
  llm-mode on --dry-run
  run grep -q 'com.googlecode.iterm2' "$LLM_MODE_DIR/state.json"
  [ "$status" -ne 0 ]
}

@test "non-whitelisted terminal is snapshotted for quit with CFG_QUIT_APPS=1" {
  setup_osascript
  echo 'CFG_QUIT_APPS=1' > "$LLM_MODE_DIR/config"
  llm-mode on --dry-run
  grep -q 'com.mitchellh.ghostty' "$LLM_MODE_DIR/state.json"
}

@test "CFG_WHITELIST_EXTRA keeps extra apps out of the snapshot" {
  setup_osascript
  printf "CFG_QUIT_APPS=1\nCFG_WHITELIST_EXTRA='com\\.mitchellh\\.ghostty'\n" > "$LLM_MODE_DIR/config"
  llm-mode on --dry-run
  run grep -q 'com.mitchellh.ghostty' "$LLM_MODE_DIR/state.json"
  [ "$status" -ne 0 ]
  grep -q 'com.apple.Safari' "$LLM_MODE_DIR/state.json"
}
