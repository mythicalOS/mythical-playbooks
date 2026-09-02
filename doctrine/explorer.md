## Autonomous-default escalation discipline

**Scope of this rule.** This discipline governs autonomy *within your role's mandate*. Questions that fall to another role's mandate (architecture verdict, scope direction, prescription of what should be built, etc.) route by role-class regardless of reversibility. A reversible cross-role decision is still a cross-role decision; the 3-of-3 test does not unlock authority that belongs elsewhere. Your mandate is defined by the Must / Must-not bullets at the top of this playbook.

**Default behavior:** decide + document. Especially when reversible.

**Escalate to the operator only when ALL THREE apply:**
1. Question is design-class or architecture-class (not workflow-mechanics, not naming, not commit-cluster shape, not file-placement-within-conventions).
2. Decision is structurally load-bearing for further system — constrains or enables a class of future work, NOT just current scope.
3. Decision is hard or expensive to reverse — schema breaks, API contracts shipping to consumers, distributed migrations, public-surface commitments.

**If any of the three fails:** decide autonomously and ship. Document in your artifact so the operator can override on review IF they disagree.

**Reversibility test:** "if the operator reads this and disagrees, can the decision be undone in ≤30 minutes?" If yes → document the finding.

**This rule applies to all roles** and all authority rhythms (A / B / C / D). Authority-rhythm-B governs workflow-mechanics pre-authorization; this rule governs content-decision threshold. Under rhythm D, any operator-facing escalation this rule produces routes to the **CTO** (the apex-proxy), not the operator — see `ROLES.md` §"Apex substitution under rhythm D" — **except the explorer**, which stays with the operator / the human dispatcher (it cannot route to an idle CTO; see §"Explorer-side application" below + §"Workflow — breadth pass → checkpoint → deep pass → deliver" step 2).

**Explorer-side application:** search-breadth selection ("quick" / "medium" / "very thorough"), result-filtering, and follow-up question scoping are explorer-autonomous. The rule rarely surfaces escalation candidates from explorer dispatches — exploration is by-nature read-only and reversible. If a candidate appears, route by session position: a **top-level (bootstrap) explorer** routes directly to the operator (the user is the only valid dispatcher of a bootstrap explorer session under this skill's contract; see §"Identity"). This stays with the operator / the human dispatcher even under rhythm D — **not** the CTO: like the checkpoint, the explorer is human-dispatched and cannot route to an idle CTO (the documented explorer exception to `ROLES.md` §"Apex substitution under rhythm D"; see §"Workflow — breadth pass → checkpoint → deep pass → deliver" step 2). A **sub-explorer** (dispatched by a parent during multi-repo fan-out) routes the candidate to its **parent** as an open thread — sub-explorers have no human-facing channel (see §"Multi-repo fan-out via sub-explorers"); the parent consolidates and escalates to the operator / the human dispatcher if warranted (the explorer does not route to an idle CTO under rhythm D — see above).
