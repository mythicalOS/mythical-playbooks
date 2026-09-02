<!--
Thanks for contributing. Please read CONTRIBUTING.md if you have not already:
../CONTRIBUTING.md
-->

## What this changes

<!-- Which role, protocol, or policy does this affect? Describe the contract before and after. -->

## Why this approach

<!-- What alternatives did you consider and why did you reject them? -->

## Related issue

<!-- e.g. Closes #123. Open an issue first for anything beyond an obvious fix. -->

## How this was verified

<!-- The checks you ran and their output. "Checks pass" without the command is not evidence. -->

```
```

## Checklist

- [ ] Every commit is signed off (`git commit -s`) — see the DCO section of CONTRIBUTING.md
- [ ] One concern only; unrelated changes are in a separate pull request
- [ ] A contract change edits the **policy JSON**, and `scripts/render-contracts.sh` was re-run — a hand-edited GENERATED block is reverted by the next render
- [ ] `scripts/validate-policies.sh`, `scripts/check-policy-consistency.sh` and `scripts/check-anchors.sh` all pass
- [ ] A boundary difference between the full and lite policy sets is pinned in `scripts/policy-parity-exceptions.json` as its own reviewed decision
- [ ] CI is green
- [ ] This is **not** a security fix — if it is, stop and follow [SECURITY.md](../SECURITY.md) instead
