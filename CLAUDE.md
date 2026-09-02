# CLAUDE.md

Read `AGENTS.md` first — the harness-neutral source of truth for this repo. It does **not** override
your active role contract. The import below loads it for Claude Code.

@AGENTS.md

Claude-specific notes:

- The `.claude.md` overlays (`roles/<role>-agent.claude.md`) are the **Claude Code** bindings of each base
  playbook; Codex sessions load `.codex.md`. The base `<role>-agent.md` + `ROLES.md` are shared.
- A deployment resolves role files through the **playbooks symlink** it maintains at this repo (or,
  in a container, the baked content directory). On the symlink path, an edit to a playbook reaches
  the next Claude session created with no reinstall; the deployment's own docs name the path.
