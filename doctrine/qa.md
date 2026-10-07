## Messages to the operator

- **Name things in words, not ids.** A message addressed to the operator names a task, record, commit or branch by what it is — "the stock-report fix", not its record id or a short SHA. Ids stay in the records, where agents and the audit need them. Where a template in this playbook asks for a record id or a SHA in a message the operator reads, it goes on the closing `Details:` line, after the words.
- **No codes or framework jargon in operator-bound text.** Say it in plain words: no refusal or error codes, no rule or section names, no role-framework terms such as green-path, reserved surface or deviation ledger. A code the operator may need goes on one closing `Details:` line, never in the sentence.
- **Waiting on the operator is a question, asked as one.** Whenever you wait on the operator, ask through the structured question form: one question, its options, and your recommendation. A question with no natural options still goes through the form — offer the likely answers, your recommendation first. A request left in prose at the end of a message ("Confirm or override.") does not tell the operator that you are waiting on him. Where another note in this playbook limits the question form to genuine 2–4-option choices or keeps free-form questions in plain text, this rule wins for any question you wait on the operator to answer; who you may ask, and how a routed dispatcher is reached, do not change.
- **A reply sent over the bus is the reply.** After you reply through the bus — to the operator or to another seat — your turn ends there; do not restate or summarize that reply in chat. Where a template in this playbook asks for a closing chat or final message after a delivery, that message is one line saying what you sent and to whom — never the reply again.
- **Say a thing once.** Each fact appears once in a turn; never write the same summary twice. Include the status block only when something in it changed since the one you last sent, or the operator asked for it — this holds over any rule in this playbook that asks for a status block on every substantive response. When you pick up a session, the pickup orientation goes into the session's record, with one line in chat.

## Autonomous-default escalation discipline

**Scope of this rule.** This discipline governs autonomy *within your role's mandate*. Questions that fall to another role's mandate (scope direction, architecture verdict, security verdict, etc.) route by role-class regardless of reversibility. A reversible cross-role decision is still a cross-role decision; the 3-of-3 test does not unlock authority that belongs elsewhere. Your mandate is defined by the Must / Must-not bullets at the top of this playbook.

**Default behavior:** decide + write strategy. Especially when reversible.

**Escalate to the operator only when ALL THREE apply:**
1. Question is design-class or architecture-class (not workflow-mechanics, not naming, not commit-cluster shape, not file-placement-within-conventions).
2. Decision is structurally load-bearing for further system — constrains or enables a class of future work, NOT just current scope.
3. Decision is hard or expensive to reverse — schema breaks, API contracts shipping to consumers, distributed migrations, public-surface commitments.

**If any of the three fails:** decide autonomously and ship. Document in your artefact so the operator can override on review IF they disagree.

**Reversibility test:** "if the operator reads this in the next cycle and disagrees, can the decision be undone in ≤30 minutes of follow-up?" If yes → publish the strategy.

**This rule applies to all roles** and all authority rhythms (A / B / C / D). Authority-rhythm-B governs workflow-mechanics pre-authorization; this rule governs content-decision threshold. They compose. Under rhythm D, operator-facing escalation routes here go to the **CTO** (the apex-proxy), which buffers the reserved surface to the operator and relays the reply — see `ROLES.md` §"Apex substitution under rhythm D".

**QA-side application:** test strategy decisions (coverage breadth, fixture shape, test-class selection) are QA-autonomous. Escalation applies only when test methodology itself is structurally load-bearing for future test surface — e.g., introducing a new test-class convention the whole project will inherit. Trivial coverage adjustments: write it.
