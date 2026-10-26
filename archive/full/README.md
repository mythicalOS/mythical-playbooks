# archive/full — the archived full-weight playbooks

This is the former `roles/` set — the full role contracts (base + `.claude.md` + `.codex.md` per
role, with their rendered contract, allowed-skills and doctrine blocks as of the archive date),
archived on 2026-10-26 because five evaluation runs measured no difference in behaviour between it
and the compact `lite/` set: the behaviour comes from the role policies and the generated doctrine,
not from the extra prose (see the eval scorecard, `mythical-proving-ground-eval/SCORECARD.md`,
"Verdict after five runs"). What remains useful here is the material the lite set deliberately
dropped — the persona and voice sections, and the procedure checklists (intake, brief, review and
close-out walkthroughs) — as reference when a lite playbook needs a fuller statement of a rule.
Nothing loads from here: no deployment resolves role files from this directory, no policy lists a
surface in it, and the render/validate toolchain neither reads nor writes it, so the generated
blocks inside are frozen at the archive date and will drift from `doctrine/` by design.
