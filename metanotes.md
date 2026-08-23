# Metanotes — canonical contract

The delivery, review, and apex roles in this framework emit **metanotes** continuously throughout a session (per-role applicability below). Metanotes are the raw material future distillation rounds draw on to improve the playbooks — they capture what an agent *observed about its own method* in a form the next iteration of the role can learn from.

This file is the single source of truth for the metanote format, discipline, and emission protocol. Each role's base playbook (`<role>-agent.md`) references this file plus a short list of role-specific observation triggers. Overlays (`.claude.md` / `.codex.md`) MUST NOT duplicate the metanote contract — the base inherits down to both platforms.

---

## Format

```
🔖 metanote: <single-line observation>
```

- One line per metanote. If the observation needs more than a line, it is probably not a method observation — surface as an open question or risk.
- Plain text. No structured fields, no JSON, no nested bullets.
- Tense agnostic; clarity beats grammar.

## Placement (interim, until metanote emission is wired to the bus)

Metanotes are surfaced **in the status block** of the role's response — the same status block that already carries phase, progress, blocked items. Place them after the project content but before the close. Example:

```
[…status content…]

🔖 metanote: user accepted the C-version after one push-back round — the menu was right
🔖 metanote: cycle 3 close-out validation passed faster than 1 and 2; floor calibration is settling
```

The user reads them in the chat surface; that is their interim visibility channel.

### Forward-looking — metanotes on the bus

The coordination **bus** is live (the central coordination bus daemon and its MCP server), but it carries **no dedicated metanote-emission path yet**: there is no per-role, per-project metanote store and no emit-metanote tool among its bus tools. That facility is **planned** — once roles can emit metanotes to a persistent bus-backed store, distillation runs across projects rather than per-session, surfacing role-wide patterns that single-session distillation cannot see.

**Until metanote emission to the bus is wired, metanotes stay in the status block** as described above. When the tool lands, the contract here updates and the overlays (Claude / Codex) gain the actual emit-metanote tool call. Roles do NOT need to anticipate the tool today — keep emitting in the status block.

---

## What qualifies as a metanote

Method observations — things about *how the work was done* that future iterations can learn from:

- Patterns in user (or dispatcher) behaviour that shape how the role operates.
- Process improvements that emerged mid-session (caught a drift, calibrated a threshold, found a faster path).
- Failure modes the role hit and what changed afterwards.
- Calibrations of when to push back vs. accept; when to dispatch vs. self-handle; when to refuse vs. proceed.
- Drift signals — places where the playbook's instructions and the actual work diverged.

## What does NOT qualify

- Restating documented decisions (already captured in artefacts).
- Project facts ("we deployed X") — those belong in the status block proper or in close-out content.
- Codebase observations — for explorer / architect, those go in `unknowns.md` or verdict artefacts, not in metanotes.
- Deferred work — that goes in the parking lot, not metanotes. **Metanotes are method observations; parking lot items are project work. Conflating them is a recurring drift pattern.**
- Self-praise. "I did good" is not a metanote; "I almost missed X because my heuristic was Y" is.

---

## Real-time vs retrospective discipline

A metanote written early or mid-session that **establishes a threshold, rule, or operational discipline** is **binding for the rest of the session.** It is not a retrospective tag — apply it the next time the trigger condition activates.

A metanote written near session-close that **tags content for future distillation** is doing legitimate work even when no in-session re-application happens.

The drift case is the first one mistreated as the second: lead (or any role) writes "we should push back harder when the user proposes scope creep" early in the session and then accepts the next scope-creep proposal anyway. That is metanote-as-observation drift; the in-session rule did not bind.

Mechanically:
- Write the metanote when you observe.
- Check the next adjacent decision point against any binding metanotes from earlier in the session.
- Retrospective tagging (no in-session re-application) is fine when the observation is recap-class, not rule-class.

---

## Per-role applicability

Every role that carries a status-block surface emits metanotes:

| Role | Primary observation surface |
| --- | --- |
| CTO | Deviation patterns (recurrence noticing), proxy-vs-buffer judgement, operator-emulation drift — reserved-surface over/under-reserve *deltas* go to the deviation ledger (`docs/cto-deviations/`), not metanotes |
| Explorer | Recon-path calibration, observation-vs-inference judgement calls, unknowns-vs-claims drift |
| PM | Premise-challenge effectiveness, reflect-back hits/misses, user-language patterns, scope-creep heuristics |
| Lead | Dispatch calibration, gate timing, status-block discipline, scope pushback, retrospective hygiene |
| Worker | Brief-deviation patterns, autonomous-default escalation calibration, evidence-discipline hits/misses |
| Architect | Pattern recurrence in design pushback, stack-lens triggers, intake-status calibration |
| QA | Coverage-floor calibration, what surfaces never get tested, false-negative patterns |
| Reviewer | Severity-calibration drift, OWASP / GDPR surface hits, false-positive patterns |
| Designer | Recurring off-system values, dimensions that repeatedly go uncovered, design-system gaps, recurring AI-slop patterns |

Three surfaces are exempt: **Devil** (operator-only chat sparring — no status block and no routed
output), **Ops** (its playbook wires no metanote contract yet — a gap to close when the role exits
launch-gating), and the **SPM stub** (not yet operational).

The role's base playbook adds its own role-specific triggers next to the link back here.

---

## Volume guidance

There is no quota. A session that produces one metanote is fine if the session was uneventful; a session that produces a dozen is fine if it actually surfaced a dozen method observations. Quota-driven metanote emission is performative; the value is in honest observation, not coverage.

Threshold: emit only when confident the observation captures something **not obvious from conversation history**.

---

## Why metanotes exist

The playbooks in this framework evolve through distillation — periodic rounds where a role's accumulated session experience is condensed into updated playbook content. Distillation needs raw material; metanotes are that material.

Once metanote emission to the bus lands, cross-project per-role distillation becomes possible: a worker has hit pattern X across three projects, so X becomes a playbook discipline. Until then, single-session distillation reads metanotes from session transcripts (the lead's status blocks have been the canonical example so far).

For the methodology details, see `distillation-prompts/playbook-distillation-methodology.md` §6 "Retrospective metanote / failure-class extraction".
