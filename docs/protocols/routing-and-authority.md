# Routing and Authority Protocol

This is the shared operational contract for record-based delivery, session
wakeups, authority rhythms, and rhythm-D apex substitution across the playbook
framework.

The **substrate itself** — the thirteen coordination kinds, the record shape and
its structured fields, retention, and the `coordination.*` / `workitems.*` /
`git.*` tool namespaces — is `docs/protocols/coordination-records.md`. This file
governs the *delivery obligation* and the *authority* around it.

This file does not replace `ROLES.md`. `ROLES.md` remains the boundary
contract. If this protocol and `ROLES.md` disagree, update this protocol to
match `ROLES.md`.

## Completion Rule

A load-bearing output is complete only when the responsible counterpart can act
on it.

That means all three checks are satisfied:

1. **Verify:** the producing role performed the role-appropriate verification
   or cross-model check.
2. **Reach:** the output is addressed to the recipient — published as a
   coordination record when the output is a coordination kind; committed at its
   contracted path when it is a permanent document, with the path carried to the
   recipient by the record that announces it or, where the role owns no such
   kind, by the delivery itself.
3. **Notify:** the pointer is handed to the recipient with `coordination.deliver`
   — which wakes a running session and queues for one that is not up yet — or the
   output is explicitly surfaced through the role's permitted human-facing
   channel.

Chat, `final`, or an inline summary is not the artefact of record. The stored
record and the verified git state are authoritative; the delivery is a doorbell,
and a doorbell with nothing published behind it is a pointer without authority.

## Routed Delivery

**Delivering a coordination record** to an agent session is three calls, in this
order. (A permanent **document** is delivered differently, and which way forks on
your contract: where you own a record kind that *announces* it, commit the
document and publish that record naming its path — the three calls below,
unchanged, delivering the **record's id**; where you own no such kind, commit it
and `coordination.deliver` the **committed path** itself, with no record at all.
Never invent a kind to fit this procedure. See §"Completion Rule" and
`docs/protocols/coordination-records.md` §"Three tiers".)

1. **Resolve the recipient** — `coordination.resolve_recipient`, immediately
   before dispatching, never from a remembered roster or from past
   responsiveness. That answers **addressability**, not liveness. When your next
   step depends on someone being up, also call `coordination.list_sessions` and
   read the `state` it returns: `wake-ready` and `running` are up, **`known` is
   not**.
2. **Publish the record** — `coordination.publish_artefact {kind, to, body}`.
   The daemon mints the id, stamps the author's role and session, and stores the
   content. The `to` field is the address: there is no directory to land in and
   no recipient token to encode in a name.
3. **Deliver the pointer** — `coordination.deliver` the record id to that
   recipient. **This is the step that resolves**, and it resolves *known*, not
   *running*: a slug the daemon knows nothing about is refused
   (`UNKNOWN_RECIPIENT`) rather than being silently dead-lettered. Your directory
   is project-scoped, so a recipient in another project is not in it and fails the
   same way. A known recipient that is running is woken; one that is not up yet
   has the message queued.

**Publishing checks nothing about `to`, and that is deliberate.** It is an
audience token, not a session handle, and it need not name a session that exists
yet — which is what makes the successor handoff possible, a session publishing
to `<slug>-next` for a session nobody has created. It is also why step 1 is not
optional: publishing to a mistyped slug **succeeds**, and the mistake surfaces
only when the delivery is refused. Resolve first, then publish to what you
resolved.

**"Known" is broader than "up".** A configured teammate who has not started is a
legitimate delivery target — the message queues for them, which is what the queue
is for. So an accepted delivery means the recipient is real, not that anyone is
awake to read it: when your workflow needs a session that is actually running (a
gate you are waiting on, an apex you are escalating to), read the `state` from
`coordination.list_sessions` rather than inferring liveness from the delivery.

A published record with no delivery is durable but may not be noticed by an idle
session. A delivery with nothing published behind it is a pointer without
authority. **A role name is not an alias for whoever holds that role.** Slugs are
what the daemon knows, so `lead` reaches someone only if a slug spelt exactly
`lead` is itself configured; addressing the role and hoping is how a dispatch
disappears. Resolve the real slug.

When the daemon knows no such recipient, do not pretend delivery succeeded:
surface the missing recipient to the dispatcher or apex authority that owns the
next step. And when your next step genuinely needs a session that is **running**
— an answer you are blocked on, an apex you are escalating to — an accepted
delivery is not that evidence: check `coordination.list_sessions` and say
plainly that nobody is up if nobody is.

At session start, `coordination.settle_artefact {id}` each predecessor record
you have consumed, so its status is truthful. Settling marks a record consumed —
it does not delete it and does not shorten its life (see
`docs/protocols/coordination-records.md` §"Retention").

## Addressing and Provenance

A coordination record carries its own addressing. The recipient is the `to`
field; the author's **role and session id are stamped by the daemon** at
publication and cannot be set by the caller. That stamp is the only provenance
any gate trusts — for a session-published record it *is* the receipt that a live
session of that role published it, and body text claiming otherwise is not
evidence of anything. A record the daemon published on a retired seat's behalf
carries no role stamp at all (`docs/protocols/coordination-records.md` §"The
record shape"), which a gate reads as no evidence, never as evidence from an
unknown role.

Records also carry the structured correlation fields consumers read without
parsing prose: `re` (the record or landing this one answers) and `branch` /
`head_sha` / `repo`; verdict kinds add `verdict` and `candidate_sha`. Fill them —
a downstream gate reads the field, not a sentence. Everything else on a record —
its id, its author, that author's role, the project, the creation time — is
stamped by the daemon and cannot be supplied.

**Dispatcher-present delivery** is the one class with no addressed recipient,
because the dispatcher receives the deliverable directly and no idle session
needs waking. Two cases: **operator-direct dispatch** (the operator is present in
chat), and **role-loaded in-session subagent dispatch** (the dispatcher invoked
the target role as a role-loaded subagent and receives the direct return —
`ROLES.md` §"Harness-native subagents (in-session)").

A third case has no recipient **yet** rather than none at all: the **initial**
PM-to-lead handoff, emitted before any lead session exists. It forks three ways,
all sanctioned (`pm-agent.md` §"Phase 5 — PRD + master plan emission"): publish to the slug the
daemon does not know yet — deliberate, per §"Routed Delivery" — and deliver
nothing, so the lead reads the record at startup; publish and deliver once the
lead session is up; or hand the master-plan path over at the spawn instead, with
no record at all. Only the middle form has a delivery step, and every later
handoff is delivered normally.

An in-session subagent has no session id of its own, so it publishes nothing and
addresses no one: its output is the direct return, and the **dispatcher** carries
it onward. Provenance travels in the body of what the dispatcher publishes, via
the canonical field:

```text
**Dispatch provenance:** <dispatcher-session-id> role-loaded-dispatch
```

(e.g. `**Dispatch provenance:** lead-1 role-loaded-dispatch`.) It is the only
provenance record for that work, because no daemon stamp was ever minted for the
subagent — which is exactly why the field is mandatory for this class and
inferring it later is not possible.

**Documents are not records, and neither substitutes for the other.** A
permanent document — a PRD, a master plan, an ADR, a long-form review report, a
design-system artefact, a go-live handbook — is a committed file in the project
repo whose path is carried to the recipient: by the record that announces it
where the author owns a kind that does so, otherwise by the delivery itself
(`docs/protocols/coordination-records.md` §"Three tiers"). The reverse never
holds: a
coordination record has no path and no filename, is never created with a
file-write tool, is never moved or renamed, and is never amended. The daemon's
wire carries no update operation, so a correction is a **new** record citing the
prior one's id, and the superseded record stays exactly as published.

The **WIP handoff** is the single artefact with a sanctioned draft-on-disk stage,
and the single record whose *publication* a rhythm may hold — not because
publishing is an irreversible action (§"Authority Rhythms" says it is not) but
because the handoff is the worker's loop-closure surface and its timing is the
lead's, which is why a dispatch may authorize it rhythm-independently
(`worker-agent.md` §"Authority-rhythm interaction for publishing the WIP
handoff"). While it is held — A awaiting green-light, C queued for the cycle
batch — the draft sits at `<repo>/.wip-handoff-staging/<filename>.md` and no
record exists yet, so there is no id to report and no doorbell has rung: the
worker reports the staging path in chat, and that report is the lead's only
signal. The staging area is a holding place, never a delivery path — delivery
happens when the record is published and delivered.

## Required Dispatch Fields

The body of an executable `task` (or `dispatch`) record carries six header
labels with exact spelling, in two classes. **Required in every executable
brief, echoed even when inherited unchanged** — the process trio:

```markdown
**Workflow profile:** lightweight | standard | high-risk
**Delivery mode:** ci-cd | on-main | yolo
**Authority rhythm:** A | B | C | D
```

**Conditional, and legitimately absent when the condition does not hold:**

```markdown
**Files touched:** <this dispatch's current file set>
**Branch convention:** feat/<ISSUE>-<slug>
**Push flow:** pr | land-then-ack | auto → <integration branch>
```

`**Files touched:**` is required whenever two or more workers run concurrently
and recommended otherwise, and is always this dispatch's own set — never
inherited. `**Branch convention:**` applies to branch-carried build work and is
omitted for in-place documentation or coordination work, and `**Push flow:**` is
carried **with** it: with no branch there is nothing to publish and nothing to
land. Both echo the project setting; neither redefines it.

Missing or misspelled required fields are bounced administratively to the
dispatcher — as a published `clarification` record addressed to that session, not
as a chat message, since chat reaches the user and not an idle lead. The
recipient does not infer the active profile, delivery mode, or rhythm from a
prior dispatch. The canonical statement of the schema, with the per-field
semantics, is `lead-agent.md` §"Dispatch-brief header fields".

## Authority Rhythms

`ROLES.md` §"Authority rhythms" is the canonical A/B/C/D table. This section is
only the operational shorthand used by validators and role overlays.

The gated set — the **irreversible actions** a rhythm holds for approval — is
**branch publication / landing / release / irreversible external action**. **The
local commit is not in it** under any rhythm: it reaches no shared state, it is
authorized by the dispatch itself, and it must *precede* the close-out that names
its SHA — a commit held behind the approval that the close-out is what asks for
would leave the lead waiting on a wake that never comes. **Publishing a
coordination record is not in it either** — publication writes only the daemon's
own expiring coordination store and reaches no remote, so the close-out, the
verdicts and the later addressed handoffs are published and delivered under every
rhythm. The rhythm is not what decides whether a given record is *delivered*,
though: that is a routing question, and the initial hand-over above is the case
where the answer can be no.

One publication is nonetheless held, by its own contract rather than by this set:
the **WIP handoff** (§"Addressing and Provenance"). That hold exists because the
handoff is the worker's loop-closure surface and its timing is the lead's to
control, not because publishing a record is an irreversible action — which is why
a dispatch can authorize it rhythm-independently (`worker-agent.md`
§"Authority-rhythm interaction for publishing the WIP handoff"). Nothing else
about a record's publication is rhythm-conditional.

| Rhythm | Short form |
| --- | --- |
| A | Manual: the close-out is the STOP; the operator green-lights each gated action individually. Commit locally → publish + deliver the close-out → await the green-light → publish the branch. |
| B | Pre-authorized: commit locally → publish + deliver the close-out → publish the branch, as one continuous sequence; when the dispatch culminates in a **dispatched irreversible action** (a release publication, an authorized deploy), the merge close-out follows the completed action unconditionally: a STOP condition reached *before* the action prevents the action, and one reached *after* it is **recorded in** that close-out and gates only the work that comes next — an irreversible act that has already happened is precisely what the record exists to capture (`worker-agent.md` §"Mandatory close-out for a dispatched irreversible action"). **Never for a landing**, which no agent performs and which the daemon closes out itself. |
| C | Batched: branch publication and the other gated actions queue for one cycle-close approval. The commit and the close-out are not queued. |
| D | Semi-auto: the CTO is the apex; cadence is B-like unless a reserved surface or STOP condition fires. |

Under every rhythm the branch is **published by the daemon at the worker's
request** and landed by the daemon at the lead's; what the rhythm gates is
*when the request may be made*, never who runs a command — nobody does.

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
| ci-cd | The CI/CD pipeline deploys on the landing the daemon performs; Level-2 "shipped" = deployed + CI/CD health recorded read-only by the lead. |
| on-main | The daemon lands the work on `main` at the lead's request; a worker-authored go-live handbook (`docs/go-live/`) is delivered to and acknowledged by a named human operator who takes it live out-of-band. |
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
to an idle CTO (output-dir-only write scope, no routed record and no push rule,
and the CTO's read scope excludes the explorer output dir). Its
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
significant. **Delivery-mode coupling** (§"Delivery Modes"): the landing must
**not** auto-trigger a prod deploy — a `ci-cd` auto-deploy landing inherits the
deploy's reserved status and takes the normal reserved route, not green-path —
and a `yolo` deploy is never green-path. Any failure takes the normal reserved
route through the CTO.

What green-path authorizes is the **lead's landing request**, not an execution:
the daemon performs the landing, re-checks the gate set against the roles it
stamped on each verdict record, and refuses an incomplete one. Under a
`land-then-ack` push flow the CTO's authorization *is* the acknowledgement the
daemon waits for; a landing that appears on the remote before it is a policy
breach, not a green-path landing.

## Authoring Rule

When a playbook needs routing or rhythm mechanics, cite this protocol and state
only the role-specific delta. Do not duplicate the full delivery, addressing, or
authority-rhythm contract in every role surface; for the record substrate itself,
cite `docs/protocols/coordination-records.md`.
