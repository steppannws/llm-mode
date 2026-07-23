load helpers

@test "off --dry-run restores from state file" {
  cat > "$LLM_MODE_DIR/state.json" <<'EOF'
{"apps": ["com.apple.Safari"], "agents": ["com.example.agent"], "wired_limit_prev": "0", "forced_kills": []}
EOF
  run llm-mode off --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"lms server stop"* ]]
  [[ "$output" == *"iogpu.wired_limit_mb=0"* ]]
  [[ "$output" == *"launchctl enable gui/"*"com.example.agent"* ]]
  [[ "$output" == *"mdutil"* ]]
}

@test "off --dry-run --relaunch opens quit apps" {
  cat > "$LLM_MODE_DIR/state.json" <<'EOF'
{"apps": ["com.apple.Safari"], "agents": [], "wired_limit_prev": "0", "forced_kills": []}
EOF
  run llm-mode off --dry-run --relaunch
  [[ "$output" == *"open -b com.apple.Safari"* ]]
}

@test "off without state file fails cleanly" {
  run llm-mode off
  [ "$status" -eq 1 ]
  [[ "$output" == *"no state file"* ]]
}

@test "off --dry-run includes state file removal" {
  cat > "$LLM_MODE_DIR/state.json" <<'EOF'
{"apps": [], "agents": [], "wired_limit_prev": "0", "forced_kills": []}
EOF
  run llm-mode off --dry-run
  [[ "$output" == *"rm -f"* ]]
}
