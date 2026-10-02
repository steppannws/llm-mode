load helpers

# --- resolution -------------------------------------------------------------

@test "auto picks lmstudio when lms is on PATH" {
  isolate_path; stub lms 'exit 0'
  run llm-mode status
  [ "$status" -eq 0 ]
  [[ "$output" == *"backend: lmstudio"* ]] || false
  [[ "$output" == *"model: qwen3-coder-30b-a3b"* ]] || false
}

@test "auto picks ollama when it is the only server installed" {
  isolate_path; stub ollama 'exit 0'
  run llm-mode status
  [[ "$output" == *"backend: ollama"* ]] || false
  [[ "$output" == *"model: qwen3-coder:30b"* ]] || false
}

@test "auto prefers lmstudio over ollama" {
  isolate_path; stub ollama 'exit 0'; stub lms 'exit 0'
  run llm-mode status
  [[ "$output" == *"backend: lmstudio"* ]] || false
}

@test "auto picks llamacpp, then mlx, with their default models" {
  isolate_path; stub llama-server 'exit 0'
  run llm-mode status
  [[ "$output" == *"backend: llamacpp"* ]] || false
  [[ "$output" == *"model: unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q4_K_M"* ]] || false
  rm "$LLM_MODE_DIR/stubs/llama-server"; stub mlx_lm.server 'exit 0'
  run llm-mode status
  [[ "$output" == *"backend: mlx"* ]] || false
  [[ "$output" == *"model: mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit"* ]] || false
}

@test "CFG_MODEL overrides the backend default" {
  isolate_path; stub ollama 'exit 0'
  echo 'CFG_MODEL=llama3.2:3b' > "$LLM_MODE_DIR/config"
  run llm-mode status
  [[ "$output" == *"model: llama3.2:3b"* ]] || false
}

@test "status reports backend none when nothing is installed" {
  isolate_path
  run llm-mode status
  [ "$status" -eq 0 ]
  [[ "$output" == *"backend: none"* ]] || false
}

@test "on fails with install hints when no server is installed, before snapshot" {
  isolate_path; stub_memsize
  run llm-mode on --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"no LLM server found"* ]] || false
  [[ "$output" == *"llama-server"* ]] || false
  [ ! -f "$LLM_MODE_DIR/state.json" ]
}

@test "unknown CFG_BACKEND fails before snapshot" {
  isolate_path; stub_memsize; stub lms 'exit 0'
  echo 'CFG_BACKEND=vllm' > "$LLM_MODE_DIR/config"
  run llm-mode on --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown CFG_BACKEND 'vllm'"* ]] || false
  [ ! -f "$LLM_MODE_DIR/state.json" ]
}

@test "explicit backend that is not installed fails before snapshot" {
  isolate_path; stub_memsize; stub lms 'exit 0'
  echo 'CFG_BACKEND=ollama' > "$LLM_MODE_DIR/config"
  run llm-mode on --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"ollama not found on PATH"* ]] || false
  [ ! -f "$LLM_MODE_DIR/state.json" ]
}

@test "custom without CFG_SERVER_CMD fails before snapshot" {
  isolate_path; stub_memsize
  echo 'CFG_BACKEND=custom' > "$LLM_MODE_DIR/config"
  run llm-mode on --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"CFG_SERVER_CMD"* ]] || false
  [ ! -f "$LLM_MODE_DIR/state.json" ]
}

@test "LM Studio is whitelisted only when it is the active backend" {
  isolate_path; stub lms 'exit 0'; stub ollama 'exit 0'
  stub osascript 'if [[ "$*" == *"background only is false"* ]]; then echo "com.apple.Safari, ai.elementlabs.lmstudio"; else echo false; fi'
  llm-mode on --dry-run
  run grep -q 'ai.elementlabs.lmstudio' "$LLM_MODE_DIR/state.json"
  [ "$status" -ne 0 ]
  rm "$LLM_MODE_DIR/state.json"
  echo 'CFG_BACKEND=ollama' > "$LLM_MODE_DIR/config"
  llm-mode on --dry-run
  grep -q 'ai.elementlabs.lmstudio' "$LLM_MODE_DIR/state.json"
}

# --- spawned servers --------------------------------------------------------

# start the configured backend without running the rest of `on`
start_backend_only() {
  bash -c "source '$LLM_MODE_BIN'; resolve_backend \"\$CFG_BACKEND\"; backend start"
}

@test "ollama on --dry-run serves on CFG_PORT, pulls and preloads the model" {
  isolate_path; stub ollama 'exit 0'
  run llm-mode on --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"nohup env OLLAMA_HOST=127.0.0.1:1234 OLLAMA_KEEP_ALIVE=-1 ollama serve"* ]] || false
  [[ "$output" == *"ollama pull qwen3-coder:30b"* ]] || false
  [[ "$output" == *"127.0.0.1:1234/api/generate"* ]] || false
}

@test "llamacpp uses -hf for repos, -m for .gguf, appends CFG_SERVER_ARGS" {
  isolate_path; stub llama-server 'exit 0'
  run llm-mode on --dry-run
  [[ "$output" == *"nohup llama-server -hf unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q4_K_M --host 127.0.0.1 --port 1234"* ]] || false
  rm "$LLM_MODE_DIR/state.json"
  cat > "$LLM_MODE_DIR/config" <<'EOF'
CFG_MODEL=/models/q.gguf
CFG_SERVER_ARGS='-c 32768'
EOF
  run llm-mode on --dry-run
  [[ "$output" == *"nohup llama-server -m /models/q.gguf --host 127.0.0.1 --port 1234 -c 32768"* ]] || false
}

@test "mlx on --dry-run starts mlx_lm.server on CFG_PORT" {
  isolate_path; stub mlx_lm.server 'exit 0'
  run llm-mode on --dry-run
  [[ "$output" == *"nohup mlx_lm.server --model mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit --host 127.0.0.1 --port 1234"* ]] || false
}

@test "custom on --dry-run runs CFG_SERVER_CMD" {
  isolate_path
  cat > "$LLM_MODE_DIR/config" <<'EOF'
CFG_BACKEND=custom
CFG_SERVER_CMD='vllm serve my/model --port 1234'
EOF
  run llm-mode on --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"nohup bash -c exec vllm serve my/model --port 1234"* ]] || false
}

@test "spawned server is tracked in server.pid and stopped by serve-stop" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD="sleep 300"\n' > "$LLM_MODE_DIR/config"
  run start_backend_only
  [ "$status" -eq 0 ]
  pid=$(sed -n 1p "$LLM_MODE_DIR/server.pid")
  kill -0 "$pid"
  run llm-mode serve-stop
  [ "$status" -eq 0 ]
  [ ! -f "$LLM_MODE_DIR/server.pid" ]
  run kill -0 "$pid"
  [ "$status" -ne 0 ]
}

@test "second start does not spawn a duplicate server" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD="sleep 300"\n' > "$LLM_MODE_DIR/config"
  start_backend_only
  first=$(sed -n 1p "$LLM_MODE_DIR/server.pid")
  run start_backend_only
  [[ "$output" == *"already running"* ]] || false
  [ "$(sed -n 1p "$LLM_MODE_DIR/server.pid")" = "$first" ]
  llm-mode serve-stop
}

@test "serve-stop ignores a pid file whose process is gone" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD=true\n' > "$LLM_MODE_DIR/config"
  printf '99999\nThu Jan  1 00:00:00 2020\n' > "$LLM_MODE_DIR/server.pid"
  run llm-mode serve-stop
  [ "$status" -eq 0 ]
  [ ! -f "$LLM_MODE_DIR/server.pid" ]
}

@test "serve-stop never kills a recycled pid" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD=true\n' > "$LLM_MODE_DIR/config"
  sleep 300 >/dev/null 2>&1 3>&- &
  other=$!
  printf '%s\nThu Jan  1 00:00:00 2020\n' "$other" > "$LLM_MODE_DIR/server.pid"
  run llm-mode serve-stop
  kill -0 "$other"
  kill "$other"; wait "$other" 2>/dev/null || true
}

@test "a .gguf path with spaces reaches llama-server as one argument" {
  isolate_path
  stub llama-server 'printf "%s\n" "$@" > "$LLM_MODE_DIR/args"; exec sleep 300'
  cat > "$LLM_MODE_DIR/config" <<'EOF'
CFG_BACKEND=llamacpp
CFG_MODEL="/Volumes/My Drive/q.gguf"
EOF
  run start_backend_only
  [ "$status" -eq 0 ]
  for _ in 1 2 3 4 5; do [ -f "$LLM_MODE_DIR/args" ] && break; sleep 1; done
  llm-mode serve-stop
  [ "$(sed -n 1p "$LLM_MODE_DIR/args")" = "-m" ]
  [ "$(sed -n 2p "$LLM_MODE_DIR/args")" = "/Volumes/My Drive/q.gguf" ]
}

@test "wait_health gives up early when the spawned server exits" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD=false\nCFG_PORT=19877\nCFG_START_TIMEOUT=60\n' > "$LLM_MODE_DIR/config"
  start=$SECONDS
  run bash -c "source '$LLM_MODE_BIN'; resolve_backend custom; backend start; wait_health"
  [ "$status" -ne 0 ]
  (( SECONDS - start < 15 )) || false
}

# --- session state ----------------------------------------------------------

@test "on --dry-run records the backend in state.json" {
  isolate_path; stub ollama 'exit 0'
  llm-mode on --dry-run
  grep -q '"backend": "ollama"' "$LLM_MODE_DIR/state.json"
}

@test "off stops the backend recorded in state, not the configured one" {
  isolate_path; stub lms 'exit 0'
  sleep 300 >/dev/null 2>&1 3>&- &
  pid=$!
  printf '%s\n%s\n' "$pid" "$(LC_ALL=C TZ=UTC ps -p "$pid" -o lstart=)" > "$LLM_MODE_DIR/server.pid"
  echo '{"apps": [], "agents": [], "wired_limit_prev": "0", "forced_kills": [], "backend": "ollama"}' > "$LLM_MODE_DIR/state.json"
  run llm-mode off --dry-run
  kill "$pid"; wait "$pid" 2>/dev/null || true
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] kill $pid"* ]] || false
  [[ "$output" != *"lms server stop"* ]] || false
}

@test "off treats state without a backend field as lmstudio" {
  isolate_path; stub ollama 'exit 0'
  echo '{"apps": [], "agents": [], "wired_limit_prev": "0", "forced_kills": []}' > "$LLM_MODE_DIR/state.json"
  run llm-mode off --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"lms server stop"* ]] || false
}

@test "on refuses to switch backend while a session is active" {
  isolate_path; stub lms 'exit 0'
  echo '{"apps": [], "agents": [], "wired_limit_prev": "0", "forced_kills": [], "backend": "ollama"}' > "$LLM_MODE_DIR/state.json"
  run llm-mode on --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"run 'llm-mode off'"* ]] || false
  grep -q '"backend": "ollama"' "$LLM_MODE_DIR/state.json"
}

wait_listen() {
  for _ in $(seq 1 20); do lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1 && return 0; sleep 0.25; done
  return 1
}

@test "preflight refuses a busy port before anything changes" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD=true\nCFG_PORT=19876\n' > "$LLM_MODE_DIR/config"
  python3 -m http.server 19876 --bind 127.0.0.1 >/dev/null 2>&1 3>&- &
  srv=$!
  wait_listen 19876
  run bash -c "source '$LLM_MODE_BIN'; preflight"
  kill "$srv"; wait "$srv" 2>/dev/null || true
  [ "$status" -ne 0 ]
  [[ "$output" == *"port 19876 already in use"* ]] || false
}

@test "preflight allows a busy port when the same backend session is active" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD=true\nCFG_PORT=19878\n' > "$LLM_MODE_DIR/config"
  echo '{"apps": [], "agents": [], "wired_limit_prev": "0", "forced_kills": [], "backend": "custom"}' > "$LLM_MODE_DIR/state.json"
  python3 -m http.server 19878 --bind 127.0.0.1 >/dev/null 2>&1 3>&- &
  srv=$!
  wait_listen 19878
  run bash -c "source '$LLM_MODE_BIN'; preflight"
  kill "$srv"; wait "$srv" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

# --- final review fixes -----------------------------------------------------

@test "server.pid written under one locale and timezone is honored under another" {
  isolate_path
  printf 'CFG_BACKEND=custom\nCFG_SERVER_CMD="sleep 300"\n' > "$LLM_MODE_DIR/config"
  (export LC_ALL=es_ES.UTF-8 TZ=America/Argentina/Buenos_Aires; start_backend_only)
  pid=$(sed -n 1p "$LLM_MODE_DIR/server.pid")
  run env LC_ALL=C TZ=UTC llm-mode serve-stop
  run kill -0 "$pid"
  [ "$status" -ne 0 ] || { kill "$pid"; false; }
}

@test "auto-detect finds servers outside a minimal GUI PATH" {
  isolate_path
  mkdir -p "$LLM_MODE_DIR/extra"
  printf '#!/bin/sh\nexit 0\n' > "$LLM_MODE_DIR/extra/ollama"; chmod +x "$LLM_MODE_DIR/extra/ollama"
  run env -i HOME="$HOME" LLM_MODE_DIR="$LLM_MODE_DIR" LLM_MODE_EXTRA_PATH="$LLM_MODE_DIR/extra" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin "$LLM_MODE_BIN" status
  [[ "$output" == *"backend: ollama"* ]] || false
}

@test "ollama start warns when the model can't be pulled or loaded" {
  isolate_path
  mkdir -p "$LLM_MODE_DIR/www/v1"; echo '{"data": []}' > "$LLM_MODE_DIR/www/v1/models"
  stub ollama 'case "$1" in
    serve) cd "$LLM_MODE_DIR/www" && exec python3 -m http.server "${OLLAMA_HOST##*:}" --bind 127.0.0.1 ;;
    *) exit 1 ;;
  esac'
  printf 'CFG_BACKEND=ollama\nCFG_MODEL=nosuch:model\nCFG_PORT=19879\nCFG_START_TIMEOUT=20\n' > "$LLM_MODE_DIR/config"
  run bash -c "source '$LLM_MODE_BIN'; resolve_backend ollama; backend start; echo \"warn=\$START_WARN\""
  llm-mode serve-stop
  [[ "$output" == *"WARNING: ollama could not load 'nosuch:model'"* ]] || false
  [[ "$output" == *"warn=ollama could not load"* ]] || false
}
