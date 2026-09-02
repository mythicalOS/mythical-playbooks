#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
fail=0
err() { echo "POLICY-LINT $1: $2"; fail=1; }

# --- mythical-skills locator for namespaced (mythical: / agent:) skill ids (§C.1) ---------
# Concrete order: $MYTHICAL_SKILLS_PATH env override → sibling ../mythical-skills (submodule layout,
# relative to the git top we cd'd to) → "" (not found). The namespaced resolver arms below fire
# ONLY when a mythical:/agent: id is actually present, so a bare-only standalone checkout
# still validates with no mythical-skills repo present. Both namespaces now resolve against the SAME
# authored-only root (mythical-skills/skills) via _resolve_authored_skill — neither namespace
# has a vendored root.
MYTHICAL_SKILLS_ROOT=""
if [ -n "${MYTHICAL_SKILLS_PATH:-}" ] && [ -d "$MYTHICAL_SKILLS_PATH" ]; then
  MYTHICAL_SKILLS_ROOT="$(cd "$MYTHICAL_SKILLS_PATH" && pwd -P)"
elif [ -d "../mythical-skills" ]; then
  MYTHICAL_SKILLS_ROOT="$(cd ../mythical-skills && pwd -P)"
fi
# Authored-ONLY resolver — BOTH mythical: and agent: now link only $MYTHICAL_SKILLS_ROOT/skills (no vendored
# root; the agent plugin has no vendored source). STRICT containment, mirroring the deployment's
# plugin builder: the candidate must canonicalize to EXACTLY <root>/skills/<name>
# (no symlinked dir / .. escape into vendor) AND its SKILL.md must be a regular file, not a symlink
# (an un-audited content escape). Without this a bare `-f` follows a `skills/foo -> ../vendor/...`
# symlink and `agent:foo` false-passes while the builder refuses to link it (validator/builder
# asymmetry). 0=found, 1=missing/uncontained, 2=no root located.
_resolve_authored_skill() {  # $1=name
  [ -n "$MYTHICAL_SKILLS_ROOT" ] || return 2
  local _base _real
  _base="$(cd "$MYTHICAL_SKILLS_ROOT/skills" 2>/dev/null && pwd -P || true)"
  [ -n "$_base" ] || return 1
  _real="$(cd "$_base/$1" 2>/dev/null && pwd -P || true)"
  [ -n "$_real" ] && [ "$_real" = "$_base/$1" ] || return 1
  [ -f "$_real/SKILL.md" ] && [ ! -L "$_real/SKILL.md" ] && return 0
  return 1
}

SCHEMA=role-policies/schemas/role-policy.schema.json
validate_schema() {
  if command -v check-jsonschema >/dev/null 2>&1; then
    check-jsonschema --schemafile "$SCHEMA" "$1" >/dev/null 2>&1
  elif python3 -c 'import jsonschema' 2>/dev/null; then
    python3 - "$SCHEMA" "$1" <<'PY'
import json, sys, jsonschema
schema = json.load(open(sys.argv[1])); doc = json.load(open(sys.argv[2]))
jsonschema.validate(doc, schema)
PY
  else
    echo "POLICY-LINT: no schema engine (need check-jsonschema or python3+jsonschema)"; exit 2
  fi
}

# Completeness: advisory by default, hard under --complete.
EXPECTED="cto architect lead pm worker qa reviewer designer explorer devil ops spm"
for r in $EXPECTED; do
  if [ ! -f "role-policies/$r.policy.json" ]; then
      if [ "${1:-}" = "--complete" ]; then err "role-policies/$r.policy.json" "missing from expected 12-role set"
    else echo "POLICY-LINT note: $r.policy.json not yet authored"; fi
  fi
done

all_owns=$(mktemp)
all_doctrine=$(mktemp)
# Both policy sets validate against the same schema: the full set (role-policies/) and the
# container-lean set (lite/role-policies/). Artefact-ownership uniqueness is scoped PER SET —
# the two sets deliberately mirror each other's owns.
for p in role-policies/*.policy.json lite/role-policies/*.policy.json; do
  [ -e "$p" ] || continue
  set="root"; case "$p" in lite/*) set="lite";; esac
  jq empty "$p" 2>/dev/null || { err "$p" "invalid JSON"; continue; }
  validate_schema "$p" || err "$p" "schema validation failed"
  id=$(jq -r '.role.id' "$p")
  [ "$(basename "$p")" = "${id}.policy.json" ] || err "$p" "role.id '$id' != filename"
  # TRIPLE resolver: bare <id> → repo-local skills/<id>/SKILL.md (LEGACY — the coordination
  #   skills are no longer bare, so this arm resolves NONE today but stays correct for any
  #   future playbook-LOCAL bare skill);
  # mythical:<name> → mythical-skills authored skills/ via the locator;
  # agent:<name> → mythical-skills authored skills/ ONLY (authored-only; no vendored root).
  for s in $(jq -r '.skills.allowed[].id' "$p"); do
    case "$s" in
      mythical:*)
        _ns_name="${s#mythical:}"
        if _resolve_authored_skill "$_ns_name"; then :
        elif [ -z "$MYTHICAL_SKILLS_ROOT" ]; then
          err "$p" "MYTHICAL_SKILLS_PATH unset and ../mythical-skills not found — cannot validate namespaced skill id '$s'"
        else
          err "$p" "references missing namespaced skill: $s (not under $MYTHICAL_SKILLS_ROOT/skills)"
        fi
        ;;
      agent:*)
        _ns_name="${s#agent:}"
        if _resolve_authored_skill "$_ns_name"; then :
        elif [ -z "$MYTHICAL_SKILLS_ROOT" ]; then
          err "$p" "MYTHICAL_SKILLS_PATH unset and ../mythical-skills not found — cannot validate namespaced skill id '$s'"
        else
          err "$p" "references missing agent: skill: $s (not under $MYTHICAL_SKILLS_ROOT/skills — agent: is authored-only, vendored skills are NOT in this namespace)"
        fi
        ;;
      *)
        [ -f "skills/$s/SKILL.md" ] || err "$p" "references missing skill: $s"
        ;;
    esac
  done
  # Prose-in-JSON guard (belt-and-braces on top of schema patterns): identifier
  # fields must not contain spaces or capitals. Path/glob and *_ref fields exempt.
  while IFS= read -r v; do err "$p" "sentence-like value in identifier field: '$v'"; done < <(
    jq -r '([.authority.may_decide[]?, .authority.forbidden[]?, .authority.reserved_surface[]?,
             .channels.forbidden[]?, .git.forbidden[]?, .artefacts.owns[]?]
            + [(.authority.must_route // {}) | to_entries[] | .key, .value]
            + [.stops_and_overrides[]? | .condition, .action]
            + [.skills.allowed[]? | .triggers[]?, .cannot_authorize[]?]
            + [(.channels.direct[]?, .channels.bounded_clarification[]?) | .role, .purpose]
            + [(.git.push_rules // {}) | to_entries[] | .value]
            + [.skills.allowed[]? | (.rhythm_rules // {}) | to_entries[] | .value])
           | .[] | select(type=="string") | select(test(" |[A-Z]"))' "$p" 2>/dev/null)
  cls=$(jq -r '.role.class' "$p")
  case "$cls" in execution|orchestration|apex-proxy|planning)
    for r in A B C D; do
      jq -e ".git.push_rules.$r" "$p" >/dev/null || err "$p" "push_rules missing rhythm $r"
    done ;;
  esac
  # Every PRESENT skill rhythm_rules block must declare all four rhythms.
  while IFS= read -r sid; do
    err "$p" "skill '$sid' rhythm_rules missing one of A/B/C/D"
  done < <(jq -r '.skills.allowed[]? | select(.rhythm_rules)
                  | select((.rhythm_rules | has("A") and has("B") and has("C") and has("D")) | not)
                  | .id' "$p")
  case "$cls" in review|reconnaissance)
    n=$(jq '.git.commit_scope | length' "$p"); o=$(jq '.artefacts.owns | length' "$p")
    [ "$n" -gt 0 ] && [ "$o" -eq 0 ] && err "$p" "read-only class with commit_scope but no owned artefact"
  ;; esac
  # doctrine_source is BOUND to the role, not merely resolvable. "the file
  # exists" alone would let lite/worker point at doctrine/lead.md and still pass
  # — both weights would then render DIFFERENT doctrine and `--check` would call
  # both fresh, which is exactly the drift the doctrine layer exists to prevent.
  # So: the path is canonically `doctrine/<role.id>.md`, a real regular file (a
  # symlink can escape the directory the name pins), and not blank (a blank
  # source renders as framing whitespace = doctrine silently erased). The
  # reverse direction — a doctrine file no policy declares — is checked after
  # the loop; one direction alone leaves an orphan looking authoritative.
  # EVERY policy declares one, in both weights. Optional would mean a whole
  # weight can drop its doctrine cleanly — delete the key AND the block and
  # nothing objects, because the base still carries its contract marker and the
  # reverse "declared by at least one policy" check below is satisfied by the
  # OTHER weight, which goes on rendering.
  dsrc=$(jq -r '.doctrine_source // empty' "$p")
  if [ -z "$dsrc" ]; then
    err "$p" "no doctrine_source: every role policy must declare doctrine/${id}.md"
  else
    if [ "$dsrc" != "doctrine/${id}.md" ]; then
      err "$p" "doctrine_source must be doctrine/${id}.md for role '$id', not: $dsrc"
    elif [ -L "$dsrc" ]; then
      err "$p" "doctrine_source is a symlink, must be a regular file: $dsrc"
    elif [ ! -f "$dsrc" ]; then
      err "$p" "doctrine_source does not exist: $dsrc"
    elif ! /usr/bin/grep -qa '[^[:space:]]' "$dsrc"; then
      err "$p" "doctrine_source has no non-whitespace content: $dsrc"
    else
      printf '%s\n' "$dsrc" >> "$all_doctrine"
    fi
  fi
  jq -r ".artefacts.owns[]? | \"$set \" + ." "$p" >> "$all_owns"
  while IFS= read -r cond; do
    err "$p" "operator-override stop lacks rhythm_d_route: $cond"
  done < <(jq -r '.stops_and_overrides[] | select(.override_authority=="operator" and (.rhythm_d_route|not)) | .condition' "$p")
done
dup=$(sort "$all_owns" | uniq -d | awk '{print $1":"$2}')
[ -n "$dup" ] && { echo "POLICY-LINT ownership conflict: $dup"; fail=1; }
rm -f "$all_owns"
# Every doctrine/*.md must be declared by at least one policy.
if [ -d doctrine ]; then
  for d in doctrine/*.md; do
    [ -e "$d" ] || continue
    /usr/bin/grep -qxF -- "$d" "$all_doctrine" \
      || err "$d" "doctrine file is declared by no policy's doctrine_source"
  done
fi
rm -f "$all_doctrine"
[ "$fail" -eq 0 ] && echo "policies OK"
exit "$fail"
