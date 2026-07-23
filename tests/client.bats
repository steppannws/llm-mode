load helpers

@test "client-connect --dry-run prints tunnel command and API URL" {
  run "$BATS_TEST_DIRNAME/../client/client-connect.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"ssh -N -L 1234:localhost:1234"* ]]
  [[ "$output" == *"http://localhost:1234/v1"* ]]
}
