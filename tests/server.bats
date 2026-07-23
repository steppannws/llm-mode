load helpers

@test "on --dry-run includes lms server start and load" {
  run llm-mode on --dry-run
  [[ "$output" == *"lms server start"* ]]
  [[ "$output" == *"lms load qwen3-coder-30b-a3b"* ]]
}

@test "serve-stop --dry-run includes lms server stop" {
  run llm-mode serve-stop --dry-run
  [[ "$output" == *"lms server stop"* ]]
}

@test "status reports server down when nothing listens" {
  echo 'CFG_PORT=19999' > "$LLM_MODE_DIR/config"
  run llm-mode status
  [[ "$output" == *"port: 19999"* ]]
  [[ "$output" == *"server: down"* ]]
}
