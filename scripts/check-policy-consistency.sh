#!/usr/bin/env bash
# check-policy-consistency.sh — cross-policy checks the JSON schema cannot express.
#
# Two concerns, one pass:
#
#   1. BOUNDARY PARITY (full ↔ lite). A role's non-negotiable boundaries —
#      `authority` and `stops_and_overrides` — must be IDENTICAL between
#      `role-policies/` and `lite/role-policies/`, except for deltas pinned in
#      `scripts/policy-parity-exceptions.json`. Every pinned delta is exact
#      (role, field, leaf path, both values) and TYPED: it declares its
#      sanctioned transform kind (citation-repoint | path-vocabulary) and must
#      satisfy that kind's checkable constraints, so the pin list cannot wave
#      through a semantic boundary change. Any unpinned difference fails, and
#      a pinned delta that no longer exists fails as STALE so the pin list can
#      never rot. A lite role with no full-set counterpart fails; a full-set
#      role absent from lite fails unless declared, with a reason, in the same
#      file's `lite_omissions`.
#
#   2. SEMANTIC LINT (each set independently). Closed-vocabulary and
#      uniqueness rules: `must_route` targets must be a role id in that set,
#      `operator`, or a pinned semantic token; `override_authority` and
#      `rhythm_d_route` must come from their closed sets; `git.push_rules` is
#      either empty or covers exactly the four rhythms A–D; no duplicate stop
#      `condition` within a policy; no duplicate entries in list-of-string
#      fields. New vocabulary is a deliberate edit to the pinned lists below,
#      never a silent drive-by.
#
# Exit 0 = clean; 1 = findings; 2 = setup error.
# Usage: scripts/check-policy-consistency.sh [--root <dir>] [--selftest]
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="check"
ROOT_DIR="$PWD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --selftest) MODE="selftest"; shift ;;
    --root) ROOT_DIR="$2"; shift 2 ;;
    *) echo "usage: $0 [--root <dir>] [--selftest]" >&2; exit 2 ;;
  esac
done

PY=$(mktemp -t check-policy-consistency.XXXXXX.py)
trap 'rm -f "$PY"' EXIT
cat > "$PY" <<'PYEOF'
import json, sys, glob, os

root_dir = sys.argv[1]
BOUNDARY_FIELDS = ("authority", "stops_and_overrides")
# Non-role routing targets that are part of the framework's vocabulary. A new
# token here is a deliberate framework change, reviewed like one.
SEMANTIC_TARGETS = {
    "operator", "dispatcher", "pm_or_lead", "parent_explorer",
    "launcher_injected_profile", "launcher_read_only_mount",
    "operator_only_surface", "operator_text_only_refusal",
    "quarantine_downloads_dir_only", "source_check_or_prior_label",
    "worker_dispatch_recommendation",
}
OVERRIDE_AUTHORITIES = {"operator", "lead-with-acknowledgment", "none"}
RHYTHM_D_ROUTES = {"cto", "operator"}  # operator = a human gate NOT re-pointed under rhythm D
RHYTHMS = {"A", "B", "C", "D"}

findings = []


def load_set(subdir):
    out = {}
    for p in sorted(glob.glob(os.path.join(root_dir, subdir, "*.policy.json"))):
        role = os.path.basename(p).split(".")[0]
        with open(p, "rb") as f:
            out[role] = json.load(f)
    return out


def leaves(value, path, setname, role, field):
    """Flatten to {leaf_path: value}. Lists of strings compare as sorted lists
    (order-insensitive); the stops array keys by `condition`."""
    out = {}
    if isinstance(value, dict):
        for k, v in value.items():
            out.update(leaves(v, f"{path}.{k}" if path else k, setname, role, field))
    elif isinstance(value, list):
        if all(isinstance(x, str) for x in value):
            if len(set(value)) != len(value):
                findings.append(f"[{setname}] {role}.{field}.{path or '(root)'}: duplicate list entries")
            out[path or "(root)"] = json.dumps(sorted(value))
        elif all(isinstance(x, dict) for x in value) and all("condition" in x for x in value):
            seen = set()
            for stop in value:
                cond = stop["condition"]
                if cond in seen:
                    findings.append(f"[{setname}] {role}.{field}: duplicate stop condition '{cond}'")
                seen.add(cond)
                rest = {k: v for k, v in stop.items() if k != "condition"}
                out.update(leaves(rest, f"{path + '.' if path else ''}{cond}", setname, role, field))
        else:
            out[path or "(root)"] = json.dumps(value, sort_keys=True)
    else:
        out[path or "(root)"] = json.dumps(value)
    return out


def semantic_lint(setname, policies):
    role_ids = set(policies)
    for role, p in sorted(policies.items()):
        auth = p.get("authority") or {}
        for cond, tgt in sorted((auth.get("must_route") or {}).items()):
            if tgt not in role_ids and tgt not in SEMANTIC_TARGETS:
                findings.append(f"[{setname}] {role}: must_route['{cond}'] -> '{tgt}' is neither a role in this set nor a pinned semantic target")
        for stop in p.get("stops_and_overrides") or []:
            cond = stop.get("condition", "(missing condition)")
            oa = stop.get("override_authority")
            if oa is not None and oa not in OVERRIDE_AUTHORITIES:
                findings.append(f"[{setname}] {role}: stop '{cond}' override_authority '{oa}' not in {sorted(OVERRIDE_AUTHORITIES)}")
            rd = stop.get("rhythm_d_route")
            if rd is not None and rd not in RHYTHM_D_ROUTES:
                findings.append(f"[{setname}] {role}: stop '{cond}' rhythm_d_route '{rd}' not in {sorted(RHYTHM_D_ROUTES)}")
        pr = (p.get("git") or {}).get("push_rules")
        if pr is not None and pr != {} and set(pr) != RHYTHMS:
            findings.append(f"[{setname}] {role}: git.push_rules keys {sorted(pr)} must be empty or exactly {sorted(RHYTHMS)}")
        # Duplicate detection on every list-of-strings leaf (and duplicate stop
        # conditions) rides along in leaves(), over EVERY field — a hard-coded
        # field list is exactly how a surface (e.g. generated_surfaces) would
        # silently escape the lint. Scalar fields flatten to a single harmless
        # leaf. Findings are deduped at print time, so overlap with the parity
        # pass's flattening is harmless.
        for field, value in p.items():
            leaves(value, "", setname, role, field)


full = load_set("role-policies")
lite = load_set(os.path.join("lite", "role-policies"))
if not full or not lite:
    print("CONSISTENCY-CHECK: could not load both policy sets", file=sys.stderr)
    sys.exit(2)

exc_path = os.path.join(root_dir, "scripts", "policy-parity-exceptions.json")
try:
    with open(exc_path, "rb") as f:
        exc_doc = json.load(f)
except FileNotFoundError:
    exc_doc = {}
exceptions = exc_doc.get("exceptions", [])
lite_omissions = exc_doc.get("lite_omissions", [])


# The sanctioned path->record-id vocabulary map, applied in order. A pin of
# kind path-vocabulary is valid ONLY if the lite value equals the root value
# under exactly these substitutions — suffix/substring heuristics would let a
# pin smuggle a semantic change (e.g. *_path -> do_nothing_record_id) through.
# A new sanctioned token is a reviewed edit to this table.
PATH_VOCAB_SUBS = (("_path", "_record_id"), ("route_directly_to", "route_to"))

# citation-repoint deltas are editorial (each lite replacement is a per-role
# authoring choice), so they cannot be validated mechanically — instead the
# exact sanctioned tuples are CHECKER-OWNED. Adding one is a reviewed change
# to this set, in the same commit as the exceptions-file entry.
CITATION_REPOINT_ALLOWLIST = {
    ("cto", "authority", "green_path.eligibility_ref",
     json.dumps('ROLES.md §"Apex substitution under rhythm D"'),
     json.dumps('cto-agent.md §"Role contract"')),
    ("lead", "authority", "green_path.eligibility_ref",
     json.dumps('ROLES.md §"Apex substitution under rhythm D"'),
     json.dumps("lead may not authorize the green path; reserved merges route to the operator")),
}


def kind_violation(e):
    """A pin must declare WHICH sanctioned transform class it belongs to and
    satisfy that class's STRUCTURAL validation — a bare five-tuple pin would be
    an unrestricted parity bypass (any semantic boundary change could be pinned
    through). Returns a violation message, or None."""
    kind = e.get("kind")
    tup = (e.get("role"), e.get("field"), e.get("path"), e.get("root"), e.get("lite"))
    if kind == "citation-repoint":
        if tup not in CITATION_REPOINT_ALLOWLIST:
            return ("citation-repoint pins are checker-owned: this exact delta is not in the "
                    "sanctioned set (extend CITATION_REPOINT_ALLOWLIST in a reviewed change)")
        return None
    if kind == "path-vocabulary":
        if e.get("field") != "stops_and_overrides" or not e.get("path", "").endswith(".action"):
            return "kind path-vocabulary applies only to stops_and_overrides *.action paths"
        try:
            rv, lv = json.loads(e.get("root", "")), json.loads(e.get("lite", ""))
        except (json.JSONDecodeError, TypeError):
            return "kind path-vocabulary values must be JSON strings"
        if not isinstance(rv, str) or not isinstance(lv, str):
            return "kind path-vocabulary values must be JSON strings"
        norm = rv
        for a, b in PATH_VOCAB_SUBS:
            norm = norm.replace(a, b)
        if norm != lv:
            return ("kind path-vocabulary: lite value is not the root value under the sanctioned "
                    f"substitutions {PATH_VOCAB_SUBS!r}")
        return None
    return f"missing or unknown kind {kind!r} (allowed: citation-repoint, path-vocabulary)"


for e in exceptions:
    v = kind_violation(e)
    if v:
        findings.append(f"exception ({e.get('role')}, {e.get('field')}, {e.get('path')}): {v}")

exc_keys = {(e.get("role"), e.get("field"), e.get("path"), e.get("root"), e.get("lite"))
            for e in exceptions}
if len(exc_keys) != len(exceptions):
    findings.append("parity exceptions file contains duplicate entries")
used = set()

# The lite role SET is pinned too: a full-set role may be absent from lite only
# by named, reasoned declaration — otherwise deleting a lite policy would pass
# as an informational note while the shipped role set silently shrank.
omit = {}
for o in lite_omissions:
    role = o.get("role")
    if role in omit:
        findings.append(f"duplicate lite omission declaration for '{role}'")
    omit[role] = o.get("reason", "")
    if not o.get("reason"):
        findings.append(f"lite omission '{role}' must state a reason")

for role in sorted(set(lite) - set(full)):
    findings.append(f"lite role '{role}' has no full-set counterpart")
for role in sorted(set(full) - set(lite)):
    if role in omit:
        print(f"note: full-set role '{role}' omitted from lite by declaration: {omit[role]}")
    else:
        findings.append(f"full-set role '{role}' is missing from lite and not a declared omission — the shipped role set shrank")
for role in sorted(omit):
    if role in lite:
        findings.append(f"declared lite omission '{role}' is actually present in lite — stale declaration, remove it")
    elif role not in full:
        findings.append(f"declared lite omission '{role}' is not a full-set role")

for role in sorted(set(full) & set(lite)):
    for field in BOUNDARY_FIELDS:
        fl = leaves(full[role].get(field), "", "full", role, field)
        ll = leaves(lite[role].get(field), "", "lite", role, field)
        for path in sorted(set(fl) | set(ll)):
            rv = fl.get(path, "<absent>")
            lv = ll.get(path, "<absent>")
            if rv == lv:
                continue
            key = (role, field, path, rv, lv)
            if key in exc_keys:
                used.add(key)
            else:
                findings.append(f"PARITY {role}.{field}.{path}: full={rv} lite={lv} (not a pinned exception)")

for key in sorted(exc_keys - used):
    findings.append(f"STALE exception no longer matches any difference: {key} — remove it")

semantic_lint("full", full)
semantic_lint("lite", lite)

findings = list(dict.fromkeys(findings))  # dedupe, order-preserving
if findings:
    for f in findings:
        print(f"CONSISTENCY-CHECK FAIL: {f}", file=sys.stderr)
    print(f"CONSISTENCY-CHECK: {len(findings)} finding(s).", file=sys.stderr)
    sys.exit(1)
print(f"consistency check OK ({len(full)} full + {len(lite)} lite policies; "
      f"{len(exceptions)} pinned parity exception(s), all in use)")
PYEOF

run_check() { python3 "$PY" "$1"; }

if [[ "$MODE" == "check" ]]; then
  run_check "$ROOT_DIR"
  exit $?
fi

# ---------------------------------------------------------------------------
# --selftest: prove the checker actually fails on the drift classes it claims
# to catch. Runs against mutated scratch copies; the repo is never touched.
# ---------------------------------------------------------------------------
command -v python3 >/dev/null || { echo "selftest needs python3" >&2; exit 2; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"; rm -f "$PY"' EXIT
stage() {  # fresh scratch copy of both sets + the exceptions file
  rm -rf "$TMP/repo"
  mkdir -p "$TMP/repo/scripts" "$TMP/repo/role-policies" "$TMP/repo/lite/role-policies"
  cp role-policies/*.policy.json "$TMP/repo/role-policies/"
  cp lite/role-policies/*.policy.json "$TMP/repo/lite/role-policies/"
  cp scripts/policy-parity-exceptions.json "$TMP/repo/scripts/" 2>/dev/null || true
}
expect() {  # expect <name> <want-exit> [<required-diagnostic-pattern>]
  # The pattern pins WHICH check fired — exit 1 alone can come from the wrong
  # check (e.g. parity masking a broken lint) or an unrelated crash. It is
  # therefore MANDATORY for every failure case; only a clean pass may omit it.
  local name="$1" want="$2" pat="${3:-}" got=0 out
  if [[ "$want" != 0 && -z "$pat" ]]; then
    echo "SELFTEST FAIL: $name — failure cases must assert a diagnostic pattern" >&2; exit 1
  fi
  out=$(run_check "$TMP/repo" 2>&1) || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "SELFTEST FAIL: $name — exit $got, wanted $want" >&2
    echo "$out" >&2; exit 1
  fi
  if [[ -n "$pat" ]] && ! /usr/bin/grep -qF "$pat" <<<"$out"; then
    echo "SELFTEST FAIL: $name — diagnostic '$pat' not found in output" >&2
    echo "$out" >&2; exit 1
  fi
  echo "selftest ok: $name"
}
stage; expect "clean copy passes" 0

stage
python3 - "$TMP/repo/lite/role-policies/worker.policy.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["stops_and_overrides"] = d["stops_and_overrides"][1:]  # drop a boundary stop
json.dump(d, open(p, "w"))
MEOF
expect "dropped lite stop fails" 1 "PARITY worker.stops_and_overrides"

# Typo the SAME target in BOTH sets: parity stays silent, so only the
# semantic lint can produce the failure — proving the lint itself works.
stage
for f in "$TMP/repo/role-policies/worker.policy.json" "$TMP/repo/lite/role-policies/worker.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["authority"]["must_route"]["scope_boundary_question"] = "laed"  # typo'd target
json.dump(d, open(p, "w"))
MEOF
done
expect "typo'd must_route target fails (both sets, lint-only)" 1 "neither a role in this set nor a pinned semantic target"

stage
python3 - "$TMP/repo/scripts/policy-parity-exceptions.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["exceptions"].append({"role": "worker", "field": "authority",
                        "path": "bogus", "root": "\"x\"", "lite": "\"y\""})
json.dump(d, open(p, "w"))
MEOF
expect "stale exception fails" 1 "STALE exception"

stage
python3 - "$TMP/repo/lite/role-policies/worker.policy.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["git"]["push_rules"] = {"A": "x", "B": "y"}  # partial rhythm cover
json.dump(d, open(p, "w"))
MEOF
expect "partial push_rules fails" 1 "push_rules keys"

# generated_surfaces is OUTSIDE the parity fields — a duplicate there can only
# be caught by the all-fields duplicate lint.
stage
python3 - "$TMP/repo/lite/role-policies/worker.policy.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["generated_surfaces"].append(d["generated_surfaces"][0])
json.dump(d, open(p, "w"))
MEOF
expect "duplicate generated_surfaces entry fails" 1 "duplicate list entries"

# The three stop-vocabulary lints, each mutated in BOTH sets so parity stays
# silent and only the lint itself can fail the run.
stage
for f in "$TMP/repo/role-policies/worker.policy.json" "$TMP/repo/lite/role-policies/worker.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["stops_and_overrides"][0]["override_authority"] = "wizard"
json.dump(d, open(p, "w"))
MEOF
done
expect "invalid override_authority fails (both sets, lint-only)" 1 "override_authority 'wizard'"

stage
for f in "$TMP/repo/role-policies/worker.policy.json" "$TMP/repo/lite/role-policies/worker.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["stops_and_overrides"][0]["rhythm_d_route"] = "lead"
json.dump(d, open(p, "w"))
MEOF
done
expect "invalid rhythm_d_route fails (both sets, lint-only)" 1 "rhythm_d_route 'lead'"

stage
for f in "$TMP/repo/role-policies/worker.policy.json" "$TMP/repo/lite/role-policies/worker.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["stops_and_overrides"].append(dict(d["stops_and_overrides"][0]))
json.dump(d, open(p, "w"))
MEOF
done
expect "duplicate stop condition fails (both sets, lint-only)" 1 "duplicate stop condition"

# The pin-bypass attack: a semantically valid boundary change (must_route
# lead -> operator in lite) with a matching five-tuple pin must NOT pass —
# neither with no kind nor smuggled under a kind whose constraints it violates.
attack() {  # attack <kind-json-fragment or empty>
  python3 - "$TMP/repo" "$1" <<'MEOF'
import json, sys, os
r, kind = sys.argv[1], sys.argv[2]
p = os.path.join(r, "lite/role-policies/worker.policy.json")
d = json.load(open(p)); d["authority"]["must_route"]["scope_boundary_question"] = "operator"
json.dump(d, open(p, "w"))
ep = os.path.join(r, "scripts/policy-parity-exceptions.json")
e = json.load(open(ep))
pin = {"role": "worker", "field": "authority",
       "path": "must_route.scope_boundary_question", "root": '"lead"', "lite": '"operator"'}
if kind:
    pin["kind"] = kind
e["exceptions"].append(pin)
json.dump(e, open(ep, "w"))
MEOF
}
stage; attack ""
expect "pinned semantic change without kind fails" 1 "missing or unknown kind"
stage; attack "citation-repoint"
expect "pinned semantic change under wrong kind fails" 1 "checker-owned"

# Constraint-shaped attacks: pins that LOOK like their kind but change
# semantics must fail structural validation.
stage
python3 - "$TMP/repo/scripts/policy-parity-exceptions.json" <<'MEOF'
import json, sys
p = sys.argv[1]; e = json.load(open(p))
e["exceptions"].append({"role": "worker", "field": "stops_and_overrides",
                        "path": "reviewer_critical_finding.action", "kind": "path-vocabulary",
                        "root": '"stop_and_route_via_lead_path"', "lite": '"do_nothing_record_id"'})
json.dump(e, open(p, "w"))
MEOF
expect "path-vocabulary pin with non-mapped semantics fails" 1 "not the root value under the sanctioned substitutions"

stage
python3 - "$TMP/repo/scripts/policy-parity-exceptions.json" <<'MEOF'
import json, sys
p = sys.argv[1]; e = json.load(open(p))
e["exceptions"].append({"role": "cto", "field": "authority",
                        "path": "green_path.eligibility_ref", "kind": "citation-repoint",
                        "root": e["exceptions"][0]["root"], "lite": '"anyone may authorize"'})
json.dump(e, open(p, "w"))
MEOF
expect "citation-repoint pin outside the owned set fails" 1 "checker-owned"

# Deleting a shipped lite role must fail unless declared in lite_omissions.
stage
rm "$TMP/repo/lite/role-policies/ops.policy.json"
expect "removed lite role fails" 1 "not a declared omission"

stage
python3 - "$TMP/repo/scripts/policy-parity-exceptions.json" <<'MEOF'
import json, sys
p = sys.argv[1]; e = json.load(open(p))
e["lite_omissions"].append({"role": "qa", "reason": "pretend"})
json.dump(e, open(p, "w"))
MEOF
expect "stale lite omission fails" 1 "actually present in lite"

echo "selftest OK (15 cases)"
