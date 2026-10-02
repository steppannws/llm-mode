load helpers

@test "defaults used when no config file" {
  run llm-mode status
  [[ "$output" == *"model: qwen3-coder-30b-a3b"* ]]
  [[ "$output" == *"port: 1234"* ]]
}

@test "config file overrides defaults" {
  echo 'CFG_MODEL=my-model' > "$LLM_MODE_DIR/config"
  echo 'CFG_PORT=9999'     >> "$LLM_MODE_DIR/config"
  run llm-mode status
  [[ "$output" == *"model: my-model"* ]]
  [[ "$output" == *"port: 9999"* ]]
}

@test "single-quoted config values (menu bar app format) load verbatim" {
  cat > "$LLM_MODE_DIR/config" <<'EOF2'
CFG_MODEL='it'\''s $HOME "x" $(touch pwned)'
EOF2
  run llm-mode status
  [[ "$output" == *'model: it'"'"'s $HOME "x" $(touch pwned)'* ]] || false
  [ ! -e pwned ]
}
