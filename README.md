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
  non-interactively (including over SSH)
- enables Remote Login (`systemsetup -setremotelogin on`) so the client Mac can SSH in

Use `./install.sh --dry-run` to preview the commands without executing them.

## Server usage (`llm-mode`)

```
llm-mode {on|off|status|serve-stop} [--dry-run] [--relaunch]
```

- **`on`** — snapshots running GUI apps and enabled launch agents to
  `~/.llm-mode/state.json`, quits GUI apps (force-kills stragglers after 10s),
  disables non-whitelisted launch agents, pauses Spotlight (`mdutil`) and Time
  Machine (`tmutil`), raises `iogpu.wired_limit_mb`, then starts the LM Studio
  server and loads the configured model. Prints free RAM before/after and an
  API health check. If `state.json` already exists, `on` **never overwrites
  it** — run `off` first to restore, then `on` again.
- **`off`** — reverses everything from `state.json`: stops the LM Studio
  server, restores the previous `iogpu.wired_limit_mb`, re-enables and
  restarts launch agents, re-enables Spotlight/Time Machine, and (with
  `--relaunch`) reopens the apps that were quit. Deletes `state.json` on
  success.
- **`status`** — prints configured model, port, wired memory limit, whether
  the server responds, LAN hostname, and current free RAM.
- **`serve-stop`** — stops just the LM Studio server, without touching
  anything else.
- `--dry-run` — logs and prints every action instead of executing it.

**Restore guarantee:** `state.json` is written before anything is changed, so
`off` can always restore even if the CLI was interrupted mid-`on`. A full
reboot is the final safety net — it resets any stubborn daemons regardless of
state file contents.

### Whitelist

`on` never touches: `sshd`, `loginwindow`, `WindowServer`, `mDNSResponder`,
`notifyd`, `cfprefsd`, `systemstats`, `powerd`, `configd`, `distnoted`,
`com.apple.Finder`, LM Studio (`LM Studio`/`lmstudio`/`lms`), and
`Terminal`/`iTerm` (so the invoking shell/SSH session survives).

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
