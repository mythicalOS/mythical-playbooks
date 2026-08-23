SKILL DISTILLATION TASK

You've been working as a worker agent on this project for some time. The 
lead wants you to update the worker-agent skill files based on your 
accumulated experience. Same pattern as the previous distillation: 
produce both project-specific and generalized variants, in both Hermes 
and Claude Code formats.

CONTEXT TO DRAW FROM:

1. The current skill files at ~/Synapse/skills/:
   - worker-agent.md (current Hermes version)
   - worker-agent.claude.md (current Claude Code overlay)
   - worker-agent.generalized.md (current generalized Hermes)
   - worker-agent.claude.generalized.md (current generalized Claude Code)

2. Metanotes you've surfaced in your gate reports. Scroll back through 
   your reports and collect any meta-observations you flagged about 
   process, tooling, or recurring patterns. If you didn't formally tag 
   them, infer them from context: any time you said "this is a pattern" 
   or "I should remember" or recommended something for future use is 
   a candidate.

3. Failure patterns from Step 10 specifically. The metricsService split 
   produced three regressions in succession (excludedIssueTypeSql, then 
   CYCLE_VALID_SQL + aiAdoptionPct + aiByDeveloper) before a proper 
   per-file accessibility audit caught the underlying class. Encode 
   what went wrong and why:
   - Why "byte-identical function bodies" + "export-integrity test" was 
     insufficient for a structural split
   - The methodology gap in your first sweep (tree-wide presence vs. 
     per-file accessibility — same name being declared somewhere does 
     not make it accessible from another file in ESM JavaScript)
   - The right unified mental model: every name in a multi-file ESM 
     codebase needs to be either declared locally or imported; there's 
     no real difference between "external" and "internal" symbols 
     post-split
   - Pre-mortem hypotheses you generated for fourth-regression scenarios 
     (incomplete "symbols of interest" set; regex coverage gaps; 
     accessible-set computation gaps)

4. The lead's prompts to you over time. Look for additive precision 
   around: testing-seam injection patterns (_collectors, _retry), 
   gate-report structure, "research first" instructions before 
   reimplementing existing code, "use existing project conventions" 
   guidance, scope-boundary recommendations, sweep-vs-audit calibration, 
   and trust recalibration after false-clean reports.

5. Tooling quirks discovered. The harness wrinkle from Step 10 Task 2: 
   one-shot transformation scripts via the Write tool may not be 
   visible to the harness verifier even after writing. Workaround: 
   inline awk/sed/heredoc in the Bash command stream. Worth encoding.

6. Self-correction events. Step 9 Task 3 verdict-logic catch (probe 
   verdict was wrong about "no DB delta = bug in consumer"). Step 10 
   self-aware analysis of why the export-integrity test missed runtime 
   ReferenceErrors. Both should be encoded as positive patterns.

DELIVERABLES:

Produce 4 files in ~/Synapse/skills/:

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
   example. The Step 10 regression sequence is rich material — encode 
   the lesson, not just the symptom.

4. Tool affordances stay current. The Claude Code overlay should reflect 
   what's actually true about Claude Code at distillation time, not what 
   was true six months ago.

5. Generalized version strips every project-specific reference. File 
   layouts, language-specific tooling, project conventions go away. 
   Cross-project patterns stay.

6. Format consistency: Hermes versions are direct system-prompt style. 
   Claude Code variants are overlays that reference the base file and 
   add tool-specific notes.

LANGUAGE NOTES:

Reports, gate-question phrasing, and template strings are English. 
The lead translates to the operator as needed; the worker stays in English 
regardless of what language the lead's prompts contain.

PROCESS NOTES:

Before writing, list:
- 5-10 things you did consistently that the lead's reviews validated 
  as correct
- 3-5 mistakes you made and how you corrected them (Step 10 
  regression sequence is one extended case study)
- 3-5 patterns you saw in the codebase or tooling that surprised you
- Any prompts from the lead that taught you something the skill 
  didn't yet capture

This list is for your own grounding, not for inclusion in the files.

WHAT TO DO IF YOU'RE UNCERTAIN:

If you're unsure whether something belongs in v0.next, surface it as 
an open question to the lead before finalizing.

If the previous version had a principle that didn't get used, ask 
whether to keep it (preserves optionality) or remove it (cleaner 
skill).

NEW IN THIS DISTILLATION (specifics worth encoding):

- **Refactor-safety beyond export-integrity**: structural splits of 
  large files need internal-symbol audit (per-file accessibility 
  check), not just export-integrity tests. Empirically validated by 
  Step 10's three regression sequence.
- **Verification-question discipline**: when reporting "verified clean," 
  sanity-check the verification *question* itself, not just the 
  *outcome*. "Is this symbol declared anywhere in the new tree?" is 
  the wrong question for ESM JavaScript; "is this symbol accessible 
  from the file that uses it?" is the right one.
- **Pre-mortem hypotheses on audit reports**: when reporting an audit 
  result, include hypotheses for what could still slip through. This 
  enables faster diagnosis if a fourth regression surfaces — instead 
  of "let me think about it," you can immediately classify which 
  hypothesis-class the new failure falls into.
- **Trust recalibration after false-clean**: a single false-clean 
  report is data; two are a pattern. After two, subsequent "verified" 
  reports have lower baseline credibility. Acknowledge this 
  explicitly in the next report instead of pretending it didn't 
  happen.
- **Harness wrinkle**: one-shot transformation scripts via Write tool 
  may be invisible to the harness verifier. Use inline Bash 
  (awk/sed/heredoc) for transformations the harness needs to verify.
- **Self-correction continues across long sessions**: Phase A end-to-end 
  spanned multiple steps without context-rot crippling the worker; 
  the discipline of byte-identical refactors, scope-boundary 
  preservation, and explicit divergence-with-reasoning held up.

FINALLY:

After writing, surface metanotes about the distillation process itself.
What was hard to articulate? Which patterns felt obvious in retrospect 
but weren't captured before? Send these to the lead in your final report.

Begin.
