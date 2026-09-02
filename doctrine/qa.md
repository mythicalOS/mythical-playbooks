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
