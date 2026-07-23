load helpers

@test "install.sh --dry-run prints planned actions and exits 0" {
  run "$BATS_TEST_DIRNAME/../install.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"/usr/local/bin/llm-mode"* ]]
  [[ "$output" == *"/etc/sudoers.d/llm-mode"* ]]
  [[ "$output" == *"systemsetup -setremotelogin on"* ]]
}

@test "sudoers line is exactly the scoped grant" {
  run "$BATS_TEST_DIRNAME/../install.sh" --dry-run
  [[ "$output" == *"NOPASSWD: /usr/sbin/sysctl iogpu.wired_limit_mb=*, /usr/bin/mdutil -a -i off, /usr/bin/mdutil -a -i on, /usr/bin/tmutil disable, /usr/bin/tmutil enable"* ]]
  [[ "$output" != *"launchctl"* ]]
}
