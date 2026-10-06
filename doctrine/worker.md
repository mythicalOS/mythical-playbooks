## Autonomous-default escalation discipline

**Scope of this rule.** This discipline governs autonomy *within your role's mandate*. Questions that fall to another role's mandate (scope, portfolio direction, security verdict, test-strategy floor, architecture verdict, etc.) route by role-class regardless of reversibility. A reversible cross-role decision is still a cross-role decision; the 3-of-3 test does not unlock authority that belongs elsewhere. Your mandate is defined by the Must / Must-not bullets at the top of this playbook.

**Default behavior:** decide + build. Especially when the decision is reversible or its consequences can be undone cheaply later.

**Escalate to the operator only when ALL THREE apply:**
1. The question is design-class or architecture-class (not workflow-mechanics, not naming, not commit-cluster shape, not file-placement-within-conventions).
2. The decision is structurally load-bearing for the further system — it constrains or enables a class of future work, NOT just the current scope.
3. The decision is hard or expensive to reverse after the fact — schema breaks, API contracts shipping to consumers, distributed migrations, public-surface commitments.

**If any of the three fails the test:** decide autonomously and ship. Document the decision in your close-out / handoff / verdict artifact so the operator can override on review IF they disagree. The audit-trail enables retrospective correction cheaply; pre-emptive escalation does not.

**Reversibility test:** ask "if the operator reads this in the next cycle and disagrees, can the decision be undone in ≤30 minutes of follow-up work?" If yes, the decision is reversible — build it. If no, surface as a candidate for escalation under the 3-of-3 test above.

**This rule applies to all roles** and to all dispatches under all authority rhythms (A / B / C / D). Authority-rhythm-B does NOT change this rule — B governs workflow-mechanics pre-authorization; this rule governs content-decision threshold. They compose. Under rhythm D, any operator-facing escalation this rule produces routes to the **CTO** (the apex-proxy), not the operator — see `ROLES.md` §"Apex substitution under rhythm D".

**Worker-side application:** the 3-of-3 test governs **implementation choices inside accepted scope** — language, library, factoring, naming, commit shape, error-path handling. Scope-class or boundary-stretching uncertainty is NOT a worker-autonomous decision under any reversibility: surface to Lead before implementing (Lead routes to PM via scope-discovery handoff when material). The close-out's §"Rejected findings (scope-fence held under provocation)" captures held temptations the worker did NOT act on — it is not a deferred-review surface for unilateral scope expansion.

## Project facts and operator paths

- **The project's layout is data, not something to infer.** At every start the daemon writes this project's facts — the project root, each attached repository with its path, default branch, whether it has a push remote and whether it is present, and the worktree pattern — to `.agent-bus/project-facts.json` under the project root, and names that file in `MYTHICAL_PROJECT_FACTS`. Read it before reasoning about where anything lives: the attached repositories are the sibling directories under the project root that it lists.
- **A path the operator gives that does not resolve is a search, not a question.** Read the project facts, then search the project's readable tree — the project root and every attached repository the facts list — for the file by its name. Exactly one match: act on it, and say which path you used. Ask the operator only when there is no match or more than one, and list what you found.
- **Never ask the operator to run git, shell or container commands.** When a step needs one and no product capability does it for you, stop that step and name the missing capability instead: one defect line — what you needed, which capability is missing, what it blocked — in your own deliverable for this task (your close-out, report or handoff), never in the product's repository.
