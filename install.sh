#!/usr/bin/env bash
# install.sh — link CLI, grant scoped sudo, enable SSH.
set -euo pipefail
DRY=0; [[ "${1:-}" == "--dry-run" ]] && DRY=1
SRC="$(cd "$(dirname "$0")" && pwd)/bin/llm-mode"

say() { echo "$*"; }
doit() { say "-> $*"; [[ $DRY -eq 1 ]] || eval "$*"; }

doit "sudo ln -sf '$SRC' /usr/local/bin/llm-mode"

SUDOERS_LINE="$USER ALL=(root) NOPASSWD: /usr/sbin/sysctl iogpu.wired_limit_mb=*, /usr/bin/mdutil -a -i off, /usr/bin/mdutil -a -i on, /usr/bin/tmutil disable, /usr/bin/tmutil enable"
SUDOERS_TMP="$(mktemp -t llm-mode-sudoers)"
# validate with visudo BEFORE the file lands in /etc/sudoers.d, so a bad line
# never becomes live sudo policy
doit "echo '$SUDOERS_LINE' > '$SUDOERS_TMP'"
doit "sudo visudo -c -f '$SUDOERS_TMP'"
doit "sudo install -m 0440 '$SUDOERS_TMP' /etc/sudoers.d/llm-mode"
rm -f "$SUDOERS_TMP"

doit "sudo systemsetup -setremotelogin on"
say "done. run: llm-mode on --dry-run"
