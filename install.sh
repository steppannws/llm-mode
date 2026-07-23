#!/usr/bin/env bash
# install.sh — link CLI, grant scoped sudo, enable SSH.
set -euo pipefail
DRY=0; [[ "${1:-}" == "--dry-run" ]] && DRY=1
SRC="$(cd "$(dirname "$0")" && pwd)/bin/llm-mode"

say() { echo "$*"; }
doit() { say "-> $*"; [[ $DRY -eq 1 ]] || eval "$*"; }

doit "sudo ln -sf '$SRC' /usr/local/bin/llm-mode"

SUDOERS_LINE="$USER ALL=(root) NOPASSWD: /usr/sbin/sysctl iogpu.wired_limit_mb=*, /usr/bin/mdutil -a -i off, /usr/bin/mdutil -a -i on, /usr/bin/tmutil disable, /usr/bin/tmutil enable"
doit "echo '$SUDOERS_LINE' | sudo tee /etc/sudoers.d/llm-mode >/dev/null"
doit "sudo visudo -c -f /etc/sudoers.d/llm-mode"

doit "sudo systemsetup -setremotelogin on"
say "done. run: llm-mode on --dry-run"
