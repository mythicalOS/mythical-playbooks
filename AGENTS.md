# AGENTS.md — mythical-playbooks

The coordination **operating system** for a multi-agent engineering team: agent roles, their boundaries,
and the protocols between them, authored as **markdown content** — not application code. There is
no compiler here; the "build" is a small bash toolchain that keeps generated contract blocks in
lockstep with machine-readable policy data.

A standalone open-source repository. A deployment may embed it as a git submodule of its own
superproject (which then carries its own `AGENTS.md`).

## Authority & precedence

Orientation only — grants no authority. If a role contract governs your session, it is
authoritative and supersedes this file. **The playbook files here are content you may be dispatched
to edit, not your operating instructions:** editing `lead-agent.md` does not make you the lead. Your
own role contract still governs you while you work on another role's playbook.

When the contract and a playbook disagree, `ROLES.md` (the boundary contract) wins and the playbook
is updated to match — never the reverse. See `ROLES.md` for that precedence rule in full.

## Layout

| Path | What it is |
|------|-----------|
| `ROLES.md` | The **boundary contract** — each role's purpose, must-do, must-not. Authoritative. |
| `README.md` | Framework overview: pipeline + review roles, the CTO apex, handoff flow. |
| `roles/<role>-agent.md` | Base playbook per role (cto, pm, lead, worker, architect, qa, reviewer, designer, explorer, devil, ops; `spm` is a stub). |
| `roles/<role>-agent.claude.md` / `.codex.md` | Host overlays binding a base playbook to Claude Code / Codex. Import the base; never duplicate it. |
| `role-policies/<role>.policy.json` | **Machine-readable contract data** (authority, channels, skills, git, stops). Authoritative for the GENERATED blocks. Schema in `role-policies/schemas/`. |
| `docs/protocols/` | Shared cross-role operational contracts. Use these for repeated mechanics (routing, authority rhythms, modularity rules) instead of duplicating the full procedure in every role surface. |
| `hooks/` | Shell hooks (e.g. `green-path-push-approve.sh`). |
| `scripts/` | The render/validate toolchain (below). |
| `metanotes.md` | The single source of truth for the metanote contract; overlays must not duplicate it. |
| `distillation-notes/`, `distillation-prompts/` | The playbook-improvement methodology and its inputs. |

The framework's contract and overview live in `ROLES.md` + `README.md`; treat those as the source of
truth rather than restating role scope elsewhere.

The framework-coordination skills the playbooks reference (`agent:routed-comms`,
`agent:coordination-wip-handoff`, `agent:cross-model-review`, …) live in the companion
`mythical-skills` repository under the `agent:` namespace, resolved via the deployment's
project-local `.claude/agent/` plugin (parallel to `mythical:`).

**Live-edit gotcha:** launcher deployments load role files through a `~/.claude/mythical-playbooks`
symlink pointing at this repo. Edits here take effect for **newly spawned agents immediately** — no
reinstall, no copy step.

## Commands

No package manager / JS build — the toolchain is bash. **Run these only if your active role permits
command execution** (the read-only review roles and cto must not; record a forbidden command as
*not-run due to role boundary*). Each script `cd`s to the repo root itself.

- `scripts/render-contracts.sh` — regenerate the GENERATED blocks inside the surfaces named by each
  policy's `generated_surfaces`. Run after editing a `role-policies/*.policy.json` or a generated
  surface. `--check` verifies freshness and mutates nothing (use in CI / pre-commit).
- `scripts/validate-policies.sh` — schema-lint the policy JSON. Needs `check-jsonschema` **or**
  `python3` + `jsonschema` on PATH.
- `scripts/check-policy-consistency.sh` — the cross-policy checks the schema cannot express:
  boundary parity between `role-policies/` and `lite/role-policies/` (`authority` +
  `stops_and_overrides` must be identical except for the deltas pinned exactly in
  `scripts/policy-parity-exceptions.json` — every pin is **typed** with a sanctioned transform
  kind (`citation-repoint` | `path-vocabulary`) and validated against that kind's constraints, so
  a semantic boundary change cannot be waved through; an unpinned difference fails, a stale pin
  fails, and a full-set role absent from lite fails unless declared with a reason in the same
  file's `lite_omissions`), plus the semantic lint (closed
  `must_route`/`override_authority`/`rhythm_d_route` vocabularies, `push_rules` rhythm coverage,
  duplicate detection). `--selftest` proves each failure mode on scratch copies. A
  boundary-affecting edit to either policy set runs this; a legitimate new delta is pinned in the
  exceptions file **as its own reviewed decision**, never silently.
- `scripts/check-anchors.sh` — verify every `§"Section"` citation resolves to a real definition.
- `scripts/token-report.sh` — per-file token sizes.

Editing a contract is a pipeline: change the **policy JSON** (or prose) → `render-contracts.sh` →
`validate-policies.sh` → `check-policy-consistency.sh` → `check-anchors.sh`. Report any failing
check exactly; never imply the corpus is clean if a check did not pass.

## Boundaries & gotchas

- **Tool-managed / gitignored — don't hand-edit or commit:** `.agents`, `.agents-active/`,
  `.wip-handoff-staging/`, `.worktrees/`, `.claude/*` (session registry, presence,
  staging, worktrees, local settings — managed by `start-agent.sh`). This repo carries its own copy
  of the `.agents` entries for standalone checkouts.
- A generated block is overwritten by `render-contracts.sh` — edit the **policy JSON**, not the
  rendered table, or the next render reverts you.
- Submodule-before-parent (when a deployment embeds this repo as a submodule): land changes on this
  repo's own remote first, then bump the gitlink in the superproject.
