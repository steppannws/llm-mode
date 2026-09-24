load helpers

@test "client-connect --dry-run prints tunnel command and API URL" {
  run "$BATS_TEST_DIRNAME/../client/client-connect.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"ssh -N -L 1234:localhost:1234"* ]]
  [[ "$output" == *"http://localhost:1234/v1"* ]]
}

@test "client-connect.ps1 -DryRun prints tunnel command and API URL" {
  command -v pwsh >/dev/null || skip "pwsh not installed"
  run pwsh -NoProfile -File "$BATS_TEST_DIRNAME/../client/client-connect.ps1" you@srv.local 4321 -DryRun
  [ "$status" -eq 0 ]
  [[ "$output" == *"ssh -N -L 4321:localhost:4321 you@srv.local"* ]]
  [[ "$output" == *"http://localhost:4321/v1"* ]]
}
