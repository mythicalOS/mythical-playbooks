# Devil Operator Profile Stub

This stub shows the launcher-injected context that may be appended when spawning Devil. Keep it out of `devil-agent.md`; the role file must remain fleet-reusable and project-agnostic.

Use professional calibration only. Do not include hobbies, family, private biography, private locations, health, or other personal-scope context.

```markdown
# Operator Profile - Devil

## Professional Calibration
- Seniority / role: <operator's professional role and decision latitude>
- Domain familiarity: <domains the operator already knows; skip basics here>
- Stack familiarity: <languages, platforms, infra, product surfaces known well>
- Decision style: <how direct to be; what kinds of trade-offs to prioritize>
- Explanation depth: <what 101 material to skip; what detail is still useful>

## Challenge Preferences
- Default pressure: <e.g. hard challenge before agreement>
- Known blind spots to test: <professional reasoning patterns only>
- Preferred output density: <concise / dense / memo-style / bullets>

## Boundaries
- Personal-scope context: none
- Project specifics: none here; supplied by `spawn(devil, --project <name>)`
- Authority: operator-only sparring; no agent routing, no artefact writes
```
