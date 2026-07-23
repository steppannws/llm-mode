# Manual test matrix

Run on the M4 server Mac. Check off with date + result.

- [ ] `llm-mode on --dry-run` — output sane, nothing executed
- [ ] `llm-mode on` — apps quit, free RAM increases, API answers on :1234
- [ ] `llm-mode status` — server up, model loaded, correct host
- [ ] `llm-mode on` again — idempotent, no errors
- [ ] From client Mac: `client-connect.sh` — tunnel opens, `curl http://localhost:1234/v1/models` succeeds
- [ ] `llm-mode off --relaunch` — agents re-enabled, Spotlight/TM back on, apps relaunch, sysctl restored (`sysctl -n iogpu.wired_limit_mb`)
- [ ] Kill terminal mid-`on`, then `llm-mode off` — restore still works from state.json
- [ ] Reboot → everything normal (final safety net)
