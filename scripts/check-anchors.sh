#!/usr/bin/env bash
# Every §"Section name" citation in playbook surfaces must resolve to a real
# definition (a heading, bold lead, or plain mention) somewhere in the corpus.
#
# The naive "grep the name anywhere" is useless: the citation §"Name" itself
# contains "Name", so it always self-satisfies. We therefore search a corpus
# with all §"..." citations STRIPPED OUT — a name only counts as resolved if it
# appears OUTSIDE a citation. Abbreviated citations (a trailing … / "..." or a
# " → sub" suffix) are matched on their leading distinctive prefix.
#
# The stripped corpus is written to a temp FILE (not a shell variable) so the
# grep is robust regardless of corpus size / shell printf limits.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
files=$(ls ./roles/*-agent*.md ROLES.md README.md 2>/dev/null)

# --- mythical-skills locator for namespaced (mythical: / agent:) anchors (§C.2) ----------------
# A `mythical:<skill> §"…"` or `agent:<skill> §"…"` citation in a PLAYBOOK resolves to a section in <skill>'s OWN
# SKILL.md under mythical-skills. Such citations are checked PER-SKILL (against that one skill body) by
# the dedicated pass at the END — they are NOT folded into the global playbook haystack. (Folding all
# skill bodies into the haystack would also let a BARE playbook anchor false-green off any mythical-skills
# body the moment one namespaced token appeared.) So: the haystack below stays
# PLAYBOOK-ONLY; the bare-citation pass STRIPS namespaced segments (handled per-skill); the per-skill
# pass resolves <skill> via this locator. Order matches validate-policies.sh (§C.1):
# $MYTHICAL_SKILLS_PATH → ../mythical-skills → clear failure. A bare-only corpus needs no mythical-skills.
MYTHICAL_SKILLS_ROOT=""
if [ -n "${MYTHICAL_SKILLS_PATH:-}" ] && [ -d "$MYTHICAL_SKILLS_PATH" ]; then
  MYTHICAL_SKILLS_ROOT="$(cd "$MYTHICAL_SKILLS_PATH" && pwd -P)"
elif [ -d "../mythical-skills" ]; then
  MYTHICAL_SKILLS_ROOT="$(cd ../mythical-skills && pwd -P)"
fi
if grep -hoE '(mythical|agent):[a-z0-9._-]+' $files >/dev/null 2>&1 && [ -z "$MYTHICAL_SKILLS_ROOT" ]; then
  echo "ANCHOR-CHECK: MYTHICAL_SKILLS_PATH unset and ../mythical-skills not found — cannot resolve namespaced (mythical:/agent:) anchors"
  exit 2
fi

# Namespaced-citation grammar (§C.2). A `mythical:<name>` token binds ONLY the anchor that
# IMMEDIATELY follows it — separated solely by an optional closing backtick, whitespace, and an
# optional "at" connector (the house invocation form: `mythical:<name>` [at] §"<anchor>"). An
# anchor that is NOT adjacent (arbitrary prose between the token and the §"…") is left to the BARE
# pass — so `Use mythical:foo for X; see §"Bar"` does NOT mis-attribute "Bar" to foo (it is
# checked as a bare playbook citation). Gate 2 must keep each namespaced citation adjacent to its
# token. The SAME regex drives both the bare-pass strip and the per-skill extraction (no drift). The
# backtick in the value is literal (single-quoted) and is NOT re-evaluated when expanded in "...".
NS_CITE_RE='(mythical|agent):[a-z0-9._-]+`?[[:space:]]*(at[[:space:]]+)?§"[^"]*"'

defs_file=$(mktemp)
trap 'rm -f "$defs_file"' EXIT
# Haystack = playbook corpus ONLY (no mythical-skills fold — see above). Namespaced anchors are verified
# per-skill at the end.
cat $files | sed 's/§"[^"]*"//g' > "$defs_file"

fail=0
for f in $files; do
  while IFS= read -r a; do
    s="${a#§\"}"; s="${s%\"}"
    [ -z "$s" ] && continue
    # Normalize abbreviated citation forms to a searchable prefix:
    # drop a " → ..." sub-reference, a trailing " (qualifier)", a trailing
    # ellipsis (… or ...), and a trailing period — then trim whitespace.
    p="${s%% → *}"
    p="$(printf '%s' "$p" | sed -E 's/ \([^)]*\)$//; s/(…|\.\.\.|\.)$//; s/[[:space:]]*$//')"
    [ -z "$p" ] && continue
    grep -qF "$p" "$defs_file" || { echo "DANGLING in $f: §\"$s\""; fail=1; }
    # STRIP adjacent namespaced citations (`mythical:<name> [at] §"anchor"`) before extracting
    # bare citations — those anchors live in mythical-skills and are verified per-skill below, so the bare
    # pass (playbook-only haystack) must not see them (else they would false-dangle here). A NON-adjacent
    # §"…" (prose between it and any token) is NOT stripped → correctly checked as a bare citation.
  done < <(sed -E "s/${NS_CITE_RE}//g" "$f" | grep -oh '§"[^"]*"' | sort -u)
done

# --- Per-skill verification for namespaced citations (§C.2 precision) ------------------------------
# The whole-corpus loop above resolves each §"anchor" against the combined corpus (how bare playbook
# anchors have always been checked). For a NAMESPACED citation that names a SPECIFIC skill —
# `mythical:<name> … §"anchor"` on one line — ADDITIONALLY require the anchor to live in THAT
# skill's OWN SKILL.md, so `mythical:foo §"X"` cannot false-green off a section that exists only
# in `mythical:bar`. Strictly additive (only ADDS DANGLING findings, never masks one); resolves
# <name> with the same precedence as validate-policies.sh — both mythical: and
# agent: authored-ONLY (there is no vendored root). Playbook surfaces only.
if [ -n "$MYTHICAL_SKILLS_ROOT" ]; then
  for f in $files; do
    while IFS= read -r cite; do
      [ -z "$cite" ] && continue
      ns="$(printf '%s' "$cite" | sed -E 's/^(mythical|agent):.*/\1/')"
      name="$(printf '%s' "$cite" | sed -E 's/^(mythical|agent):([a-z0-9._-]+).*/\2/')"
      anchor="${cite#*§\"}"; anchor="${anchor%\"}"
      [ -z "$name" ] && continue
      [ -z "$anchor" ] && continue
      skill_md=""
      # BOTH agent: and mythical: are authored-ONLY now, with STRICT containment (mirror the
      # deployment's plugin builder + validate-policies.sh _resolve_authored_skill):
      # the dir must canonicalize to EXACTLY <root>/skills/<name> and SKILL.md be a regular file, not a
      # symlink — no escape into other content (there is no vendored root). A bare
      # `-f` would follow a `skills/<name> -> …` symlink and false-pass while the builder refuses to link it.
      _as_base="$(cd "$MYTHICAL_SKILLS_ROOT/skills" 2>/dev/null && pwd -P || true)"
      _as_real=""
      [ -n "$_as_base" ] && _as_real="$(cd "$_as_base/$name" 2>/dev/null && pwd -P || true)"
      if [ -n "$_as_real" ] && [ "$_as_real" = "$_as_base/$name" ] && [ -f "$_as_real/SKILL.md" ] && [ ! -L "$_as_real/SKILL.md" ]; then
        skill_md="$_as_real/SKILL.md"
      fi
      if [ -z "$skill_md" ]; then
        echo "DANGLING in $f: $ns:$name §\"$anchor\" (skill '$name' not found under mythical-skills)"; fail=1; continue
      fi
      # Normalize the abbreviated-citation forms exactly like the main loop, then require the prefix
      # in THAT skill body only.
      p="${anchor%% → *}"
      p="$(printf '%s' "$p" | sed -E 's/ \([^)]*\)$//; s/(…|\.\.\.|\.)$//; s/[[:space:]]*$//')"
      [ -z "$p" ] && continue
      # Resolve against the skill's HEADING lines. A skill's sections are its citable anchors, and these
      # skills use a SELF-CITING heading convention — `## §"Name"` (the § marker is IN the heading) — as
      # well as plain `## Name` headings; matching heading lines resolves both. Matching ONLY headings
      # also keeps the self-satisfaction guard: an anchor that appears solely as an inline §"…" cross-ref
      # (not a heading) does NOT resolve. (A plain strip-then-match would wrongly delete a `## §"Name"`
      # heading and false-dangle every self-citing anchor.)
      grep -E '^#{1,6}[[:space:]]' "$skill_md" | grep -qF -- "$p" || { echo "DANGLING in $f: $ns:$name §\"$anchor\" (no heading defines it in $name/SKILL.md)"; fail=1; }
    done < <(grep -oE "$NS_CITE_RE" "$f")
  done
fi

[ "$fail" -eq 0 ] && echo "anchors OK"
exit "$fail"
