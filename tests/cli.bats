load helpers

@test "unknown subcommand exits 2 with usage" {
  run llm-mode bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

@test "no subcommand prints usage" {
  run llm-mode
  [ "$status" -eq 2 ]
}

@test "--dry-run on prints actions without executing" {
  run llm-mode on --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
}

@test "log writes timestamped lines to state dir" {
  llm-mode on --dry-run
  [ -f "$LLM_MODE_DIR/log" ]
  grep -q "on: start" "$LLM_MODE_DIR/log"
}
