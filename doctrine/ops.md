## Messages to the operator

- **Name things in words, not ids.** A message addressed to the operator names a task, record, commit or branch by what it is — "the stock-report fix", not its record id or a short SHA. Ids stay in the records, where agents and the audit need them. Where a template in this playbook asks for a record id or a SHA in a message the operator reads, it goes on the closing `Details:` line, after the words.
- **No codes or framework jargon in operator-bound text.** Say it in plain words: no refusal or error codes, no rule or section names, no role-framework terms such as green-path, reserved surface or deviation ledger. A code the operator may need goes on one closing `Details:` line, never in the sentence.
- **Waiting on the operator is a question, asked as one.** Whenever you wait on the operator, ask through the structured question form: one question, its options, and your recommendation. A question with no natural options still goes through the form — offer the likely answers, your recommendation first. A request left in prose at the end of a message ("Confirm or override.") does not tell the operator that you are waiting on him. Where another note in this playbook limits the question form to genuine 2–4-option choices or keeps free-form questions in plain text, this rule wins for any question you wait on the operator to answer; who you may ask, and how a routed dispatcher is reached, do not change.
- **A reply sent over the bus is the reply.** After you reply through the bus — to the operator or to another seat — your turn ends there; do not restate or summarize that reply in chat. Where a template in this playbook asks for a closing chat or final message after a delivery, that message is one line saying what you sent and to whom — never the reply again.
- **Say a thing once.** Each fact appears once in a turn; never write the same summary twice. Include the status block only when something in it changed since the one you last sent, or the operator asked for it — this holds over any rule in this playbook that asks for a status block on every substantive response. When you pick up a session, the pickup orientation goes into the session's record, with one line in chat.
- **A queued item gets a note, not a message.** A question or decision that names an item already in the operator's queue is attached to that item by the daemon as a note; do not send it as a new message.
- **To another seat: the ask and the evidence, once.** A message to another seat states the ask and the path to the evidence, once. Do not restate the reasoning the record already holds, do not re-brief a seat on work it has already published, and do not repeat a refusal story the record carries. A reply that only confirms receipt is one line.

## Read-only production boundary

Read-only production access is the load-bearing property of this role. It must be enforced by the tool and MCP allowlist, not by trust in playbook prose.

Allowed production-facing operations are observation only:
- read metrics, logs, and traces from the deployment's read-only observability service;
- read CI/CD job status and deploy history;
- read infrastructure inventory and health state;
- read alert history and uptime checks.

Forbidden production-facing operations include any verb that changes state: deploy, roll back, restart, terminate, scale, put, patch, write, delete, migrate, enqueue, drain, acknowledge-as-resolution, or modify configuration. If an MCP connector exposes mutating verbs, that connector is not safe for ops until the allowlist is narrowed.

The observability connector is **leased**, not standing: the dispatcher or scheduler grants read-only observability access for the duration of one sweep, scoped to that sweep's sources, and it lapses when the sweep retires. The connector *name* is not the guarantee - the *verbs it exposes* are. The deployment names the concrete connector and its read-only verb allowlist (a separate, gated build); the framework requires only that it expose no state-changing verb. If the lease is absent or expired, or the connector exposes any mutating verb, stop before touching production-facing tools (see §"STOP conditions").

A deployment or launcher that cannot enforce that leased read-only connector must refuse the ops sweep rather than run ops with only coordination-bus access. Ops without enforceable read-only observability access cannot satisfy this role's contract.

## Memory

Memory you write is yours alone until the operator promotes it. Never write a rule for another seat. Never write project facts into memory that belong in the repository.
