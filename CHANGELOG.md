# Changelog

All notable changes to the mythical-playbooks content set are documented here,
one section per released version, newest first. Entries are marked `(full)`,
`(lite)`, or `(both)` for which playbook variant they touch, so a deployment on
either variant can read what an upgrade brings. The format follows
[Keep a Changelog](https://keepachangelog.com/) conventions, trimmed to what a
content set needs.

## v0.1.0 — 2026-08-19

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
- (both) Repository governance for the public release: `TRADEMARK.md`, the DCO
  sign-off contract in `CONTRIBUTING.md`, a pull-request template, and a
  Dependabot policy that keeps the SHA-pinned CI actions current.

### Changed
- (both) The review seam: self-review checklists in the planning skills are the
  floor; load-bearing artefacts escalate per each role's load-bearing
  classification and the deployment's review mode.
- (both) PM's load-bearing set names the design-exploration spec through every
  restating surface; lead's names standard and high-risk implementation plans.
- (both) Worker's pre-handoff discipline lives in `branch-lifecycle` (the
  `code-review-request` skill merged upstream).
