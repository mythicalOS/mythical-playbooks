<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/logo-dark.svg">
    <img src=".github/assets/logo-light.svg" alt="mythicalOS" width="84" height="84">
  </picture>
</p>

<h1 align="center">mythical-playbooks</h1>

<p align="center">
  <strong>A coordination OS for AI agents: opinionated role playbooks, independent review gates, and the protocols between them.</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache_2.0-blue.svg" alt="License: Apache-2.0"></a>
  <img src="https://img.shields.io/badge/roles-11-0F6B66.svg" alt="11 roles">
  <img src="https://img.shields.io/badge/content-markdown_only-555.svg" alt="Content: markdown only">
  <a href="https://mythicalos.ai"><img src="https://img.shields.io/badge/part_of-mythicalOS-0F6B66.svg" alt="Part of mythicalOS"></a>
</p>

---

A **playbook** is a direct, opinionated system prompt that gives an AI agent a role, a discipline, and
a set of rules for handing work off to other roles. Load one into a fresh session and the agent has a
posture — including when to refuse. This repo is markdown **content**, not application code; the only
"build" is a small bash toolchain that keeps generated contract blocks in lockstep with policy data.

**Why playbooks, not skills?** A skill tells an agent what it *can do*; a playbook tells it *who it is
and what discipline it exercises*. The load-bearing failures in multi-agent work aren't capability
gaps — they're discipline gaps: silent scope-creep, drift from the brief, confident wrong work. The
playbooks here are calibrated against real coordination failures and lean opinionated on purpose.

## The roles

Eleven roles, each a base playbook plus Claude Code (`.claude.md`) and Codex (`.codex.md`) overlays.
Four pipeline roles deliver work, four read-only review roles gate it, plus observation and apex
strategy. Each role has a narrow remit and protects the others' boundaries.

| Role | Remit |
|------|-------|
| **pm** | Front-of-pipeline scoping — turns a fuzzy idea into a PRD + master plan |
| **lead** | Orchestrates execution across workers; never writes production code |
| **worker** | Executes scoped tasks at senior-engineer latitude; stops at review gates |
| **explorer** | One-off, read-only codebase reconnaissance before scoping |
| **architect** | Architecture review (read-only) — accept / accept-with-changes / reject / re-scope |
| **qa** | Test strategy (read-only) — a risk-weighted coverage floor |
| **reviewer** | Security / compliance review (read-only) — severity-graded findings |
| **designer** | Visual / interaction / design-system review |
| **ops** | Read-only production health observation |
| **cto** | Strategic apex; the team's operator-proxy under authority rhythm D |
| **devil** | Operator-only sparring, outside the authority chain |

Roles that face the human address them as the **operator**. `spm` is a defined-but-not-operational
strategic stub. See **[`ROLES.md`](ROLES.md)** for the boundary contract — each role's purpose and its
must / must-not lines — and **[`docs/framework.md`](docs/framework.md)** for how work flows: the
branch-addressed handoff, workflow profiles, the gate matrix, authority rhythms, and cross-model
review. Coordination itself runs on daemon-stored records, not on files —
**[`docs/protocols/coordination-records.md`](docs/protocols/coordination-records.md)** is that
contract, and the same daemon is the only thing that writes to a git remote.

## Stability

A **living system, not a frozen spec.** Playbooks are tuned continuously against real operation, and
a release may change role behaviour without notice when something is found to work better. What stays
deliberately stable is **intent at the boundaries** — a role's purpose and its must/must-not lines in
`ROLES.md`. **If you depend on today's exact behaviour, fork and pin.**

## Layout

| Path | What it is |
|------|------------|
| [`ROLES.md`](ROLES.md) | The boundary contract — authoritative. |
| `roles/<role>-agent.md` `.claude.md` `.codex.md` | Base playbook per role + host overlays. |
| `role-policies/<role>.policy.json` | Machine-readable contract data; generated blocks render from it. |
| [`docs/framework.md`](docs/framework.md) | How work flows: profiles, gates, cross-model review, artefacts, usage. |
| `docs/protocols/` | Shared cross-role mechanics (the coordination-record substrate, delivery + authority, discipline, modularity). |
| `scripts/` | The bash render/validate toolchain. |

The framework-coordination skills the playbooks reference live in the companion
[`mythical-skills`](https://github.com/mythicalOS/mythical-skills) repository.

## License

**Apache-2.0** — see [LICENSE](LICENSE) and [NOTICE](NOTICE). The licence covers the content, not the
mythicalOS name and marks — see [TRADEMARK.md](TRADEMARK.md). If you adapt these and find
improvements worth sharing back, please do. Contributions welcome under a DCO sign-off, no CLA — see
[CONTRIBUTING.md](CONTRIBUTING.md).
