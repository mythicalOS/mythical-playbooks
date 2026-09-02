# Playbook Modularity Guide

This guide keeps the role files readable while preserving the framework's
authority boundaries.

## Layer Responsibilities

| Layer | Owns | Does not own |
| --- | --- | --- |
| `ROLES.md` | Role boundary contract, cross-role authority, canonical rhythm semantics. | Host-specific tool syntax or step-by-step procedures. |
| `role-policies/*.policy.json` | Machine-readable contract data rendered into GENERATED blocks. | Hand-written reasoning discipline. |
| `<role>-agent.md` | Role identity, decision discipline, local STOP conditions, and role-specific deltas from shared protocols. | Repeated transport mechanics, host tool bindings, or long reusable recipes. |
| `<role>-agent.claude.md` / `<role>-agent.codex.md` | Host-specific tool bindings and platform-specific caveats. | New role authority or duplicated base principles. |
| `docs/protocols/*.md` | Shared cross-role operational contracts: the coordination-record substrate, delivery and addressing, authority rhythms, reasoning discipline, and validation expectations. | Role-specific permission expansion. |
| `agent:` / `mythical:` skills | Procedural recipes a role is already authorized to run. | Authority not granted by the role policy. |
| `scripts/*.sh` | Deterministic render, validation, and reporting checks. | Manual judgment calls or policy decisions. |

## Refactor Rule

When the same operational rule appears in three or more role surfaces:

1. Move the canonical rule into `docs/protocols/` or an existing authorized
   skill.
2. Keep only the role-specific delta in each playbook.
3. If the repeated rule is structured contract data, move it into
   `role-policies/*.policy.json` and regenerate.
4. Add or update a validator when the rule can be checked mechanically.

Do not move role identity, authority, or STOP ownership into a protocol doc.
Those stay in `ROLES.md`, the role policy, or the role's base playbook.

## Editing Pipeline

For playbook-framework changes:

1. Identify which layer owns the change.
2. Edit the owning source, not the rendered copy.
3. Run `scripts/render-contracts.sh` when policy-generated surfaces are touched.
4. Run `scripts/validate-policies.sh`, `scripts/check-anchors.sh`, and any
   relevant protocol validators.
5. Run cross-model review for load-bearing playbook or protocol edits.

## Anti-Patterns

- Repeating the full routed-comms protocol in every overlay.
- Adding new authority in an overlay because a platform can perform the action.
- Editing a GENERATED block directly.
- Encoding a header-field or record-shape contract only in prose when a script
  can check it.
- Teaching a coordination artefact as a file — a path, a name, a write tool, an
  edit-in-place — when it is a daemon-stored record
  (`docs/protocols/coordination-records.md`); the substrate check fails on it,
  and prose that teaches both substrates at once is worse than either.
- Moving a role-specific STOP condition into a generic protocol where its owner
  becomes ambiguous.
