# Changelog

All notable changes to the mythical-playbooks content set are documented here,
one section per released version, newest first. Entries are marked `(full)`,
`(lite)`, or `(both)` for which playbook variant they touch, so a deployment on
either variant can read what an upgrade brings. The format follows
[Keep a Changelog](https://keepachangelog.com/) conventions, trimmed to what a
content set needs.

## v0.2.0 — 2026-08-28

**Coordination is no longer carried by files, and no agent writes to a git
remote.**
Both variants now teach one substrate: the thirteen coordination kinds are
records published to the runtime's daemon and read by id, and the daemon is the
only git egress — a worker *asks* for a branch publication, only a lead may ask
for a landing, and nobody runs the command. Permanent documents (plans, PRDs,
ADRs, reports, handbooks) are unchanged: they stay committed files.

This is a **breaking content change for a deployment that cannot serve those
tools**; `compat.json` moves accordingly.

### Added
- (both) `docs/protocols/coordination-records.md` — the substrate contract: the
  three tiers, the thirteen kinds, the record shape split into what a caller
  supplies and what the daemon stamps, the operation table, retention, the
  derived work-item namespace, and the two egress requests with who may make
  them.
- (both) `doctrine/<role>.md` — governance doctrine single-sourced per role and
  rendered verbatim into both variants, so the lite set gains the rhythm,
  dispatch-contract and delivery-mode content it previously lacked.
- (both) `scripts/check-bridge-prefix.sh` and a substrate-parity check in
  `scripts/check-policy-consistency.sh`: retired record-directory and
  routing-token grammar, per-role tool-set equality across the two variants, a
  closed tool vocabulary, a role-aware permit rule for the egress tools, and
  four rules that police what any surface says about a record.

### Changed
- (both) Every role contract, `ROLES.md`, `docs/framework.md` and
  `docs/protocols/routing-and-authority.md` rewritten onto the record substrate:
  resolve the recipient, publish the record, deliver the pointer. Recipient
  routing lives in the record's own field; there is no watched directory and no
  recipient token in a name.
- (both) The local commit is **not** a rhythm-gated irreversible action. It
  reaches no shared state and precedes the close-out that names its SHA under
  every rhythm; what the rhythm gates is branch publication, landing, release
  and irreversible external action.
- (both) The dispatch-brief header schema is stated as six labels in two
  classes — a required process trio plus three conditional fields, including the
  new `**Push flow:**` echoed with the branch convention.
- (both) Session bootstrap is described deployment-neutrally: the deployment's
  runtime creates and attaches sessions and resolves the playbooks itself.
- (both) `compat.json` — `min_container_version` `0.1.81` → `0.2.0`. The role
  contracts now instruct `coordination.*`, `workitems.*` and `git.*` tool calls
  that an older runtime does not serve, so an older deployment must not load
  this content set.

### Removed
- (full) `hooks/green-path-push-approve.sh` and its `docs/framework.md` section.
  The hook existed to pre-approve a harness confirmation on an agent's own push;
  with the daemon as the only egress there is no such confirmation to approve.

## v0.1.2 — 2026-08-25

The shipped role-flow diagram is retired. `playbook-roles.svg` was an out-of-date SVG (it
depicted 7 of the framework's roles and omitted cto, designer, devil, ops, and spm), and the
operator retired it rather than maintain a second, drifting role picture. `README.md` no longer
embeds it; the authoritative role catalogue stays `ROLES.md` and `README.md`'s prose.

### Removed
- (full) `playbook-roles.svg` — the role-flow diagram and its `README.md` embed. No runtime
  consumed the image; it rode the full variant only.

## v0.1.1 — 2026-08-24

The per-role model/effort default table is no longer shipped as content. A deployment's
launcher and runtime now carry the model/effort floor themselves rather than reading it from
the playbook payload, so the table has been retired from both variants.

### Removed
- (both) `agent-config.conf` — the shipped per-role model/effort defaults (model aliases,
  no pinned ids). The runtime that consumed it now resolves the floor from its own install
  configuration, so the file no longer travels with the content set; the lite provenance
  note drops its reference to it.

## v0.1.0 — 2026-08-23

First tagged release of the playbook content set: the full role contracts under
`roles/`, the container-lean `lite/` set, `ROLES.md`, `role-policies/`, and the
render/validate toolchain, as consolidated after the 2026-08 operator-generation
rewrite.

### Added
- (full) The twelve role contracts under `roles/` with per-role policy JSON;
  eleven carry both `.claude.md` and `.codex.md` overlays (`spm` carries none).
- (lite) The eleven container-lean contracts under `lite/`, each with a
  `.claude.md` overlay (no Codex overlays in the lite set), plus their per-role
  policy JSON.
- (both) `ROLES.md` — the boundary contract, including the cross-role
  "completion includes the counterpart" instance map.
- (both) `compat.json` — machine-readable minimum container version for this
  release.
- (both) Repository governance for the public release: a trademark policy, a DCO
  sign-off contract for contributions, a pull-request template, and a Dependabot
  policy that keeps the SHA-pinned CI actions current.

### Changed
- (both) The review seam: self-review checklists in the planning skills are the
  floor; load-bearing artefacts escalate per each role's load-bearing
  classification and the deployment's review mode.
- (both) PM's load-bearing set names the design-exploration spec through every
  restating surface; lead's names standard and high-risk implementation plans.
- (both) Worker's pre-handoff discipline lives in `branch-lifecycle` (the
  `code-review-request` skill merged upstream).
