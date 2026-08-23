# Design plan — standardize cross-model review (Codex) as a universal pre-commit gate + transparency requirement

**Status:** kicked off / un-parked (2026-05-28). Lead #4 session executes against this plan; Worker #12 dogfoods the Phase A rollout.
**Original parking:** 2026-05-27 by Lead #2 (Phase 4 session).
**Un-park trigger fired:** (c) the operator explicitly lifts the parking lot at session start (2026-05-28).
**Phase A executor:** Worker #12 (in the `codex-rollout` worktree of the playbooks repo).
**Disjoint-scope partner:** Worker #13 (separate Lead session) is extracting role-playbook sections into skills; file-overlap on base playbooks resolved by branch-isolation — Worker #12's `codex-rollout` lands first to main; Worker #13's branch rebases onto the landed state.

**Revisions from the original parked plan (this un-park):**
- Codex (cross-model) review of the plan itself surfaced 7 substantive corrections; Lead surfaced 4 additional refinements.
- Authority correction (dominant): worker owns the pre-commit cross-model review loop; reviewer-agent consumes the worker's review record under its read-only/no-execution contract; lead and PM rollout deferred until worker/reviewer behavior stabilizes. **(Scope superseded 2026-05-29 — see Amendment below: lead + PM now run cross-model validation on their load-bearing output.)**
- 11 changes integrated below; superseded sections retain a "↻" marker at the heading.

**Amendment (2026-05-29, Lead #2):** the role scope below is **superseded**. Cross-model validation now applies to **every role's load-bearing primary output**, not only worker (Gate 2.2) + reviewer (Gate 2.3). Architect, QA, PM, and lead now run a cross-model adversarial pass on their load-bearing outputs (verdict / strategy / master plan / coordination artefact), profile-tiered — see `README.md` §"Cross-model review configuration" (generalized principle) + each role's playbook §"Cross-model validation of load-bearing output". This **reverses** the PM/lead deferral (§4, §11.1, §"Indefinitely deferred"). Empirical anchor: a milestone-driving architect verdict shipped without a cross-model pass; on prompting, Codex caught a real build-spec self-contradiction that would have cost worker rework (operator-supplied transcript, captured in `docs/design-reviews/2026-05-29-lead-2-all-roles-cross-model-validation.md`). The remediation-loop-vs-output-validation distinction is the key correction: read-only verdict roles correctly run no *remediation loop*, but their *output reasoning* still benefits from a second-model adversarial read. Explorer is excluded (factual recon, low cross-model value — the operator 2026-05-29).

---

## 1. The value case (the operator's framing)

The current `Phase 1–4` evidence shows cross-model adversarial review catches real, non-obvious findings:

| Phase | Codex rounds | Round-1 finding class | Caught by Codex that lead missed |
| --- | ---: | --- | --- |
| Phase 1 (`coordination-wip-handoff`) | 1 | P2 cd-before-git | Yes (commits in wrong directory) |
| Phase 2 (`structural-refactor-verification`) | 12 | P1 findings-not-fixes blanket rule | Yes (two-faced authority distinction lead had glossed) |
| Phase 3 (`verification-patterns`) | 2 | 2 authority / consistency findings | Yes (schema-rejected case + Phase 3 reference state) |
| Phase 4 (`lead-cycle-retro-template` + `lead-risk-triage-consolidation`) | 3 | P2 false "Lead is Claude-only" assumption | Yes — buried in YAML `assumes:` block inside a 7K SKILL.md, easy for a human reader to skim past |

The Phase 4 Round-1 finding is particularly load-bearing for this design: it was an integrity claim (where can this skill be invoked from?) embedded in metadata, ~3 levels deep in the file. No human reviewer would have caught it without a methodical re-walk of every `assumes:` block against current overlay-file existence. Codex caught it on the first read. **This is the pattern that justifies formalization.**

Hypothesis the standardization tests: *"For any diff with non-trivial cross-file consistency surface, cross-model adversarial review catches a class of integrity failures that single-model self-review structurally cannot — independent of how careful the author was."*

---

## 2. What needs to be standardized ↻

Five distinct dimensions, all of which the current Phase 1–4 pattern handles informally:

1. **When to invoke review** — which dispatches require it, which are exempt (lightweight typos, single-doc edits with no cross-file consistency surface).
2. **Who invokes it (authority correction).** **Worker owns the pre-commit loop** — the worker authoring a diff runs cross-model review against its own working tree before commit, iterates findings to CLEAN, and records the round-by-round trajectory in the close-out. **Reviewer-agent consumes the worker's review record** under its read-only/no-execution contract; reviewer does NOT run the loop. **Lead and PM rollout are secondary/deferred** — lead's coordination-artefact loop and PM's master-plan-emit loop are out of scope for the initial rollout; revisit after worker/reviewer behavior stabilises (≥2 cycles). The read-only verdict roles (architect, qa, reviewer, explorer) never run remediation loops themselves; reviewer's relationship to the worker's record is defined in §3.E below. **[Superseded 2026-05-29 (see Amendment at top): the remediation-loop exclusion still holds — read-only roles run no remediation loop — but cross-model *output validation* (a second-model adversarial read of the verdict / strategy / plan / coordination artefact, distinct from a remediation loop) now applies to architect / qa / pm / lead.]**
3. **How to invoke it** — concrete tool binding per platform overlay (Claude-author → `Bash codex review --uncommitted`; Codex-author → cross-platform reverse). Author always runs its own loop; the binding lives in the author's overlay.
4. **What to do with findings** — iterate to CLEAN before commit; record each round's findings as material; never skip-and-commit on author judgment alone. Iteration cap scales by workflow profile (see §11.4 below).
5. **Transparency in artefacts** — every coordination artefact whose subject is a reviewed diff carries the round count + final verdict + any deferred findings. This is the dimension the operator most-clearly named.

---

## 3. Candidate approaches (deeper than the prior brainstorm)

### A. Principle in base role-playbooks

Add a section to `worker-agent.md`, `lead-agent.md`, possibly `pm-agent.md`:

```markdown
### Cross-model adversarial review before commit

For any diff that materially affects code, skills, role playbooks, or
cross-file contracts: before `git commit`, invoke cross-model adversarial
review (default tool: `codex review --uncommitted` with high reasoning
effort). Iterate until the review returns CLEAN — every round's findings
are addressed in the working tree before the next round runs.

Exemption: lightweight diffs (typo / single-doc clarification / no
cross-file consistency surface) MAY skip review when the author's
workflow-profile is lightweight AND the diff is bounded to ≤2 surfaces
that do not include role playbooks, skill files, or contract artefacts.

The review tool MUST run from a different model than the diff author.
Codex-on-Codex review collapses adversarial-read benefit; a single model
cannot reliably second-guess its own blind spots. See §"Cross-platform
pairing rule" in the standardization plan.

The review's outcome — round count, severity breakdown, deferred
findings — is a transparency obligation recorded in:
  - the dispatch's close-out under §"Pre-commit cross-model review"
  - the cycle retro's §"Review-role / gate value" section
  - the commit message body
  - any subsequent handoff that references this commit
```

**Pros:** principle-level; cross-platform applicability; surfaces at every role bootstrap.
**Cons:** abstract — must be paired with concrete tool binding per overlay.
**Compatible with:** B, D, E (these add the tool binding + the matrix encoding + the reviewer relationship).

### B. Workflow-profile matrix expansion ↻

`README.md` gate matrix + `lead-agent.md` §"Workflow profile selection" gain explicit "Worker cross-model review (Gate 2 sub-step)" column. Authority correction baked in: worker review is mandatory at standard and high-risk; human reviewer (when dispatched) consumes the worker's record and does NOT exempt worker review.

| Gate | Lightweight | Standard | High-risk |
| --- | --- | --- | --- |
| Gate 1 (design) | Skipped | Conditional | Required |
| Gate 2.1 (tests + verification) | Worker self | Worker self + QA floor | Full QA + worker |
| **Gate 2.2 (worker cross-model review)** | **Optional (per author judgment)** | **Mandatory before commit** | **Mandatory before commit** |
| **Gate 2.3 (reviewer-agent baseline)** | **n/a — reviewer dispatch on a lightweight-classified diff is normally a profile-misclassification; primary disposition is for the Lead to upgrade the profile to standard (which moves the diff into the Standard column with Gate 2.2 + 2.3 applying). Residual edge case (caution-dispatch of reviewer at lightweight, e.g., docs-only diff explaining a sensitive flow) handled per `reviewer-agent.md` §"Cross-model baseline" Step 5** | **n/a unless reviewer dispatched; if dispatched, reviewer consumes worker record + may run optional baseline against frozen diff/range** | **Reviewer dispatched: consumes worker record; may run optional baseline against frozen diff/range; never substitutes for worker Gate 2.2** |
| Gate 3 (integration) | Optional | Required | Required + rollback rehearsal |

**Critical:** human reviewer dispatch does NOT exempt the worker's Gate 2.2. Worker review and reviewer baseline are distinct surfaces with distinct authority (worker = remediation; reviewer = independent verdict).

**Pros:** composes with existing risk-proportional model; explicit per profile; preserves reviewer's read-only contract; signals lightweight is the exception, not the default.
**Cons:** workflow profile must actually be set correctly (a high-risk dispatch declared lightweight escapes the gate).
**Compatible with:** A (principle backs the matrix); D (transparency requirements flow from the matrix's "mandatory" semantics); E (reviewer-baseline row maps to §E rewrite below).

### C. New `pre-commit-cross-model-review` skill

Single procedure: detect-diff → invoke-Codex → parse-findings → iterate → final-verdict → record-transparency-data. Lazy-loaded; invoked at the §"Cross-model adversarial review" trigger.

**Pros:** single source of truth for the iteration loop + transparency formatting; visible in the skill catalogue; lazy-load fits Phase 4's plural-namespace pattern (`pre-commit-patterns` even, to reserve namespace for future cross-platform invocations like Anthropic-side review of Codex work).
**Cons:** Phase 4 just landed two narrow lead-template skills; adding another may signal "extract before stabilising" anti-pattern. Procedure may not yet be stable enough for skill extraction (Phase 5 of this brainstorm should re-evaluate after 2–3 cycles of A+B+D in practice).
**Compatible with:** A+B+D — extracts after they stabilise.

### D. Transparency requirements in artefact shapes

Update the canonical artefact shapes so cross-model review state is mandatory:

- **Close-out** (`worker-agent.md` §"How to Report at a Gate"): new required section §"Pre-commit cross-model review" — names tool + version, round count, severity breakdown per round, final verdict, any deferred findings (with justification).
- **TL;DR chat-emit** (5-line format per `worker-agent.claude.md` + `worker-agent.codex.md`): one line `Cross-model review: <tool> <N rounds> → <CLEAN | findings deferred — see close-out>`.
- **Cycle retro** (`skills/lead-cycle-retro-template/SKILL.md` §"Review-role / gate value"): explicit sub-bullet for cross-model review trajectory across the cycle (per-dispatch round counts; total findings; which findings were genuine vs noise).
- **Lead-to-lead handoff** (cycle-close artefact): summary line "Review-loop trajectory this cycle: Phase X: N rounds; Phase Y: M rounds; ..."
- **Merge close-out** (`worker-agent.md` §"Mandatory worker merge close-out"): named line `Codex review: <N rounds> → CLEAN at commit <SHA>` so the merge-close-out's audit trail covers the review state.
- **Commit message body** (already de-facto Phase 1–4 pattern, e.g. Phase 2's "12 rounds of legitimate iteration"): formalize. Required for any commit produced from a dispatch with workflow profile ≥ standard.
- **Design memo** (Gate 1 artefact, when present): pre-declare the expected round budget; post-declare the actual; calibration delta feeds the retro.

**Pros:** transparency obligation is encoded in the artefact contracts the system already reads. No new artefact type needed.
**Cons:** N artefact shapes to update; each retro template / SKILL.md / playbook section needs a small edit.
**Compatible with:** A+B+C — the transparency requirements are what the principle / matrix / skill produce as output.

### E. Reviewer-agent baseline — consumes the worker's record, optionally runs baseline against a frozen diff ↻

`reviewer-agent.md` gains a §"Cross-model baseline" section. Rewritten per the read-only/no-execution contract that defines reviewer's role (verdict-focused, independent, never runs remediation loops):

> **Step 1 — Read the worker's record.** When a human reviewer is dispatched (standard / high-risk profile triggers from `lead-agent.md` §"reviewer-agent — Gate 2 security/compliance gate"), the reviewer reads the worker's close-out §"Pre-commit cross-model review" section FIRST. The record's round count, final verdict, and findings breakdown are the primary baseline signal. The reviewer does NOT re-run the worker's loop.
>
> **Step 2 — Optional reviewer baseline (read-only).** The reviewer MAY run an optional independent baseline pass *only against a frozen diff or commit range* (e.g., `codex review --commit <SHA>` against the merge-commit, or `codex review --base <prior-ref>` against a frozen base — `<SHA>..<SHA>` range syntax is not supported by codex-cli 0.134.0; the positional argument is the review prompt, not a range), NOT against the worker's mutable working tree. Reasons the baseline must run against a frozen surface:
> - Reviewer's contract is read-only / no-execution / no-network-fetch; running review on `--uncommitted` state (which mutates between iterations) implicitly couples the reviewer to the worker's remediation loop. That coupling violates the independent-verdict mandate.
> - The frozen diff/range is the artefact the reviewer's verdict will attach to. The baseline must read what the verdict covers, not what's still being edited.
>
> **Step 3 — Fallback when only mutable state exists.** If no frozen diff/range is available (worker's loop still in flight, no commit yet), the reviewer consumes the worker's record only and does NOT run a baseline at all. Verdict still issues per the standard severity-graded shape; the baseline column in the reviewer artefact is marked `not run — no frozen surface available`.
>
> **Step 4 — Verdict shape.** The reviewer's verdict carries a new §"Cross-model baseline" sub-section with: (a) worker pre-commit record reviewed (yes/no + cite path); (b) worker round count + final verdict; (c) reviewer baseline run (yes/no + tool + frozen range cited); (d) disagreements between reviewer's read and worker's findings (with rationale); (e) baseline findings promoted into the reviewer's severity-graded findings list. The reviewer's overall verdict (`block` / `accept with required fixes` / `accept with advisories` / `accept`) is the reviewer's own judgment, not Codex's.
>
> **Step 5 — Worker exempt (no record exists).** Rare residual edge case. **Primary disposition:** when a reviewer-trigger surface fires on a diff classified as `lightweight`, that is normally a profile-misclassification; the dispatching Lead should upgrade the profile to `standard` (which makes Gate 2.2 mandatory and renders this step moot) rather than dispatch a reviewer against a lightweight-classified diff. Step 5 covers the residual case where the Lead has judged caution-dispatch of the reviewer at lightweight to be appropriate (e.g., docs-only diff explaining an auth flow without changing it). When this case is real: the worker has been exempted from Gate 2.2 per the lightweight-diff exemption, there is no worker record to consume. The reviewer documents the exemption justification cited from the dispatch brief as `Worker pre-commit record: exempted — <one-line reason citing the exemption criterion>` and MAY run an optional baseline against the frozen range under the same Step-2 read-only constraints. If no frozen range is available either, fall through to Step 3.
>
> **Single sanctioned external operation.** The read-only cross-model review call against a frozen surface (`codex review --commit <SHA>` / `--base <prior-ref>`) is the one allowed exception to the reviewer's no-run / no-network contract — it analyses the frozen diff and returns findings without fetching external advisory data or mutating the codebase. Everything else in the no-run / no-network contract stands.
>
> **Failure modes (named in §7 below):** the baseline degrades the reviewer's contract if it (1) writes files, (2) executes code beyond the sanctioned cross-model review-model call itself, (3) fetches CVE / advisory / vendor data over the network during the baseline pass, or (4) reviews mutable remediation state. The single review-model call against the frozen surface is NOT a violation under (2) or (3) — it is the sanctioned exception. A reviewer that does any of (1)–(4) beyond that one call is no longer issuing an independent verdict.

**Pros:** preserves reviewer's read-only contract; cleanly separates worker's remediation authority from reviewer's verdict authority; covers both reviewer-dispatched and no-reviewer projects; reviewer baseline is genuinely supplementary signal, not a duplicate loop.
**Cons:** reviewer workflow adds one tool invocation upfront — still small. Baseline only runs against frozen surfaces, which slightly delays reviewer's pass relative to "review the diff continuously"; this is the right trade for contract integrity.
**Compatible with:** A+B+D — the reviewer-baseline row in §B's matrix maps directly to this section; transparency obligations in §6 carry the baseline sub-section in the reviewer's artefact.

---

## 4. Recommended path (A + B + D + E worker/reviewer-first, with C reserved; ~~PM and lead-owned loops deferred~~ — PM + lead load-bearing validation REVERSED-to-active 2026-05-29, see Amendment at top) ↻

**Phase A — Worker base + reviewer evidence contract + workflow-profile matrix.** Single combined dispatch (Worker #12 this cycle). Files:
- `worker-agent.md` — new §"Cross-model adversarial review before commit" (A's principle text, worker-authored loop, dual-invocation forbidden).
- `reviewer-agent.md` — new §"Cross-model baseline" section (E rewrite: consumes worker record; optional baseline against frozen diff/range only) + reviewer artefact contract update naming the new §"Cross-model baseline" sub-section.
- `README.md` — workflow-profile matrix update with Gate 2.2 (worker) + Gate 2.3 (reviewer) rows + new §"Cross-model review configuration" naming the cross-platform pairing rule.
- `lead-agent.md` — workflow-profile-matrix anchor (matrix lives in README; lead-agent.md gets a one-paragraph pointer + the iteration-cap scaling rule for STOP authority).

Estimated 2–4 Codex iteration rounds (cross-file consistency surface).

**Phase B — Worker + reviewer overlays (Claude + Codex tool bindings).** Files:
- `worker-agent.claude.md` — Bash binding for `codex review --uncommitted`; TL;DR format extension for cross-model review state.
- `worker-agent.codex.md` — `functions.exec_command` binding for cross-platform Claude review (when Codex is the author); TL;DR format extension.
- `reviewer-agent.claude.md` — Bash binding for the optional baseline pass against frozen ranges only; reviewer artefact §"Cross-model baseline" template.
- `reviewer-agent.codex.md` — symmetric cross-platform binding.

Estimated 2–3 rounds.

**Phase C — Transparency in retro / handoff / commit-message / close-out shapes.** Files:
- Close-out shape (in `worker-agent.md` §"How to Report at a Gate") — new required §"Pre-commit cross-model review" sub-section.
- Merge close-out shape (in `worker-agent.md` §"Mandatory worker merge close-out") — one-line addition naming review state at commit.
- `skills/lead-cycle-retro-template/SKILL.md` §"Review-role / gate value" sub-bullet structure.
- Lead-to-lead handoff template (in `lead-agent.md` §"Maintaining state across context windows") — new required §"Review trajectory across this cycle" section.
- Commit-message convention (documented in worker-agent.md + lead-agent.md).
- Design memo round-budget pre-declare / post-declare (Gate 1 artefact, when present).
- §6.1 log-path durability fix (this plan §6 update — see below).

Estimated 2–3 rounds.

**Deferred:** **— REVERSED 2026-05-29 (see Amendment at top); both items below are now active per the generalized principle. Retained for history.**
- **PM rollout** — master-plan-emit cross-model review. ~~No empirical anchor yet~~ → now active; the architect-verdict transcript supplied the anchor.
- **Lead-owned coordination-artefact review loop** — ~~bonus, not foundational~~ → now active for **load-bearing** coordination artefacts (risk-triage, master-plan-affecting handoffs, playbook/distillation edits — NOT routine task briefs).
- **Skill extraction (C from §3 above)** — only after 3+ cycles in production with stable procedure.

Each phase: own design plan delta (this file), own Gate 1 (operator green-light against the un-parked plan), own worker-side Codex Gate 2 (dogfooded), own commit. Phase A is the immediate work; Phase B and C dispatched as separate cycles after Phase A lands.

---

## 5. The cross-platform pairing rule (load-bearing) ↻

The single most important rule in this plan. Without it, the standardization degrades into theatre.

**Rule:** *the review tool MUST run a different MODEL than the diff author. Model-boundary is required; session-boundary is incidental.*

Why: a model cannot reliably review its own blind spots. The Phase 4 Round-1 P2 (false Claude-only assumption) was caught by Codex because the assumption was made BY a Claude (model) and Codex (model) was reading-as-stranger. Had Codex (model) made the same assumption in a Codex-authored skill and another Codex (model) session reviewed it, the same blind spot would propagate — both share priors, training distribution, default-framings. The shared-priors are the model's, not the session's.

**Empirical correction to the prior version of this section:** Phase 1–4 Codex review ran from the *same session* as the author in some cases (Phase 4 example: Lead #2 authored the skill edits AND ran `codex review --uncommitted` from the same Claude Code session). The protection was model-boundary (Claude author → Codex review-tool), not session-boundary. The original wording of this section claimed session-boundary was the protection; it was wrong. Sessions are an organisational unit; models are the read-as-stranger unit.

**Concrete pairings:**

- Worker is Claude Code → cross-review tool is Codex CLI (`codex review --uncommitted`). May run from the same Claude Code session as the worker; the Codex CLI invocation IS the model-boundary.
- Worker is Codex CLI → cross-review tool is Claude (the platform overlay names the binding; likely Claude Code via Bash, or claude.ai web review of a pasted diff). May run from the same Codex session.
- Worker is some other agent → at minimum, the review tool must be a different model family. Same-family different-checkpoint review is degraded — borderline acceptable for lightweight work, NOT acceptable for high-risk.

**Implementation:**

Each role overlay names the cross-review tool by name. Cannot be left as "use whatever cross-model review you have" — the discipline collapses to "no review" in practice.

When only one model is available (no cross-platform setup), the project gets an explicit note in `README.md` §"Cross-model review configuration". The fallback is **profile-tiered**: at `lightweight` a worker MAY record a documented-degraded same-model review (better than no-review for low-stakes diffs); at `standard` / `high-risk` same-model review does NOT satisfy the gate — the Lead must wire a second model before the gate clears OR accept the risk explicitly with acknowledgment in the gate close-out (Lead disposition). Single-model fallback is a known-degraded state, not the default.

**Anti-pattern (refined):** "I'll have the worker session run review of its own diff via the same model" — Claude reviewing Claude's diff, Codex reviewing Codex's diff. This is the same-priors trap. The protection is the model running the review must be DIFFERENT from the model that authored — regardless of whether the session is the same or different. The dual-invocation forbidden rule (see §7 below) is a separate concern: even when model-boundary is satisfied, only the AUTHOR runs the loop; downstream readers (lead, reviewer) do NOT re-run cross-model review on the same diff.

---

## 6. Transparency obligations — the operator-named dimension

The operator's framing: handoffs, TL;DRs, and similar summaries should also state how many review-loop rounds the work went through.

Concrete encoding:

### 6.1 In close-out's `Pre-commit cross-model review` section ↻

```markdown
## Pre-commit cross-model review

Tool: codex review --uncommitted --config model_reasoning_effort=xhigh
Tool version: codex-cli 0.134.0
Cross-model pairing: Claude Code (worker) → Codex (review)

Round-by-round:
- Round 1: 1 P2 — <one-line finding>. Fix: <one-line action>.
- Round 2: 1 P2 + 1 P3 — <one-line each>. Fix: <one-line>.
- Round 3: CLEAN.

Total findings: 3 (0 P1, 2 P2, 1 P3).
Final verdict: CLEAN at Round 3.
Deferred findings: none. (If any: list with rationale + parking-lot trigger.)
```

**Log durability — no ephemeral paths in the artefact body.** Earlier draft of this section included `Log: <path>` per round with `/tmp/...` style paths as examples. Removed: `/tmp/` paths evaporate; the close-out is supposed to be durable audit-trail. The round-by-round one-line finding + fix summary IS the durable record. If detailed logs are desired for retrospective forensics, commit them to `docs/cross-model-review-logs/<date>-<slug>/round-N.log` and cite that path — but the close-out body must remain readable without external log retrieval. Phase C will formalize this in `worker-agent.md` §"How to Report at a Gate".

### 6.2 In chat-emit TL;DR (5-line format, expanded to 6)

```
Worker close-out — <slug>
Commits: <SHA>
TL;DR (4 lines):
- <substantive line 1>
- <substantive line 2>
- <substantive line 3>
- Cross-model review: codex 3 rounds → CLEAN (1 P1 / 2 P2 / 1 P3 across rounds, all fixed inline)
```

### 6.3 In cycle retro §"Review-role / gate value"

Already exists in the Phase 4 `lead-cycle-retro-template` skill. Add explicit sub-bullet structure:

```markdown
## Review-role / gate value

- Architect (if dispatched): <verdict + cycle-load-bearing finding count>
- QA (if dispatched): <strategy fit + drift events>
- Reviewer (if dispatched): <verdict + findings count>
- Cross-model review trajectory:
  - <Phase / dispatch ID>: <N rounds> → <final verdict> (<findings breakdown>)
  - <Phase / dispatch ID>: <N rounds> → <final verdict> (<findings breakdown>)
  - Cumulative this cycle: <total rounds across all dispatches>, <total findings>, <% that were genuine vs noise>.
```

### 6.4 In lead-to-lead handoff (cycle close)

```markdown
## Review trajectory across this cycle

Cross-model review (codex `--uncommitted`):
- Dispatch A: 1 round → CLEAN
- Dispatch B: 3 rounds → CLEAN (1 P2, 1 P2 cascade, 1 P3)
- Total: 4 rounds, 3 findings, 0 deferred.

Human reviewer (when dispatched): <verdict trajectory or "none dispatched this cycle">.
```

### 6.5 In commit message body ↻

```
skills: Phase 4 — extract lead-cycle-retro-template + lead-risk-triage-consolidation

<body prose>

Pre-commit cross-model review:
- Tool: codex review --uncommitted --config model_reasoning_effort=xhigh (codex-cli 0.134.0)
- 3 rounds → CLEAN (1 P2, 1 P2 cascade, 1 P3, all fixed inline)
- Cross-model pairing: Claude Code (author) → Codex (reviewer)
- Detailed round logs (optional): docs/cross-model-review-logs/2026-05-27-phase4/round-{1,2,3}.log
```

The commit message format is the load-bearing record because it survives in git history when chat transcripts evaporate. Round logs are optional but, when included, MUST point at committed paths under `docs/cross-model-review-logs/` — not at `/tmp/` or other ephemeral locations.

### 6.6 In merge close-out (worker side)

```markdown
## Merge state

Branch: main
Commit: <SHA>
Tree: green
Cross-model review state at commit: codex 3 rounds → CLEAN.
```

### 6.7 In design memo (Gate 1 artefact, when present)

Pre-declare expected budget; post-declare actual; calibration delta feeds the retro. Already informally done in Phase 4 design memo's §"Gates" — formalize.

### 6.8 In reviewer-agent verdict — `## Cross-model baseline` sub-section

When the reviewer-agent has been dispatched (standard or high-risk profile), the verdict carries this sub-section. The shape mirrors the worker's record but reads, not runs:

```markdown
## Cross-model baseline

Worker pre-commit record: yes — see docs/closeouts/<date>-<worker>-to-<lead>-<slug>.md §"Pre-commit cross-model review".
Worker round count / final verdict: 3 rounds → CLEAN (1 P2, 1 P2 cascade, 1 P3, all fixed inline).
Reviewer baseline run: yes — `codex review --commit <SHA>` against the merge-commit (or `codex review --base <prior-ref>` against a frozen base). Tool: codex-cli 0.134.0.
Disagreements with worker's record: none (or list with rationale).
Baseline findings promoted into reviewer findings: <severity-graded list with cross-link to §"Findings" below>.
```

If `Reviewer baseline run: no — no frozen surface available`, the field documents the absence: reviewer consumes worker record only; verdict still issues at the standard severity-graded shape.

---

## 7. Edge cases / failure modes to design against ↻

1. **Same-model self-review (Codex-on-Codex, Claude-on-Claude)** — degraded; named anti-pattern in §5 (model-boundary rule). The principle text must explicitly forbid for high-risk; advisory-degraded for lightweight when no cross-model tool is available.

2. **Review-loop pre-occurs implementation** — author runs Codex on a half-finished diff to "validate direction." This is fine as advisory, but does NOT count toward the pre-commit gate. The pre-commit gate runs on the final diff before commit, not on intermediate states.

3. **Author dismisses findings as "noise"** — every finding must be addressed-or-deferred in writing. "Disagreed and ignored" is a deferred finding that goes in the close-out's deferred section with rationale. Codex findings have low noise rate per Phase 1–4 (1 false positive across ~18 rounds), but the discipline of writing rationale catches genuine noise vs author-rationalization.

4. **Iteration cap escape** — see §11.4 below for profile-scaled cap. STOP and write a WIP-handoff per `lead-agent.md` §"WIP-handoff..." when cap is hit without convergence. Dispatch becomes an operator-decision (continue with smaller scope, re-scope, or hand to human reviewer).

5. **Cost runaway** — Codex CLI is metered. Per-dispatch budget mirrors the iteration cap (§11.4). Cost overrun = signal that workflow-profile was mis-set, not that the gate is wrong.

6. **Reviewer trusts worker's CLEAN record too much** — worker's CLEAN does NOT prove correctness; it proves no Codex-visible findings in worker's loop. Human reviewer (when dispatched) MUST still produce its own verdict; reading the worker's record is Step 1, not the verdict (see §3.E).

7. **Code path Codex can't see** — Codex reviews diff; it doesn't run tests, hit production endpoints, or load runtime state. CLEAN at Codex does NOT mean Gate 3 (integration smoke) is skipped. The two gates compose.

8. **Stale review** — author addresses findings, makes additional changes, but doesn't re-run Codex. The "iterate until CLEAN" rule means the LAST Codex run must be on the FINAL pre-commit diff, not an earlier state. Mechanism: workflow-profile matrix says "re-run Codex on any change after the prior CLEAN."

9. **Transparency dilution** — author writes "Codex 3 rounds → CLEAN" without listing the findings. The format in §6 above is non-optional; "round count without finding-breakdown" defeats the audit-trail purpose. The dispatch's close-out reviewer (lead or the operator) reads the breakdown and decides whether the findings were substantive.

10. **Project without configured Codex CLI** — the discipline degrades to advisory until cross-model review is wired. Project bootstrap (README) names the cross-model review tool explicitly; absent the line, single-model fallback is the known-degraded state.

11. **Reviewer baseline contract violation** — the reviewer-agent's read-only/no-execution contract carves out exactly one sanctioned external operation: the read-only cross-model review-model call against a frozen surface (`codex review --commit <SHA>` / `--base <prior-ref>`), which analyses the frozen diff and returns findings without fetching external advisory data or mutating the codebase. The contract is breached when the baseline run goes beyond that one call: (1) writes files anywhere on the filesystem (other than its own verdict artefact at `docs/code-reviews/`), (2) executes code beyond the sanctioned review-model call itself (test runs, builds, live-instrumentation), (3) fetches CVE / advisory / vendor data over the network during the baseline pass, or (4) reviews mutable remediation state (`--uncommitted` against a still-iterating working tree). A reviewer that does any of (1)–(4) beyond the sanctioned call is no longer issuing an independent verdict — it has coupled into the worker's remediation loop. The reviewer-agent.md update in Phase A names these four as hard failure modes of the baseline alongside the single-sanctioned-operation carve-out; the platform overlays MUST bind the reviewer's tool to that read-only invocation against a frozen range and nothing more.

12. **Dual-invocation of cross-model review on the same diff** — anti-pattern where two roles run Codex review on the same content (e.g., worker runs `--uncommitted` then lead re-runs `codex review <SHA>` on worker's commit, or reviewer re-runs the worker's loop). Forbidden: only the AUTHOR runs the remediation loop. Downstream roles consume the worker's record (lead reads the close-out's §"Pre-commit cross-model review"; reviewer reads same + optionally runs an INDEPENDENT baseline against a frozen range per §3.E — that baseline is a verdict-input, not a re-run of the worker's loop). Doubles cost without doubling signal; corrupts authority partition.

---

## 8. Surfaces touched (when the plan executes) ↻

Concrete edit list per the Phase A/B/C reshape. Phase A is the immediate dispatch; B and C are follow-up cycles.

### Phase A (this dispatch — Worker #12)

| Surface | Edit class | Estimated size |
| --- | --- | --- |
| `worker-agent.md` | New section §"Cross-model adversarial review before commit" + dual-invocation forbidden rule | ~35 lines |
| `reviewer-agent.md` | New §"Cross-model baseline" section (E rewrite: consumes worker record; optional baseline against frozen diff only) + reviewer-artefact contract update naming §"Cross-model baseline" sub-section + 4 failure modes named | ~30 lines |
| `README.md` | §"Workflow profiles" matrix update (Gate 2.2 worker + Gate 2.3 reviewer rows) + new §"Cross-model review configuration" naming cross-platform pairing rule | ~20 lines |
| `lead-agent.md` | Workflow-profile-matrix anchor (one-paragraph pointer at README matrix) + iteration-cap scaling rule | ~8 lines |
| `docs/codex-review-standardization.md` (this file) | Already updated by Lead this session | n/a — Lead-side |

**Phase A subtotal:** ~95 lines across 4 files (plus this design plan). Workflow profile: **standard**.

### Phase B (follow-up cycle — overlay bindings)

| Surface | Edit class | Estimated size |
| --- | --- | --- |
| `worker-agent.claude.md` | Bash tool binding for `codex review --uncommitted` + TL;DR format extension | ~10 lines |
| `worker-agent.codex.md` | `functions.exec_command` binding for cross-platform Claude review + TL;DR format extension | ~10 lines |
| `reviewer-agent.claude.md` | Bash binding for optional baseline pass against frozen ranges only + verdict §"Cross-model baseline" template | ~10 lines |
| `reviewer-agent.codex.md` | Symmetric cross-platform binding | ~10 lines |

**Phase B subtotal:** ~40 lines across 4 files. Workflow profile: **standard**.

### Phase C (follow-up cycle — transparency in retro / handoff / commit-message / close-out shapes)

| Surface | Edit class | Estimated size |
| --- | --- | --- |
| Close-out shape (in `worker-agent.md` §"How to Report at a Gate") | New required §"Pre-commit cross-model review" sub-section | ~12 lines |
| Merge close-out shape (in `worker-agent.md` §"Mandatory worker merge close-out") | One-line addition + log-path convention | ~3 lines |
| `skills/lead-cycle-retro-template/SKILL.md` | §"Review-role / gate value" sub-bullet expansion | ~5 lines |
| Lead-to-lead handoff template (in `lead-agent.md` §"Maintaining state across context windows") | New required §"Review trajectory across this cycle" section | ~8 lines |
| Commit-message convention (documented in `worker-agent.md` + `lead-agent.md`) | Naming the cross-model review block | ~10 lines |
| Design-memo round-budget pre-declare/post-declare convention (in `lead-agent.md` §"Workflow profile selection") | Sub-bullet | ~5 lines |
| `docs/cross-model-review-logs/` directory + `.gitkeep` | New directory for optional durable round logs | n/a |

**Phase C subtotal:** ~45 lines across ~5 files. Workflow profile: **standard**.

### Deferred (post-cycle, no dispatch this rollout)

| Surface | Edit class | Reason |
| --- | --- | --- |
| `pm-agent.md` + `pm-agent.{claude,codex}.md` | PM master-plan-emit cross-model review | **REVERSED 2026-05-29 (Amendment at top) — now active; architect-verdict transcript is the anchor** |
| `lead-agent.md` lead-owned coordination-artefact review loop | Lead-side loop on load-bearing coordination artefacts | **REVERSED 2026-05-29 — now active for load-bearing artefacts (risk-triage, master-plan-affecting handoffs, playbook/distillation edits); routine task briefs excluded** |
| Skill extraction (`pre-commit-patterns` or similar) | Procedure → SKILL.md | Only after 3+ cycles in production with stable procedure |

**Total in-scope this rollout:** ~180 lines across ~13 files in Phases A+B+C. Comparable in size to Phase 2 (~286 lines) and larger than Phase 4 (~40 lines). Phase A is sized for one worker in one session; Phase B and C dispatched in subsequent cycles.

---

## 9. Composition with existing playbooks (compatibility check)

This plan must not break anything the four landed Phase 1–4 skills + the existing playbooks already do.

- **`coordination-wip-handoff` skill:** unchanged. WIP-handoffs are mid-stream STOP artefacts; cross-model review of a WIP-handoff body is low-signal (the body is state, not contract). Adding cross-model review to WIP-handoff emission would slow STOP for low gain. **Resume-session covering:** the Codex review applies to the *resume session's* final commit, and that final commit must cover BOTH the resumed-work diff AND any cleanup of the WIP-state (uncommitted scratch, half-finished test fixtures, dropped probe directories). The resume-session worker explicitly stages both surfaces before running `codex review --uncommitted`; the close-out's §"Pre-commit cross-model review" cites both the resumed scope and the WIP-cleanup as covered. WIP-handoff itself is NOT reviewed; the resume-session's final pre-commit diff IS.
- **`structural-refactor-verification` skill:** unchanged. Refactor verification is worker-side audit; cross-model review at commit time still runs *on top of* the worker's verification claim. Compose: verification audit ✓ + cross-model review ✓ → commit.
- **`verification-patterns` skill:** unchanged. Schema-CHECK audit is observability data; cross-model review of the close-out (which carries the matrix) still applies.
- **`lead-cycle-retro-template` skill:** ALMOST unchanged. §"Review-role / gate value" gains the sub-bullet structure named in §6.3 above. Backward-compatible extension; no breaking change to template shape.
- **`lead-risk-triage-consolidation` skill:** ~~unchanged; cross-model review of the triage prose is low-signal~~ **→ superseded 2026-05-29 (Amendment at top): a risk-triage consolidation IS a load-bearing coordination artefact and now gets cross-model validation per `lead-agent.md` §"Cross-model validation of load-bearing output" before it reaches the operator.**
- **Workflow profiles (lightweight / standard / high-risk):** EXTENDED. Lightweight stays optional; standard becomes mandatory-default; high-risk becomes mandatory with reviewer-supplement. No profile is removed or renamed.
- **Authority rhythms (A / B / C):** UNCHANGED. Cross-model review fires before the rhythm's commit step in all three cases. Under A, review runs at close-out and feeds the user's green-light. Under B, review runs continuously per commit cluster. Under C, review runs in the cycle-batch.
- **Review-role dispatch (architect / qa / reviewer):** ~~UNCHANGED for architect + qa~~ **(superseded 2026-05-29 — see Amendment at top: architect + qa now run cross-model validation on their load-bearing output)**; reviewer-agent gets the §"Cross-model review as baseline" supplement per E.

Net: no existing artefact contract breaks. Some get small additions; many are unaffected.

---

## 10. Cost / value calibration

**Cost per dispatch (rough):**
- Codex CLI invocation: ~$0.20 – $1.00 per round depending on diff size + reasoning effort.
- Wall-clock: ~2–8 minutes per round (Phase 4 rounds averaged ~3 min).
- Human-attention cost: ~10–20 seconds per round for the author to read findings + decide action.

**Value per dispatch (empirical from Phase 1–4):**
- Catches integrity failures that escape human re-read (Phase 4 Round 1, Phase 1 Round 1).
- Catches authority-distinction errors (Phase 2 Round 1).
- Catches stale state in long memos / artefacts (Phase 4 Round 2 P3).
- Caps the discipline-decay surface for solo-developer work: the only-other-agent-on-the-team becomes a forcing function for "would I be embarrassed if this got reviewed?"

**Net:** cost is small per dispatch; value is high per finding caught. Pareto-shape — most findings cluster in early rounds; CLEAN convergence is fast for well-shaped diffs. Phase 2's 12 rounds was an outlier because the authority distinction was genuinely subtle, not because Codex was noisy.

---

## 11. Resolved / remaining questions at un-park ↻

### 11.1 ~~PM master-plan emit — does it warrant cross-model review?~~ → ~~DEFERRED~~ REVERSED 2026-05-29 (active)

~~Deferred per §4 reshape.~~ **Reversed 2026-05-29 (see Amendment at top).** PM now runs cross-model validation on its load-bearing master plan / scope-discovery handoff (`pm-agent.md` §"Cross-model validation of load-bearing output"). The original deferral cited "no empirical anchor"; the architect-verdict transcript is the anchor, and the structural symmetry (any load-bearing output carries the same propagated-defect risk) generalizes it to the PM's plan.

### 11.2 Parallel-worker aggregation (unchanged from prior draft)

When two workers run concurrently on disjoint scopes, run cross-model review per-worker first (catches per-worker issues), then merged-diff if scopes intersect non-trivially. Phase A's choice to run a single worker (Worker #12) sidesteps this for the immediate rollout; revisit when Phase B introduces parallel overlay edits.

### 11.3 Cross-platform pairing in solo-developer projects (unchanged)

When the only available "other model" is the same provider's smaller variant: profile-tiered per §5 — a documented-degraded fallback at lightweight; at standard / high-risk it does NOT satisfy the gate without Lead disposition (wire a second model, or accept the risk with explicit acknowledgment). Project README names the trade-off (per §5 rule + §"Cross-model review configuration" in README addition).

### 11.4 Iteration cap calibration → RESOLVED (scales by workflow profile)

| Profile | Iteration cap | Rationale |
| --- | --- | --- |
| Lightweight | 3 rounds | Small diffs rarely need >2 rounds (Phase 1 evidence: 1 round; Phase 3: 2 rounds). Cap at 3 covers Phase-1-shaped work plus one safety margin. |
| Standard | 8 rounds | Mid-complexity diffs converge in 3–5 rounds typically (Phase 4: 3; Phase 3 covering audit: 2). 8 rounds covers 2× the typical convergence point. |
| High-risk | 12 rounds | Phase 2 took 12 rounds and stayed productive throughout (P1 finding emerged late). 12 is the current empirical floor for "still productive." Beyond 12, the dispatch shape is degraded — STOP + WIP-handoff + the operator decision. |

Empirical anchor: Phase 1–4 evidence (Phase 1 = 1 round; Phase 2 = 12; Phase 3 = 2; Phase 4 = 3). Cap STOP behavior: WIP-handoff per `lead-agent.md` §"WIP-handoff..." names cap-hit as a structural blocker; resume-session continues under same or revised profile per the operator decision.

### 11.5 Anthropic-side review of Codex work (unchanged)

Symmetrical to current Claude-authoring-Codex-reviewing pattern. Tool binding TBD; investigate Claude Code's CLI invocation options for cross-model review of a Codex-authored diff. Phase B overlay binding for `worker-agent.codex.md` will name the concrete tool.

### 11.6 Transparency-format brittleness (unchanged)

Per §3.C, deferred until 2–3 cycles of empirical use; skill extraction only when procedure is stable.

---

## 12. Un-park trigger history (retained for audit trail)

Triggers documented at parking-time (2026-05-27):
- (a) Next skill-extraction or playbook-distillation cycle reaches dispatch shape.
- (b) A regression lands on `origin/main` that a Codex pre-commit review would have caught.
- (c) the operator explicitly lifts the parking lot at session start.
- (d) Two consecutive cycles ship without invoking Codex review at all.

**Trigger fired:** (c) on 2026-05-28 at Lead #4 session start. Un-park executed by Lead #4 with this plan rewrite. Section retained for cross-handoff factual continuity per `lead-agent.md` principle #6.

---

## 13. Not in scope for this plan

- **Automating the loop** (Codex runs, fixes are auto-applied, re-runs). The human-in-the-loop step is where author judgment lands; automating it removes the discipline value. The standardization is about WHEN and HOW to invoke, not about removing human judgment.
- **Replacing human reviewer-agent dispatch.** Cross-model review supplements; it does not substitute when the reviewer-agent's compliance / security / regulatory scope applies. See E.
- **Cross-model review of dialogue / chat / brainstorm phases.** This plan is about pre-commit review of contract / code / playbook artefacts. Conversational scoping (PM Phases 0–4, lead-worker bounded dialogue) is excluded.
- **Project-bootstrap automation.** Wiring `codex` to a fresh project's `bin/start-agent.sh` is a separate dispatch; this plan assumes the tool is already on PATH.
- **Multi-model review (more than two models)** — interesting but speculative; defer until two-model pattern has empirical anchor across 5+ cycles.

---

## 14. Dispatch shape (un-parked — Phase A is the immediate dispatch) ↻

**Phase A (immediate — Worker #12 in worktree `codex-rollout`).** Worker base + reviewer evidence contract + workflow-profile matrix. Files: worker-agent.md (principle + dual-invocation rule), reviewer-agent.md (baseline section + reviewer artefact contract + 4 failure modes), README.md (matrix + cross-model configuration), lead-agent.md (matrix anchor + iteration-cap scaling). Workflow profile: standard. Codex iteration cap: 8 rounds (worker dogfoods the new principle on its own diff). Expected: 2–4 rounds.

**Phase B (follow-up cycle — separate dispatch after Phase A lands).** Worker + reviewer overlays (Claude + Codex). Estimated 2–3 rounds.

**Phase C (follow-up cycle — separate dispatch after Phase B lands).** Transparency in retro / handoff / commit-message / close-out shapes + log-path durability formalisation. Estimated 2–3 rounds.

**Phase D (deferred — post-3+-cycles).** Skill extraction (C from §3) only after procedure is stable.

~~**Indefinitely deferred (no current trigger):** PM master-plan-emit cross-model review; lead-owned coordination-artefact review loop. Both re-evaluate after Phase A/B/C land with empirical anchor data.~~ **Reversed 2026-05-29 (see Amendment at top).** Both PM master-plan-emit and lead load-bearing coordination-artefact cross-model validation are now active per the generalized principle (`README.md` §"Cross-model review configuration"); the architect-verdict transcript supplied the empirical anchor.

Each phase: own design plan delta (this file), own Gate 1 (operator green-light), own worker-side Codex Gate 2 (dogfooded), own commit. Phase A this cycle; B and C in subsequent cycles.

---

## End of plan

Un-parked 2026-05-28 by Lead #4. Worker #12 executes Phase A against this spec in worktree `codex-rollout`. Worker #13 (separate Lead's session) operates on a separate branch extracting role-playbook sections into skills; branch isolation handles disjoint-by-construction. Worker #12 lands first to main per the operator sequencing; Worker #13 rebases onto landed state.
