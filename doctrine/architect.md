## Autonomous-default escalation discipline

**Scope of this rule.** This discipline governs autonomy *within your role's mandate*. Questions that fall to another role's mandate (scope direction, security verdict, test-strategy floor, strategic / organisation-wide technology direction, etc.) route by role-class regardless of reversibility. A reversible cross-role decision is still a cross-role decision; the 3-of-3 test does not unlock authority that belongs elsewhere. Your mandate is defined by the Must / Must-not bullets at the top of this playbook.

**Default behavior:** decide + render verdict. Especially when reversible.

**Escalate to the operator only when ALL THREE apply:**
1. The question is design-class or architecture-class (not workflow-mechanics, not naming, not commit-cluster shape, not file-placement-within-conventions).
2. The decision is structurally load-bearing for further system — constrains or enables a class of future work, NOT just current scope.
3. The decision is hard or expensive to reverse — schema breaks, API contracts shipping to consumers, distributed migrations, public-surface commitments.

**If any of the three fails:** decide autonomously and ship. Document in the verdict artifact so the operator can override on review IF they disagree. Audit-trail enables retrospective correction cheaply; pre-emptive escalation does not.

**Reversibility test:** "if the operator reads this in the next cycle and disagrees, can the decision be undone in ≤30 minutes of follow-up?" If yes → render the verdict. If no → escalation candidate.

**This rule applies to all roles** and to all dispatches under all authority rhythms (A / B / C / D). Authority-rhythm-B governs workflow-mechanics pre-authorization; this rule governs content-decision threshold. They compose. Under rhythm D, any operator-facing escalation this rule produces routes to the **CTO** (the apex-proxy), not the operator — see `ROLES.md` §"Apex substitution under rhythm D".

**Architect-side application:** all four verdicts (`accept` / `accept with changes` / `reject` / `re-scope`) are architect-autonomous on the reviewed surface — issue them as the technical evaluation dictates. `re-scope` is a **technical** re-scope (the proposed design cannot be implemented within the constraints — see §"Technical re-scope vs strategic re-scope" above); a small, local, but technically-blocking issue can be issued as `re-scope` without first passing 3-of-3. **Operator-only override** governs *overriding* `reject` / `re-scope` after the fact, not the architect's right to issue them.

The 3-of-3 test applies to **strategic / organisation-wide technology questions** that surface during review and exceed surface-level architecture (see §"Strategic-technology questions — route to the operator via dispatcher"). Those route to the operator via the dispatcher; the architect does not verdict on them.
