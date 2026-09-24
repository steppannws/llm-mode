#!/usr/bin/env bash
# client-connect.sh — run on the client Mac; tunnels the LLM API from the server.
set -euo pipefail
HOST="${LLM_HOST:-stepan@m4.local}"
PORT="${LLM_PORT:-1234}"
DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    *@*)       HOST="$a" ;;
    [0-9]*)    PORT="$a" ;;
  esac
done

CMD="ssh -N -L $PORT:localhost:$PORT $HOST"
echo "tunnel: $CMD"
echo "API when up: http://localhost:$PORT/v1  (OpenAI-compatible)"
echo "aider: aider --openai-api-base http://localhost:$PORT/v1 --openai-api-key local"
[[ $DRY -eq 1 ]] && exit 0

$CMD &
TUNNEL_PID=$!
trap 'kill $TUNNEL_PID 2>/dev/null' EXIT
echo "waiting for API..."
for _ in $(seq 1 30); do
  kill -0 $TUNNEL_PID 2>/dev/null || { echo "ssh exited" >&2; exit 1; }
  curl -sf -m 2 "http://localhost:$PORT/v1/models" >/dev/null && { echo "API ready."; break; }
  sleep 2
done
wait $TUNNEL_PID
