#!/usr/bin/env bash
# green-path-push-approve.sh
# Claude Code PreToolUse hook — auto-approves ONE qualifying green-path push to `main`.
#
# DISTRIBUTION: this file ships in the mythical-playbooks framework as an INERT asset.
# It does nothing until a project's .claude/settings.json registers it (PreToolUse → Bash)
# by absolute path. That registration is a human/operator action — an agent is hard-blocked
# from doing it. Enable it via the DEPLOYMENT's project-setup tooling (which lives in the
# deployment's superproject — NOT part of this framework repo) or by hand; see README.md
# §"Green-path push hook" for the manual steps. This is a Claude Code PreToolUse hook (Codex unaffected).
# PREREQUISITE: `jq` must be on PATH (the input is parsed with it); absent jq → safe-defer
# (the zero-touch path simply won't engage). Document/install jq as part of enablement.
#
# WHY THIS EXISTS
#   Under authority rhythm D, an all-green merge-to-main is CTO-authorized (green-path
#   delegation). The only remaining human touchpoint is the `--permission-mode auto`
#   classifier's hard gate on `git push` to main. This hook clears THAT one gate — for a
#   push that has already cleared green-path, and for nothing else.
#
# SECURITY MODEL — READ BEFORE ENABLING (this removes an OS-level irreversibility backstop)
#   Convenience gate, NOT a security boundary. It auto-approves a push only when a marker file
#   vouches for the EXACT commit being pushed. The real authorization is the green-path gate set
#   (reviewer 0 CRITICAL / 0 HIGH, cross-model CLEAN, no architect reject/re-scope, not
#   strategically significant) that ran BEFORE the marker was written. A buggy or rogue agent
#   that writes a marker for an arbitrary SHA could push that SHA — enable only if you accept
#   trading the one-click backstop for hands-off green-path landings.
#
# PROPERTIES: marker-based · SHA-bound · single-use · fresh (<=MAX_AGE_SECONDS) · fail-safe-to-defer
#   On ANY uncertainty (no/old/mismatched marker, parse error, missing jq, not on main, not a
#   git push) it emits nothing and exits 0 → the normal permission flow runs and the human is
#   asked. This hook NEVER emits "deny" and never blocks more than the default.
#
# MARKER PROTOCOL — immediately before the green-path push, the authorized landing step writes
# the marker for the exact commit it is about to push:
#   echo "$(git -C "$CLAUDE_PROJECT_DIR" rev-parse HEAD) main" > "$CLAUDE_PROJECT_DIR/.claude/green-path-push.marker"
#   (use `git -C "$CLAUDE_PROJECT_DIR"`, NOT bare git/cwd — cwd may be a worktree, per worker-agent.claude.md)
# For genuine zero-touch the worker emits this when it holds a CTO green-path GO.

set +e
MAX_AGE_SECONDS=300
DEFER() { exit 0; }   # emit nothing → normal permission flow proceeds (human is asked)

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="$REPO/.claude/green-path-push.marker"

command -v jq >/dev/null 2>&1 || DEFER          # no jq → defer (fail-safe)
INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
[ "$TOOL" = "Bash" ] || DEFER
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$CMD" ] || DEFER

# Strict gate: permissionDecision:allow applies to the WHOLE Bash call, so only a
# single push with an EXPLICIT `main` refspec may pass — never a compound command, an
# alternate repo (-C), force/mirror/delete, an extra refspec, or an AMBIGUOUS bare form
# (`git push` / `git push origin` / `git push origin HEAD`) whose target depends on the
# repo's push.default (matching/current) and could push refs beyond the reviewed main
# commit. Reject shell control operators, then exact-match a tiny explicit-main allowlist
# (whitespace-normalized — this also neutralizes newline/tab-injected compounds).
for _bad in ';' '&' '|' '`' '$' '(' ')' '<' '>'; do
  case "$CMD" in *"$_bad"*) DEFER ;; esac
done
CMD_NORM="$(printf '%s' "$CMD" | tr '\t\n' '  ' | tr -s ' ')"
CMD_NORM="${CMD_NORM# }"; CMD_NORM="${CMD_NORM% }"
CMD_NORM="${CMD_NORM%" -q"}"; CMD_NORM="${CMD_NORM%" --quiet"}"
case "$CMD_NORM" in
  "git push origin main"|"git push origin HEAD:main") : ;;
  *) DEFER ;;
esac

# The push executes in the Bash tool's cwd (from the hook input), which under the worktree
# model can differ from the repo we validate below. Require they are the SAME git repo —
# else the HEAD/branch we verify is not the HEAD that actually gets pushed → defer.
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$CWD" ] || DEFER
REPO_TOP="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)"
CWD_TOP="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)"
[ -n "$REPO_TOP" ] && [ "$REPO_TOP" = "$CWD_TOP" ] || DEFER

# Block configs that publish refs beyond the reviewed main commit. With push.followTags
# enabled (any config level), `git push origin main` also pushes reachable annotated tags,
# so the approved call would publish refs the marker never validated → defer. (An explicit
# command refspec overrides remote.<name>.push, so followTags is the live vector here.)
case "$(git -C "$CWD" config --get push.followTags 2>/dev/null)" in
  true|yes|on|1) DEFER ;;
esac

# `origin` must resolve to exactly ONE push URL — multiple pushurl entries publish the
# reviewed commit to every destination (secondary remotes / mirrors), beyond the single
# main landing the marker vouches for → defer.
[ "$(git -C "$CWD" remote get-url --push --all origin 2>/dev/null | grep -c .)" = "1" ] || DEFER

[ -f "$MARKER" ] || DEFER

NOW="$(date +%s)"
# Portable mtime: GNU stat (-c %Y) first, BSD/macOS stat (-f %m) fallback. Validate it is
# a pure integer — a non-numeric result (wrong stat variant, missing file, fs-info dump)
# DEFERS (fail-safe); it must never fall through to allow on a broken freshness check.
MTIME="$(stat -c %Y "$MARKER" 2>/dev/null || stat -f %m "$MARKER" 2>/dev/null)"
case "$MTIME" in ''|*[!0-9]*) DEFER ;; esac
[ "$MTIME" -le "$NOW" ] || DEFER                 # future mtime (clock skew / touched-ahead) → defer
[ $(( NOW - MTIME )) -le "$MAX_AGE_SECONDS" ] || DEFER

read -r MARK_SHA MARK_BRANCH < "$MARKER"
[ -n "$MARK_SHA" ] || DEFER
[ "${MARK_BRANCH:-main}" = "main" ] || DEFER

HEAD_SHA="$(git -C "$REPO" rev-parse HEAD 2>/dev/null)"
[ -n "$HEAD_SHA" ] || DEFER
[ "$HEAD_SHA" = "$MARK_SHA" ] || DEFER

CUR_BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ "$CUR_BRANCH" = "main" ] || DEFER

rm -f "$MARKER"   # single-use
cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "green-path: HEAD ${HEAD_SHA} on main matched a fresh single-use marker; auto-approved per CTO green-path delegation"
  }
}
JSON
exit 0
