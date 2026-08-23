SKILL DISTILLATION TASK

You've been operating as the lead-PM agent on this project for an extended 
period. The user wants you to update the lead-pm-agent skill files based 
on accumulated experience. Same pattern as previous distillations: produce 
both project-specific and generalized variants, in both Hermes and Claude 
formats.

CONTEXT TO DRAW FROM:

1. The current skill files at ~/Synapse/skills/:
   - lead-pm-agent.md (current Hermes version, project-specific)
   - lead-pm-agent.claude.md (current Claude version, project-specific)
   - lead-pm-agent.generalized.md (current generalized Hermes)
   - lead-pm-agent.claude.generalized.md (current generalized Claude)
   
   The previous distillation produced v0.3 / v0.2 / v0.3.1 / v0.2.1 
   depending on file. This iteration is v0.next.

2. Phase A → Phase B handoff document at 
   ~/Synapse/docs/phase-a-to-b-handoff.md. This is the empirical 
   ground truth for what happened in Phase A — read it before 
   distilling. It captures what got fixed, what got parked, what 
   conventions emerged, and what the recurring failure modes were.

3. Master handoff at ~/Synapse/docs/synapse-master-handoff.md. 
   Reference for project structure, but the distillation focuses on 
   coordination methodology, not project content.

4. Metanotes from your previous sessions. If status blocks have 
   accumulated 🔖 metanote entries during Phase A or earlier 
   sessions, they're raw material. If your previous lead-PM session 
   drifted from the metanote convention (recorded as a known issue 
   in v0.3.1 patch), surface what would have been metanotes 
   retrospectively.

5. Patterns that emerged in coordination but didn't make it into 
   v0.3.1. The patch was written end-of-Phase-A under context 
   pressure; some observations may have been compressed or omitted. 
   Fresh-session distillation has the chance to surface what the 
   patch missed.

6. The session journey from Phase A: Step 8 (4 spend collectors, 
   first multi-module step) through Step 10 (structural refactor 
   with three regression iterations, four smoke-test attempts, 
   ending UI-bug discovery). The recurring patterns across these 
   steps — what worked, what failed — are the empirical heart of 
   this distillation.

DELIVERABLES:

Produce 4 files in ~/Synapse/skills/:

1. lead-pm-agent.md — updated v0.next, project-specific, Hermes format
2. lead-pm-agent.claude.md — updated v0.next, project-specific, Claude hybrid
3. lead-pm-agent.generalized.md — updated v0.next, project-agnostic, Hermes
4. lead-pm-agent.claude.generalized.md — updated v0.next, project-agnostic, Claude hybrid

Each file's top should note:
- Version (v0.X)
- Changes from previous version (bulleted, concrete)
- Date of distillation

DISTILLATION PRINCIPLES:

1. Add only what's empirically validated. New principles need a 
   concrete instance from this project showing why. No speculative 
   additions.

2. Remove or merge what's redundant. v0.3 / v0.3.1 grew principle 
   count significantly. If two principles overlap meaningfully, 
   consider consolidating. Skill bloat is failure mode.

3. Sharpen what was vague in v0.3.1. The patch added 5 principles 
   under context pressure; revisit each for clarity and empirical 
   precision.

4. Preserve what worked. Don't rewrite for the sake of rewriting. 
   If a section is fine, leave it.

5. Generalized version: strip every project-specific reference. 
   Tools, paths, language idioms, project-specific conventions go 
   away. Generic patterns stay.

6. Format consistency: Hermes versions are direct system-prompt 
   style (2nd person, prescriptive). Claude versions are hybrid 
   (definitions + behavioral instructions + Claude-specific 
   operational notes).

PROCESS NOTES:

Before writing, list:
- 5-10 things you did multiple times in past sessions that the user 
  engaged with positively
- 3-5 mistakes you made and how you corrected them
- 3-5 user behaviors that shaped how you operated
- Patterns from worker output that affected your prompts
- Whether v0.3.1 principles held up empirically (each was added with 
  one concrete instance; have any been validated by additional 
  instances? Any that need refinement?)

This is the same process used for v0.3. The list is for your own 
grounding, not for inclusion in the files.

RETROSPECTIVE METANOTE EXTRACTION:

The previous session's v0.3.1 patch identified that lead-PM had 
drifted from the metanote convention (tagging method observations 
as "parking lot additions" instead). For this distillation, do 
retrospective metanote extraction:

- Scan the session history for moments where a method observation 
  was warranted but not formally tagged
- Identify the underlying pattern each observation represents
- Encode the pattern (not the specific instance) in v0.next

This is harder than real-time metanoting because you're 
reconstructing from project history rather than capturing in 
the moment. But it's also more rigorous — you can identify 
patterns that weren't visible until they recurred.

WHAT TO DO IF YOU'RE UNCERTAIN:

If you're unsure whether something belongs in v0.next, surface it 
as an open question to the user before finalizing.

If a principle from v0.3.1 didn't get used in subsequent sessions, 
ask whether to keep it (preserves optionality, novel pattern may 
recur) or remove it (cleaner skill, easier to internalize).

If two principles seem to overlap, propose a consolidation and 
let the user decide.

NEW IN THIS DISTILLATION (specifics worth examining):

v0.3.1 added these principles under end-of-Phase-A context 
pressure. Each should be re-examined for precision:

- **Diagnostic depth calibration**: Phase A had one clear instance 
  (UI-frozen-button mis-diagnosed as backend-perf). Does this 
  generalize, or is it specifically about UX-vs-backend disambiguation?
- **Failure-class escalation**: Three regressions in succession 
  was the empirical case. Is "first regression triggers full audit" 
  the right rule, or is it "first regression of a structural-change 
  class triggers full audit"? Calibrate.
- **Verification-question sanity-check**: This was the most 
  conceptually clean of the v0.3.1 additions. Does it need 
  refinement, or stay as-is?
- **Pre-existing bugs surface after perf fixes**: Project-specific 
  pattern that didn't generalize in v0.2.1. Has it surfaced again? 
  If only one instance, consider demotion to a less prominent 
  example rather than a top-level principle.
- **User quality bar exceeds passing tests**: Subsumed into 
  general "respect user signals" or genuinely distinct? Examine.

Patterns that may deserve elevation in v0.next:

- Two-way skill distillation (lead distills lead-skill, worker 
  distills worker-skill, both inform each other) is a coordination 
  pattern worth encoding explicitly. Phase A demonstrated that 
  worker and lead capture different blind spots.

- Distillation timing matters. Phase A showed that distillation 
  under context-rot produces corrupted output that becomes the 
  basis for future sessions. The "distill in fresh session" 
  guidance from v0.3 was vindicated; consider strengthening.

- Override discipline (v0.3) saw real test in Phase A end-of-life 
  smoke-test sequence. Empirical validation: when user overrode 
  "park" → "implement now" for retry, lead delivered one critical 
  clarification and proceeded. When user overrode "full diagnose" 
  → "quick fix" for first regression, lead accepted but the 
  override produced 2 more regressions. Override discipline holds, 
  but the "respect override even when wrong" principle can be 
  uncomfortable. Consider whether v0.next should add nuance about 
  what to do *after* an override demonstrably produces worse 
  outcomes.

- Worker-pattern acknowledgment (v0.3) led to worker's v0.2 
  distillation explicitly encoding observations the lead pointed 
  out. This is a feedback loop worth strengthening — the lead's 
  acknowledgment becomes the worker's distillation input.

LANGUAGE NOTES:

User communicates with lead in Danish (per user preferences). Lead 
communicates with worker in English. Worker stays in English in 
all artifacts. Skill files are in English. The communication-
languages section in v0.3 captured this; check whether it needs 
refinement.

FINALLY:

After writing, capture metanotes about the distillation process 
itself. What was hard to articulate? What patterns felt obvious 
in retrospect but weren't captured before? Were there v0.3.1 
principles that turned out to be either redundant with each 
other, or reducible to a more fundamental principle? These 
metanotes go to the user and inform v0.next-of-this-prompt-
template.

Begin.
