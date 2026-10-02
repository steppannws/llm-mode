load helpers

stub_apps() {
  stub osascript 'case "$*" in
    *"bundle identifier of (processes"*) echo "com.google.Chrome, com.apple.Terminal, com.tinyspeck.slackmacgap" ;;
    *com.google.Chrome*) echo "Google Chrome" ;;
    *com.tinyspeck.slackmacgap*) echo "Slack" ;;
  esac'
}

@test "on --dry-run --json lists app names that would quit, whitelist applied" {
  stub_apps
  echo "CFG_QUIT_APPS=1" >"$LLM_MODE_DIR/config"
  run llm-mode on --dry-run --json
  [ "$status" -eq 0 ]
  [ "$output" = '{"quit":["Google Chrome","Slack"]}' ]
}

@test "on --dry-run --json touches nothing" {
  stub_apps
  llm-mode on --dry-run --json >/dev/null
  [ ! -f "$LLM_MODE_DIR/state.json" ]
  ! grep -q "RUN" "$LLM_MODE_DIR/log" 2>/dev/null
}

@test "on --dry-run --json lists nothing when CFG_QUIT_APPS is off" {
  stub_apps
  run llm-mode on --dry-run --json
  [ "$status" -eq 0 ]
  [ "$output" = '{"quit":[]}' ]
}

@test "on --dry-run --json with nothing to quit prints an empty list" {
  echo "CFG_QUIT_APPS=1" >"$LLM_MODE_DIR/config"
  stub osascript 'echo "com.apple.Terminal"'
  run llm-mode on --dry-run --json
  [ "$output" = '{"quit":[]}' ]
}

@test "on --json without --dry-run is refused" {
  run llm-mode on --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]] || false
}

@test "on --dry-run --json fails like on when no backend is installed" {
  isolate_path; stub_apps
  run llm-mode on --dry-run --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"no LLM server found"* ]] || false
}

@test "models lists LM Studio LLMs only" {
  isolate_path
  stub lms 'if [[ "$*" == "ls --json" ]]; then echo "[{\"modelKey\":\"qwen3-coder\",\"type\":\"llm\"},{\"modelKey\":\"nomic-embed\",\"type\":\"embedding\"}]"; fi'
  run llm-mode models
  [ "$status" -eq 0 ]
  [ "$output" = "qwen3-coder" ]
}

@test "models lists ollama names without the header" {
  isolate_path
  stub ollama 'if [[ "$1" == list ]]; then printf "NAME ID SIZE MODIFIED\nqwen3-coder:30b abc 18GB 2d\nllama3.2:3b def 2GB 5d\n"; fi'
  run llm-mode models
  [ "$output" = $'qwen3-coder:30b\nllama3.2:3b' ]
}

@test "models lists gguf files for llamacpp, skipping mmproj" {
  isolate_path; stub llama-server 'exit 0'
  export HOME="$LLM_MODE_DIR/home"
  mkdir -p "$HOME/models/a" "$HOME/.cache/llama.cpp"
  touch "$HOME/models/a/m.gguf" "$HOME/models/a/mmproj-m.gguf" "$HOME/.cache/llama.cpp/c.gguf"
  run llm-mode models
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.cache/llama.cpp/c.gguf"$'\n'"$HOME/models/a/m.gguf" ]
}

@test "models prints nothing for mlx" {
  isolate_path; stub mlx_lm.server 'exit 0'
  run llm-mode models
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
