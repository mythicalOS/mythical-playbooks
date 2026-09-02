# Contributing

Thanks for your interest in mythical-playbooks. Everything in this repository is Markdown and
JSON content plus a small validation toolchain — no build, no runtime dependencies beyond
`bash`, `git`, `jq`, and `python3`.

## Before you start

**Open an issue first** for anything beyond an obvious fix. Playbook wording is deliberate;
a change that looks cosmetic can shift a role boundary. Typo and broken-link fixes need no
issue — just send the pull request.

## How a playbook change lands

The machine-readable **role policy** is the source of truth for a role's contract; parts of
the playbook surfaces are generated from it.

1. **Edit the policy JSON** (`role-policies/<role>.policy.json`) when the change touches
   authority, channels, artefacts, skills, or git scope. Prose-only changes edit the playbook
   Markdown directly — but never inside a `GENERATED` block.
2. **Render** — `scripts/render-contracts.sh` regenerates the generated blocks in the
   surfaces each policy names; `scripts/render-contracts.sh --check` verifies freshness
   without mutating anything.
3. **Validate** — `scripts/validate-policies.sh` lints every policy against the schema and
   the cross-policy rules.
4. **Anchors** — `scripts/check-anchors.sh` verifies that every `§"Section name"` citation
   resolves to a real definition in the corpus.

The `lite/` set is hand-maintained compact content: keep edits brief (brevity is that set's
value), keep the base ↔ overlay pair consistent, and mirror any contract change into the
matching `lite/role-policies/` policy.

## Developer Certificate of Origin (DCO)

Every commit must be signed off. By signing off you certify the
[Developer Certificate of Origin 1.1](https://developercertificate.org/) — in short, that you
wrote the contribution or otherwise have the right to submit it under the project's licence.
There is no CLA, and you keep the copyright in what you write.

Sign off with `-s`:

```sh
git commit -s -m "your message"
```

That appends a trailer to your commit message:

```
Signed-off-by: Your Name <your.email@example.com>
```

Use your real name and an address you can be reached at. Anonymous and pseudonymous sign-offs
cannot be accepted.

To sign off commits you already made:

```sh
git rebase --signoff main       # or: git commit --amend -s   (for the last commit only)
```

## Pull requests

- **One concern per pull request.** A wording pass bundled with a contract change is two
  pull requests.
- **Explain the why.** The diff shows what changed; the description should say what problem
  it solves.
- **Green CI.** The checks above plus a content gate run on every pull request; failing
  checks will not be reviewed.
- Keep the existing style — match the surrounding wording density and tone rather than
  importing conventions from elsewhere.

## Security and conduct

Do not report vulnerabilities through issues or pull requests — see
[SECURITY.md](SECURITY.md). Participation is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md).
