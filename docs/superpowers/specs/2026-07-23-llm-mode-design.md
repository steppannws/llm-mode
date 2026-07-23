# llm-mode — Design

Date: 2026-07-23
Status: approved (conversation, pending written-spec review)

## Purpose

Turn a MacBook Pro M4 (24 GB unified memory) into a dedicated local-LLM coding server on demand. One command frees maximum RAM by quitting apps and disabling non-essential background processes, raises the GPU memory limit, starts an LM Studio inference server, and exposes it to a second Mac over an SSH tunnel. A restore command reverses everything.

## Decisions (from brainstorming)

- Form: shell-script core + thin SwiftUI menu bar wrapper.
- Cleanup level: aggressive (user apps + launch agents + system services), but every action recorded so it can be fully reversed/relaunched.
- Inference stack: LM Studio managed via `lms` CLI (MLX backend, OpenAI-compatible API on port 1234).
- Remote access: SSH tunnel only. Server binds localhost; client connects with `ssh -L`. No LAN-exposed API.

## Components

| Component | What | Notes |
|---|---|---|
| `llm-mode` | Single-file CLI (bash). Subcommands: `on`, `off`, `status`, `serve-stop`, `--dry-run` | The only place logic lives. Works over SSH. |
| `LLMMode.app` | SwiftUI `MenuBarExtra` app | Buttons: On / Off / Status. Shows free RAM, server state, loaded model, LAN hostname. Shells out to `llm-mode`. |
| `client-connect.sh` | Script for the client Mac | Opens `ssh -L 1234:localhost:1234 <user>@<host>.local`, waits until `http://localhost:1234/v1/models` responds, prints editor config hints. |
| `~/.llm-mode/state.json` | State snapshot | Written by `on`: quit apps (bundle ids), disabled launch agents/daemons (labels + domain), previous sysctl value, paused services. `off` replays it in reverse. |
| `~/.llm-mode/log` | Append-only action log | Every step, timestamped. |

## `on` sequence

1. Snapshot: running GUI apps (bundle ids), enabled launchd agents (user + gui domain), current `iogpu.wired_limit_mb` → `state.json`.
2. Graceful-quit all GUI apps via AppleScript `quit`; force `kill` stragglers after 10 s. LM Studio and Terminal/SSH parent excluded.
3. Disable + bootout non-whitelisted launch agents; pause Spotlight (`mdutil -a -i off`), Time Machine (`tmutil disable`), iCloud/Photos sync agents (`bird`, `cloudd`, `photoanalysisd` via bootout).
4. `sysctl iogpu.wired_limit_mb=20480` (leaves ~4 GB for macOS).
5. `lms server start` (localhost bind) then `lms load <default model>` (model configurable in `~/.llm-mode/config`; default: `qwen3-coder-30b-a3b` 4-bit MLX).
6. Report: RAM free before/after, API health check result.

## `off` sequence

Reverse from `state.json`: stop LM Studio server, restore previous sysctl value, re-enable + bootstrap agents, `mdutil -a -i on`, `tmutil enable`, optionally relaunch previously quit apps (`--relaunch` flag).

## Whitelist (never touched)

`sshd`, `loginwindow`, `WindowServer`, `mDNSResponder`, `notifyd`, `cfprefsd`, `systemstats`, `powerd`, `configd`, `distnoted`, `launchd`-critical set, LM Studio processes, the invoking shell/SSH session chain.

Known limitation, accepted: some system daemons respawn via `KeepAlive` regardless of bootout; they are small and left alone after one attempt.

## Privileges

`sysctl`, `mdutil`, `tmutil`, and system-domain bootouts need root. Installer adds a sudoers drop-in (`/etc/sudoers.d/llm-mode`) with `NOPASSWD` scoped to the exact commands needed (sysctl wired-limit key, mdutil on/off, tmutil enable/disable) — no launchctl, which the CLI only uses in the user domain without sudo. This keeps `on`/`off` non-interactive over SSH.

## Error handling

- Every step logs to `~/.llm-mode/log` before and after execution.
- `on` is idempotent: safe to re-run; skips already-done steps.
- Crash mid-`on`: `state.json` written first, so `off` always restores.
- Failed graceful quit → force kill after timeout, recorded as forced in state.

## Testing

- `--dry-run` prints every action without executing.
- Manual matrix: `on` → `status` → `off` restores agents/apps/sysctl; second `on` idempotent; SSH-only session from client Mac (tunnel + API check); pull-the-plug test (reboot mid-on → `off` still restores from state file).

## Out of scope (YAGNI)

- No App Store distribution, no code-signing pipeline (local `xcodebuild` only).
- No multi-model queueing/orchestration — LM Studio handles model lifecycle.
- No LAN-exposed API mode.
- No Linux/Windows client script.
