load helpers

# valid JSON or fail; prints the parsed value of a python expression over `d`
jq_py() { python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print($1)"; }

@test "status --json prints one valid object with all fields" {
  stub_memsize
  run llm-mode status --json
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  keys=$(echo "$output" | jq_py "','.join(sorted(d))")
  [ "$keys" = "backend,backends,host,mem,mode,model,port,server,started_at" ]
  [ "$(echo "$output" | jq_py "d['backend']")" = "lmstudio" ]
  [ "$(echo "$output" | jq_py "d['model']")" = "qwen3-coder-30b-a3b" ]
  [ "$(echo "$output" | jq_py "d['port']")" = "1234" ]
  [ "$(echo "$output" | jq_py "d['mode']")" = "off" ]
  [ "$(echo "$output" | jq_py "d['started_at']")" = "None" ]
  [ "$(echo "$output" | jq_py "d['mem']['total_mb']")" = "24576" ]
  [ "$(echo "$output" | jq_py "d['mem']['wired_limit_mb']")" = "20480" ]
  [ "$(echo "$output" | jq_py "d['mem']['reserve_mb']")" = "4096" ]
  [ "$(echo "$output" | jq_py "d['backends']['lmstudio']")" = "True" ]
}

@test "status --json backends map reflects installed servers" {
  isolate_path; stub_memsize; stub ollama 'exit 0'; stub mlx_lm.server 'exit 0'
  run llm-mode status --json
  [ "$(echo "$output" | jq_py "d['backends']")" = "{'lmstudio': False, 'ollama': True, 'llamacpp': False, 'mlx': True}" ]
}

@test "status --json reports mode on and started_at from a real state" {
  stub_memsize
  echo '{"apps": [], "agents": [], "wired_limit_prev": "0", "forced_kills": [], "backend": "lmstudio", "started_at": 1790917393}' > "$LLM_MODE_DIR/state.json"
  run llm-mode status --json
  [ "$(echo "$output" | jq_py "d['mode']")" = "on" ]
  [ "$(echo "$output" | jq_py "d['started_at']")" = "1790917393" ]
}

@test "status --json reports mode off for a dry-run state" {
  stub_memsize
  echo '{"apps": [], "agents": [], "wired_limit_prev": "0", "forced_kills": [], "backend": "lmstudio", "dry_run": true, "started_at": 1}' > "$LLM_MODE_DIR/state.json"
  run llm-mode status --json
  [ "$(echo "$output" | jq_py "d['mode']")" = "off" ]
  [ "$(echo "$output" | jq_py "d['started_at']")" = "None" ]
}

@test "status --json stays valid JSON with no backend and a bad port" {
  isolate_path; stub_memsize
  echo 'CFG_PORT=abc' > "$LLM_MODE_DIR/config"
  run llm-mode status --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq_py "d['backend']")" = "None" ]
  [ "$(echo "$output" | jq_py "d['port']")" = "0" ]
}

@test "status --json escapes quotes and backslashes in strings" {
  stub_memsize
  cat > "$LLM_MODE_DIR/config" <<'EOF'
CFG_MODEL='a"b\c'
EOF
  run llm-mode status --json
  [ "$(echo "$output" | jq_py "d['model']")" = 'a"b\c' ]
}

@test "on --dry-run writes started_at into state" {
  llm-mode on --dry-run >/dev/null
  python3 -c "import json; d=json.load(open('$LLM_MODE_DIR/state.json')); assert isinstance(d['started_at'], int)"
}

@test "plain status output is unchanged by --json support" {
  stub_memsize
  run llm-mode status
  [ "${lines[0]}" = "backend: lmstudio" ]
  [[ "$output" != *"{"* ]] || false
}

@test "status --json survives ps failing for a vanished server pid" {
  stub_memsize
  stub curl 'exit 0'
  stub lsof 'echo 4242'
  stub ps 'exit 1'
  run llm-mode status --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq_py "d['server']")" = "up" ]
}
