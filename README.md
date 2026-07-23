# llm-mode

Turn a Mac into a dedicated local-LLM coding server on demand. One command frees
maximum RAM by quitting apps and disabling non-essential background services,
raises the GPU memory limit, starts an LM Studio inference server, and exposes
it to a second Mac over an SSH tunnel. A restore command reverses everything.

## Components

- `bin/llm-mode` — the CLI, single source of logic. Runs on the server Mac.
- `client/client-connect.sh` — run on the client Mac; opens the SSH tunnel to the server's API.
- `app/` — SwiftUI menu bar wrapper (`LLMMode.app`) around the CLI: On / Off / Refresh, shows server state, free RAM, and host.
- `install.sh` — one-time setup: symlinks the CLI, grants scoped passwordless sudo, enables Remote Login.

## Requirements

- macOS 14+
- [LM Studio](https://lmstudio.ai) with its `lms` CLI on `PATH`
- `bats-core` (only for running the test suite)
- `xcodegen` (only for building the menu bar app)

## Install

```
./install.sh
```

This must be run manually (it prompts for your sudo password). It:

- symlinks `bin/llm-mode` to `/usr/local/bin/llm-mode`
- installs `/etc/sudoers.d/llm-mode`, a `NOPASSWD` grant scoped to exactly:
  `sysctl iogpu.wired_limit_mb=*`, `mdutil -a -i off`, `mdutil -a -i on`,
  `tmutil disable`, `tmutil enable` — nothing else, so `on`/`off` can run
  non-interactively (including over SSH). The grant is written to a temp file
  and validated with `visudo -c -f` before it's ever installed into
  `/etc/sudoers.d/`, so a malformed line can't take effect on the live sudo
  policy.
- enables Remote Login (`systemsetup -setremotelogin on`) so the client Mac can SSH in

Use `./install.sh --dry-run` to preview the commands without executing them.

## Server usage (`llm-mode`)

```
llm-mode {on|off|status|serve-stop} [--dry-run] [--relaunch]
```

- **`on`** — snapshots running GUI apps and enabled, user-installed launch
  agents to `~/.llm-mode/state.json`, quits GUI apps that are actually running
  (force-kills stragglers after 10s), disables those non-whitelisted launch
  agents, pauses Spotlight (`mdutil`) and Time Machine (`tmutil`), raises
  `iogpu.wired_limit_mb`, then starts the LM Studio server and loads the
  configured model. Prints free RAM before/after and an API health check. Only
  user-installed agents (ones with a plist under `~/Library/LaunchAgents`) are
  disabled — they're the only ones `off` can reliably restore; system/Apple
  GUI agents are left alone (`pause_services` separately handles `bird`,
  `cloudd`, `photoanalysisd`). If `state.json` already exists, `on` **never
  overwrites real state** — run `off` first to restore, then `on` again. The
  one exception: a state file written by a previous `on --dry-run` (tagged
  `"dry_run": true`) is not real state, so a real `on` replaces it with a
  fresh snapshot instead of treating it as something to protect.
- **`off`** — reverses everything from `state.json` on a best-effort basis:
  stops the LM Studio server, restores the previous `iogpu.wired_limit_mb`,
  re-enables and restarts launch agents, re-enables Spotlight/Time Machine,
  and (with `--relaunch`) reopens the apps that were quit. Deletes
  `state.json` on success. Every restore step is independent — if one fails
  (e.g. a `sudo` prompt can't be answered because there's no TTY, such as when
  triggered from the menu bar app), it's logged and `off` continues with the
  rest rather than aborting halfway. Prints `restored.` when everything
  succeeded, or `restored with N failed steps (see log)` otherwise.
- **`status`** — prints configured model, port, wired memory limit, whether
  the server responds, LAN hostname, and current free RAM.
- **`serve-stop`** — stops just the LM Studio server, without touching
  anything else.
- `--dry-run` — prints every action instead of executing it. It still writes
  a provisional `state.json` (tagged `"dry_run": true`) so the dry-run output
  reflects what a real `on` would snapshot; that provisional file is replaced
  outright by the next real `on`, so it never blocks or gets mistaken for
  real state to restore.

**Restore guarantee:** `state.json` is written before anything is changed, so
`off` can always restore even if the CLI was interrupted mid-`on`. A full
reboot is the final safety net — it resets any stubborn daemons regardless of
state file contents.

### Whitelist

`on` never touches: `sshd`, `loginwindow`, `WindowServer`, `mDNSResponder`,
`notifyd`, `cfprefsd`, `systemstats`, `powerd`, `configd`, `distnoted`,
`com.apple.Finder`, LM Studio (`LM Studio`/`lmstudio`/`lms`), and
`Terminal`/`iTerm` (so the invoking shell/SSH session survives).

**Run it from a whitelisted terminal.** Invoke `llm-mode` from Terminal.app,
iTerm2, or over an SSH session — those are the only terminal apps in the
whitelist. Other terminal apps (VS Code's integrated terminal, Warp, kitty,
etc.) are **not** whitelisted and will be quit like any other GUI app when you
run `on`.

### Configuration

State, config, and log live under `~/.llm-mode/`:

- `~/.llm-mode/state.json` — snapshot written by `on`, consumed and deleted by `off`
- `~/.llm-mode/config` — optional shell-sourced overrides
- `~/.llm-mode/log` — append-only, timestamped action log

Config keys (defaults shown):

```
CFG_MODEL=qwen3-coder-30b-a3b
CFG_PORT=1234
CFG_WIRED_MB=20480
```

## Client usage

From the client Mac:

```
client/client-connect.sh [user@host] [port]
```

Defaults come from `LLM_HOST` (default `stepan@m4.local`) and `LLM_PORT`
(default `1234`) env vars, or pass them positionally. It opens
`ssh -N -L <port>:localhost:<port> <host>`, waits for
`http://localhost:<port>/v1/models` to respond, then holds the tunnel open
until interrupted. Pass `--dry-run` to print the tunnel command without
connecting.

### Editor configuration

Once the tunnel is up, point any OpenAI-compatible client at
`http://localhost:1234/v1` (API key can be anything, e.g. `local`):

- **Continue** / **Cline**: set the model's API base URL to `http://localhost:1234/v1`
- **Zed**: configure a custom OpenAI-compatible provider with base URL `http://localhost:1234/v1`
- **aider**: `aider --openai-api-base http://localhost:1234/v1 --openai-api-key local`

## Menu bar app

```
cd app && xcodegen && xcodebuild -scheme LLMMode -configuration Release build
```

Requires the CLI already installed (`llm-mode` on `PATH`) since the app shells
out to it. Menu bar only, no Dock icon. Buttons: LLM Mode ON / OFF, Refresh,
Quit; shows model, up/down state, free RAM, and host.

## Model storage note

Models live wherever LM Studio is configured to store them. If pointing LM
Studio at an external drive, it must be formatted **APFS or exFAT** — FAT32's
4 GB per-file limit will block loading quantized model files larger than that.

## Testing

```
bats tests/
```

See `docs/manual-tests.md` for the manual test matrix to run on the actual
server/client Macs (RAM freed, agents restored, reboot safety net, etc.) —
things the automated suite can't exercise safely.
