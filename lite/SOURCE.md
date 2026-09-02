# Provenance — the `lite/` set

The `lite/` set — compact per-role playbook bases, their `.claude.md` host overlays, and the role
policies under `lite/role-policies/` — was extracted from a private coordination framework and
condensed for the container runtime that ships it. Each base is a
distillation of a much larger role contract; brevity is this set's value, and edits should
preserve it.

- One base (`<role>-agent.md`) + one host overlay (`<role>-agent.claude.md`) per role.
- One machine-readable contract (`role-policies/<role>.policy.json`) per role.
- Each base ends in a **generated doctrine block** — the role's governance doctrine, authored once
  in the repository-root `doctrine/<role>.md` and rendered into both weights, so the doctrine a
  role teaches cannot drift between them. Edit the source file, never the rendered block.

The human directing an instance is addressed as the **operator** throughout; the runtime may
supply a preferred call-name at session start.

**Stability:** the lite set is tuned continuously and rides product releases — behaviour
(prompts, procedures, defaults) may change without notice, while each role's purpose and
must/must-not boundaries change rarely and explicitly. A deployment that needs today's exact
behaviour should fork and pin its own copy rather than track this set.
