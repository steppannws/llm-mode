setup() {
  export LLM_MODE_DIR="$(mktemp -d)"
  export LLM_MODE_BIN="$BATS_TEST_DIRNAME/../bin/llm-mode"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  # pin backend auto-detect to lmstudio regardless of what this machine has
  stub lms 'exit 0'
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

# drop the default lms stub and every real LLM server from PATH, so
# backend auto-detect only sees stubs added after this call
isolate_path() {
  rm -f "$LLM_MODE_DIR/stubs/lms"
  export LLM_MODE_EXTRA_PATH="$LLM_MODE_DIR/extra"
  export PATH="$LLM_MODE_DIR/stubs:$BATS_TEST_DIRNAME/../bin:/usr/bin:/bin:/usr/sbin:/sbin"
}

# 24 GB machine; any other sysctl read returns 0
stub_memsize() {
  stub sysctl 'if [[ "$*" == "-n hw.memsize" ]]; then echo '"${1:-25769803776}"'; else echo 0; fi'
}
