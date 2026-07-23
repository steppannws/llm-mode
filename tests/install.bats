load helpers

@test "install.sh --dry-run prints planned actions and exits 0" {
  run "$BATS_TEST_DIRNAME/../install.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"/usr/local/bin/llm-mode"* ]]
  [[ "$output" == *"/etc/sudoers.d/llm-mode"* ]]
  [[ "$output" == *"systemsetup -setremotelogin on"* ]]
}
