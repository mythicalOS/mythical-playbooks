# Routing and Authority Protocol

This is the shared operational contract for file-based delivery, bus wakeups,
authority rhythms, and rhythm-D apex substitution across the playbook
framework.

This file does not replace `ROLES.md`. `ROLES.md` remains the boundary
contract. If this protocol and `ROLES.md` disagree, update this protocol to
match `ROLES.md`.

## Completion Rule

A load-bearing output is complete only when the responsible counterpart can act
on it.

That means all three checks are satisfied:

1. **Verify:** the producing role performed the role-appropriate verification
   or cross-model check.
2. **Reach:** the artifact is addressed to the live recipient when the
   recipient is an agent session.
3. **Notify:** the recipient is woken, or the artifact is explicitly surfaced
   through the role's permitted human-facing channel.

Chat, `final`, an inline summary, or a bus wake alone is not the artifact of
record when a durable file is required. The file content and verified git state
are authoritative; the bus wake is a doorbell.

## Routed Delivery

A routed delivery to an agent session requires:

1. **Watched directory:** the artifact lands in a watched coordination
   directory such as `docs/tasks/`, `docs/handoffs/`, `docs/closeouts/`,
   `docs/design-reviews/`, `docs/design-system/`, `docs/ux-reviews/`,
   `docs/test-strategies/`, `docs/code-reviews/`, `docs/ops-intake/`,
   `docs/incidents/`, `docs/risk-triage/`, or
   `docs/retros/`.
2. **Live numbered recipient:** the filename carries the recipient session id,
   for example `lead-1`, `pm-2`, `cto-1`, not a bare role name.
3. **Bus wake:** the sender sends a bus message to that live session id.

A committed file without the bus wake is durable but may not be noticed by an
idle session. A bus wake without the file is a pointer without authority. A
bare role token such as `-to-lead-` or `-to-cto-` names no live session and is a
dead letter.

When no recipient session exists, do not pretend delivery succeeded. Surface
the missing live session to the dispatcher or apex authority that owns the next
step.

## Filename Classes

Task artifacts address the assignee directly:

```text
docs/tasks/<date>-<recipient-id>-<slug>.md
```

Routed closeout-kind artifacts include both sender and recipient:

```text
docs/handoffs/<date>-<sender-id>-to-<recipient-id>-<slug>.md
docs/closeouts/<date>-<sender-id>-to-<recipient-id>-<slug>.md
docs/design-reviews/<date>-<architect-session-id>-to-<recipient-id>-<slug>.md
docs/design-system/<date>-<designer-session-id>-to-<recipient-id>-<slug>.md
docs/ux-reviews/<date>-<designer-session-id>-to-<recipient-id>-<slug>.md
docs/test-strategies/<date>-<qa-session-id>-to-<recipient-id>-<slug>.md
docs/code-reviews/<date>-<reviewer-session-id>-to-<recipient-id>-<slug>.md
docs/ops-intake/<date>-<ops-session-id>-to-<recipient-id>-<slug>.md
docs/incidents/<date>-<ops-session-id>-to-<recipient-id>-<slug>.md
docs/risk-triage/<date>-<sender-id>-to-<recipient-id>-<slug>.md
docs/retros/<date>-<sender-id>-to-<recipient-id>-<slug>.md
```

Tokenless artifacts are the **dispatcher-present** delivery class — retained
when no idle session needs to be woken because the dispatcher receives the
deliverable directly. Two cases: **operator-direct dispatch** (the operator is present in
chat), and **role-loaded in-session subagent dispatch** (the dispatcher invoked
the target role as a role-loaded subagent and receives the direct return —
`ROLES.md` §"Harness-native subagents (in-session)"):

```text
docs/design-reviews/<date>-architect-<slug>.md
docs/ux-reviews/<date>-designer-<slug>.md
docs/test-strategies/<date>-qa-<slug>.md
docs/code-reviews/<date>-reviewer-<slug>.md
docs/tasks/<date>-worker-<slug>.md          # role-loaded worker dispatch: brief
docs/closeouts/<date>-worker-<slug>.md      # role-loaded worker dispatch: close-out
```

An in-session subagent has no session id, so its artifact carries neither a
live-session routing token nor a synthetic one — the bare role name in the
tokenless shape is valid here precisely because delivery is the direct
in-session return, never the watched-dir wake path (the numberless dead-letter
rule governs routed wake delivery, which this class never uses). Provenance
lives in the artifact body, not the filename — via the canonical field:

```text
**Dispatch provenance:** <dispatcher-session-id> role-loaded-dispatch
```

(e.g. `**Dispatch provenance:** lead-1 role-loaded-dispatch`). For the worker
shapes — `docs/tasks/<date>-worker-*.md` and `docs/closeouts/<date>-worker-*.md`
— the field is validator-enforced; the bare-`worker` filename carries no session
identity, so the body field is the only provenance record.

Tokenless durable design-system artifacts are retained when the Designer is
authoring product design source-of-truth material rather than routing a verdict
to an idle session:

```text
docs/design-system/<date>-designer-system-<slug>.md
docs/design-system/<date>-designer-prototype-<slug>.md
docs/design-system/<date>-designer-decision-<slug>.md
```

Initial launcher inputs may also be tokenless when the recipient session is not
running yet, such as the initial PM-to-lead handoff. The tokenless file is
launcher input, not routed delivery to an idle session.

Staging paths such as `.wip-handoff-staging/` are not delivery paths. They are
work-in-progress holding areas until the artifact is moved to the routed path
under the active rhythm's publication rule.

## Required Dispatch Fields

Every executable task brief carries these fields with exact spelling:

```markdown
**Workflow profile:** lightweight | standard | high-risk
**Delivery mode:** ci-cd | on-main | yolo
**Authority rhythm:** A | B | C | D
```

For parallel dispatch, and preferably for every executable dispatch, include:

```markdown
**Files touched:** <current dispatch file set>
```

Missing or misspelled required fields are bounced administratively to the
dispatcher. The recipient does not infer the active profile, delivery mode, or
rhythm from a prior artifact.

## Authority Rhythms

`ROLES.md` §"Authority rhythms" is the canonical A/B/C/D table. This section is
only the operational shorthand used by validators and role overlays.

| Rhythm | Short form |
| --- | --- |
| A | Manual: closeout is a STOP before irreversible actions. |
| B | Pre-authorized: closeout, commit, and push proceed continuously; when the dispatch culminates in a merge, the merge closeout follows unless another STOP condition fires. |
| C | Batched: irreversible actions queue for cycle-close approval. |
| D | Semi-auto: CTO is the apex; delivery cadence is B-like unless a reserved surface or STOP condition fires. |

The lead echoes the selected rhythm in every executable dispatch. A missing
echo is a bounce condition.

## Delivery Modes

`ROLES.md` §"Delivery modes" is the canonical table. This section is only the
operational shorthand used by validators and role overlays. Delivery mode is
orthogonal to the rhythm (when the team pauses) and the workflow profile (how
many gates run); it sets where the team-level *shipped* end-state lands and
never relaxes gate rigor.

| Mode | Short form |
| --- | --- |
| ci-cd | CI/CD pipeline deploys on merge; Level-2 "shipped" = deployed + CI/CD health recorded read-only by the lead. |
| on-main | Lands on `main`; a worker-authored go-live handbook (`docs/go-live/`) is delivered to and acknowledged by a named human operator who takes it live out-of-band. |
| yolo | The worker deploys directly under explicit apex authorization (a reserved action, never green-path); post-deploy health recorded in the close-out. |

The lead echoes the selected delivery mode in every executable dispatch. A
missing echo is a bounce condition.

## Rhythm-D Apex Substitution

Under rhythm D, routes that normally point to the operator point to the CTO. The
authority is not weakened; the route is substituted.

The default escalation chain is:

```text
Worker -> Lead -> CTO -> operator
```

The CTO buffers the reserved surface to the operator and relays the operator's reply back to
the team. No agent waits on the operator directly under rhythm D.

**Exception — the explorer.** The bootstrap explorer is one role this
substitution does not cover: it is user-dispatched, read-only, and cannot route
to an idle CTO (output-dir-only write scope, no `-to-<recipient>-` token-routing
or push rule, and the CTO's read scope excludes the explorer output dir). Its
checkpoint approval and any escalation stay with the operator / the human dispatcher
under every rhythm, including D; its multi-repo fan-out is a reserved
new-agent-spawn held for direct human-operator approval (never CTO-cleared). Owned by
`ROLES.md` §"Apex substitution under rhythm D" + `explorer-agent.md` §"Workflow —
breadth pass → checkpoint → deep pass → deliver" step 2 + §"Multi-repo
fan-out via sub-explorers".

**Exception — Devil.** Devil is not an operator route from the team; it is outside
A/B/C/D authority routing entirely. It stays operator-only under every rhythm, no
team role addresses it, and no CTO substitution applies. Owned by `ROLES.md`
§"Apex substitution under rhythm D" + `devil-agent.md` §"Out-of-chain boundary".

The reserved surface is:

- reviewer CRITICAL override;
- architect `reject` / `re-scope` override;
- strategic re-scope;
- release / merge-to-main;
- irreversible external action;
- new agent spawn.

The green-path exception applies only to an all-green merge-to-main under
rhythm D. All criteria in `ROLES.md` §"Apex substitution under rhythm D" must
hold: gates clear, reviewer 0 CRITICAL and 0 HIGH, cross-model CLEAN, no
architect `reject` / `re-scope`, no contested gate, and not strategically
significant. **Delivery-mode coupling** (§"Delivery Modes"): the merge must
**not** auto-trigger a prod deploy — a `ci-cd` auto-deploy merge inherits the
deploy's reserved status and is operator/lead-landed, not green-path — and a
`yolo` deploy is never green-path. Any failure takes the normal reserved route
through the CTO.

## Authoring Rule

When a playbook needs routing or rhythm mechanics, cite this protocol and state
only the role-specific delta. Do not duplicate the full bus, filename, or
authority-rhythm contract in every role surface.
