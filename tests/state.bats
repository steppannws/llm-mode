load helpers

@test "state_write then state_get round-trips" {
  echo '{"apps": ["com.apple.Safari"], "wired_limit_prev": "0"}' > "$LLM_MODE_DIR/state.json"
  run llm-mode status
  [ "$status" -eq 0 ]
}

@test "on --dry-run writes state file with keys" {
  run llm-mode on --dry-run
  [ -f "$LLM_MODE_DIR/state.json" ]
  python3 -c "import json,sys; d=json.load(open('$LLM_MODE_DIR/state.json')); assert set(['apps','agents','wired_limit_prev','forced_kills']) <= set(d)"
}

@test "snapshot never clobbers existing state file" {
  echo '{"apps": ["com.seeded"], "agents": [], "wired_limit_prev": "0", "forced_kills": ["x"]}' > "$LLM_MODE_DIR/state.json"
  run llm-mode on --dry-run
  grep -q '"forced_kills": \["x"\]' "$LLM_MODE_DIR/state.json"
}
