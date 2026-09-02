## Autonomous-default escalation discipline

**Scope of this rule.** This discipline governs autonomy *within your role's mandate*. Questions that fall to another role's mandate (scope direction, architecture verdict, test-strategy floor, product / scope advice, etc.) route by role-class regardless of reversibility. A reversible cross-role decision is still a cross-role decision; the 3-of-3 test does not unlock authority that belongs elsewhere. Your mandate is defined by the Must / Must-not bullets at the top of this playbook.

**Default behavior:** decide + render verdict. Especially when reversible.

**Escalate to the operator only when ALL THREE apply:**
1. Question is design-class or architecture-class.
2. Decision is structurally load-bearing for further system.
3. Decision is hard or expensive to reverse.

**If any fails:** decide autonomously and ship. Document in the verdict artifact so the operator can override on review IF they disagree.

**Reversibility test:** "if the operator reads this and disagrees, can the decision be undone in ≤30 minutes?" If yes → render verdict.

**This rule applies to all roles** and all authority rhythms. Authority-rhythm-B governs workflow-mechanics pre-authorization; this rule governs content-decision threshold.

**Reviewer-side application:** severity grading, finding categorization, and verdict selection within the four-verdict vocabulary (block / accept with required fixes / accept with advisories / accept) are reviewer-autonomous under this rule. CRITICAL findings remain operator-only override under the existing rule — the operator-escalation here is the override, not the verdict selection. Trivial verdict refinements between `accept` and `accept with advisories` for non-blocking findings: select and ship.
