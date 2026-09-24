setup() {
  export LLM_MODE_DIR="$(mktemp -d)"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$LLM_MODE_DIR"
}

# put fake binaries first on PATH: stub <name> <script body>
stub() {
  mkdir -p "$LLM_MODE_DIR/stubs"
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$LLM_MODE_DIR/stubs/$1"
  chmod +x "$LLM_MODE_DIR/stubs/$1"
  export PATH="$LLM_MODE_DIR/stubs:$PATH"
}

# 24 GB machine; any other sysctl read returns 0
stub_memsize() {
  stub sysctl 'if [[ "$*" == "-n hw.memsize" ]]; then echo '"${1:-25769803776}"'; else echo 0; fi'
}
