# r096/lines — cross-model review (one lane: the operator-message lines)

**VERDICT: CLEAN after 3 turns** (no Class A in turn 3). Reviewer: Codex `gpt-6-astra`, `codex exec --ignore-user-config --sandbox read-only`, stdin `/dev/null`, verdict read only from `--output-last-message`.
Reviewed range: `d614cdb..0ee3f49`. Final diff hash (`git diff d614cdb 0ee3f49 | shasum -a 256`): `37a9d01da2d8f6107996d2d43976c005c8f36af0671b227a60848894a7d870e1`.
Size: 89 source lines in `doctrine/*.md` + one hand edit in `roles/cto-agent.md`; the other 20 files are the generated copies `scripts/render-contracts.sh` writes (`--check` green).

`docs/reviews/` did not exist in this repository; this file creates it. The bake projection drops `docs/**` except `docs/protocols/**`, so this file does not reach a baked payload.

## Scope
The four operator-message rules from the owner's 0.9.5 test findings (#12, #16, #17, #24, their "Playbooks:" sentences), as one doctrine section "Messages to the operator" in the ten roles whose policy grants a direct operator channel (architect, cto, designer, devil, explorer, lead, ops, pm, qa, reviewer), rendered into both `roles/` and `lite/`. Worker and spm have no operator channel and are left out. The CTO announcement template's closing "Confirm or override." becomes a question asked through the form. Nothing else.

## Turn 1 — NOT CLEAN (4 Class A)
- [A] doctrine/architect.md:6 — All ten additions restrict #16 to replies “to the operator”; the required rule covers replies through the bus regardless of recipient. Agent-to-agent replies remain outside it. — Remove “to the operator” from this bullet in all ten sources.
- [A] doctrine/architect.md:3 — The identifier ban conflicts with explicit chat-output requirements: roles/architect-agent.codex.md:48 requires the record id in `final`, as do roles/reviewer-agent.codex.md:44 and roles/cto-agent.codex.md:77; lite/reviewer-agent.claude.md:44–45 requires a subject SHA and record-id pointer. Neither precedence clause resolves this. — Explicitly make plain-language operator references supersede identifier-bearing chat templates, retaining identifiers in records.
- [A] doctrine/devil.md:7 — Requiring pickup orientation in a session record contradicts Devil’s prohibition on writing coordination artefacts (roles/devil-agent.md:19, :89) and its empty MCP allowlist. — Qualify record placement by existing record-writing authority; preserve Devil’s chat-only boundary.
- [A] doctrine/cto.md:5 — Requiring options conflicts with the CTO announcement contract’s explicit “a recommendation, not options” (roles/cto-agent.md:424). The free-form-question precedence clause does not explicitly override this options prohibition. — Extend the precedence clause to cover the existing recommendation-only announcement format while retaining the recommendation.
Calls:
- A (accepted): the bus-reply rule was narrowed to replies to the operator; counsel's sentence covers any reply through the bus. Fixed: any recipient.
- A (accepted): host templates require a record id or SHA in chat/final output; without a rule, two instructions collide. Fixed: such ids go on the closing `Details:` line, after the words.
- A (accepted): Devil writes no records, so "the pickup orientation goes into the session's record" could not be followed. Fixed: Devil's section drops the bus bullet and the record half; pickup is one line in chat.
- A (accepted): the CTO announcement said "a recommendation, not options" and ended in "Confirm or override." — the very prose question #24 names. Fixed: the template asks through the form, recommendation first.

## Turn 2 — NOT CLEAN (2 Class A)
- [A] doctrine/architect.md:6 — Ending the turn after a bus reply conflicts with mandatory chat output in roles/architect-agent.codex.md:48, roles/reviewer-agent.codex.md:44, roles/qa-agent.codex.md:46, and roles/cto-agent.codex.md:77. Moving identifiers to `Details:` does not resolve the requirement to send that additional message. — Explicitly make the bus-reply rule supersede post-delivery chat/final templates across the affected doctrines.
- [A] doctrine/reviewer.md:5 — Requiring the structured form even without natural options conflicts with roles/reviewer-agent.claude.md:29 and lite/reviewer-agent.claude.md:46, which permit it only for genuine 2–4-option review-content choices. The precedence clause covers notes requiring free-form questions in plain text, but these restrictions contain no such allowance. — Explicitly override the genuine-choice restriction for questions awaiting the operator, while retaining the actual-dispatcher and routing boundaries.
Calls:
- A (accepted): the Codex overlays require a `final` message after delivery; the rule did not say what that message becomes. Fixed: one line saying what was sent and to whom, never the reply again.
- A (accepted): the reviewer overlays limit the question form to genuine 2–4-option choices; the precedence clause covered only "free-form in plain text". Fixed: the clause names both limits, and keeps who may be asked and routed-dispatcher reach unchanged.

## Turn 3 — CLEAN (0 Class A, 1 Class B)
- [B] doctrine/cto.md:6 — “After you reply through the bus” could be read to include the mandatory interim receipt acknowledgment in roles/cto-agent.codex.md:64, before review and operator announcement are complete. — Clarify that the turn-ending rule concerns the completed reply, not the explicitly interim receipt acknowledgment.
Calls:
- B (logged, not fixed): the CTO's interim receipt acknowledgment is a separate, explicitly interim message, not "the reply"; the reading the finding fears is possible but the rule's subject is the reply itself. Wording only; it does not change what an agent does with a completed reply.

## Checks (on 0ee3f49)
- `scripts/render-contracts.sh --check` — exit 0.
- `scripts/validate-policies.sh` (python with `jsonschema` from a local uv tool on PATH, `MYTHICAL_SKILLS_PATH` set to the skills checkout) — exit 0, "policies OK".
- `scripts/check-policy-consistency.sh` — exit 0, "consistency check OK (12 full + 11 lite policies; 2 pinned parity exception(s), all in use; substrate parity ON)".
- `scripts/check-anchors.sh` — exit 1, 23 DANGLING; the same 23 lines on base `d614cdb` (byte-compared): pre-existing, none added.
- `scripts/check-bridge-prefix.sh` — exit 0.
- `scripts/render-contracts.sh --selftest` — exit 0, 27 cases.
- `scripts/check-policy-consistency.sh --selftest` — exit 0, "selftest OK (233 cases)" (synthetic fixture; run on 09b8851, the fixture does not read the corpus edits).
- `git merge-tree --write-tree` against `nrf/seat-rules` and `nrf/review-lane`: both merge clean (neither merged).
