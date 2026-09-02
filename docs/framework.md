# The framework in depth

Reference detail behind the [README](../README.md). The README is the overview and the role
line-up; this document carries how work flows, the risk-proportional process (profiles, gates,
cross-model review), the role-policy layer, the coordination-artefact catalogue, and the usage
recipes. The **boundary contract** — each role's purpose and its must / must-not lines — is
[`ROLES.md`](../ROLES.md), which wins wherever a playbook and it disagree. Shared cross-role
mechanics live under [`docs/protocols/`](protocols/) — in particular
[`coordination-records.md`](protocols/coordination-records.md), which is the contract for the
coordination substrate every section below assumes.

## Roles, in detail

### Pipeline roles

```
User
  ↕ (user's language)

┌─ explorer-agent ─────────────────────────────────────────────────┐
│ Reads existing codebases. Produces navigation artefacts.         │
│ One-off, read-only. Skipped for greenfield work.                 │
└──────────────────────────────────────────────────────────────────┘
  ↓ artefacts at <repo>/docs/architecture/

┌─ pm-agent ───────────────────────────────────────────────────────┐
│ Scopes new work. Premise-challenges. Locks the problem before    │
│ the solution. Emits a PRD + master plan + initial PM→lead handoff.│
└──────────────────────────────────────────────────────────────────┘
  ↓ PRD + master plan under <repo>/docs/; the PM→lead handoff as a record

┌─ lead-agent ─────────────────────────────────────────────────────┐
│ Orchestrates execution. Coordinates workers. Maintains state.    │
│ Pushes back on scope. Never writes production code.              │
└──────────────────────────────────────────────────────────────────┘
  ↕ task / close-out / handoff records on the daemon

┌─ worker-agent ───────────────────────────────────────────────────┐
│ Executes scoped tasks at senior-engineer latitude. Stops at      │
│ review gates. Quantifies evidence. Reports via close-outs.       │
└──────────────────────────────────────────────────────────────────┘
```

### Review roles (read-only side-inputs to the pipeline)

The lead invokes these when a phase has the relevant surface; the architect and designer may also be
dispatched by the PM during scoping, or by the operator directly. Architect and reviewer publish
verdict records and QA publishes a test-strategy record (a coverage floor, not a pass/fail verdict);
the designer's UX verdict is a committed **document** whose path is delivered to the recipient — the
contract of each role says which, and neither substitutes for the other
([`protocols/coordination-records.md`](protocols/coordination-records.md)).

- **architect** — reviews architecture (proposal, existing code, or hybrid). Verdicts: accept /
  accept-with-changes / reject / re-scope. Hard-block; operator-only override.
- **qa** — defines test strategy per phase or component: what to test, how, and what *not* to test.
  May include concrete cases as the floor; the worker writes the tests.
- **reviewer** — security / compliance / code review at Gate 2. Severity-graded findings
  (CRITICAL/HIGH/MEDIUM/LOW/INFO); CRITICAL is hard-block, operator-only override.
- **designer** — visual / interaction / design-system review. Owns `DESIGN.md` and design-system
  artefacts; `revise` is advisory-strong, lead-overridable.

### Observation and sparring

- **ops** — a scheduled read-only sweep over running production. Emits maintenance/bug intake or an
  incident surface; never mutates production. Not provisionable or launchable until a deployment
  wires the read-only observability MCP allowlist/lease.
- **devil** — operator-only sparring, outside the A/B/C/D authority chain. Challenges assumptions,
  denominators, and framing. Writes no artefacts, dispatches no one, cannot be addressed by agents.

Each role protects the others' territory: the lead never executes production code; the worker never
decides scope; the review roles never write the work they review; ops never executes what it
observes; devil never enters the authority chain.

### Cross-role dialogue

The default is record-based — decisions, verdicts, and release authority route through published
coordination records, addressed to a resolved recipient and delivered to it
([`protocols/coordination-records.md`](protocols/coordination-records.md)). Four short channels exist
for **bounded fact-or-intent questions that don't change scope, verdict, or authority**:
reviewer↔worker, architect↔dispatcher/worker, qa↔worker, designer↔worker. The rule: clarification is
permitted; decisions are not. Any exchange that changes scope, gates, risk floor, severity, or
release authority must land back in the lead's record trail before it binds.

## Execution model — parallel-by-default branch isolation

Build work is parallel-by-default. Each worker runs in a **dedicated git worktree** on a **feature
branch it creates and names** (`feat/<ISSUE>-<slug>`). Isolation is by construction: a separate
`.git` index and `HEAD` per worktree, so concurrent workers cannot collide.

**No agent writes to the remote — nothing an agent runs pushes, lands, or otherwise changes remote
state. The daemon is the only git egress**, on every lane and under every authority rhythm. Reading
is not egress: a review role fetches the branch it is reviewing, and that changes nothing.
A worker commits locally — a local commit reaches no shared state, so it is
authorized by the dispatch itself and is never held for an approval — and then *asks* the daemon to
publish the branch: `git.push_branch {repo, branch, sha}`, naming the exact commit id. The lead may
ask for the same thing (it is the one who carries the documents the read-only roles commit and stop
on). No other role may ask at all, and nobody — agent or operator — runs the command: the daemon
holds the credential and performs the operation.

The hand-off is branch-addressed:

- **Worker**, in this order and no other: commits locally, then publishes and delivers its
  close-out record naming that commit — its required `Branch: <name> @ <SHA>` field — and only then
  asks for the branch publication, when the active rhythm permits it. The close-out is never held
  for a rhythm; the publication is. Under a rhythm that defers it, the close-out truthfully names a
  committed but unpublished SHA, and the gate chain fetches that SHA once the branch is published.
- **Review roles** `git fetch` that branch and review against that SHA — a real diff, never a prose
  apply-spec — and publish their verdicts as records naming the same SHA.
- **Lead** verifies every verdict cites that SHA, then **requests the landing**:
  `git.request_landing {sha, task_record_id, repo}`. It owns and serializes landings; it performs
  none. There is no merge agent.
- **The daemon is the gate.** It re-checks the verdict set for exactly that SHA, trusting only the
  author role it stamped on each record when the record was published — never the record's text,
  which the daemon cannot verify — and refuses an incomplete set without touching anything. It then
  lands per the project's **push flow** (`pr` | `land-then-ack` | `auto`) and composes the review
  summary into the merge commit or the pull request.
- **The acknowledgement is authority, not ceremony.** Under `land-then-ack` the prepared landing
  waits for the operator's acknowledgement — the CTO's under rhythm D. A pull request a human merges
  before that acknowledgement arrives is a **policy breach, not a landing**: the daemon fails the
  landing, finalizes nothing, and tells the lead.
- **PM / CTO** work on the integration branch; the permanent documents they own live there, at
  their contracted paths. Only the worker's *implementation* lives on the feature branch until the
  daemon lands it.

## Risk-proportional process

Not every change needs the full machinery. At cycle start the lead records one of three **workflow
profiles**, calibrated by reversibility, blast radius, and contract/data/security impact:

| Profile | Typical scope | Minimum control |
|---------|---------------|-----------------|
| **Lightweight** | Docs correction, isolated reversible fix, local refactor | One scoped close-out with verification evidence |
| **Standard** | Feature work, shared internal contract, component change | Planned verification + one review gate |
| **High-risk** | Auth, personal data, financial flows, public API, schema migration, deploy/release | Full 3-gate model + explicit operator override rules |

### Gate matrix

The default gates compose with the profile — not every gate runs in every profile:

| Gate | What it gates | Lightweight | Standard | High-risk |
|------|---------------|-------------|----------|-----------|
| **1** — design | Architecture verdict before implementation | Skipped | Conditional | Required |
| **2** — implementation + tests | QA-floor + reviewer verdict before the landing or a deploy | Worker self-verification | QA-floor + reviewer if triggered | Required, reviewer at full surface |
| **2.2** — worker cross-model review | Independent-model adversarial read of the diff before commit (caps 3 / 8 / 12 rounds) | Optional | Mandatory | Mandatory |
| **2.3** — reviewer baseline | Reviewer's optional read-only baseline against a frozen diff; never substitutes for 2.2 | n/a | if dispatched | if dispatched |
| **3** — integration + smoke | Post-landing smoke against the integrated system | Optional | Required | Required |

CRITICAL reviewer findings and architect `reject` / `re-scope` are operator-only override at any
profile. The profile selects how many gates run; it does not loosen override authority.

### Authority rhythms and delivery modes

**Authority rhythms (A/B/C/D)** govern when the team pauses for human approval of irreversible
actions — branch publication, landing, release, irreversible external action. **The local commit is
not one of them**: it reaches no shared state and is authorized by the dispatch under every rhythm.
The lead echoes the active rhythm in every dispatch brief. Under **rhythm D** (semi-auto,
CTO-proxied) the CTO is the team's apex: no agent waits on the operator, the CTO buffers the reserved
surface and relays replies, and an all-green merge-to-main is CTO-authorized green-path. **Delivery
modes (`ci-cd` / `on-main` / `yolo`)** are an orthogonal axis setting how far "done" reaches and how
work goes live — they never relax gate rigor. Canonical semantics for both live in
[`ROLES.md`](../ROLES.md) and [`docs/protocols/routing-and-authority.md`](protocols/routing-and-authority.md).

Green-path delegation removes the CTO's judgment pause and nothing else has to be arranged for it:
because the daemon is the only git egress, an authorized landing costs no keystroke and trips no
harness confirmation, so rhythm D is hands-off by construction rather than by opt-in wiring.

### Cross-model review

Cross-model adversarial review applies to **every role's load-bearing primary output**, not only the
worker's diff. Before a role declares a load-bearing output dispatch-ready it runs an adversarial pass
**from a different model family than the author** and folds findings in before delivery — same-model
self-review is the forbidden anti-pattern (shared priors are the model's, not the session's). Caps
scale by profile (3 / 8 / 12 rounds). A deployment selects how the gate is satisfied via
`review.mode`: **`cross-model`** (default — a different model family) or **`ephemeral`** (a sanctioned
fresh-context same-model subagent lane for deployments without a second model account, honestly weaker
against model-family blind spots). The per-role bindings and the iterate-to-CLEAN loop live in the
role overlays and the `agent:cross-model-review` skill.

## Role-policy layer

Contract data lives in machine-readable policy JSON; the playbooks carry identity and discipline. A
renderer + lint keep the two in lockstep.

- `role-policies/<role>.policy.json` is authoritative for allowed skills, activation triggers,
  rhythm-dependent permissions, channels, artefact ownership, mutation/push boundaries, STOP routing,
  escalation, and override rules.
- `roles/<role>-agent.md` is authoritative for identity, reasoning discipline, quality standard, and
  collaboration behaviour.
- A `SKILL.md` is procedural only — it cannot grant authority absent from the invoking role's policy.
- Agents load the **generated** markdown renderings, never the JSON.

Validation is bash-only: `scripts/render-contracts.sh --check` (generated freshness),
`scripts/validate-policies.sh` (policy JSON + skill references), `scripts/check-policy-consistency.sh`
(cross-policy checks the schema can't express), and `scripts/check-anchors.sh` (`§"Section"`
citations). The scope of "authoritative" is the structured contract *data*; `ROLES.md` remains the
runtime precedence contract.

## The role files

Thirty-three role playbook files under `roles/`: the nine delivery, review, and observation roles ×
(base + Claude Code overlay + Codex overlay) = 27, plus the operational **CTO** apex set (3) and the
operator-only **Devil** sparring set (3). One strategic role stub (`spm-agent.md`) is defined but not
operational — SPM-class concerns route to the operator.

The base playbook is the role contract — direct system-prompt format, framework-agnostic,
principle-heavy. The `.claude.md` overlay adds Claude Code affordances; the `.codex.md` overlay does
the same for Codex. Principles live in the base; overlays never duplicate them. When a project needs
per-project identity, paths, or conventions, put an overlay at
`<project-repo>/skills/<role>-agent.md` — it extends, never duplicates.

### Which roles run, per profile

| Role | Lightweight | Standard | High-risk |
|------|-------------|----------|-----------|
| pm | Optional | Conditional (when fuzzy) | Mandatory at front |
| lead | Mandatory | Mandatory | Mandatory |
| worker | Mandatory | Mandatory | Mandatory |
| explorer | Optional | Conditional | Conditional |
| architect | Skipped | Conditional (design surface) | Mandatory |
| qa | Skipped | Conditional (test surface) | Mandatory |
| reviewer | Normally skipped | Conditional (trigger surface) | Mandatory |
| designer | Conditional (UI surface) | Conditional | Conditional (customer-facing UI) |
| devil | operator-only sparring, not a workflow participant | — | — |

## Distillation

These playbooks evolve by **distillation**: rather than patching a contract when a discipline gap
shows up, sessions accumulate empirical evidence of the gap and a distiller re-derives the affected
playbook from that evidence. The methodology, per-role runtime templates, and the parked-pattern
register are maintained alongside this repository and are not published here. Post-write reflections
about the process are kept separate from the playbooks, so the playbooks stay pattern-only.

## Skills

Conditional procedures lifted out of role playbooks live in the companion
[`mythical-skills`](https://github.com/mythicalOS/mythical-skills) repository under the `agent:`
namespace, invoked by roles that explicitly allow them (each overlay's §"Allowed skills"). Authority,
triggers, and decisions stay in the playbooks; the skill executes within authority the playbook has
already granted. Examples: `agent:coordination-wip-handoff`, `agent:cross-model-review`,
`agent:routed-comms`, `agent:adr-authoring`, `agent:good-morning` / `good-night`.

## Coordination artefacts

Coordination runs on **two substrates**, and which one an artefact belongs to is settled by *what it
is*, never by who wrote it.

**Permanent documents are committed files**, each at its contracted path in the project repo —
usually under `docs/`, though not always. They are the durable record, they are reviewed as diffs,
and nothing in this arc changes how they are written:

- `docs/prd/<slug>-prd.md`, `docs/plans/<slug>-master-plan.md`, `docs/glossary/CONTEXT.md` — PM writes.
- `docs/adr/NNNN-<slug>.md` — append-only decision records (technical tier: architect; strategic
  tier: CTO). Reversal is a new superseding record, never a rewrite.
- `docs/design-reviews/…`, `docs/ux-reviews/…`, `docs/design-system/…`, `DESIGN.md` — the long-form
  review report and the design source-of-truth the architect and designer own.
- `docs/architecture/…` — the explorer's navigation set.
- `docs/ops-intake/…`, `docs/incidents/…` — ops writes; `docs/go-live/…` — `on-main` delivery mode only.
- `docs/retros/…` — lead writes.

**The thirteen coordination kinds are daemon-stored records** — task, dispatch, acknowledgment,
clarification, close-out, addendum, merge close-out, design review, code review, test strategy, risk
triage, handoff, WIP handoff. A record is published with
`coordination.publish_artefact {kind, to, body}`, read back **by its id** with
`coordination.read_artefact`, settled when consumed, and expires on the deployment's retention
setting. There is no path and no filename: the record's own `to` field addresses the recipient, and on a
session-published record the daemon stamps the author's role and session onto it, so the record is
itself the receipt that a live session of that role published it (a record the daemon writes on a
retired seat's behalf carries no role stamp — a gate reads that as no evidence). **A published record wakes no one** —
`coordination.deliver` is the doorbell over a pull floor, and the two steps are separate on purpose.

The full contract — the three tiers, the thirteen kinds grouped, the record shape and its structured
fields, publish / deliver / read / settle, retention, and the `workitems.*` and `git.*` namespaces —
is [`protocols/coordination-records.md`](protocols/coordination-records.md). Delivery obligations,
authority rhythms and apex substitution are in
[`protocols/routing-and-authority.md`](protocols/routing-and-authority.md).

## Usage

### Bootstrap a session

Sessions are created and joined by the consuming deployment's runtime; no launcher ships in this
content repo, and nobody starts an agent by hand from inside the runtime. A session is **created**
from the deployment's control surface for one role, in one project, with a starting instruction —
that is the primary lane, and the created session runs headless under the daemon. A created session
may also be **attached** from a terminal, joining a live pane through a picker that lists the agents
across every project and marks which of them are attachable; attaching is a view into a running
session, not a second way to start one.

The playbooks themselves are resolved by the deployment, not by the agent: from a **playbooks
symlink** it maintains on a workstation, or from the read-only content directory baked into its
runtime image. Either way an edit here reaches the **next** session with no reinstall and no copy
step; a running session keeps the contract it was started with.

Launchable roles: `cto | explorer | pm | lead | worker | architect | qa | reviewer | designer`. `ops`
is refused until the observability lease exists; `devil` is reachable only through the deployment's
SDK spawn lane. Authority rhythm D needs a live CTO session — the apex the team escalates to — so
that session is created before the rhythm is selected.

### Running the PM

For turning a fuzzy idea into a master plan the lead can orchestrate against:

1. Spawn a `pm` session pointed at the target repo.
2. Run the five-phase scoping workflow conversationally (Phase 0 premise challenge → Phase 5
   emission). Most of the value is in the conversation, not at emission.
3. At Phase 5 the PM commits the PRD first, then the master plan (citing it), and publishes the
   initial PM→lead `handoff` record naming both.
4. Create a `lead` for the same project; it reads the two documents and the handoff record at
   startup and picks up Phase 1.
5. Scope changes flow through a **new** handoff record and in-place master-plan edits — never re-emit
   the master plan as a new filename, and never edit a published record (records are append-only; a
   correction is a new record citing the prior one's id).

### Running the explorer

For unfamiliar codebases, before scoping: create an explorer for the target repo, it runs a breadth
pass, emits one coverage-plan checkpoint, the operator approves it (a human-authority gate under
every rhythm), then the deep pass runs on the approved paths and the navigation set lands at
`<repo>/docs/architecture/` as committed documents.

### Running Devil

Operator-only sparring, not a workflow participant:

```text
spawn(devil)                     # unbound; spar from supplied facts / general reasoning
spawn(devil, --project <name>)   # bind project files read-only for grounded challenge
```

Devil is not created the way the other roles are — the deployment's runtime spawns it through its SDK
lane, with no coordination credential and no live-presence entry, so no agent can address it and it
addresses none. Unbound, project-specific claims remain priors unless the operator supplied or bound
the source.

### Triggering a new playbook iteration

When a playbook's discipline gaps have accumulated enough evidence: open the per-role runtime template
from the distillation toolkit, substitute the round's placeholders, paste into a fresh session, review
the produced files, and record a post-write reflection keyed by role and date. For substantial
changes, dispatch a fresh-worker review before adoption.
