# PM Distillation — Runtime Template

> Self-contained runtime template. Copy this file, substitute the `{{PLACEHOLDERS}}` for one specific distillation round, and use the resulting prompt body as the actual prompt sent to a fresh PM session.
>
> For the time-invariant patterns behind these instructions (why this shape, why these principles), see `playbook-distillation-methodology.md` in this directory. The template inlines what the prompt needs to stand alone; the methodology file is for human reference.

---

## How to use this template

1. Copy this file to a working location (e.g., `/tmp/pm-distillation-<date>.md`).
2. Substitute every `{{PLACEHOLDER}}` with the values for *this* round (see "Placeholders" below).
3. Verify that no `{{` remains in the body.
4. Paste "The prompt body" section verbatim into a fresh PM session.
5. The PM produces the four files in `{{PLAYBOOKS_DIR}}`. The user reviews and saves.

---

## Placeholders

Substitute each before paste.

**Identifiers:**
- `{{PROJECT_NAME}}` — e.g., `Synapse`, `Atlas`, `Phoenix`.
- `{{PLAYBOOKS_DIR}}` — absolute path to the directory holding the four playbooks, e.g., `~/Synapse/playbooks/`.
- `{{HARNESS}}` — the harness suffix in use, e.g., `claude`.
- `{{PREV_VERSION}}` — version-string of the previous distillation, e.g., `v0.1`.
- `{{NEW_VERSION}}` — version-string for this round, e.g., `v0.2`.
- `{{DISTILLATION_DATE}}` — ISO date, e.g., `2026-08-15`.

**Empirical ground truth:**
- `{{MASTER_PLAN_PATHS}}` — comma-separated absolute paths to master plans emitted since the previous distillation. The PM reads these before drafting — they are the empirical record of scoping engagements run through this playbook.
- `{{HANDOFF_PATHS}}` — comma-separated absolute paths to PM-to-lead handoff documents from the same period. These capture how the PM's output was received and where it required follow-up.
- `{{KEY_ENGAGEMENTS}}` — comma-separated short names for specific scoping engagements worth case-studying (e.g., `Synapse-MVP scoping, Atlas-rewrite premise-challenge cycle`).

**Patterns to re-examine** (schema below):
- `{{PRINCIPLES_TO_REEXAMINE}}` — block of structured entries, one per principle from `{{PREV_VERSION}}` that warrants explicit re-examination.

**Patterns for elevation** (schema below):
- `{{NEW_PATTERNS}}` — block of structured entries, one per empirically validated pattern that may deserve becoming a named principle in `{{NEW_VERSION}}`.

**Project context:**
- `{{LANGUAGE_NOTES}}` — project-specific user-PM language conventions.
- `{{SCOPING_QUIRKS}}` — comma-separated short names for project-shape-specific scoping patterns discovered this round (e.g., `regulatory-deadline phasing, multi-stakeholder premise-challenge`).

---

## Schema for `{{PRINCIPLES_TO_REEXAMINE}}` and `{{NEW_PATTERNS}}`

Each entry follows this exact shape. Free-form prose is explicitly disallowed.

```
### Principle: <name>
**Status:** kept | refined | demoted | dropped | new
**Empirical instances since last version:** <count>
- <1-line instance description>
- <1-line instance description>
- ...
**Reasoning:** <1-2 sentences why this status, given the instances above>
```

Notes:

- `**Status:**` must be exactly one of the five labels.
- `**Empirical instances since last version:**` must include the count, then the bulleted instances. If count is 0, the principle is a candidate for `demoted` or `dropped`.
- `**Reasoning:**` is hard-capped at 2 sentences.
- For `{{NEW_PATTERNS}}` entries, `**Status:** new` and the instances explain why this pattern is ready for elevation.

---

## The prompt body

Substitute `{{PLACEHOLDERS}}` before sending. Everything between the dashes is the actual prompt.

---

PLAYBOOK DISTILLATION TASK — PM, {{NEW_VERSION}}

You are entering a fresh PM session to distil the pm-agent playbooks from `{{PREV_VERSION}}` to `{{NEW_VERSION}}` based on accumulated experience on project `{{PROJECT_NAME}}`.

## Deliverables

Produce or update the role's playbook surfaces in `{{PLAYBOOKS_DIR}}`:

1. `pm-agent.md` — the base playbook, project-agnostic, {{NEW_VERSION}}.
2. `pm-agent.{{HARNESS}}.md` — harness overlay, {{NEW_VERSION}}.

(A deployment that maintains project-specific forks of these playbooks updates them downstream from
the base; this repository carries no `*.generalized.md` twins — the base file IS the generalized set.)

Each file's top must carry:

```
# <Title>

> Version: **<version>** (project-specific | project-agnostic, <scope>).
> Distilled: {{DISTILLATION_DATE}} <one-sentence trigger description>.
>
> Changes from <previous>:
> - <bulleted, concrete change>
> - ...
```

## Context to draw from

1. The current playbooks at `{{PLAYBOOKS_DIR}}`. Read them first; understand what's already encoded before adding.
2. Empirical ground truth in `{{MASTER_PLAN_PATHS}}` and `{{HANDOFF_PATHS}}`. The master plans are the artefacts the PM produced; the handoffs are the bridge to the lead. Read both before drafting.
3. Key engagements worth case-studying: {{KEY_ENGAGEMENTS}}. For each, identify what underlying pattern the engagement represents — premise-challenge failure modes, problem-vs-solution drift, scope-creep parking discipline, phasing patterns that worked vs broke.
4. Scoping quirks worth encoding: {{SCOPING_QUIRKS}}. These belong in a deployment's project-specific fork, not in the project-agnostic base.
5. User pushback during scoping. Did the user redirect, reframe, or refuse? Each redirect is a signal the playbook should reflect.
6. Cases where the master plan held under execution vs cases where the lead had to push scope changes back to the PM. The latter are calibration data for phasing discipline.

## Distillation principles

1. **Add only what's empirically validated.** A new principle needs a concrete scoping engagement showing why. No speculative "could happen" warnings.
2. **Sharpen with concrete examples.** Each principle should have at least one named example — a project, a premise-challenge sequence, a parked item that re-activated correctly.
3. **Remove or merge what didn't recur.** If a principle from `{{PREV_VERSION}}` never came into play, consider whether it should stay. Playbook bloat is a failure mode.
4. **Format consistency.** Base playbooks are direct system-prompt style (2nd person, prescriptive). Harness overlays are hybrid (definitions + behavioural instructions + harness-specific operational notes) and never duplicate the base content — only extend it.
5. **The playbooks stay project-agnostic — strip every project-specific reference.** Project names, stakeholder names, framework names. Cross-project patterns stay.
6. **Honest version header.** Version + date + changes-from-previous, in that order, at the top of every file.

## Pre-write grounding exercise

Before drafting any file content, list for your own grounding:

- 5-10 things you did consistently during scoping that the user validated as correct (the pushback that landed, the premise-challenges that survived, the parked items that earned their parking).
- 3-5 mistakes you made — places where the user had to re-direct, where a premise survived too easily and the project later mis-targeted, where scope crept silently into the master plan.
- 3-5 patterns you saw in the engagement that surprised you — about the user's domain, about typical scoping shapes, about where master plans typically falter.
- Any user prompts that taught you something the previous playbook version didn't yet capture.

This list is for grounding only. It does not appear in the output files.

## Retrospective failure-class extraction

The PM's failure modes are quiet — a wrong-target project ships and only reveals the scoping defect months later. Distillation must reconstruct what would have been captured.

Process:

1. Scan the master plans and handoffs for moments where a scoping discipline gap was warranted but not formally captured.
2. Identify the underlying pattern (not the instance).
3. Encode the pattern in `{{NEW_VERSION}}`.

Canonical case studies: a premise that survived challenge but turned out to be a symptom of something deeper; a phase that bundled too much and shipped late; a parked item without a trigger that silently corrupted the plan; a tech-stack choice that locked too early.

## Principles to re-examine this round

{{PRINCIPLES_TO_REEXAMINE}}

For each entry above:

- If status is `kept`: confirm the principle still holds; light edit for clarity if needed.
- If status is `refined`: rewrite the principle text with the refinement informed by the new instances.
- If status is `demoted`: move the principle from a top-level section to a less prominent location.
- If status is `dropped`: remove the principle. State explicitly in the changes-from-previous block that the principle was dropped and why.

## New patterns that may deserve elevation

{{NEW_PATTERNS}}

For each entry above:

- If the empirical instances support elevation: introduce the principle as a new top-level section in the relevant files. Keep the phrasing project-agnostic.
- If the instances are insufficient: do not elevate; flag in the post-write reflection that the pattern was considered but deferred.

## Language notes for this project

{{LANGUAGE_NOTES}}

## Anti-patterns to avoid

- Cheerleader tone ("you're a brilliant senior PM").
- Vague principles ("be thoughtful").
- Long lists of hypothetical situations.
- Cross-contamination between base and harness files.
- Project-specific examples in the playbooks.
- Treating an engagement's master plan as the empirical anchor by itself — the load-bearing evidence is the *delta* between the master plan and what actually shipped (or didn't).

## Uncertainty handling

If unsure:

- Whether a new pattern is validated enough → surface as open question before finalising.
- Whether a previous-version principle should stay → propose keep vs drop and ask. Default is drop if not invoked since last distillation.
- Whether two principles overlap → propose a consolidation explicitly; let the user decide.
- Whether scope is right (narrow vs broad) → state both phrasings and ask which.

Open questions land at the bottom of the deliverable, numbered, with your recommendation per question.

## Post-write reflection

After writing the four files, surface metanotes about the distillation process itself:

- What was hard to articulate?
- Which patterns felt obvious in retrospect but weren't captured before?
- Were previous-version principles redundant with each other, or reducible to a more fundamental one?
- What in this runtime template or the underlying methodology made the distillation easier or harder?

These metanotes feed the next iteration of:

- This runtime template (if the observation is per-instance).
- The methodology file at `{{PLAYBOOKS_DIR}}/distillation-prompts/playbook-distillation-methodology.md` (if the observation is time-invariant).

A distillation without post-write reflection is incomplete.

---
