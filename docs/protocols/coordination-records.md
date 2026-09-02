# Coordination Records Protocol

This is the shared operational contract for the **substrate** coordination runs
on: what a coordination record is, which artefacts are records and which are
documents, the operations a session has on them, how long they live, and the two
adjacent tool namespaces — work items and git egress.

Delivery obligations, addressing and authority rhythms are
`docs/protocols/routing-and-authority.md`. Role boundaries are `ROLES.md`, which
wins wherever a playbook and it disagree. This file states the mechanism; it
grants nothing — which tools a role may call is its policy's business.

## Three tiers

Coordination has three tiers, and an artefact's tier is settled by **what it is**,
never by who produced it or how important it feels.

| Tier | What lives there | Where it lives | Lifetime |
| --- | --- | --- | --- |
| **A — permanent documents** | plans, PRDs, ADRs, roadmaps, retros, glossary, architecture, design-system source, long-form review reports, go-live handbooks, project memory | committed files at their contracted path in the project repo — usually under `docs/`, not always | forever, in git history |
| **B — coordination records** | the thirteen process kinds below — the traffic between sessions | the daemon's record store, addressed and read by id | expires on the deployment's retention setting |
| **C — work items** | the tracked state of dispatched work | the daemon's local work-item store, derived from tier-B records | as long as its records |

Tier A is unchanged by the record substrate: those documents are still written
with an editor, committed, and reviewed as diffs. Tier B replaced a directory
convention: the process artefacts used to be committed files with recipient
tokens in their names, and they are not files at all any more. Tier C is derived
— nothing is written to it directly.

**A record is not a cheap document, and a document is not a slow record.** A
decision that must survive the project goes in tier A; traffic that only has to
reach a counterpart goes in tier B and never acquires a path.

**How a tier-A document reaches its recipient depends on the author's contract.**
Where the role owns a record kind that carries the announcement — an architect's
`design_review` naming its long-form report, a PM's `handoff` naming the plan and
PRD it just committed — the document is committed and the **record** names its
path. Where the role owns no suitable kind, the delivery carries the path
directly: `coordination.deliver` addressed to the recipient, with the committed
path as its content. Either way the recipient is addressed by the delivery, never
by a filename, and a committed document nobody was told about is not delivered.
A role's own contract says which of the two it uses; do not invent a record kind
to satisfy the pattern.

## The thirteen kinds

The kind set is **closed**. The daemon refuses a kind that is not one of these:

| Group | Kinds |
| --- | --- |
| Assignment | `task`, `dispatch`, `acknowledgment`, `clarification` |
| Completion trail | `closeout`, `addendum`, `merge_closeout` |
| Governance verdicts | `design_review`, `code_review`, `test_strategy`, `risk_triage` |
| Continuity | `handoff`, `wip_handoff` |

A verdict kind is a *verdict*, not the report behind it: a review that warrants a
long-form write-up commits that document under the tree its author's contract
grants, and the verdict record names its path.

**Not every governance output is one of these kinds.** The designer's UX-review
verdict and its design-system material are tier-A **documents** by ruling — they
are committed at their contracted paths and delivered by `coordination.deliver`
carrying the path, because the recipient is addressed by the delivery and never
by a filename. The kind list above is closed; a role's own contract says which
of its outputs is a record and which is a document, and neither substitutes for
the other.

**A gate is satisfied by a stamped record, so a role-loaded in-session review
cannot satisfy one.** An in-session subagent has no session of its own, publishes
nothing, and returns its result to the dispatcher; if the dispatcher republishes
that result, the daemon stamps **the dispatcher's** role, which is not the
reviewing role the gate is looking for. Such a review is therefore advisory — it
informs the dispatcher's judgment and never counts toward a landing's gate set. A
gate that must actually be cleared is dispatched to a real session of that role,
which publishes its own verdict.

## The record shape

A record has two halves, and the split is the whole point.

**What the caller supplies** — and nothing else is settable, by construction:
`kind`, `to` (the resolved recipient) and `body` (the content), plus the
structured fields a consumer reads without parsing prose:

- `re` — the correlation target: the record or landing this one answers.
- `branch`, `head_sha`, `repo` — the state the record was written against. A
  branch name alone does not identify a repository, which is why `repo` is its
  own field.
- verdict kinds add `verdict` (`green` or `reject`) and `candidate_sha` — a gate
  keys on the exact candidate, never on a description of it.

**What the daemon stamps, and the caller cannot set.** The record's id, its
author (the attested session slug), the author's **role**, the author's session
id, the review lane the session was spawned in, the project's authority rhythm at
publication, the project partition, the creation time, and the record's position
in the store's append order. These are the **only** provenance any gate trusts. A
session cannot claim a role it was not spawned with, cannot claim to be another
session, and cannot make its body text into evidence: for a **session-published**
record the stamp *is* the receipt that a live session of that role published it,
which is what lets a retained authorization survive a daemon restart.

Some of those fields are legitimately absent, and a consumer must read absence as
absence rather than as a default. The review lane and the rhythm are missing when
the deployment resolves none. The **author role and session id are missing on a
record the daemon itself published on a retired seat's behalf** — it is marked
with a daemon-internal origin, no session can set that marker, and `from` still
names the seat so continuity keeps working. A gate that needs an attested role
therefore requires the role stamp to be *present*, and treats a record without one
as not evidence rather than as evidence from an unknown role.

Two consequences follow, and both are load-bearing:

- **A record is append-only.** The wire carries no update operation, so a
  published record is never edited, moved, renamed or amended. A correction is a
  **new** record citing the prior one's id, and the superseded record stays
  exactly as published.
- **A record is never a file.** It has no path and no filename, is never created
  with a file-write tool, and is never read with a filesystem read tool. Prose
  that names a record "at" a path is describing something that does not exist.

## Operations

| Call | What it does |
| --- | --- |
| `coordination.publish_artefact {kind, to, body}` | stores the record, mints its id, stamps the author. **This wakes no one.** |
| `coordination.deliver` | the doorbell. It is accepted for any **known** recipient: a running session is woken, and one that is not up yet has the message **queued** for it. Publication is the pull floor; delivery is the push over it. |
| `coordination.read_artefact` | returns a record's **content**, by id. There is no other read. |
| `coordination.list_artefacts` | metadata-only discovery over your project's records — id, kind, from, to, created_at, status — filterable by kind and by time. Bodies come from `read_artefact`. |
| `coordination.settle_artefact {id}` | declares a record **consumed**. It flips the record terminal; it does not delete it — a settled record stays listed, truthfully marked, until retention reclaims it. Settle each predecessor record you have acted on. |
| `coordination.resolve_recipient` | **addressability**: is this slug a recipient the daemon knows — a live session, a configured teammate not yet up, or a first-class agent identity? Resolve immediately before dispatching, never from memory. |
| `coordination.list_sessions` | **liveness**, and only if you read the `state` it returns: `wake-ready` (the daemon can inject now) and `running` are up; **`known` is not**. Listed is not running. |
| `coordination.whoami` | who you are. |
| `coordination.ask` | puts a multiple-choice question to **your human operator** and blocks until it is answered. For a decision that is genuinely the operator's — never a channel to another agent, and never a substitute for a `clarification` record. |

**Resolution happens at `deliver`, not at publish**, and it resolves *known*,
not *running*. `to` is an audience token the store keeps (case-folded, so
capitalization never decides anything); publishing checks nothing about it, which
is what lets a handoff be addressed to a successor that does not exist yet. The
**delivery** is what refuses, with `UNKNOWN_RECIPIENT`, and "known" is
deliberately broader than "up": a live session, a configured team member who has
not started, and a first-class agent identity all count, because a message to one
that is not up must **queue** rather than fail. Your directory is
**project-scoped**, so a recipient in another project is simply not in it and
fails as unknown like any other stranger — there is no separate cross-project
answer to read, and no probe. So a dispatch to a mistyped slug publishes happily
and fails at the doorbell, while a dispatch to a real teammate who is not running
succeeds and waits for them.

Two things follow. **Resolve before you publish** — the publish will not catch
your typo. And **a successful delivery is not evidence anyone read it**: when a
workflow needs a session that is actually running — a gate you are waiting on, an
apex you are escalating to — call `coordination.list_sessions` and read the
`state`, treating `known` as not up.

## Retention

Records **expire**. The deployment sets a retention window in days and the store
reclaims a record at that age **from its creation** — settled or not. Settling is
a statement that the work is consumed, not a request to delete; it changes the
record's status and nothing about its lifetime. This is deliberate: records are
process traffic, and process traffic that still matters in a month was in the
wrong tier.

Two practical consequences. First, **anything that must outlive the window is a
tier-A document** — write it, commit it, and carry its path the way your contract
says (§"Three tiers"). Second, a
gate set is a *cache of retained records*: a landing that re-checks its verdicts
after an expiry can find the set no longer complete, and it refuses rather than
proceeding on a set it can no longer see.

## Work items — `workitems.*`

Publishing a `task` record creates or links a **work item**, keyed by that
record's id. The records that `re` it walk its lifecycle, and its `status` is one
of `dispatched` · `in_progress` · `gate_stopped` · `closed_out` · `in_review` ·
`verdict_pending` · `handed_off` · `merged`.

**Nothing writes a work item.** There is no write verb and no status to set: the
store is *derived* from the records and rebuilt from them in append order, so an
item exists because a `task` record exists and its status is whatever the records
referencing it say. To move an item, publish the record — and an item whose task
record has passed the retention window is gone with it. `workitems.list` and
`workitems.get` are the whole surface, both read-only and both scoped to your own
project with no selector.

## Git egress — `git.*`

**The daemon is the only git egress**, on every lane and under every authority
rhythm. No agent holds a credential and none runs the command; there are exactly
two requests, and both are refused for a role the daemon did not admit:

| Call | Who may | What it does |
| --- | --- | --- |
| `git.push_branch {repo, branch, sha}` | worker, lead | publishes a **feature branch** at an exact commit id. Never the integration branch. |
| `git.request_landing {sha, task_record_id, repo, branch?}` | lead only | asks the daemon to land a reviewed candidate. |

A local commit is not egress: it reaches no shared state, so it is authorized by
the dispatch itself and precedes the close-out that names its SHA.

On a landing request you supply no target, no remote and no ref: `sha` is the
candidate already published, `task_record_id` is the `task` record the landing
completes (it is what carries the work item to `merged`), and `branch` is
optional — give it only to disambiguate a SHA published under more than one ref.

On a landing request the daemon re-checks the gate set for exactly that candidate
against the **author roles it stamped** on the verdict records — reviewer green,
cross-model clean, architect accept, any reject a hard block — refuses an
incomplete set without touching anything, and otherwise lands per the project's
push flow (`pr` | `land-then-ack` | `auto`), composing the review summary into the
merge commit or the pull request. Under `land-then-ack` it holds the prepared
landing for the operator's acknowledgement — the CTO's under rhythm D — and a
landing that reaches the remote before that acknowledgement is a **policy breach,
not a landing**: the daemon fails it and tells the lead.

`repo` names one of the project's configured repositories, and may be omitted only
in a single-repository project.

## Both lanes teach one substrate

A session is the same coordination participant whether it was created headless by
the deployment's runtime or joined from a terminal: the same `coordination.*`
tools under the same names, the same record store, the same addressing. Nothing
about coordination is conditional on how a session was started, and a playbook
that needed a lane-specific coordination rule would be describing a defect.

Egress is one model on both lanes too — **the daemon performs it, always** — but
egress is a *capability the deployment grants a session*, not something a session
possesses. A lane on which the deployment cannot attest a session has no
`git.*` tools at all: that session has **no** egress path, not a different one.
So a role contract never says "on this lane, push it yourself"; the worst case is
that a request cannot be made, and the correct response is to say so, not to
reach the remote another way. Check what you actually hold rather than assuming
either way.

## Authoring Rule

When a playbook needs record mechanics, cite this protocol and state only the
role-specific delta — which kinds the role owns, which it consumes, and what its
body must contain. Do not restate the operation list, the tier table or the
egress contract in a role surface, and do not re-derive authority here: what a
role *may* publish, read or request is its policy's, and `ROLES.md` is the
boundary.
