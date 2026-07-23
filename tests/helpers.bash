setup() {
  export LLM_MODE_DIR="$(mktemp -d)"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$LLM_MODE_DIR"
}
