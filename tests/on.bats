load helpers

@test "on --dry-run mentions quit, bootout, mdutil, sysctl" {
  run llm-mode on --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"osascript"* ]]
  [[ "$output" == *"launchctl bootout"* ]] || [[ "$output" == *"no agents to disable"* ]]
  [[ "$output" == *"mdutil"* ]]
  [[ "$output" == *"iogpu.wired_limit_mb=20480"* ]]
}

@test "on --dry-run never calls kill" {
  run llm-mode on --dry-run
  [[ "$output" != *"[dry-run] kill "* ]]
}
