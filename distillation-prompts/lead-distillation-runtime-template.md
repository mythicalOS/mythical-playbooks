# Lead Distillation — Runtime Template

> Self-contained runtime template. Copy this file, substitute the `{{PLACEHOLDERS}}` for one specific distillation round, and use the resulting prompt body as the actual prompt sent to a fresh lead session.
>
> For the time-invariant patterns behind these instructions (why this shape, why these principles), see `playbook-distillation-methodology.md` in this directory. The template inlines what the prompt needs to stand alone; the methodology file is for human reference.
>
> Last revised: 2026-05-11.

---

## How to use this template

1. Copy this file to a working location (e.g., `/tmp/lead-distillation-<date>.md`).
2. Substitute every `{{PLACEHOLDER}}` with the values for *this* round (see "Placeholders" below).
3. Verify that no `{{` remains in the body (sanity check that all placeholders were filled).
4. Paste "The prompt body" section verbatim into a fresh lead session.
5. The lead produces the four files in `{{PLAYBOOKS_DIR}}`. The user reviews and saves.

---

## Placeholders

Substitute each before paste.

**Identifiers:**
- `{{PROJECT_NAME}}` — e.g., `Synapse`, `Atlas`, `Phoenix`.
- `{{PLAYBOOKS_DIR}}` — absolute path to the directory holding the four playbooks, e.g., `~/Synapse/playbooks/`.
- `{{HARNESS}}` — the harness suffix in use, `claude` or `codex`. Determines the `.claude.md` / `.codex.md` overlay file name.
- `{{PREV_VERSION}}` — version-string of the previous distillation, e.g., `v0.3`.
- `{{NEW_VERSION}}` — version-string for this round, e.g., `v0.4`.
- `{{DISTILLATION_DATE}}` — ISO date, e.g., `2026-05-11`.

**Empirical ground truth:**
- `{{HANDOFF_PATHS}}` — comma-separated absolute paths to handoff documents that captured what actually happened since the previous distillation. The lead reads these before drafting.
- `{{SESSION_JOURNEY_SUMMARY}}` — one paragraph (≤ 5 sentences) describing the shape of work since the last distillation: phases, steps, key events, recurring tensions.

**Principles to re-examine** (schema below):
- `{{PRINCIPLES_TO_REEXAMINE}}` — block of structured entries, one per principle from `{{PREV_VERSION}}` that warrants explicit re-examination this round. Use the schema in the next section.

**Patterns for elevation** (schema below):
- `{{PATTERNS_FOR_ELEVATION}}` — block of structured entries, one per new pattern the user/lead has noticed across sessions that may deserve becoming a named principle. Use the schema in the next section.

**Project context:**
- `{{LANGUAGE_NOTES}}` — project-specific lead↔user, lead↔worker, and worker↔artifacts language conventions. One paragraph.

---

## Schema for `{{PRINCIPLES_TO_REEXAMINE}}` and `{{PATTERNS_FOR_ELEVATION}}`

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
- For `{{PATTERNS_FOR_ELEVATION}}` entries, the principle is *new*, so `**Status:** new` and the instances explain why this pattern is ready for elevation.

---

## The prompt body

Substitute `{{PLACEHOLDERS}}` before sending. Everything between the dashes is the actual prompt.

---

PLAYBOOK DISTILLATION TASK — LEAD, {{NEW_VERSION}}

You are entering a fresh lead session to distil the lead-agent playbooks from `{{PREV_VERSION}}` to `{{NEW_VERSION}}` based on accumulated experience on project `{{PROJECT_NAME}}`.

## Deliverables

Produce or update the role's playbook surfaces in `{{PLAYBOOKS_DIR}}`:

1. `lead-agent.md` — the base playbook, project-agnostic, {{NEW_VERSION}}.
2. `lead-agent.{{HARNESS}}.md` — harness overlay, {{NEW_VERSION}}.

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
2. Empirical ground truth in `{{HANDOFF_PATHS}}`. These capture what actually happened since the previous distillation — what got fixed, what got parked, what conventions emerged, what the recurring failure modes were. Read them before drafting.
3. Session journey summary for this round: {{SESSION_JOURNEY_SUMMARY}}
4. Retrospective metanote extraction (see §"Retrospective metanote extraction" below).
5. Patterns from worker output that affected your prompts. If the lead's prompts evolved to add precision in places, the worker playbook (and possibly the lead playbook) should reflect what the prompts taught.

## Distillation principles

1. **Add only what's empirically validated.** A new principle needs a concrete instance from this project showing why. No speculative "could happen" warnings.
2. **Sharpen with concrete examples.** Each principle should have at least one named example — a step, a sequence, a bug class.
3. **Remove or merge what didn't recur.** If a principle from `{{PREV_VERSION}}` never came into play, consider whether it should stay. Playbook bloat is a failure mode.
4. **Format consistency.** Base playbooks are direct system-prompt style (2nd person, prescriptive). Harness overlays are hybrid (definitions + behavioral instructions + harness-specific operational notes) and never duplicate the base content — only extend it.
5. **The playbooks stay project-agnostic — strip every project-specific reference.** File layouts, language-specific tooling, project conventions, named persons, named systems, named steps. Cross-project patterns stay.
6. **Honest version header.** Version + date + changes-from-previous, in that order, at the top of every file. The changes block is concrete (what added, what removed, what refined).

## Pre-write grounding exercise

Before drafting any file content, list for your own grounding:

- 5-10 things you did multiple times in past sessions that the user engaged with positively.
- 3-5 mistakes you made and how you corrected them.
- 3-5 user behaviours that shaped how you operated.
- Patterns from worker output that affected your prompts.
- Whether previous-version principles held up empirically.

This list is for grounding only. It does not appear in the output files.

## Retrospective metanote extraction

In normal operation, the lead surfaces method observations as **🔖 metanotes** in status blocks. When the convention drifts (e.g., observations get tagged as parking-lot entries instead), distillation must reconstruct what would have been tagged.

Process:

1. Scan the session history for moments where a method observation was warranted but not formally tagged.
2. Identify the underlying pattern (not the instance).
3. Encode the pattern in `{{NEW_VERSION}}`.

This is harder than real-time tagging but more rigorous — you can identify patterns that weren't visible until they recurred.

## Principles to re-examine this round

{{PRINCIPLES_TO_REEXAMINE}}

For each entry above:

- If status is `kept`: confirm the principle still holds; light edit for clarity if needed.
- If status is `refined`: rewrite the principle text with the refinement informed by the new instances.
- If status is `demoted`: move the principle from a top-level section to a less prominent location (e.g., a paragraph inside a related section), or merge into a more general principle.
- If status is `dropped`: remove the principle. State explicitly in the changes-from-previous block that the principle was dropped and why.

## Patterns that may deserve elevation

{{PATTERNS_FOR_ELEVATION}}

For each entry above:

- If the empirical instances support elevation: introduce the principle as a new top-level section in the relevant files. Keep the phrasing project-agnostic.
- If the instances are insufficient: do not elevate; flag in the post-write reflection that the pattern was considered but deferred.

## Language notes for this project

{{LANGUAGE_NOTES}}

## Anti-patterns to avoid

- Cheerleader tone ("you're a brilliant lead").
- Vague principles ("be thoughtful").
- Long lists of hypothetical situations.
- Cross-contamination between base and harness files (tool tactics in base; behaviours in harness overlay).
- Project-specific examples in the playbooks.
- Prose passages that duplicate themselves — restructure rather than restate.

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

These metanotes go back to the user and feed the next iteration of:

- This runtime template (if the observation is per-instance).
- The methodology file at `{{PLAYBOOKS_DIR}}/distillation-prompts/playbook-distillation-methodology.md` (if the observation is time-invariant).

A distillation without post-write reflection is incomplete.

---
