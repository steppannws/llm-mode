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

@test "on --dry-run tags the state file it writes as dry_run" {
  run llm-mode on --dry-run
  grep -q '"dry_run": true' "$LLM_MODE_DIR/state.json"
}

# F3 guard: a dry-run snapshot must never be mistaken for a real one. This
# only exercises the DRY_RUN=1 half of the guard (early-return, state
# preserved) — the DRY_RUN=0 half (real `on` replacing a dry-run state) can't
# be safely exercised here since it would perform a real restore-worthy
# snapshot on the test machine; see docs/manual-tests.md for that case.
@test "on --dry-run never clobbers an existing dry-run state file" {
  cat > "$LLM_MODE_DIR/state.json" <<'EOF'
{"apps": ["com.example.dry"], "agents": [], "wired_limit_prev": "0", "forced_kills": [], "dry_run": true}
EOF
  run llm-mode on --dry-run
  grep -q '"dry_run": true' "$LLM_MODE_DIR/state.json"
  grep -q "com.example.dry" "$LLM_MODE_DIR/state.json"
}
