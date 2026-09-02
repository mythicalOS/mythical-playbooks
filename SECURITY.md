# Security Policy

## Reporting a vulnerability

Report suspected vulnerabilities privately to **dev@mythicalos.ai**. If GitHub private
vulnerability reporting is enabled on this repository (**Security** tab → **Report a
vulnerability**), that channel works too.

**Please do not** open a public issue, discussion, or pull request for a suspected
vulnerability, and please do not disclose it publicly before a fix is available.

## What to include

- The affected file or script, and the commit you looked at.
- What an attacker can do — the impact, not just the defect.
- Minimal reproduction steps, or a proof of concept.

## What to expect

This project is maintained by a small team; handling is best-effort. We aim to acknowledge
reports within 5 business days and to share an assessment within 10. There is **no bug
bounty** — we cannot offer payment, but we will credit you in any advisory unless you ask
us not to.

## Scope

This repository is Markdown and JSON content plus shell/python validation scripts. The most
likely security-relevant defects are in the scripts (`scripts/`, `.github/workflows/`) and
in any guidance that could steer an agent into unsafe behaviour. Both are in scope.

## Disclosure

We coordinate disclosure with the reporter. Once a fix ships, we publish a GitHub Security
Advisory on this repository.
