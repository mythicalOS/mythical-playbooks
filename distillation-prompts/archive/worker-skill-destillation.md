# Worker Skill Destillation — Prompt Template

> Use this when the lead wants to refine the worker-agent skill files based on accumulated experience from a project. This is a prompt the lead sends to the worker (in English) to trigger v0.next distillation of the worker skill.

---

## When to use this

The lead triggers this when:

- The worker has accumulated enough new patterns to warrant skill iteration (typically: multiple module extractions, several handled mistakes, observed framework gaps)
- The worker is approaching context-pressure (60-70% used, before quality drops)
- A fresh worker session is upcoming and v0.next should be loaded into it

Don't trigger this for:

- Single bugfixes the worker handled
- Project-specific decisions (those go in the master handoff)
- Cosmetic skill changes

---

## How to use this

The lead pastes the prompt below into the worker session. The worker produces updated skill files. The user reviews and saves them.

The prompt is in English because lead↔worker communication is in English by default. If your project has different language rules, adjust accordingly.

---

## The prompt

```
SKILL DISTILLATION TASK

You've been working as a worker agent on this project for some time. The 
lead wants you to update the worker-agent skill files based on your 
accumulated experience. Same pattern as the previous distillation: 
produce both project-specific and generalized variants, in both Hermes 
and Claude Code formats.

CONTEXT TO DRAW FROM:

1. The current skill files at ~/<project>/skills/:
   - worker-agent.md (current Hermes version)
   - worker-agent.claude.md (current Claude Code overlay)
   - worker-agent.generalized.md (current generalized Hermes)
   - worker-agent.claude.generalized.md (current generalized Claude Code overlay)

2. Metanotes you've surfaced in your gate reports. Scroll back through 
   your reports and collect every 🔖 metanote. They're the raw material 
   for v0.next.

3. Failure patterns you've observed but haven't formally captured. New 
   classes of bug you encountered. Tooling quirks specific to this 
   project's stack that should be generalized into patterns.

4. The lead's prompts to you over time. Did the lead's prompts evolve? 
   Did they start adding precision in places you needed it? That's a 
   signal the worker skill should reflect what the prompts taught.

5. Cases where you stopped autonomously vs. proceeded vs. got it wrong. 
   The threshold for "stop and ask" should sharpen with each iteration.

DELIVERABLES:

Produce 4 files in the same directory as the current skills:

1. worker-agent.md — updated v0.next, project-specific, Hermes format
2. worker-agent.claude.md — updated v0.next, project-specific, Claude Code overlay
3. worker-agent.generalized.md — updated v0.next, project-agnostic, Hermes
4. worker-agent.claude.generalized.md — updated v0.next, project-agnostic, Claude Code overlay

Each file's top should note:
- Version (v0.X)
- Changes from previous version (bulleted, concrete)
- Date of distillation

DISTILLATION PRINCIPLES:

1. Add only what's empirically validated. New patterns need a concrete 
   instance from this project. No speculative "could happen" warnings.

2. Remove what proved unnecessary. If a principle from the previous 
   version never came into play, consider whether it should stay.

3. Sharpen common-failure patterns. Each pattern should have a concrete 
   example. If you've observed a new pattern multiple times, add it. If 
   a listed pattern only happened once across many steps, consider 
   demoting it.

4. Tool affordances stay current. The Claude Code overlay should reflect 
   what's actually true about Claude Code at distillation time, not what 
   was true six months ago.

5. Generalized version strips every project-specific reference. File 
   layouts, language-specific tooling, project conventions go away. 
   Cross-project patterns stay.

6. Format consistency: Hermes versions are direct system-prompt style. 
   Claude Code variants are overlays that reference the base file and 
   add tool-specific notes.

PROCESS NOTES:

Before writing, list:
- 5-10 things you did consistently that the lead's reviews validated as 
  correct
- 3-5 mistakes you made and how you corrected them
- 3-5 patterns you saw in the codebase or tooling that surprised you
- Any prompts from the lead that taught you something the skill didn't 
  yet capture

This list is for your own grounding, not for inclusion in the files.

LANGUAGE NOTES:

If your previous skill version had templates in a non-English language 
that should now be English, this is the iteration to fix that. Reports, 
gate-question phrasing, and template strings should be English in v0.next 
unless the project explicitly requires otherwise.

WHAT TO DO IF YOU'RE UNCERTAIN:

If you're unsure whether something belongs in v0.next, surface it as an 
open question to the lead before finalizing.

If the previous version had a principle that didn't get used, ask whether 
to keep it (preserves optionality) or remove it (cleaner skill).

FINALLY:

After writing, surface metanotes about the distillation process itself.
What was hard to articulate? Which patterns felt obvious in retrospect 
but weren't captured before? Send these to the lead in your final report.

Begin.
```

---

## After the worker produces the files

The worker will write 4 files. The lead reviews them and reports findings to the user. The user saves them.

Decision points after files exist:

- Use immediately in current worker session (limited effect since conversation already shaped by v0.previous)
- Save for next worker session (cleaner test)
- Run a parallel comparison test if you want validation similar to the lead-skill v0.1 → v0.2 transition

---

## When to update this prompt template

Update this template when:

- The distillation process reveals new patterns worth instructing
- Format conventions change (new variant types, restructured overlays)
- The worker-agent skill structure changes substantially

Version this template alongside the skill files. Current: v1.0.
