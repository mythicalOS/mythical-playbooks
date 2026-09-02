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
| `lite/` | The **container-lean weight** — one compact base + `.claude.md` overlay per role, and its own `lite/role-policies/`. Same roles, same boundaries, less prose. |
| `doctrine/<role>.md` | **Single-source governance doctrine** per role, named by a policy's `doctrine_source` and rendered verbatim into the `doctrine <role>` block of BOTH weights. Edit here, never in a rendered block. |
| `docs/protocols/` | Shared cross-role operational contracts. Use these for repeated mechanics — the coordination-record substrate (`coordination-records.md`), delivery + authority rhythms (`routing-and-authority.md`), reasoning discipline, modularity rules — instead of duplicating the full procedure in every role surface. |
| `scripts/` | The render/validate toolchain (below). |
| `METANOTES.md` | The single source of truth for the metanote contract; overlays must not duplicate it. |

The framework's contract and overview live in `ROLES.md` + `README.md`; treat those as the source of
truth rather than restating role scope elsewhere.

The framework-coordination skills the playbooks reference (`agent:routed-comms`,
`agent:coordination-wip-handoff`, `agent:cross-model-review`, …) live in the companion
`mythical-skills` repository under the `agent:` namespace, resolved via the deployment's
project-local `.claude/agent/` plugin (parallel to `mythical:`).

**Live-edit gotcha:** a deployment resolves the playbooks itself — on a workstation through a
**playbooks symlink** it maintains at this repo, and in a container from the read-only content
directory baked into its image. The symlink's own name is the deployment's choice and is named by
the deployment's own docs, not here. On the symlink path, edits here take effect for **newly created
sessions immediately** — no reinstall, no copy step; a running session keeps the contract it was
started with, and the baked path changes only when the image is rebuilt.

## Commands

No package manager / JS build — the toolchain is bash. **Run these only if your active role permits
command execution** (the read-only review roles and cto must not; record a forbidden command as
*not-run due to role boundary*). Each script `cd`s to the repo root itself.

- `scripts/render-contracts.sh` — regenerate the GENERATED blocks inside the surfaces named by each
  policy's `generated_surfaces`. **Both policy sets drive it** (`role-policies/` and
  `lite/role-policies/`), and every surface path is repo-root-relative in both. Block types:
  `contract <role>`, `allowed-skills <role>`, and `doctrine <role>` (the verbatim body of the
  policy's `doctrine_source`). Run after editing a policy JSON, a `doctrine/*.md`, or a generated
  surface. It runs in **two passes** — everything is validated before anything is written, and each
  rewrite is staged beside its target and installed only if the whole run rendered cleanly, so a
  refusal (or a mid-run write failure) leaves the corpus untouched rather than half-rendered.
  `--check` verifies freshness and mutates nothing (use in CI / pre-commit); `--selftest` proves
  every refusal path on a scratch copy — a blank, absent or unbound doctrine source, a malformed,
  duplicated, fenced or unpaired marker, a deleted doctrine block, a symlinked surface, a missing
  matrix host — and that each refusal mutates nothing.
- `scripts/validate-policies.sh` — schema-lint the policy JSON, and check the `doctrine_source`
  bijection both ways: a declared source must be exactly `doctrine/<role.id>.md`, a regular file
  (not a symlink) with non-whitespace content; a `doctrine/*.md` no policy declares fails.
  Needs `check-jsonschema` **or** `python3` + `jsonschema` on PATH.
- `scripts/check-policy-consistency.sh` — the cross-policy checks the schema cannot express:
  boundary parity between `role-policies/` and `lite/role-policies/` (`authority` +
  `stops_and_overrides` must be identical except for the deltas pinned exactly in
  `scripts/policy-parity-exceptions.json` — every pin is **typed** with a sanctioned transform
  kind (`citation-repoint` | `path-vocabulary`) and validated against that kind's constraints, so
  a semantic boundary change cannot be waved through; an unpinned difference fails, a stale pin
  fails, and a full-set role absent from lite fails unless declared with a reason in the same
  file's `lite_omissions`), plus the semantic lint (closed
  `must_route`/`override_authority`/`rhythm_d_route` vocabularies, `push_rules` rhythm coverage,
  duplicate detection), plus — under `--substrate` — **substrate parity over the PROSE surfaces**:
  no retired record-directory / routing-token grammar in `roles/**.md` or `lite/**.md`
  (`SUBSTRATE-LEGACY`); per-role tool-set **equality** between the weights, each side the union over
  the role's base file **and its shipped overlays** (`SUBSTRATE-SET`); a closed daemon-tool
  vocabulary (`SUBSTRATE-VOCAB`); and a role-aware permit rule derived from the role manifest —
  only the roles the daemon admits at the socket may be taught `git.request_landing` /
  `git.push_branch` (`SUBSTRATE-ROLE`); and the four ARTEFACT-keyed rules, which police what a
  surface says about a coordination record no matter which role says it and no matter what else
  that role may legitimately write — a record written with a write tool (`SUBSTRATE-RECORD-WRITE`),
  a record read by path or with a filesystem read tool (`SUBSTRATE-RECORD-READ`), an egress alias
  or an actor-free landing (`SUBSTRATE-EGRESS`), and a close-out taught in any order other than
  commit locally → publish + deliver the close-out → publish the branch (`SUBSTRATE-ORDER`). The
  `verdict` / `strategy` nouns are policed with a **document exemption**: a line naming the
  document home those artefacts legitimately live at (`docs/design-reviews/`, `docs/adr/`,
  `docs/ux-reviews/`, a long-form report) is exempt — the exemption is bought by the document
  surface, never by the role. A properly fenced ` ```historical ` block is exempt from
  every one of them; an unclosed fence is itself a finding (`SUBSTRATE-FENCE`), and an
  over-indented one is not a fence at all. There is no name-keyed exemption for
  `git.<policy-field>` tokens — cite a contract row by its row name, not a `git.`-prefixed token.
  `--substrate` is **on by default** (`SUBSTRATE_DEFAULT=1` in the script — both weights are on
  the daemon substrate now; the flag remains accepted so an explicit request still works), and the
  **selftest always runs with it ON**. `--selftest` proves each failure mode on
  scratch copies — the substrate cases against a clean SYNTHETIC fixture (live file names, stub
  content, deterministic seeds), never copies of the live corpus — and **asserts the case count**.
  A boundary-affecting edit to either policy set runs this; a legitimate new delta is pinned in the
  exceptions file **as its own reviewed decision**, never silently.
- `scripts/check-anchors.sh` — verify every `§"Section"` citation resolves to a real definition.
- `scripts/token-report.sh` — per-file token sizes.

Editing a contract is a pipeline: change the **policy JSON** (or prose) → `render-contracts.sh` →
`validate-policies.sh` → `check-policy-consistency.sh` → `check-anchors.sh`. Report any failing
check exactly; never imply the corpus is clean if a check did not pass.

## Boundaries & gotchas

- **Tool-managed / gitignored — don't hand-edit or commit:** the session registry and presence
  files, `.wip-handoff-staging/`, `.worktrees/`, `.claude/*` — all written by the deployment's
  runtime and its dev/bootstrap launcher. **None of them is a coordination surface**: recipient
  resolution is the daemon's (`coordination.resolve_recipient` / `coordination.list_sessions`),
  never a scan of a directory, and the staging area holds one WIP-handoff draft, never a delivery.
  This repo carries its own registry entries for standalone checkouts.
- A generated block is overwritten by `render-contracts.sh` — edit the **policy JSON**, not the
  rendered table, or the next render reverts you.
- Submodule-before-parent (when a deployment embeds this repo as a submodule): land changes on this
  repo's own remote first, then bump the gitlink in the superproject.
