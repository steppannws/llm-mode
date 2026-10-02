# Manual test matrix

Run on the M4 server Mac. Check off with date + result.

- [ ] `llm-mode on --dry-run` — output sane, nothing executed
- [ ] `llm-mode on` — apps quit, free RAM increases, API answers on :1234
- [ ] `llm-mode status` — server up, model loaded, correct host
- [ ] `llm-mode on` again — idempotent, no errors
- [ ] `llm-mode on` again — second real `on` does not relaunch previously
      quit apps (regression check for the quit-apps relaunch bug: quitting an
      app that isn't running must not launch it)
- [ ] From client Mac: `client/client-connect.sh` — tunnel opens, `curl http://localhost:1234/v1/models` succeeds
- [ ] `llm-mode off --relaunch` — agents re-enabled, Spotlight/TM back on, apps relaunch, sysctl restored (`sysctl -n iogpu.wired_limit_mb`)
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
- [ ] `ollama`: `llm-mode on` with Ollama.app running — app is quit, our `ollama serve` answers on :1234 with the model loaded (`curl localhost:1234/v1/models`); `off --relaunch` reopens Ollama.app
- [ ] `mlx`: `llm-mode on` — `mlx_lm.server` answers on :1234; `off` stops it
- [ ] `custom` with `CFG_SERVER_CMD='llama-server -hf <repo> --port 1234'` — same as llamacpp
- [ ] Switch config backend while `on` is active — `on` refuses, `off` stops the original backend
- [ ] Something else on :1234 (e.g. `python3 -m http.server 1234`) with a non-LM Studio backend — `on` refuses before quitting any app
- [ ] Bad model name with `llamacpp` — `on` prints the warning pointing at `server.log` within seconds, not after the full timeout
- [ ] Menu bar shows `<backend> · <model> — up`
