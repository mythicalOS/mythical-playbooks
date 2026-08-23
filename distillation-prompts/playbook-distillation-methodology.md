# Playbook Distillation Methodology

> Role-agnostic, project-agnostic, time-invariant. Document of record for *how* playbook distillation works.
> For *this* distillation, use one of the runtime templates in this directory.
>
> Last revised: 2026-05-27 — added §13 "Skill extraction discipline" anchored on three-phase empirical record (Phase 1 `coordination-wip-handoff`, Phase 2 `structural-refactor-verification`, Phase 3 `verification-patterns`). Closes the Take-2-admission-5 gap (relocation discipline distinct from §12's promotion discipline). Added 4th update-trigger to §11 covering new structural layers. Added one parked pattern to §12 (plural-namespace, single instance); elevated synthetic-fixture smoke testing to §13.6 directly (two empirical instances per §12's recurrence threshold).

---

## 1. Purpose

A playbook encodes how an agent operates in a coordination pattern (lead, worker, or future role). Distillation is the process of updating a playbook based on empirical experience from running the pattern. Each distillation produces a new version of the playbook that the next session loads.

The artefacts of a distillation are the per-role playbook surfaces:

- `<role>-agent.md` — the base playbook, direct system-prompt format, maintained project-agnostic
- `<role>-agent.<harness>.md` — harness-specific overlay (`.claude` for Claude Code, `.codex` for Codex CLI)

(Earlier rounds maintained project-specific and `*.generalized.md` twins of each file; the playbooks
in this repository ARE the generalized set now, so the base file is the single source and a
deployment that needs project-specific forks maintains them downstream.)

The runtime templates in this directory drive a single distillation round; this methodology file defines the patterns that hold across rounds.

---

## 2. When to distill (and when not to)

Triggers:

- A worker or lead has accumulated empirically validated new patterns since the last distillation (typically: multiple module extractions, several handled mistakes, observed framework gaps).
- The session approaches context-pressure (60-70% of context window used) and quality is at risk if work continues without a fresh session.
- A fresh session is upcoming and the new version should be loaded into it cleanly.
- A multi-step phase has closed and the natural retrospective moment has arrived.

Anti-triggers:

- Single bugfixes the worker handled.
- Cosmetic playbook changes (typos, formatting).
- Project-specific decisions (those go in the master handoff, not in playbooks).
- Lead or worker is in a degraded-judgement state (recovering from rot, just after a chain of false-clean reports). Wait for a fresh session.

---

## 3. The output shape

Every distillation produces or updates a role's playbook surfaces. The naming convention is load-bearing:

| Variant | File | Purpose |
|---|---|---|
| Base playbook | `<role>-agent.md` | Direct system-prompt markdown for any framework that loads raw markdown as system context; project-agnostic |
| Harness overlay | `<role>-agent.claude.md` / `<role>-agent.codex.md` | Overlay on the base file; adds harness-specific tool affordances and operational notes only |

Each file's top must carry, in this order:

```
# <Title>

> Version: **vX.Y[.Z]** (project-specific | project-agnostic, <scope>).
> Distilled: YYYY-MM-DD <one-sentence trigger description>.
>
> Changes from v<previous>:
> - <bulleted, concrete change>
> - ...
```

A deployment that maintains project-specific forks of these playbooks versions them independently
and syncs at major version bumps where possible, letting them lag at patch revisions where the patch
is project-specific noise; in this repository the base files are the project-agnostic source.

The base playbook is the source of truth; the harness overlay references the base file ("Read that first; this file adds tool-specific affordances and operational notes"). The harness overlay must not duplicate principles from the base file — only extend them with tool-specific tactics.

---

## 4. Distillation principles

These six invariants govern every distillation regardless of role or project.

1. **Add only what's empirically validated.** A new principle needs a concrete instance from this project showing why. No speculative "could happen" warnings. If you can't name the case study, the principle isn't ready.
2. **Sharpen with concrete examples.** Each principle should have at least one named example (a step, a sequence, a bug class). The example anchors the principle so a future reader can reconstruct why it exists.
3. **Remove or merge what didn't recur.** If a principle from the previous version never came into play, consider whether it should stay. Playbook bloat is a failure mode — long files don't get internalized.
4. **Format consistency.** Base playbooks are direct system-prompt style (2nd person, prescriptive). Harness overlays are hybrid (definitions + behavioral instructions + harness-specific operational notes) and never duplicate the base content — only extend it.
5. **The playbooks stay project-agnostic — strip every project-specific reference.** File layouts, language-specific tooling, project conventions, named persons, named systems, named steps. Cross-project patterns stay; project examples become "a recent multi-step refactor session" or similar.
6. **Honest version header.** Version + date + changes-from-previous, in that order, at the top of every file. The changes block is concrete (what added, what removed, what refined), not marketing.

---

## 5. Pre-write grounding exercise

Before drafting any file content, the distilling agent (lead or worker) lists, for its own grounding:

- 5-10 things it did consistently that the other party (user for lead, lead for worker) engaged with positively.
- 3-5 mistakes it made and how it corrected them.
- 3-5 patterns in the codebase or tooling that surprised it.
- Any prompts from the counterparty that taught it something the previous playbook version didn't yet capture.

This list is for grounding only. It does not appear in the output files. The exercise exists because empirical validation requires recalling specific instances, not generalized impressions. An agent that can't name 3 mistakes likely has degraded recall and should wait for a fresher session.

---

## 6. Retrospective metanote / failure-class extraction

In normal operation:

- The lead surfaces method observations as **🔖 metanotes** in status blocks during the session.
- The worker surfaces method observations as **failure-class patterns** in gate reports during the session.

When the convention drifts (lead tags observations as parking-lot entries instead; worker buries failure classes in commit messages), distillation must reconstruct what would have been tagged.

Process:

1. Scan the session history for moments where a method observation was warranted but not formally captured.
2. Identify the underlying pattern (not the instance).
3. Encode the pattern in the new version.

This is harder than real-time tagging because you're reconstructing from project history, but it's also more rigorous — you can identify patterns that weren't visible until they recurred.

---

## 7. Anti-patterns to avoid

The following have been observed degrading distillation outputs across multiple rounds. Watch for them while drafting.

- **Cheerleader tone.** "You're a brilliant senior engineer who always knows best." This makes the playbook performative rather than operational.
- **Vague principles.** "Be thoughtful." "Use good judgement." Principles must be falsifiable — if you can't tell whether you're failing the principle in a concrete situation, it's not a principle.
- **Long lists of situations.** Twenty bullet points covering hypothetical edge cases. Trim aggressively; if a situation hasn't appeared in real practice, it doesn't belong yet.
- **Cross-contamination between base and harness files.** Tool-specific tactics in the base file; behavioural principles in the harness overlay. Each file has a job; respect the partition.
- **Project-specific examples in the playbooks.** Named projects, persons, file paths, language idioms, internal-system references. Replace with role-neutral phrasing ("a recent multi-step refactor session" rather than "Phase B Step 0").
- **Prose passages that duplicate themselves.** Re-explaining the same idea in different paragraphs is a signal the writer hasn't internalized the idea yet. Restructure rather than restate.

---

## 8. Success criteria

A distillation succeeded if:

- A different agent could load the resulting playbook and operate in a way the user would recognise as continuous with prior sessions.
- The user reading the file would recognise the dynamic the playbook describes.
- The patterns are portable across projects of similar shape (the playbooks are maintained project-agnostic, which tests this directly).
- The next iteration of distillation has clear material to work from (good changes-from-previous blocks; named patterns; concrete examples).

If any of these fail, the distillation produced a partial artefact that needs revision before adoption.

---

## 9. Uncertainty handling

If, during distillation, the agent is unsure:

- Whether a new pattern is empirically validated enough → surface to counterparty before finalising.
- Whether a previous-version principle should stay → ask: keep for optionality, or drop for cleanliness? Default is drop if the principle hasn't been invoked in the period since last distillation.
- Whether two principles overlap meaningfully → propose a consolidation explicitly; let counterparty decide.
- Whether the scope of a new principle is right → state two phrasings (narrow vs broad) and ask which.

Open questions land at the bottom of the distillation deliverable, numbered. The counterparty answers; finalisation follows.

---

## 10. Post-write reflection

After writing the playbook surfaces, the distilling agent surfaces metanotes about the distillation process itself:

- What was hard to articulate?
- Which patterns felt obvious in retrospect but weren't captured before?
- Were previous-version principles redundant or reducible to a more fundamental one?
- What in the runtime template or this methodology file made the distillation easier or harder?

These metanotes go back to the user and feed:

- The next iteration of this methodology file (if the observation is time-invariant).
- The next iteration of the relevant runtime template (if the observation is per-instance).

A distillation without post-write reflection is incomplete.

---

## 11. When to update this methodology file

Update this file when:

- Distillation runs reveal new patterns about the *process* (vs the role-specific content).
- Format conventions change (new variant types, restructured overlays, new placeholder syntax).
- The output-shape contract changes (e.g., a fifth variant emerges, or a variant gets retired).
- **A new structural layer is introduced.** Skills as procedural lazy-loadable extracts arrived in May 2026 as a third layer beyond playbook/overlay; future layers (shared-script libraries, cross-role reference catalogues, etc.) belong here too. Document the new layer's allocation rules in a dedicated section (see §13 for the skill-extraction record).

Time-invariant patterns evolve slowly. Most distillation rounds will not touch this file; they touch the runtime templates and the playbooks themselves.

---

## 12. Parked pattern observations (awaiting recurrence)

When a distillation round surfaces a candidate pattern with only one empirical instance, the methodology default is to park rather than elevate. Empirical bar for top-level elevation: ≥2 instances (single instance is permitted by §4.1 but only when the pattern's category is structurally important enough to warrant a forcing rule). Single-instance patterns live here until a second instance recurs.

Format: `**<pattern name>** — observed YYYY-MM-DD. Empirical: <1-line description>. Watch for second instance before elevating.`

### Lead-PM v0.4 round (2026-05-11)

- **Deliverable annotation discipline** — observed 2026-05-11. Empirical: lead delivered a file-selection list without annotating that the items included all members of a relevant category; user had to manually count to verify the selection was complete. Watch for second instance before elevating.

- **CLI-tool wrapping discipline** — observed 2026-05-11. Empirical: lead designed a wrapper script around an external CLI without first reading the tool's `--help` output; multiple script iterations could have been one with tool-documentation-first design. Watch for second instance before elevating.

- **Multi-topic user-message segmentation** — observed 2026-05-11. Empirical: user packaged multiple topics (architectural constraint + operational request + meta-question) into a single message; lead responded with a synthesized answer that merged them; user had to disentangle the three streams. Watch for second instance before elevating.

### Explorer-agent v0.2 round (2026-05-17)

- **Changelog distillation-event role-attribution boundary** — observed 2026-05-17. Empirical: lead wrote a stakeholder-role-directed phrase in a v0.2 changelog header (the project-specific user-role identifier appeared as the directing actor), treating originating-stakeholder role-name as parallel to "Worker #N reviewed" distillation-event attribution; pre-write state-leak audit missed it because the stakeholder role-name was on the project identifier list but lead's mental model classified it as changelog-exception; fresh-worker review caught it. Watch for second instance before elevating to methodology §3 / §4.6 explicit boundary rule (acceptable: peer-role attribution like Worker-N; not acceptable: originating-stakeholder role-name — user, sponsor, customer-name, or any role outside the coordination pattern).

- **Multi-checkpoint discipline preservation under fan-out** — observed 2026-05-17. Empirical: explorer-agent v0.2 added multi-repo fan-out; single-checkpoint discipline preserved by having the parent own the meta-checkpoint and sub-explorers report to parent (not to human). Three explicit assertions across two files needed to make the boundary visible. Watch for second instance (any other role expanding into fan-out architecture) before elevating to a cross-role principle ("when a role expands into multi-instance parallel execution, the single-checkpoint discipline shifts to the orchestrator level, not the worker level").

- **Descriptive-not-prescriptive discipline extended to new output type** — observed 2026-05-17. Empirical: explorer-agent v0.2 introduced `insights.md` extending `for-new-development.md`'s established discipline (observations not prescriptions) to a new content class (design patterns + novel code + pain points). Required two reinforcement points in the file (section description + Common Failure Patterns "Prescription leak" updated + mental test) to make the boundary visible. Watch for second instance (any other role introducing a new output type that needs descriptive framing) before elevating to a meta-pattern about how to introduce new descriptive-only output types cleanly.

### Skill-extraction round (2026-05-26 → 2026-05-27)

- **Plural-namespace pattern for reserved future content** — observed 2026-05-27. Empirical: Phase 3 named the new skill `verification-patterns` (plural) rather than `schema-check-coverage-audit` (the single first pattern) to reserve namespace for future rare verification patterns of the same class without committing to immediate inclusion. Trade-off vs trigger-promiscuity (Take 3 §C.1): a plural-named skill must keep each pattern's `When to invoke` sub-section distinct so the umbrella name does not invite the wrong trigger. Watch for second instance — Phase 4's proposed `lead-coordination-templates` (retro + risk-triage templates combined) would be the candidate; if Phase 4 happens with that shape, elevate to §13 as the convention for any skill expected to host multiple patterns.

### Recurrence trigger

When a parked pattern observes a second empirical instance:

1. Move it from this list to the relevant playbook as a top-level principle.
2. Update the version-changes block in that file to reference both empirical instances.
3. Delete the entry from this section (do not leave it as "elevated"; the section is a parking lot, not a history log).

If a parked pattern goes a full year without a second instance, drop it. The bar for naming patterns is empirical recurrence, not novelty.

---

## 13. Skill extraction discipline

Skills arrived in May 2026 as a third structural layer in the framework — beyond role-playbook (the role contract) and harness overlay (the platform binding), skills extract conditional or rare procedures into lazily-loaded `SKILL.md` files — today hosted in the companion `mythical-skills` repository (the `agent:` / `mythical:` namespaces) and resolved into a project-local plugin by the deployment's setup tooling. Roles invoke skills via an Allowed-skills allowlist in their overlay; the skill body loads only on invocation (always-on cost is the frontmatter `description` only). The three skills landed across May 26–27 (`coordination-wip-handoff`, `structural-refactor-verification`, `verification-patterns`) produced the empirically-anchored discipline below. This section is the formal counterpart to §12 — §12 governs "is this real" (promotion threshold via recurrence); §13 governs "where should real things live" (allocation across playbook / overlay / skill).

### 13.1 Relocation gate — where extracted content lives

The third skill-extraction review summary (recording Take 2's admission 5) identified that the methodology had no formal gate for "where should real things live" once recurrence had established a pattern was real. Three phases of skill extraction navigated this informally via lead-design-memo + Codex cross-model review + Gate 3 (smoke test or natural trigger). That informal gate is now the formal relocation discipline.

A pattern's home is determined by three questions, in order:

1. **How often does it fire?** Every dispatch → role-playbook (always-on context cost is acceptable). Conditional on dispatch shape (some dispatches, not all) → role-playbook if small (under ~30 lines), skill if substantial. Rare (a small fraction of dispatches) → skill (lazy-load wins).
2. **Does the harness need it?** Cross-platform principles → base role-playbook. Platform-specific tooling (e.g., `Bash` recipes for Claude, `functions.exec_command` patterns for Codex) → harness overlay. Procedure that platforms invoke with different mechanics but the same authority semantics → skill body, with platform-specific tool-mapping in each overlay's Allowed-skills bullet.
3. **Where does authority live?** Decisions (when to STOP, which rhythm applies, what's in scope) → playbook. Procedure (how to execute under decided authority) → skill. If a candidate skill needs to carry authority decisions to operate, the extraction is wrong — keep it inline. The skill's positive authority obligations (e.g., held-A/C STOP, report-not-fix, create-vs-surface routing) are limits on the procedure, not authority decisions the skill makes.

The gate procedure for each extraction:

- **Gate 1:** lead writes a design memo at `docs/design-reviews/YYYY-MM-DD-lead-skill-extraction-<phase>.md` naming what extracts, what stays, the authority obligation, the risk register. The operator reviews (or self-reviews per pre-authorization).
- **Gate 2:** Codex cross-model review (`codex review --uncommitted` with high reasoning effort). Cross-model is structural — internal self-review misses authority-consistency drift across surfaces (see §13.3). Iteration cost per §13.2.
- **Gate 3:** synthetic-fixture smoke test (when the skill has a safe boundary; see §13.6) OR natural trigger (when the skill is destructive-action-bounded and the smoke test would not be faithful).

### 13.2 Iteration cost scales with authority shape

Empirical pattern across Phase 1+2+3:

| Authority shape | Codex iteration rounds | Source |
|---|---|---|
| Single-faced STOP boundary (held-A/C) | 1 | Phase 1 `coordination-wip-handoff` |
| Two-faced create-vs-surface (in-scope-fix + out-of-scope-Rejected) | 12 | Phase 2 `structural-refactor-verification` |
| Single-faced report-only | 2 | Phase 3 `verification-patterns` |

Two-faced authority (where the skill makes one class of finding in-scope and another out-of-scope) takes substantially more iteration than single-faced (where the skill is uniformly STOP-only or report-only) because the distinction must land consistently on every surface (§13.3) and cross-reference drift compounds with each surface added; the same conceptual mistake (wrong default mental model) recurs at multiple anchor points.

**Budget guidance for future skill extractions:**

- 1-2 Codex rounds for single-faced authority on a small surface.
- 3-5 rounds for single-faced on a wider surface (multi-step procedure).
- 8-15 rounds for two-faced authority regardless of surface size.

If iteration runs past budget without convergence, surface explicit "iteration capped at round N" rationale in the commit message with known-followups listed (Phase 2 commit `6bf77e3` set the precedent). Do not commit before iteration converges *or* the cap rationale + followups are honest.

### 13.3 Multi-surface authority consistency

The same authority statement must appear consistently on every surface the agent reads. For skills, that means four surfaces minimum:

1. **SKILL.md frontmatter `description`** — always-on context cost on Claude (loaded with the description before the skill is invoked); first impression for the worker deciding whether to invoke.
2. **SKILL.md body §"Authority boundary"** — read on invocation; full statement with examples.
3. **Role-overlay §"Allowed skills" bullet** — read at role-load; the contract the role agrees to.
4. **README §Skills bullet** — read by framework readers (lead, the operator, future-distillation authors); part of the operational record.

A contradiction on any of these four causes worker drift. Phase 2's 12-round Codex iteration was substantially this class of finding: the authority concept evolved across iterations and each iteration risked leaving one surface stale.

**Pre-commit check:** before requesting Codex review, grep all four surfaces for the authority concept's keywords and re-read each independently. The drift surface is large enough that self-review is unreliable; cross-model review (Codex) is the structural defense.

### 13.4 YAML hygiene for skill frontmatter

SKILL.md frontmatter is YAML. Multi-line entries with embedded `:` or `"` characters break plain-scalar parsing — Phase 1 round-12 P1 HIGH finding. Use block scalars (`- |`) for any `assumes:`, `authority-boundary:`, `rhythm-gating:`, or similar list-of-paragraph entries from the start of the SKILL.md authoring; do not wait for a parser failure to discover the issue.

**Verification before commit:**

```bash
ruby -ryaml -e 'content = File.read("<skills-root>/<name>/SKILL.md"); fm = content.split("---", 3)[1]; YAML.safe_load(fm); puts "YAML OK"'
```

Should print `YAML OK`. If it errors with `could not find expected ':'`, an embedded colon broke a plain scalar; convert the relevant list entries to `- |` block scalars.

### 13.5 Pre-resolve open questions in the dispatch revision

Pattern observed across all three phases: open questions named at Gate 1 (the design memo) cost a roundtrip per question. Pre-resolving them in the *dispatch handoff itself* (before the lead opens the design memo) saves the roundtrip and surfaces only genuine implementation-time discoveries at Gate 1. The original Phase 1 handoff revision (the skill-extraction handoff's addenda) pre-resolved all four named open questions; Phase 2 + Phase 3 inherited the pre-resolution and ran cleanly through Gate 1.

**Discipline:** if a candidate skill extraction surfaces design questions during initial scoping, resolve them in the handoff revision (or in a dedicated decision-memo committed before the dispatch fires), not in the lead's Gate 1 memo. Reserve Gate 1 memo open-questions for things the lead genuinely discovered during memo authoring, not things the dispatcher chose to defer.

### 13.6 Synthetic-fixture smoke test for safe-boundary skills

When a skill has a clean safety boundary — destructive-action STOP gate, filesystem isolation, or read-only nature — Gate 3 validation can use a synthetic fixture rather than waiting for a natural trigger. The fixture must exercise the authority obligations the skill claims and be containable to a safe location.

Two empirical anchors:

- **Phase 1 `coordination-wip-handoff`** (2026-05-26) used the skill's own held-A/C STOP boundary as the safety mechanism: the smoke-test dispatch was option A without rhythm-independent authorization, so the skill could not publish-mv even if the worker tried.
- **Phase 2 `structural-refactor-verification`** (2026-05-27) used filesystem isolation in `/tmp/refactor-smoke/` with an explicit hard boundary forbidding modifications to the live playbooks repo.

The smoke-test design pattern per skill: identify the skill's safety boundary; design a fixture that exercises every authority obligation the skill carries (e.g., Phase 2's fixture had both refactor-regressions to fix inline AND adjacent-surface findings to hold in Rejected findings); pre-resolve any baseline-test or precondition gaps in the dispatch so Step 0 / entry gates do not block.

**When this pattern does NOT apply:** skills whose safety relies on a downstream consumer (e.g., a published artefact reaching the lead via a bus wake) cannot be smoke-tested synthetically because the consumer is not simulatable; defer Gate 3 to natural trigger. Phase 3 `verification-patterns` designed a synthetic SQL CHECK + write-path fixture but deferred execution; the third empirical instance (executed, not just designed) would lock the pattern as default Gate 3 practice for all qualifying skills. Until then, the pattern is recommended-where-applicable, not default.

### 13.7 What does NOT belong in a skill

Three categories of content stay in role-playbook regardless of size:

- **Authority decisions** — when to STOP, which rhythm applies, what's in scope, CRITICAL-override semantics, scope-discovery routing. These are role-contract material; the skill is procedure under the contract.
- **High-frequency general rules** — content that applies in most dispatches (e.g., `worker-agent.md` §"Pre-commit shared-index audit", §"Bidirectional file-based coordination", §"Mock-then-construct order" general form). Lazy-load value is negative when the rule loads in most dispatches anyway.
- **Cross-skill consistency rules** — meta-rules that govern how multiple skills interact (e.g., the Allowed-skills allowlist contract itself). These belong in the role overlay where the allowlist lives, not in any individual skill.

When a skill candidate has substantial content that fails these tests, the extraction is wrong — re-scope or keep inline.
