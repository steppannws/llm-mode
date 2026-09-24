load helpers

@test "wired limit defaults to total RAM minus 4GB reserve" {
  stub_memsize 25769803776   # 24 GB
  run llm-mode status
  [[ "$output" == *"wired_limit_mb: 20480"* ]]
}

@test "CFG_RESERVE_MB changes the auto wired limit" {
  stub_memsize 68719476736   # 64 GB
  echo 'CFG_RESERVE_MB=8192' > "$LLM_MODE_DIR/config"
  run llm-mode status
  [[ "$output" == *"wired_limit_mb: 57344"* ]]
}

@test "explicit CFG_WIRED_MB wins over auto-detect" {
  stub_memsize 68719476736
  echo 'CFG_WIRED_MB=12345' > "$LLM_MODE_DIR/config"
  run llm-mode status
  [[ "$output" == *"wired_limit_mb: 12345"* ]]
}

@test "on refuses to start when reserve >= total RAM, before snapshot" {
  stub_memsize 4294967296    # 4 GB
  run llm-mode on --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"CFG_RESERVE_MB"* ]]
  [ ! -f "$LLM_MODE_DIR/state.json" ]
}

@test "free RAM counts free + speculative + inactive using reported page size" {
  stub vm_stat 'cat <<V
Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free:                             256.
Pages active:                        999999.
Pages inactive:                         512.
Pages speculative:                      256.
Pages wired down:                    999999.
Pages purgeable:                        128.
V'
  run llm-mode status
  [[ "$output" == *"free RAM: 4MB"* ]]
}
