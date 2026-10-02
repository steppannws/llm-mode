load helpers

setup_osascript() {
  stub osascript 'if [[ "$*" == *"background only is false"* ]]; then echo "com.apple.Safari, com.mitchellh.ghostty"; else echo false; fi'
}

@test "non-whitelisted terminal is snapshotted for quit by default" {
  setup_osascript
  llm-mode on --dry-run
  grep -q 'com.mitchellh.ghostty' "$LLM_MODE_DIR/state.json"
}

@test "CFG_WHITELIST_EXTRA keeps extra apps out of the snapshot" {
  setup_osascript
  echo "CFG_WHITELIST_EXTRA='com\.mitchellh\.ghostty'" > "$LLM_MODE_DIR/config"
  llm-mode on --dry-run
  run grep -q 'com.mitchellh.ghostty' "$LLM_MODE_DIR/state.json"
  [ "$status" -ne 0 ]
  grep -q 'com.apple.Safari' "$LLM_MODE_DIR/state.json"
}
