# Worker Distillation — Runtime Template

> Self-contained runtime template. Copy this file, substitute the `{{PLACEHOLDERS}}` for one specific distillation round, and use the resulting prompt body as the actual prompt the lead sends to a fresh worker session.
>
> For the time-invariant patterns behind these instructions (why this shape, why these principles), see `playbook-distillation-methodology.md` in this directory. The template inlines what the prompt needs to stand alone; the methodology file is for human reference.
>
> Last revised: 2026-05-11.

---

## How to use this template

1. Copy this file to a working location (e.g., `/tmp/worker-distillation-<date>.md`).
2. Substitute every `{{PLACEHOLDER}}` with the values for *this* round (see "Placeholders" below).
3. Verify that no `{{` remains in the body (sanity check that all placeholders were filled).
4. Lead pastes "The prompt body" section verbatim into a fresh worker session.
5. The worker produces the four files in `{{PLAYBOOKS_DIR}}`. Lead reviews; user saves.

---

## Placeholders

Substitute each before paste.

**Identifiers:**
- `{{PROJECT_NAME}}` — e.g., `Synapse`, `Atlas`, `Phoenix`.
- `{{PLAYBOOKS_DIR}}` — absolute path to the directory holding the four playbooks, e.g., `~/Synapse/playbooks/`.
- `{{HARNESS}}` — the harness suffix in use, e.g., `claude`.
- `{{PREV_VERSION}}` — version-string of the previous distillation, e.g., `v0.3 / v0.2`.
- `{{NEW_VERSION}}` — version-string for this round, e.g., `v0.4`.
- `{{DISTILLATION_DATE}}` — ISO date, e.g., `2026-05-11`.

**Empirical ground truth:**
- `{{HANDOFF_PATHS}}` — comma-separated absolute paths to handoff documents that captured what happened since the previous distillation. The worker reads these before drafting.
- `{{KEY_INCIDENTS}}` — comma-separated short names for specific steps, sequences, or incidents worth case-studying in this round (e.g., `Step 10 three-regression sequence, Phase B Step 0 sync-perf misread`).

**Patterns to re-examine** (schema below):
- `{{PRINCIPLES_TO_REEXAMINE}}` — block of structured entries, one per principle from `{{PREV_VERSION}}` that warrants explicit re-examination.

**Patterns for elevation** (schema below):
- `{{NEW_PATTERNS}}` — block of structured entries, one per empirically validated pattern that may deserve becoming a named principle in `{{NEW_VERSION}}`.

**Tooling and project context:**
- `{{TOOLING_QUIRKS}}` — comma-separated short names for harness or stack-specific quirks discovered this round (e.g., `transformation-script harness-visibility, EADDRINUSE on running concurrently process`). These belong primarily in the harness overlay variants.
- `{{LANGUAGE_NOTES}}` — project-specific worker↔lead and worker↔artifacts language conventions.

---

## Schema for `{{PRINCIPLES_TO_REEXAMINE}}` and `{{NEW_PATTERNS}}`

Each entry follows this exact shape. Free-form prose is explicitly disallowed — it has been observed collapsing into duplicated long-form passages across past distillation rounds, which is why this schema exists.

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

- `**Status:**` must be exactly one of the five labels. No other status words.
- `**Empirical instances since last version:**` must include the count, then the bulleted instances. If count is 0, the principle is a candidate for `demoted` or `dropped`.
- `**Reasoning:**` is hard-capped at 2 sentences. If you need more, the schema is wrong for that entry — surface as an open question instead.
- For `{{NEW_PATTERNS}}` entries, `**Status:** new` and the instances explain why this pattern is ready for elevation.

---

## The prompt body

Substitute `{{PLACEHOLDERS}}` before sending. Everything between the dashes is the actual prompt.

---

PLAYBOOK DISTILLATION TASK — WORKER, {{NEW_VERSION}}

You are entering a fresh worker session to distil the worker-agent playbooks from `{{PREV_VERSION}}` to `{{NEW_VERSION}}` based on your accumulated experience on project `{{PROJECT_NAME}}`.

## Deliverables

Produce or update the role's playbook surfaces in `{{PLAYBOOKS_DIR}}`:

1. `worker-agent.md` — the base playbook, project-agnostic, {{NEW_VERSION}}.
2. `worker-agent.{{HARNESS}}.md` — harness overlay, {{NEW_VERSION}}.

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
2. Empirical ground truth in `{{HANDOFF_PATHS}}`. These capture what happened since the previous distillation — read them before drafting.
3. Key incidents worth case-studying: {{KEY_INCIDENTS}}. For each, identify what underlying pattern the incident represents and whether it belongs as a new principle, an example for an existing principle, or stays out of the playbook entirely.
4. Tooling quirks worth encoding: {{TOOLING_QUIRKS}}. These primarily belong in the harness overlay variants.
5. Lead prompts to you over time. Did the lead's prompts evolve to add precision? That's a signal the playbook should reflect what the prompts taught.
6. Cases where you stopped autonomously vs. proceeded vs. got it wrong. The threshold for "stop and ask" should sharpen with each iteration.

## Distillation principles

1. **Add only what's empirically validated.** A new principle needs a concrete instance from this project showing why. No speculative "could happen" warnings.
2. **Sharpen with concrete examples.** Each principle should have at least one named example — a step, a sequence, a bug class.
3. **Remove or merge what didn't recur.** If a principle from `{{PREV_VERSION}}` never came into play, consider whether it should stay. Playbook bloat is a failure mode.
4. **Format consistency.** Base playbooks are direct system-prompt style (2nd person, prescriptive). Harness overlays are hybrid (definitions + behavioural instructions + harness-specific operational notes) and never duplicate the base content — only extend it.
5. **The playbooks stay project-agnostic — strip every project-specific reference.** File layouts, language-specific tooling, project conventions, named persons, named systems, named steps. Cross-project patterns stay.
6. **Honest version header.** Version + date + changes-from-previous, in that order, at the top of every file. The changes block is concrete.

## Pre-write grounding exercise

Before drafting any file content, list for your own grounding:

- 5-10 things you did consistently that the lead's reviews validated as correct.
- 3-5 mistakes you made and how you corrected them.
- 3-5 patterns you saw in the codebase or tooling that surprised you.
- Any prompts from the lead that taught you something the previous playbook version didn't yet capture.

This list is for grounding only. It does not appear in the output files.

## Retrospective failure-class extraction

In normal operation, the worker surfaces method observations as failure-class patterns in gate reports. When the convention drifts (observations buried in commit messages or normal prose), distillation must reconstruct what would have been captured.

Process:

1. Scan the session history for moments where a method observation was warranted but not formally captured.
2. Identify the underlying pattern (not the instance).
3. Encode the pattern in `{{NEW_VERSION}}`.

The canonical case study is a regression sequence where multiple successive bugs share an underlying methodology gap. Extract the gap, not the bugs.

## Principles to re-examine this round

{{PRINCIPLES_TO_REEXAMINE}}

For each entry above:

- If status is `kept`: confirm the principle still holds; light edit for clarity if needed.
- If status is `refined`: rewrite the principle text with the refinement informed by the new instances.
- If status is `demoted`: move the principle from a top-level section to a less prominent location (e.g., a paragraph inside a related section), or merge into a more general principle.
- If status is `dropped`: remove the principle. State explicitly in the changes-from-previous block that the principle was dropped and why.

## New patterns that may deserve elevation

{{NEW_PATTERNS}}

For each entry above:

- If the empirical instances support elevation: introduce the principle as a new top-level section in the relevant files. Keep the phrasing project-agnostic.
- If the instances are insufficient: do not elevate; flag in the post-write reflection that the pattern was considered but deferred.

## Language notes for this project

{{LANGUAGE_NOTES}}

## Anti-patterns to avoid

- Cheerleader tone ("you're a brilliant senior engineer").
- Vague principles ("be thoughtful").
- Long lists of hypothetical situations.
- Cross-contamination between base and harness files (tool tactics in base; behaviours in harness overlay).
- Project-specific examples in the playbooks.
- Prose passages that duplicate themselves — restructure rather than restate.

## Uncertainty handling

If unsure:

- Whether a new pattern is validated enough → surface as open question before finalising.
- Whether a previous-version principle should stay → propose keep vs drop and ask. Default is drop if not invoked since last distillation.
- Whether two principles overlap → propose a consolidation explicitly; let the lead decide.
- Whether scope is right (narrow vs broad) → state both phrasings and ask which.

Open questions land at the bottom of the deliverable, numbered, with your recommendation per question.

## Post-write reflection

After writing the four files, surface metanotes about the distillation process itself:

- What was hard to articulate?
- Which patterns felt obvious in retrospect but weren't captured before?
- Were previous-version principles redundant with each other, or reducible to a more fundamental one?
- What in this runtime template or the underlying methodology made the distillation easier or harder?

These metanotes go back to lead and feed the next iteration of:

- This runtime template (if the observation is per-instance).
- The methodology file at `{{PLAYBOOKS_DIR}}/distillation-prompts/playbook-distillation-methodology.md` (if the observation is time-invariant).

A distillation without post-write reflection is incomplete.

---
