# Manual test matrix

Run on the M4 server Mac. Check off with date + result.

- [ ] `llm-mode on --dry-run` — output sane, nothing executed
- [ ] `llm-mode on` (with `CFG_QUIT_APPS=1`) — apps quit, free RAM increases, API answers on :1234
- [ ] `llm-mode status` — server up, model loaded, correct host
- [ ] `llm-mode on` again — idempotent, no errors
- [ ] `llm-mode on` again — second real `on` (with `CFG_QUIT_APPS=1`) does not relaunch previously
      quit apps (regression check for the quit-apps relaunch bug: quitting an
      app that isn't running must not launch it)
- [ ] From client Mac: `client/client-connect.sh` — tunnel opens, `curl http://localhost:1234/v1/models` succeeds
- [ ] `llm-mode off --relaunch` (after an `on` with `CFG_QUIT_APPS=1`) — agents re-enabled, Spotlight/TM back on, apps relaunch, sysctl restored (`sysctl -n iogpu.wired_limit_mb`)
- [ ] Kill terminal mid-`on`, then `llm-mode off` — restore still works from state.json
- [ ] `off` triggered from the menu bar app (no TTY) — completes with sudo
      steps either succeeding or logged as failed in `~/.llm-mode/log`, never
      aborting midway (some steps may fail without a TTY to satisfy `sudo`)
- [ ] `llm-mode on --dry-run` then `llm-mode on` for real — the real `on`
      replaces the dry-run snapshot (`"dry_run": true` in state.json) with a
      fresh real one instead of treating it as protected existing state
- [ ] Reboot → everything normal (final safety net)

## Backends

Run each with `CFG_BACKEND=<name>` in `~/.llm-mode/config`, on the server Mac.

- [ ] `llamacpp`: `llm-mode on` — `llama-server` downloads/loads the model, API answers on :1234, `server.pid` exists; `llm-mode off` — process gone, `server.pid` removed
- [ ] `ollama`: `llm-mode on` with Ollama.app running and `CFG_QUIT_APPS=1` — app is quit, our `ollama serve` answers on :1234 with the model loaded (`curl localhost:1234/v1/models`); `off --relaunch` reopens Ollama.app
- [ ] `mlx`: `llm-mode on` — `mlx_lm.server` answers on :1234; `off` stops it
- [ ] `custom` with `CFG_SERVER_CMD='llama-server -hf <repo> --port 1234'` — same as llamacpp
- [ ] Switch config backend while `on` is active — `on` refuses, `off` stops the original backend
- [ ] Something else on :1234 (e.g. `python3 -m http.server 1234`) with a non-LM Studio backend — `on` refuses before quitting any app
- [ ] Bad model name with `llamacpp` — `on` prints the warning pointing at `server.log` within seconds, not after the full timeout
- [ ] Menu bar shows `<backend> · <model> — up`

## Menu bar app

- [ ] Panel renders in dark and light mode; values match `llm-mode status --json`
- [ ] Panel refreshes every ~3 s while open (uptime ticks, free RAM moves); no CLI runs while closed (`log` shows no new lines)
- [ ] GPU ring and "Model" segment show a plausible size with a model loaded (LM Studio and llama.cpp) — see the model_mb decision in the spec
- [ ] With `CFG_QUIT_APPS` off (default), toggle ON starts directly — no overlay, no app quits
- [ ] Settings → Apps → enable "Quit other apps when turning on"; toggle ON → overlay lists the right apps; Cancel (also while it's loading) leaves everything running
- [ ] "Don't ask again" + Turn On → next ON skips the overlay; re-enable in Settings → General brings it back
- [ ] Failed `on` (e.g. `CFG_BACKEND=mlx` without mlx installed) → toggle snaps back, red error under the header
- [ ] ⚙︎ opens Settings in front of other windows
- [ ] Settings comes to the front when opened from the panel
- [ ] Each Settings tab writes the right `CFG_*` line; hand-written lines and comments in the config survive
- [ ] Settings → Memory: opening the tab with a hand-set `CFG_WIRED_MB` (e.g. 20000) leaves the config file unchanged
- [ ] Launch at login: enable, log out/in, app is in the menu bar
- [ ] Remove `/usr/local/bin/llm-mode` → red "CLI not found" card, toggle disabled
