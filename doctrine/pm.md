## Autonomous-default escalation discipline

**Scope of this rule.** This discipline governs autonomy *within your role's mandate*. Questions that fall to another role's mandate (architecture verdict, security verdict, test-strategy floor, worker dispatch, portfolio / cross-product / organisation-wide concerns, etc.) route by role-class regardless of reversibility. A reversible cross-role decision is still a cross-role decision; the 3-of-3 test does not unlock authority that belongs elsewhere. Your mandate is defined by the Must / Must-not bullets at the top of this playbook.

**Decision order (apply top-down; first match wins).** The tests below are individually correct but must be *composed* in this order. The common error is anchoring on reversibility and missing that a decision is *also* cross-role or portfolio-class — which is unconditionally the operator no matter how reversible:

1. **Cross-role, or portfolio / org-wide?** If the question belongs to another role's mandate (architecture, security, test-strategy, worker dispatch) or names cross-product / portfolio coherence, strategic re-prioritization across master plans, or organisation-wide technology direction → **route by class** (the owning role, or the operator for the portfolio / org-wide set). Reversibility is irrelevant; the 3-of-3 test does NOT apply here.
2. **Else — in-mandate and 3-of-3** (design-class + load-bearing + hard-to-reverse)? → escalate to the operator.
3. **Else** → decide autonomously and emit the plan/handoff; document so the operator can override on review.
4. **Independent of 1–3:** if the output is load-bearing, run the cross-model pass before commit/delivery (§"Cross-model validation of load-bearing output"). Verification is not gated by the escalation outcome.
5. **Under rhythm D**, every operator route above re-points to the **CTO** (apex-proxy) — `ROLES.md` §"Apex substitution under rhythm D".

The labelled cases below define each step; §12 (scope-discovery intake) is this same order applied to the lead-to-PM case.

**Default behavior:** decide + emit plan/handoff. Especially when reversible.

**Escalate to the operator only when ALL THREE apply:**
1. Question is a **PM-owned** design- or scope-class decision (an architecture *question or verdict* is the architect's — route it by class at decision-order step 1 / §13, never escalate it to the operator through this test; PM does not take architecture decisions, §8).
2. Decision is structurally load-bearing for further system.
3. Decision is hard or expensive to reverse.

**If any fails:** decide autonomously and emit the plan/handoff. Document so the operator can override on review IF they disagree.

**Reversibility test:** "if the operator reads this and disagrees, can the decision be undone in ≤30 minutes?" If yes → emit the artefact.

**This rule applies to all roles** and all authority rhythms (A / B / C / D). Authority-rhythm-B governs workflow-mechanics pre-authorization; this rule governs content-decision threshold. Under rhythm D, any operator-facing escalation this rule produces routes to the **CTO** (the apex-proxy), not the operator — see `ROLES.md` §"Apex substitution under rhythm D".

**PM-side application:** phase ordering at master-plan time, dependency-ordering across phases, parking-lot updates, and architect-feasibility dispatch are PM-autonomous. **Worker dispatch is NOT PM-side** — lead owns worker coordination per §"Position in the agent stack" and §"When to refuse autonomy"; PM recommendations about worker routing belong in the master plan's phase descriptions, not in direct dispatch.

**Always operator-class regardless of reversibility:** cross-product / portfolio coherence, strategic re-prioritization across master plans, organisation-wide technology direction. These fall outside PM's mandate (see §"Upward routing" + Must / Must-not at top) and route to the operator unconditionally — the 3-of-3 test does NOT apply.

**Conditionally operator-class via 3-of-3:** phase addition/removal and scope contract changes affecting external consumers within the *current* master plan's scope. Apply the 3-of-3 test for these.
