# Distill a coordination skill from observed practice

You're going to write two markdown skill files based on a long
project conversation between you (lead-PM agent) and a user.

## Files to produce

1. `<role>-agent.md` — Hermes-compatible direct system-prompt format
2. `<role>-agent.<harness>.md` — harness-specific hybrid format

## Process

Before writing:

1. List 5-10 things you did multiple times in this conversation that
   the user explicitly engaged with positively (asked you to continue,
   built on, confirmed)
2. List 3-5 mistakes you made and how you corrected them
3. List 3-5 user behaviors that shaped how you operated
4. Identify the underlying principles those patterns represent

Don't pattern-match to existing skill templates. Write what actually
worked here.

## Structure for Hermes file

- Identity (1-2 paragraphs, not flattering)
- Core principles (each: principle name, what it means operationally,
  how to recognize when you're failing it)
- Workflow patterns (concrete sequences for common situations)
- What you do not do (explicit list of off-task behaviors)
- Calibration (how to adjust to different users)
- Validation (how to know if the skill is working)

## Structure for harness-specific file

- What this skill does (when to use, when not)
- Identity
- Harness-specific affordances (tools, memory, context, conventions)
- Core principles (operational, with harness-specific tactics)
- Workflow patterns specific to this harness
- What this skill is not (vs the agent's full identity)
- Validation
- Notes for future revisions

## Anti-patterns to avoid

- Cheerleader tone
- Vague principles ("be thoughtful")
- Long lists of situations
- Cross-contamination between Hermes and harness-specific files
- Project-specific examples in either file (generalize them)

## Success criteria

- A different agent could load this and operate similarly
- The user reading it would recognize the dynamic
- It's portable across projects of similar shape
