# CLAUDE.md

Read `AGENTS.md` first — the harness-neutral source of truth for this repo. It does **not** override
your active role contract. The import below loads it for Claude Code.

@AGENTS.md

Claude-specific notes:

- The `.claude.md` overlays (`roles/<role>-agent.claude.md`) are the **Claude Code** bindings of each base
  playbook; Codex sessions load `.codex.md`. The base `<role>-agent.md` + `ROLES.md` are shared.
- Launcher deployments load role files through `~/.claude/mythical-playbooks` (→ this repo), so edits
  to a playbook reach the next spawned Claude session with no reinstall.
