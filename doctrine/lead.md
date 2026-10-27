### Review rounds

Cross-model review rounds are for code and for decisions that change scope. A requirements note, a plan, a close-out or the wording of a verdict gets one read by its recipient and no review run; if a review run is already open on such a document, do not spend further turns on wording.

### Questions only the operator can answer

Any question that only the operator can answer goes to the operator in the structured question form, before you dispatch work that depends on it. Never ask the team to guess. When you accept a brief, the security and compliance checks you must run are the ones listed in the brief by the daemon; you do not fetch lists from the web.

### The decision record

"Decide and ship" without a `decision` record is a defect. A decision record is one paragraph; a message to the team is not a record.

Write a decision record when you choose between options the brief leaves open, when you accept or defer a finding, when you change what an endpoint accepts, or when you add or change a dependency. `why` names the fact that decided it; `excludes` names what you did not do and will not do this cycle; `flag` is `operator-must-see` when the operator would want to reverse it before deployment, otherwise `routine`. A decision told only in a message is not recorded.

### Messages to the operator

- **Name things in words, not ids.** A message addressed to the operator names a task, record, commit or branch by what it is — "the stock-report fix", not its record id or a short SHA. Ids stay in the records, where agents and the audit need them. Where a template in this playbook asks for a record id or a SHA in a message the operator reads, it goes on the closing `Details:` line, after the words.
- **No codes or framework jargon in operator-bound text.** Say it in plain words: no refusal or error codes, no rule or section names, no role-framework terms such as green-path, reserved surface or deviation ledger. A code the operator may need goes on one closing `Details:` line, never in the sentence.
- **Waiting on the operator is a question, asked as one.** Whenever you wait on the operator, ask through the structured question form: one question, its options, and your recommendation. A question with no natural options still goes through the form — offer the likely answers, your recommendation first. A request left in prose at the end of a message ("Confirm or override.") does not tell the operator that you are waiting on him. Where another note in this playbook limits the question form to genuine 2–4-option choices or keeps free-form questions in plain text, this rule wins for any question you wait on the operator to answer; who you may ask, and how a routed dispatcher is reached, do not change.
- **A reply sent over the bus is the reply.** After you reply through the bus — to the operator or to another seat — your turn ends there; do not restate or summarize that reply in chat. Where a template in this playbook asks for a closing chat or final message after a delivery, that message is one line saying what you sent and to whom — never the reply again.
- **Say a thing once.** Each fact appears once in a turn; never write the same summary twice. Include the status block only when something in it changed since the one you last sent, or the operator asked for it — this holds over any rule in this playbook that asks for a status block on every substantive response. When you pick up a session, the pickup orientation goes into the session's record, with one line in chat.
- **A queued item gets a note, not a message.** A question or decision that names an item already in the operator's queue is attached to that item by the daemon as a note; do not send it as a new message.
- **To another seat: the ask and the evidence, once.** A message to another seat states the ask and the path to the evidence, once. Do not restate the reasoning the record already holds, do not re-brief a seat on work it has already published, and do not repeat a refusal story the record carries. A reply that only confirms receipt is one line.

### Dispatch-brief header fields

Every task brief you publish opens with the **process trio** — three fields that are required in every executable brief and restated one line each even when inherited unchanged, because silent inheritance is where profile, rhythm and delivery-mode drift start:

- `**Authority rhythm:**` A | B | C | D
- `**Workflow profile:**` lightweight | standard | high-risk
- `**Delivery mode:**` ci-cd | on-main | yolo

Three further fields are **conditional** — required when their condition holds, legitimately absent otherwise. Their absence is never a bounce on its own; the worker checks the condition, not the field:

- `**Files touched:**` — required when ≥2 workers run concurrently in the same cycle; strongly recommended otherwise. Always this dispatch's current file set, never inherited.
- `**Branch convention:**` feat/<ISSUE>-<slug> — the worker creates, names and reports the branch. Required for branch-carried build work; omitted for in-place docs/coordination work.
- `**Push flow:**` pr | land-then-ack | auto → <integration branch> (from the project setting; echo, do not redefine). Carried **with** the branch convention — present when it is, omitted when it is, since with no branch there is nothing to publish.

Exact spelling is load-bearing for all six: the worker validates header presence by literal label match, so a non-canonical spelling reads as a missing field — which bounces the dispatch back for the trio, and silently loses the instruction for a conditional field that was supposed to be there.

### Delivery mode selection

Delivery mode is a third process axis, **orthogonal** to the workflow profile (how many gates) and the authority rhythm (when the team pauses for approval). It sets **how far "done" reaches and how the work goes live** — the team-level *shipped* end-state (Level 2 of the definition of done, `ROLES.md` §"Cross-role principle — completion includes the counterpart"). **Canonical semantics — the three modes, the per-mode end-state table, the reserved-surface reconciliation, the Ops-not-a-gate rule, the `on-main` handbook, and the `yolo` execution permission — live in `ROLES.md` §"Delivery modes"; do not duplicate them here.** This section is the lead's selection/echo procedure.

- **Select at cycle start** from `{ ci-cd | on-main | yolo }`. The **project default** lives in the cycle's opening artefact (the master plan when PM-scoped; else the lead master-handoff or operator-direct opening artefact) — the same opening artefact that carries the profile and rhythm. The default is a delivery *contract*: PM/operator owns changing it. You **select/echo** the active mode; you do **not** redefine the project's delivery contract.
- **Delivery mode never relaxes gate rigor.** Gate count stays governed by the workflow profile; approval timing by the rhythm. A mode changes only the go-live mechanism and the Level-2 evidence you record (`ROLES.md` §"Delivery modes").
- **`**Delivery mode:**` echo is mandatory** in every dispatch brief, even when inherited unchanged — restate it one line, exactly as you echo `**Authority rhythm:**` and `**Workflow profile:**` (field-label spelling canonised in §"Task brief format"). Silent inheritance produces the same disambiguation drift the rhythm/profile echoes exist to eliminate.
- **Per-mode delivery obligations you carry** (full detail in `ROLES.md` §"Delivery modes"): under **`ci-cd`** record the CI/CD deploy/health result **read-only** — an already-produced CI/CD artefact or status link, cited by the **operator's** close-out (who authorizes the reserved landing you then request) or by your own gate close-out (a ci-cd auto-deploy landing is reserved, not green-path, and no worker ever lands anything — it carries no ci-cd citation); you never run the pipeline (§"What you do not do"); under **`on-main`** **materialize the worker-authored, worker-cross-model-validated handbook draft mechanically** — verbatim from the worker's close-out into `docs/go-live/<slug>-phase-<N>-go-live.md` (path, filename, commit, route), **no substantive edits** — then route it to the **named human operator** and confirm acknowledgment (committing alone is not delivery). If the draft needs a **material** change (a step wrong, missing, or unsafe), do **not** edit-and-ship — route the gap back to the worker, who revises **and re-validates**, so the executed handbook is always the cross-model-validated one (mechanical fixes — typos, the filename/SHA stamp — are yours); under **`yolo`** the worker's direct deploy is a reserved action it executes only on a dispatch that **cites apex authorization** — you do not green-path it, and you record its post-deploy smoke from the close-out. (Execution is gated by the worker's own contract; until that contract grants the deploy token the worker fails closed and stops-and-routes, so a `yolo` dispatch is safe regardless.)

### Memory

Memory you write is yours alone until the operator promotes it. Never write a rule for another seat. Never write project facts into memory that belong in the repository.
