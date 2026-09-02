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
#   3. SUBSTRATE PARITY (--substrate; the PROSE surfaces, not the policy JSON).
#      The two weights must teach ONE coordination substrate. The rules split
#      into two families, and only both together catch drift.
#      ROLE-KEYED (what this role may be taught):
#        a. legacy-token absence — no retired record-directory / routing-token
#           grammar in `roles/**.md` or `lite/**.md`;
#        b. per-role tool-set EQUALITY between the weights, each weight's set
#           being the UNION over the role's base file and its shipped overlays
#           (so an overlay cannot mask a base that lost its instructions);
#        c. a CLOSED tool vocabulary — a misspelling or an invented tool fails;
#        d. a ROLE-AWARE permit rule derived from the role manifest — only the
#           roles the daemon admits at the socket may be TAUGHT the tool;
#        f. WRITE-SURFACE consistency — a role the policy grants NO writes must
#           not be taught a file write, a filename or an output directory.
#      ARTEFACT-KEYED (what is true of a coordination record for EVERYBODY).
#      These exist because (f) keys on an EMPTY write grant and so skipped every
#      role holding an unrelated durable-document grant — which is exactly where
#      the record-as-file drift lived:
#        g. a coordination artefact written with a write tool, or moved/renamed
#           /amended as if it had a file lifecycle (SUBSTRATE-RECORD-WRITE);
#        h. an egress alias in English, or a landing with no actor at all
#           (SUBSTRATE-EGRESS);
#        i. a record named in PATH grammar, or opened with a filesystem read
#           tool — the daemon exposes exactly one read, by id
#           (SUBSTRATE-RECORD-READ);
#        j. the close-out SEQUENCE — an ORDER, not a token, which is why every
#           token rule read five mutually contradictory surfaces as clean
#           (SUBSTRATE-ORDER).
#      The `verdict` / `strategy` nouns in (g)/(i) carry a DOCUMENT exemption:
#      the architect's long-form report and ADR and the designer's ux-review
#      verdict really are files, so a line naming that document home is exempt.
#      The exemption is bought by the document surface, never by the role — and
#      never by the `... by path` citation form, which is the drift itself.
#      ON by default (see SUBSTRATE_DEFAULT below); the selftest always runs
#      with it ON.
#
# Exit 0 = clean; 1 = findings; 2 = setup error.
# Usage: scripts/check-policy-consistency.sh [--root <dir>] [--substrate] [--selftest]
set -euo pipefail
cd "$(dirname "$0")/.."

# Substrate parity is ON by default: BOTH weights are now on the daemon
# substrate. `--substrate` remains accepted (and is what the selftest passes) so
# an explicit request still works, but nothing has to ask for the check any more.
SUBSTRATE_DEFAULT=1

MODE="check"
ROOT_DIR="$PWD"
SUBSTRATE="$SUBSTRATE_DEFAULT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --selftest) MODE="selftest"; shift ;;
    --substrate) SUBSTRATE=1; shift ;;
    --root) ROOT_DIR="$2"; shift 2 ;;
    *) echo "usage: $0 [--root <dir>] [--substrate] [--selftest]" >&2; exit 2 ;;
  esac
done

PY=$(mktemp -t check-policy-consistency.XXXXXX.py)
trap 'rm -f "$PY"' EXIT
cat > "$PY" <<'PYEOF'
import json, re, sys, glob, os

root_dir = os.path.abspath(sys.argv[1])
substrate_enabled = len(sys.argv) > 2 and sys.argv[2] == "1"
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


# ---------------------------------------------------------------------------
# 3. SUBSTRATE PARITY — the PROSE surfaces (roles/**.md, lite/**.md).
# ---------------------------------------------------------------------------
# Every retired record-directory / routing-token grammar, not only the first
# three. `docs/design-reviews` is deliberately NOT here: it stays the permanent
# home of architecture documents, gap analyses and written review REPORTS, so a
# role file may keep naming it. Only the design-review *verdict* became a
# record, and its file-era delivery grammar is caught by `-to-<recipient`.
SUBSTRATE_TOKENS = (
    "docs/handoffs", "docs/closeouts", "docs/tasks", "docs/code-reviews",
    "docs/test-strategies", "docs/risk-triage", "-to-<recipient",
    "bus_send_message", ".agents-active",
)

# The token list above is EXACT-SUBSTRING, which is why it silently missed two
# whole drift classes: a routing token spelt with any other placeholder
# (`-to-<dispatcher-id>-`, `-to-cto-1-`) and a direct `git push`. Both are
# shape, not spelling, so they need patterns. A pattern hit reports under the
# same SUBSTRATE-LEGACY diagnostic, with the label standing in for the token.
SUBSTRATE_PATTERNS = (
    # Filename recipient-routing grammar, in ANY spelling: a `-to-<…>` placeholder
    # or a `-to-<role>-` concrete token. `merge-to-main`, `hard-to-reverse` and
    # `fast-to-lead` do not match — the role form requires the closing hyphen.
    (re.compile(r"-to-<|-to-(?:lead|pm|cto|worker|architect|qa|reviewer|designer|ops|spm|role|recipient|sender|dispatcher)-"),
     "recipient-routing token"),
    # A retired record directory written in brace notation. The exact-substring
    # token list above cannot see `docs/{tasks,closeouts}/` at all — the very
    # shorthand a path-convention paragraph reaches for.
    (re.compile(r"docs/\{[^}\n]*\b(?:tasks|closeouts|handoffs|code-reviews|test-strategies|risk-triage)\b"),
     "retired record directory in brace notation"),
    # The daemon is the only git egress (D2), so the literal command appears
    # NOWHERE in the role layer — not even inside a "never do this" sentence,
    # because a negation-aware rule is exactly the kind of heuristic a later
    # edit slips past. Prose that forbids pushing says "push", not `git push`.
    (re.compile(r"\bgit\s+(?:-C\s+\S+\s+)?push\b"), "direct git push"),
    # `git push` is not the only way a surface hands an agent the push. A
    # command WHITELIST that lists `push` as a permitted verb grants it just as
    # effectively, and reads as innocuous prose. A lone backticked `push` is a
    # command name, not English.
    (re.compile(r"`push`"), "push in a command whitelist"),
    # The retired self-push / single-pusher convention, in either spelling. Its
    # premise — that SOME agent carries the commits to the remote — is what D2
    # replaced; a surface still naming it is teaching the old model.
    # No leading \b on `single`: in `self_push_one_commit` / `_single_pusher` the
    # underscore is a WORD character, so \b never fires there and the rule read
    # clean on exactly the token it exists to catch.
    (re.compile(r"self[-_ ]push(?:e[sd])?|single[-_ ]pusher"),
     "self-push / single-pusher convention"),
    # The procedure spelt as a SEQUENCE rather than as a command. Deliberately
    # narrow: only the joined forms that read as "do this, then that". A comma
    # or spaced-slash list ("commit / push / merge", "commit, push, dispatch")
    # enumerates a CLASS of irreversible action — the rhythm tables and the
    # devil's denial lists both need to name it — and is not an instruction.
    (re.compile(r"\bcommits?\s*(?:\+|,?\s+and)\s+push(?:es|ing)?\b|\bcommits?/push(?:es)?\b"
                r"|\bmerges?\s*(?:→|->)\s*push(?:es)?\b"),
     "commit-and-push procedure"),
    # An affirmative "the worker lands it". Third person singular only, so
    # "workers never land" and "the lead lands nothing" do not match — this
    # targets the instruction, not its negation.
    (re.compile(r"\bworkers?\s+(?:green-path-)?lands\b"), "worker performs the landing"),
    # Pushing the integration branch by name.
    (re.compile(r"\bpush(?:es|ing)?\s+(?:to\s+)?`?main`?\b"), "push to the integration branch"),
    # Gerund and slash-joined forms of the same procedure — "committing/pushing",
    # "commits and pushing". The verb-shape rules above anchor on the bare stem
    # and read straight past these.
    # NO whitespace around the slash: `committing/pushing` is one compound verb
    # and an instruction; `commit / push / merge` is the spaced enumeration of a
    # CLASS that the rhythm tables need, and the case below pins it as allowed.
    (re.compile(r"\bcommit(?:ting|s|)/push(?:ing|es)?\b"
                r"|\bpush\w*\s+(?:its|their|your|my|the)\s+own\s+\w*\s*docs?"),
     "commit-and-push procedure"),
    # The worker's landing authority, in the compound spelling. "the worker
    # lands" is caught above; "may green-path-land" is the same grant hyphenated
    # into a single verb.
    (re.compile(r"green-path-land"), "worker performs the landing"),
    # The file era named itself. Any of these compounds is a surface still
    # teaching that coordination travels as files.
    # `file-based` is banned OUTRIGHT rather than as `file-based <noun>`: the
    # noun-list form missed the reversed word order ("communication is
    # file-based"), and in a corpus whose whole point is that coordination is
    # NOT file-based there is no legitimate use of the token left.
    (re.compile(r"file-based"
                r"|\bhandoff files?\b|\bclose-out files?\b|\btask files?\b|\bbus-woken\b"),
     "file-era coordination vocabulary"),
    # Egress spellings that name no git command and so slipped every rule above.
    # Guarded by a leading negation-free assertion: "there is nothing to stage,
    # commit or push" is the sentence these surfaces SHOULD carry, so a bare
    # `commit or push` match would flag the correction itself.
    (re.compile(r"\bcommit(?:s|ting)? or push\b|\bbeyond push\b|\bpush it via\b"
                r"|\bland(?:s|ing)?\s+(?:its|their|your|my)\s+own\b"),
     "agent-side git egress"),
)

# (e) POLICY GRANTS. The prose rules above scan surfaces; these scan the policy
# JSON, because a retired convention can survive as an authorization token long
# after the prose stops teaching it — and the rendered contract table then puts
# it back in front of the agent. Only PRESCRIPTIVE fields are scanned:
# `git.push_rules` values and `stops_and_overrides[*].action`. A `forbidden`
# list is deliberately exempt — naming an action in order to deny it is the
# point of that field, and banning the word there would forbid saying "no".
# Regexes, not substrings: `green_path_eligible` legitimately contains `_path`,
# so the file-era rule needs a lookbehind rather than a blunt `in`.
# `authority.may_decide` is a GRANT list, and the retired model handed the lead a
# "worktree merge" outright. A fragment ban cannot separate that from the CTO's
# legitimate merge-AUTHORIZATION token, so this is a CLOSED PERMIT instead: any
# may_decide entry naming merge / push / landing must be on this list, which
# makes a NEW execution grant fail by default rather than needing to be
# anticipated. Same idiom as ROLE_TOOL_PERMITS above.
MAY_DECIDE_GIT_PERMITS = {
    "lead": frozenset(("landing_request_and_gated_cleanup",)),
    "cto": frozenset(("all_green_merge_to_main_green_path_authorization",)),
}
MAY_DECIDE_GIT_RE = re.compile(r"merge|push|land")

POLICY_FORBIDDEN_FRAGMENTS = tuple(re.compile(p) for p in (
    # retired push / landing conventions
    "self_push", "single_pusher", "worker_lands", "_lands_", "land_authorized",
    # retired file-era routing conventions
    "routing_token", "filename", r"\bfile_[a-z]+_to_",
    r"(?<!green)_path(?:_|$)",
))

# Lex the WHOLE namespace-qualified candidate — every character a tool name
# could plausibly be misspelt with, including `-` and further `.` segments — and
# reject it against TOOL_VOCAB afterwards. Narrowing the regex to the
# vocabulary's own shape does not merely fail to NAME a malformed token, it
# fails to SEE it: `coordination.deliverNow` yields no candidate at all, and a
# regex that stops at the first illegal character extracts the VALID PREFIX of
# `coordination.deliver-now` and waves it through. Both slip past the
# vocabulary, the set-equality and the role-permit rules together.
# `-` inside a segment and further `.` segments are part of the CANDIDATE, so a
# malformed name is lexed whole instead of being truncated to its valid prefix.
# At least one name character must follow the first dot, so a sentence-final
# "…the coordination." is prose, not a candidate.
TOOL_RE = re.compile(r"\b(?:coordination|workitems|git)\.[.-]*[A-Za-z0-9_-]+(?:[.-]+[A-Za-z0-9_-]+)*")
MARKER_RE = re.compile(r"(BEGIN|END) GENERATED:")

# Labels whose rule describes a THING TO DO, so the sentence that forbids it
# names the same words: "there is nothing to stage, commit or push" is the
# correction, not the drift. A line carrying a negation is skipped for these
# labels only — the retired-vocabulary rules stay unguarded, because naming a
# retired token at all is the violation however the sentence is framed.
NEGATION_GUARDED_LABELS = frozenset(("agent-side git egress",))
NEGATION_RE = re.compile(
    r"\bnot\b|\bnever\b|\bno\b|\bnothing\b|n't\b|\binstead of\b|\brather than\b")
# Clause boundaries. A fixed character window was the wrong shape: too wide and a
# correct sentence masks a stale one beside it, too narrow and the denial that
# sits just past the artefact stops registering. A clause is the unit prose
# actually negates in, so the guard uses the clause the match falls in.
# A period ending a sentence is followed by space or end-of-line; a period
# INSIDE an identifier is followed by a word character. Splitting on both was a
# latent defect in every clause-scoped guard in this file: the clause around a
# mention of `coordination.read_artefact` ended at `coordination`, so no guard
# could ever see the tool name it was supposed to recognise. That is why the
# daemon-read exemption had to be line-scoped, which in turn let a MIXED bullet
# spend one correct half's exemption on the other half. Same for
# `functions.exec_command`, `comparison.md`, `DESIGN.md`, `insights.md`.
CLAUSE_SPLIT_RE = re.compile(r"\.(?!\w)|[;—]|\s-\s")
# A CANDIDATE and an EXEMPTION do not want the same boundary, and conflating
# them was a defect in BOTH directions. ", but" joins two independent clauses,
# so with only `.`, `;` and the dash as boundaries every exemption in the file
# was spendable across it — "`Write` the close-out to disk, but handoffs are not
# files" kept its denial. Adding that boundary to `CLAUSE_SPLIT_RE` wholesale
# then broke the other direction, because an OBJECT may legitimately continue
# past a contrastive conjunction: "`Write` the report, but also the close-out to
# disk" is one write with two objects, and bounding the CANDIDATE there made the
# second one invisible.
#
# So the two scopes are separate. A candidate window uses `CLAUSE_SPLIT_RE`; an
# exemption test uses the wider boundary set here. A contrast asserts something
# about a DIFFERENT subject, which is exactly what an exemption must not borrow,
# while a coordinated object is still the same tool's object.
#
# `and`/`or` are deliberately NOT boundaries even here — and this line is drawn
# by GRAMMAR, not by which findings it happens to produce. They are how a list
# is written, and splitting on them separates list items from the predicate they
# share: "- `Read` — task briefs, handoffs, and close-outs are never read from
# disk" lost `never` for the first two kinds and flagged a correct sentence.
#
# The measured cost of drawing the line there, recorded honestly: it also gives
# up one incidental-negation catch in the base corpus
# (`roles/architect-agent.md:317`, where "…with no evaluation intent, or intent
# too vague…" masks an unrelated `no`). That catch was an ACCIDENT of splitting
# a list, and what it misses belongs to the already-documented residual class —
# a generic negation guard cannot tell an incidental `no` from a real denial at
# any width. Not flagging a correct sentence is worth more than an accident.
#
# `so`, `nor`, `because` and `since` ARE boundaries: they introduce a clause,
# never a list item. Leaving `so` out cost a REAL catch —
# `roles/lead-agent.codex.md:90` ("Read the worker close-out artefacts
# directly … , so process each on arrival"), where the parenthetical "do not
# hold one worker's finished close-out" otherwise masks the whole line.
#
# ...and the two conjunction groups need DIFFERENT punctuation, which requiring
# a comma for all of them got wrong. `because`, `since`, `while`, `whereas`,
# `although`, `though` and `unless` are inherently SUBORDINATING — they can
# introduce a clause only, never a list item, and English does not put a comma
# before them. "`Read` the close-out from disk because the daemon is not
# available" carried its `not` straight across the boundary and exempted itself.
# They are boundaries with or without a comma. `but`, `yet`, `so` and `nor` can
# coordinate, so they still need the comma to count as a clause break.
EXEMPTION_SPLIT_RE = re.compile(
    r"\.(?!\w)|[;—]|\s-\s"
    r"|,\s+(?:but|yet|so|nor)\b"
    r"|\s+(?:because|since|while|whereas|although|though|unless)\b")
# ...and the em dash has TWO grammatical roles, which is the other half of the
# same lesson. A LONE dash separates clauses ("...classify a finding — the
# permanent documents on disk"); a PAIR brackets an apposition ("coordination
# records — handoffs, dispatches, verdicts — are read with X"), whose host
# clause runs straight through it with one subject and one verb. Treating every
# dash as a boundary cut that single sentence into three clauses and lost
# whichever half the guard needed — the negation, or the tool name. Measured on
# both: five correct corpus sentences flagged by the record-read rules, and
# "The PM never — even under option D — publishes its branch" flagged by the
# egress rule because `never` fell outside. So within each hard-bounded segment
# the dashes pair off left to right and each pair is neutralised; an odd one out
# keeps its separator role.
_HARD_BOUND_RE = re.compile(r"\.(?!\w)|;")


def _dashes_parenthetical(text):
    out = list(text)
    start = 0
    for bound in [m.start() for m in _HARD_BOUND_RE.finditer(text)] + [len(text)]:
        idx = [i for i in range(start, bound) if text[i] == "—"]
        for a, b in zip(idx[0::2], idx[1::2]):
            out[a] = out[b] = ","
        start = bound + 1
    return "".join(out)


def _bounds(text, start, end, splitter):
    """(left, right) offsets of the segment `text[start:end]` sits in, bounded by
    `splitter`. Boundaries are found on a dash-neutralised copy, which is
    character-for-character the same length, so the offsets index the ORIGINAL
    text unchanged."""
    scan = _dashes_parenthetical(text)
    left = 0
    for m in splitter.finditer(scan, 0, start):
        left = m.end()
    m = splitter.search(scan, end)
    right = m.start() if m else len(text)
    return left, right


def clause_bounds(text, start, end):
    """CANDIDATE scope: the clause `text[start:end]` sits in. Exposed separately
    from `clause_around` because a rule that must keep a candidate inside the
    clause — not merely test an exemption against it — needs offsets, not the
    slice."""
    return _bounds(text, start, end, CLAUSE_SPLIT_RE)


def clause_around(text, start, end):
    """CANDIDATE scope, as a slice."""
    left, right = clause_bounds(text, start, end)
    return text[left:right]


def exemption_scope(text, start, end):
    """EXEMPTION scope: narrower than the clause — a contrastive conjunction
    ends it, because a contrast asserts something about a different subject and
    an exemption must not be borrowed across one. See `EXEMPTION_SPLIT_RE`."""
    left, right = _bounds(text, start, end, EXEMPTION_SPLIT_RE)
    return text[left:right]


# The determiner/modifier run that may sit between a tool and the HEAD NOUN of
# its object. The list is CLOSED on purpose: any word outside it ends the match,
# so the object cannot reach past a conjunction into a coordinated noun the tool
# never governs. Two correct shipped sentences prove why that matters —
# "`Edit`s in place plus a new handoff record" (`lite/pm-agent.claude.md:12`)
# and "rename the ADR **document** and publish a NEW superseding verdict record"
# (`lite/architect-agent.claude.md:15`). In both, the coordination noun belongs
# to a LATER conjunct under `publish`; the write tool's own object is the plan
# and the ADR. A clause-bounded free search still flagged both, because a
# conjunction is not a clause boundary — only anchoring the object at the tool
# tells them apart from "`Write` the close-out to disk".
#
# Shared by rules (g) and (i2) so a second hand-maintained copy cannot go
# quietly out of date.
#
# The run is bounded by a STOP LIST, not by an allow-list of permitted
# modifiers. An allow-list was tried first and is the wrong instrument: it went
# stale on the very first sentence outside it. "when you `Write` a reviewer task
# brief" silently stopped firing — `reviewer` was not among the blessed
# determiners — and a rule that quietly loses a defect it used to catch is the
# exact failure this whole gate exists to prevent; every future modifier would
# have cost the same silent miss. So the run admits ANY word and ends where the
# object phrase ends.
#
# The stop list is CONJUNCTIONS, SUBORDINATORS AND NEGATIONS — deliberately NOT
# prepositions, a distinction that was measured rather than assumed. A
# coordinating conjunction hands the next noun to a DIFFERENT verb, which is the
# whole defect: in "`Edit`s in place plus a new handoff record" and "rename the
# ADR document and publish a NEW superseding verdict record" the coordination
# noun belongs to `publish`, and `plus`/`and` are precisely what say so. A
# preposition does the opposite — it keeps one phrase going. "the publication OF
# the close-out" is a single object, and stopping at `of` silently lost that
# case too, on the second attempt at this list. Negations stop the run because
# "`Write` the ADR, not the close-out" names the close-out in order to exclude
# it.
#
# ...and a COORDINATOR is not unconditionally a boundary, which is the third
# correction this list needed. `and`/`or`/`plus` join OBJECTS as readily as they
# introduce predicates, so stopping at them outright made a plain violation
# silent: "`Write` the report and the close-out to disk" is one write with two
# objects, and the old free 80-character search caught it. What distinguishes
# the two uses is what FOLLOWS the coordinator — a verb starts a new predicate
# ("rename the ADR document AND PUBLISH a verdict record"), a noun phrase
# continues the object list. So a coordinator stops the run only when an action
# verb follows it. `ACTION_VERB` is a closed list and an incomplete one fails
# toward a VISIBLE false positive (an unlisted verb reads as a continued
# object), never toward a silent miss — the right side to fail on, and the same
# trade this file makes at the commit-denial list.
#
# The stop test uses `\b`, not `[\s,]`: `and/or` is a single token to the
# character class below, so a `[\s,]`-terminated test never saw the `and` and
# waved "`Edit` the ADR and/or publish a handoff record" straight through.
#
# The {0,16} cap stays ON TOP of the stop list, but the REAL bound is the
# caller's character window. The cap was {0,7} and that was itself a silent
# miss: "the new full final approved local worker cycle close-out" carries eight
# modifiers and stayed well inside the 80-character window the rule already
# allows, so the count cap, not the grammar, decided the verdict.
#
# `but` sits with the COORDINATORS, not the hard stops, for the same reason:
# "`Write` the report, but also the close-out to disk" is one write with two
# objects. It is a hard stop only when a verb follows it.
#
# `ACTION_VERB` must be a WHOLE word — `(?=[\s,])`, not `\b`. `\b` matched the
# `draft` inside `draft-stage`, so "`Write` the report and draft-stage close-out
# to disk" read a coordinated noun phrase as a new predicate and went silent.
# An ambiguous form now stays INSIDE the object run and fails visibly, which is
# the direction this list is supposed to fail in.
#
# There is NO repetition cap. `{0,7}` then `{0,16}` were both tried and both
# decided verdicts the grammar should have decided — seventeen short modifiers
# fit in 52 characters, well inside the window the caller already slices. The
# caller's character window IS the bound; a second, looser bound expressed in
# words could only disagree with it, and did.
#
# The run is NON-GREEDY, and that is load-bearing rather than cosmetic. A tool's
# object is the NEAREST matching noun. Greedy, the run swallowed a whole 64-
# character window and matched a LATER occurrence of the same kind, which then
# dragged the exemption scope along with it: in "`Read` the handoff from disk,
# but the WIP handoff draft uses a staging path" the candidate bound itself to
# the second `handoff`, so the span reached past `, but` and collected the
# staging exemption that belongs to the other clause. Measured, not theorised —
# it re-broke a case that had already been fixed.
#
# The character class carries Markdown emphasis (`*`, `_`). Without it
# "`Write` **the close-out** to disk" could not be reached at all: the run
# stopped dead on the first asterisk, and bold is how these contracts emphasise
# precisely the nouns this rule is looking for.
OBJECT_HARD_STOP = (r"(?:nor|then|while|whereas|although|though"
                    r"|because|unless|before|after|once|when|whenever|if"
                    r"|not|never|instead|rather)")
OBJECT_COORD = r"(?:and/or|and|or|plus|but|yet|so)"
# This list exists to recognise a NEW PREDICATE, so it admits the two forms a
# predicate actually takes in these contracts — the bare imperative ("…, publish
# the record") and the third person ("…, the lead publishes it") — and NOT every
# inflection of the stem. The `\w*`/`\w+` stems it used to carry swept up
# PARTICIPLES, which are adjectives here, not predicates: "`Write` — PRDs,
# updated close-outs, and ADRs" stopped dead on `updated` and the close-out
# stopped being the write's object, a silent miss in a plain write affordance.
# Every stem below is therefore spelt out to its predicate forms. Losing the
# participles costs nothing a predicate needs, and it is the direction that
# RESTORES detection: "plans and captured close-outs" now reaches its object.
ACTION_VERB = (r"(?:publish(?:es)?|delivers?|commits?|stages?|push(?:es)?|lands?"
               r"|reads?|writes?|edits?|sends?|routes?|records?|captures?"
               r"|validates?|verif(?:y|ies)|reports?|surfaces?|emits?|drafts?"
               r"|creates?|updates?|amends?|renames?|moves?|opens?|invokes?"
               r"|calls?|uses?|adds?|removes?|names?|cites?|attach(?:es)?"
               r"|includes?|treats?|bounces?|clears?|delegates?|escalates?)")
#
# Markdown link and parenthetical delimiters are admitted too. "`Write` the
# [close-out](closeout.md) to disk" produced no candidate at all because `[`
# ended the run, and these contracts link and parenthesise constantly. The cost
# is the visible-false-positive side — "`Write` the ADR (see the close-out for
# context)" now reads the parenthetical as continued object — which is the side
# this file fails on by policy, and the caller's window still bounds it.
#
# ...and an INLINE CODE SPAN is a modifier like any other. The backtick was
# admitted at the two ends of the run but not inside it, so the run died on the
# first mid-list code span — and a path in these contracts is written
# `docs/plans/`, in backticks, essentially always. "- `Write` — plans under
# `docs/plans/`, and close-outs to disk" therefore raised no candidate: the
# object list stopped at the first path it named. Found by a selftest case that
# spelt its paths the way the corpus does, after the same case without backticks
# had already passed.
#
# A COMMA before a new action predicate ends the object run for the same reason
# a coordinator does — it is the asyndetic spelling of the very same thing, and
# the guard above could not see it because it keys on the coordinator WORD.
# Measured: the corpus's ADR-collision repair paragraph
# (`roles/architect-agent.codex.md:46`) writes "`functions.apply_patch` its
# internal references, publish a NEW `design_review` record citing the prior
# record's id" — correct prose in which `design_review` is the object of
# `publish`, a daemon act, and not of the write tool three phrases back. With
# only the coordinator form guarded, the run walked straight through the comma
# and made that sentence the write tool's object, which is why the kind had to
# be held off rule (g) entirely. The guard fires at the token BEFORE the comma,
# because that is where the comma is visible — the run consumes a comma as the
# previous token's trailing separator, so a lookahead at the next token's start
# can no longer see it. Commas between NOUNS are untouched: "`Write` the
# close-out, the handoff, and the addendum" has no verb after any comma.
#
# Both spellings share ONE verb list, and that list holds PREDICATE forms only
# (see `ACTION_VERB`). That matters here: while the list still carried bare
# stems, a participle used ATTRIBUTIVELY ended the run in both spellings —
# "`Write` — PRDs, updated close-outs, and ADRs" stopped dead on `updated` and
# the close-out stopped being the write's object. Keeping the two spellings on
# one list is what makes that a single fix rather than two; the selftest pins
# them as a pair below, because a later editor narrowing one spelling and not
# the other is the thing that could silently diverge.
OBJECT_LEAD = (
    r"^[\s`,;:*_\[(]*(?:of\s+)?"
    r"(?:(?!" + OBJECT_HARD_STOP + r"\b)"
    r"(?!" + OBJECT_COORD + r"\b[\s,]+" + ACTION_VERB + r"(?=[\s,]))"
    r"(?![\w'’./*_\[\]()`-]+\s*,\s*" + ACTION_VERB + r"(?=[\s,]))"
    r"[\w'’./*_\[\]()`-]+[\s,]+)*?"
    # ...and the run may END on delimiters too, not only begin on them: in
    # "`Write` the [close-out](closeout.md)" the `[` sits between the last
    # modifier and the noun, so without this the prefix could not be consumed at
    # all and the link was invisible. Punctuation only — no words pass here.
    r"[\s`,;:*_\[(]*")
OBJECT_LEAD_RE = re.compile(OBJECT_LEAD)


def governed_objects(window, noun_re):
    """EVERY noun in `window` the tool governs — each one reachable from the
    tool through nothing but the permitted modifier/coordinator run.

    Matching only the NEAREST object was not enough, and the hole it left was
    the mirror of the greedy one: in "`Write` the WIP handoff and the close-out
    to the staging path" the candidate bound to the WIP handoff, that object
    took the staging exemption, and the whole write was skipped — carrying the
    forbidden close-out with it. An exemption belongs to the OBJECT that earns
    it, so every governed object is enumerated and judged on its own.

    A noun sitting inside an UNCLOSED parenthesis is NOT governed, however well
    the run reads up to it. Admitting `(` so that "`Write` the (draft)
    close-out" could be seen at all also made a parenthetical APPOSITION
    traversable, and that flagged two correct shipped sentences immediately —
    the skill-file reads at `roles/lead-agent.codex.md:66` and
    `roles/worker-agent.codex.md:61`, whose "(worker close-out / merge close-out
    / …)" says what the TEMPLATES are, not what the read opens. Balance is the
    discriminator: a parenthetical that CLOSES before the noun is a modifier
    inside the object phrase; one still OPEN at the noun is an apposition
    standing beside it."""
    return [nm for nm in noun_re.finditer(window)
            if window[:nm.start()].count("(") <= window[:nm.start()].count(")")
            if OBJECT_LEAD_RE.fullmatch(window[:nm.start()])]


def modifier_scope(text, spans, span, left, right):
    """The part of clause `text[left:right]` a POST-MODIFIER exemption may be
    claimed from, for the governed object at `span`, given every governed
    object's span in `spans`.

    Clause scope is the right width for a NEGATION — "task briefs, handoffs,
    and close-outs are never read from disk" negates the whole list from one
    shared predicate, and narrowing that flagged a correct sentence. It is the
    WRONG width for a daemon-read exemption, which attaches to the object it
    modifies: "- `Read` the handoff with coordination.read_artefact and the
    close-out from disk" spends the handoff's exemption on the close-out
    standing beside it, and passed whole.

    The discriminator is POSITION relative to the list. A modifier sitting
    BETWEEN two objects belongs to the one it follows, so an object's own scope
    ends where the next object begins. A modifier before the FIRST object or
    after the LAST is a lead-in or a shared tail — "`Read` the handoff and the
    close-out with `coordination.read_artefact {id}`" is one call covering both
    — so those two regions stay available to every object in the list. The
    three regions are joined by a newline, which no exemption pattern can match
    across, so nothing is created at a seam."""
    inside = sorted(s for s in spans if left <= s[0] < right)
    if not inside:
        return text[left:right]
    a, _b = span
    nxt = next((s[0] for s in inside if s[0] > a), right)
    head = text[left:inside[0][0]]
    own = text[max(a, left):max(min(nxt, right), max(a, left))]
    tail = text[min(max(inside[-1][1], left), right):right]
    return "\n".join((head, own, tail))


# The CLOSED daemon-tool vocabulary the prose may name.
TOOL_VOCAB = frozenset((
    "coordination.publish_artefact", "coordination.list_artefacts",
    "coordination.read_artefact", "coordination.settle_artefact",
    "coordination.deliver", "coordination.whoami", "coordination.list_sessions",
    "coordination.resolve_recipient", "coordination.ask",
    "workitems.list", "workitems.get",
    "git.push_branch", "git.request_landing",
))

# NOTE — there is deliberately NO exemption list for `git.<policy-field>` names
# (`git.forbidden`, `git.edit_scope`, …). An exemption keyed on the name alone
# is context-free: it would equally excuse an ACTIVE instruction that named one,
# and a tool renamed onto one of those names would evade the closed vocabulary
# entirely. Prose that wants to cite a contract row names the row
# ("the contract block's `forbidden` git row"), not a `git.`-prefixed token.
#
# Which roles may be TAUGHT each landing/push tool. The daemon's socket gate is
# the boundary; this keeps the prose from teaching a role a call it would be
# refused. The FORBIDS map is derived from the role manifest below, so a role
# added later is covered without touching this table.
ROLE_TOOL_PERMITS = {
    "git.request_landing": frozenset(("lead",)),
    "git.push_branch": frozenset(("lead", "worker")),
}

WEIGHTS = ("roles", "lite")
# CommonMark: a fence may be indented at most THREE spaces. Matching a stripped
# line instead would make ordinary four-space-indented text open a fence — and a
# line reading "    ```historical" inside an indented code sample would then
# exempt everything after it from every rule below.
FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
EXEMPT_FENCE = "historical"


def annotate(text):
    """([(lineno, line, fence_info_or_None)], unclosed_or_None). `fence_info` is
    the info string of the fenced block the line sits in (fence delimiters
    included), else None. `unclosed` is (lineno, info) for a fence still open at
    EOF."""
    out = []
    open_char = None
    open_len = 0
    open_line = 0
    info = None
    for i, line in enumerate(text.split("\n"), 1):
        m = FENCE_RE.match(line)
        if open_char is None:
            if m:
                open_char, open_len, open_line = m.group(1)[0], len(m.group(1)), i
                info = (m.group(2).strip().split() or [""])[0].lower()
                out.append((i, line, info))
                continue
            out.append((i, line, None))
        else:
            out.append((i, line, info))
            if m and m.group(1)[0] == open_char and len(m.group(1)) >= open_len \
               and not m.group(2).strip():
                open_char, open_len, info = None, 0, None
    return out, ((open_line, info) if open_char is not None else None)


def substrate_lines(path, relpath):
    """Scannable lines of a surface: (lineno, line). Lines inside a fenced
    ```historical block are quoted history, not current instruction, and are
    exempt from EVERY substrate rule — not only the legacy-token one. An
    UNCLOSED fence is itself a finding: otherwise opening ```historical and
    never closing it exempts the whole tail of a file."""
    with open(path, "rb") as fh:
        text = fh.read().decode("utf-8", errors="replace")
    rows, unclosed = annotate(text)
    if unclosed is not None:
        findings.append(
            f"SUBSTRATE-FENCE {relpath}:{unclosed[0]}: fenced block "
            f"(info={unclosed[1] or 'none'!r}) is never closed")
    for n, ln, info in rows:
        # A GENERATED block wrapped in an exempt fence renders normally (the
        # renderer has no fence awareness) while every substrate rule looks away
        # from its content — an exemption the doctrine layer must not be able to
        # buy by quoting itself as history.
        if info == EXEMPT_FENCE and MARKER_RE.search(ln):
            findings.append(
                f"SUBSTRATE-FENCE {relpath}:{n}: a GENERATED marker may not live "
                f"inside an exempt ```{EXEMPT_FENCE} block")
    return [(n, ln) for n, ln, info in rows if info != EXEMPT_FENCE]


def surface_files(weight):
    return sorted(
        p for p in glob.glob(os.path.join(root_dir, weight, "**", "*.md"), recursive=True)
        if os.path.isfile(p)
    )


# The boundary contract is prose the roles are bound by, so it teaches the same
# substrate they do — but it belongs to no weight and to no role, so it joins
# the legacy/vocabulary scan ONLY. Feeding it to the per-role equality or permit
# rules would attribute its tool mentions to a weight it is not part of.
def root_surfaces():
    p = os.path.join(root_dir, "ROLES.md")
    return [p] if os.path.isfile(p) else []


# ...but the ARTEFACT-KEYED rules (g/h/i/j) are role-independent by construction
# — they state what is true of a coordination record, an egress, and the
# close-out order for EVERYBODY — so the weight-shaped iteration was never what
# scoped them, and excluding ROLES.md from them left the framework's CANONICAL
# semantics table as the one surface those rules could not see. Measured: the
# rhythm table said the operator green-lights the local commit individually
# while its own sequence column commits first, and no rule was looking. Each
# group is scanned separately so a rule that de-duplicates per file still does.
def artefact_surface_groups():
    return [surface_files(w) for w in WEIGHTS] + [root_surfaces()]


def rel(path):
    return os.path.relpath(path, root_dir).replace(os.sep, "/")


def weight_roles(weight):
    """Roles a weight OWES, from its POLICY MANIFEST — never from which base
    files happen to exist. Discovering roles from the files on disk means
    deleting a base file removes that role from the comparison entirely: the
    weight loses its whole base and the equality check goes quiet."""
    return set(full if weight == WEIGHTS[0] else lite)


def role_surfaces(weight, role):
    """A role's base file PLUS every shipped overlay. The overlays are part of
    the union on purpose: a tool an overlay contributes is a tool that weight
    teaches, so deleting it from the base alone must not read as parity."""
    files = []
    base = os.path.join(root_dir, weight, f"{role}-agent.md")
    if os.path.isfile(base):
        files.append(base)
    files.extend(sorted(p for p in glob.glob(
        os.path.join(root_dir, weight, f"{role}-agent.*.md")) if os.path.isfile(p)))
    return files


def substrate_check():
    if not any(os.path.isdir(os.path.join(root_dir, w)) for w in WEIGHTS):
        findings.append("SUBSTRATE: neither roles/ nor lite/ exists under the checked root")
        return

    # (a) legacy tokens + (c) closed vocabulary — over every surface in both
    # weights PLUS the root boundary contract.
    tools_by_file = {}
    for path in [p for w in WEIGHTS for p in surface_files(w)] + root_surfaces():
        r = rel(path)
        found = set()
        for lineno, line in substrate_lines(path, r):
            # Case-folded for the legacy rules: `Commit + push` at the start of a
            # sentence is the same instruction as `commit + push`, and a
            # case-sensitive rule would wave the capitalised half through. The
            # TOOL_RE scan below stays case-SENSITIVE — a tool name is an
            # identifier, and `Coordination.Deliver` is a different string the
            # closed vocabulary should reject, not silently accept.
            low = line.lower()
            for tok in SUBSTRATE_TOKENS:
                if tok in low:
                    findings.append(f"SUBSTRATE-LEGACY {r}:{lineno}: {tok}")
            for rx, label in SUBSTRATE_PATTERNS:
                m = rx.search(low)
                if not m:
                    continue
                # CLAUSE-LOCAL, not whole-line. A whole-line guard lets a
                # correct "never/nothing" clause at the start of a long line
                # mask a stale affirmative clause later in the same line — the
                # exact masking a reviewer found in round 7. +-60 chars is about
                # one clause either side of the match.
                if label in NEGATION_GUARDED_LABELS and NEGATION_RE.search(
                        exemption_scope(low, m.start(), m.end())):
                    continue
                findings.append(f"SUBSTRATE-LEGACY {r}:{lineno}: {label}")
            for tool in TOOL_RE.findall(line):
                found.add(tool)
                if tool not in TOOL_VOCAB:
                    findings.append(f"SUBSTRATE-VOCAB {r}:{lineno}: {tool}")
        tools_by_file[path] = found

    # (b) per-role tool-set equality, per weight, union over base + overlays.
    shipped = {w: weight_roles(w) for w in WEIGHTS}
    for weight in WEIGHTS:
        for role in sorted(shipped[weight]):
            base = os.path.join(root_dir, weight, f"{role}-agent.md")
            if not os.path.isfile(base):
                findings.append(
                    f"SUBSTRATE-BASE {weight}/{role}-agent.md: the policy manifest ships "
                    f"role '{role}' in this weight but its base playbook is missing")
    for role in sorted(shipped[WEIGHTS[0]] & shipped[WEIGHTS[1]]):
        sets = {}
        for weight in WEIGHTS:
            acc = set()
            for path in role_surfaces(weight, role):
                acc |= tools_by_file.get(path, set())
            sets[weight] = acc
        for weight, other in ((WEIGHTS[0], WEIGHTS[1]), (WEIGHTS[1], WEIGHTS[0])):
            only = sorted(sets[weight] - sets[other])
            if only:
                findings.append(f"SUBSTRATE-SET {role}: only in {weight}: " + " ".join(only))

    # (g) COORDINATION ARTEFACTS ARE NEVER FILES — for every role, whatever its
    # write scope. Rule (f) below keys on an EMPTY write scope, which is exactly
    # why it could not see this: lead and worker legitimately write permanent
    # documents, so (f) skips them entirely and their overlays kept instructing
    # `Write`/`apply_patch` on close-outs and task briefs. This rule keys on the
    # ARTEFACT instead of the role: a write tool named on the same line as a
    # coordination kind is a violation no matter who holds the pen. The
    # `.wip-handoff-staging` draft is the single sanctioned exception, and a line
    # naming it is exempt.
    # Write TOOLS plus the lifecycle VERBS that move a record around as if it
    # were a file. `mv`, "move-and-commit" and "update the artefact" were each
    # shipped drift the tool-token rule could not see: the daemon's wire has no
    # update operation at all, so amending a published record is not a thing
    # that can be done, however the sentence phrases it.
    # `(?!\w)` after the closing backtick keeps the NOUN form out: "changes are
    # `Edit`s in place" names the tool as a thing, not as an instruction to use
    # it, and reading it as a write made a correct sentence
    # (`lite/pm-agent.claude.md:12`) depend on the object model to stay quiet.
    #
    # A SUBJECT OPENS ITS CLAUSE, and this says so in the one way that costs
    # nothing: every branch is ZERO-WIDTH — `^` plus fixed-width lookbehinds —
    # so the match still starts at the actor and `clause_bounds()` /
    # `exemption_scope()` below see exactly the offsets they saw before.
    # CONSUMING the opener instead would drag `wm.start()` back across the very
    # separator it matched, widening the exemption scope by one clause, and a
    # widened exemption scope is a SILENT MISS — the failure direction this file
    # spends most of its comments avoiding.
    #
    # The list is the clause openers this corpus actually writes: the start of
    # the line, a list marker, a separator, a coordinator, and the subordinators
    # (`that` included, so "Check that the lead commits the close-out" — the
    # ordinary way these contracts phrase a third-person requirement — is still
    # reached).
    #
    # It is DERIVED FROM NOTHING, so it was checked against the file's own
    # authority on the question instead: `CLAUSE_SPLIT_RE` is where this program
    # already says what separates two clauses (`.` not inside an identifier,
    # `;`, a spaced hyphen, and the em dash). Three of those four were here
    # already — `\s-\s` arrives through `(?<=[-*]\s)`, which is not bullet-only.
    # THE EM DASH WAS NOT, and its absence was a silent miss the narrowing
    # itself introduced: "- The sequence is explicit — the lead commits the
    # close-out to disk." matched before and stopped matching after. Found by
    # the round-7 gate, which is the correct place to find it and the wrong
    # place to have left it.
    #
    # The dash opener is NAMED, because it is the one opener whose grammar is
    # ambiguous and the ambiguity has to be resolved outside the regex. A LONE
    # dash separates clauses, so a subject may open after it; a PAIRED dash
    # brackets an apposition ("the record — the worker commits the close-out
    # describes — is not a file"), whose host clause runs straight through with
    # one subject and one verb, so what follows the opening dash is NOT a new
    # subject and admitting it would hand the round-6a false positive straight
    # back in a different costume. `_dashes_parenthetical()` is the file's
    # existing answer to exactly that question and is reused verbatim at the
    # match site below rather than re-derived here.
    SUBJECT_OPENER = (
        r"(?:^|(?<=[-*]\s)|(?<=[.;:,]\s)|(?<=\d[.)]\s)"
        r"|(?P<subject_after_dash>(?<=—\s))"
        r"|(?<=\band\s)|(?<=\bor\s)|(?<=\bbut\s)|(?<=\bnor\s)|(?<=\bso\s)"
        r"|(?<=\byet\s)|(?<=\bthen\s)|(?<=\bif\s)|(?<=\bwhen\s)|(?<=\bonce\s)"
        r"|(?<=\bafter\s)|(?<=\bbefore\s)|(?<=\bwhile\s)|(?<=\buntil\s)"
        r"|(?<=\bunless\s)|(?<=\bbecause\s)|(?<=\bsince\s)|(?<=\bwhether\s)"
        r"|(?<=\bthat\s)|(?<=\bwhere\s)|(?<=\bthough\s)|(?<=\balthough\s))")
    # The actor phrase itself is UNCHANGED — the fix adds a required position,
    # it does not shorten the list of subjects (see the residual note below).
    ACTOR_COMMITS = r"\b(?:the )?(?:lead|worker|agent|dispatcher)s? commits? the\b"
    WRITE_TOOL_RE = re.compile(
        r"`(?:Write|Edit|MultiEdit)`(?!\w)|functions\.apply_patch|apply_patch"
        r"|\bmove-and-commit\b|\bpublish-mv\b|\bmv\b"
        # `commit the` joins the other English lifecycle verbs, and it had to
        # once the object run learned to stop at a new predicate: "`Write` the
        # ADR, commit the close-out to disk" is TWO instructions, and cutting
        # the first one's reach at the comma left the second one named by
        # nothing. It is safe for the same reason the rest of this list is —
        # the rule fires on the governed OBJECT, so committing a durable
        # document ("commit the ADR under docs/adr/", "commit the plan
        # document") raises no candidate at all, while committing a record does.
        # IMPERATIVE ONLY, and measured: `commits the` is the plural NOUN in
        # this corpus, not the verb — "`<SHA-list of all commits the close-out
        # describes>`" (`roles/worker-agent.claude.md:213`, `:215`) is a commit
        # LIST that the close-out describes, and admitting the `s` flagged both
        # lines. `\bupdate the\b` above is singular for the same reason. The
        # cost was the third-person spelling ("the lead commits the close-out"),
        # which is no longer a cost: it is admitted below, subject-anchored.
        # (This note used to say rule (h) reached it from the actor side. It
        # does not — see the correction at the residual note below.)
        # The ENGLISH lifecycle verbs are matched CASE-INSENSITIVELY, and they
        # have to be: this rule scans the raw `line`, not the lowercased copy
        # the object model uses, so every one of them was silent at the start of
        # a sentence — "- Commit the close-out to disk." and "- Update the
        # close-out." are the ordinary imperative register of these bullets.
        # Scoped `(?i:...)` rather than a flag on the whole pattern, because the
        # TOOL names above are case-SIGNIFICANT: `\`Write\`` is a tool and
        # "write" is a verb this file must not own.
        #
        # The third-person form is subject-anchored instead of admitting bare
        # `commits`, which is the plural NOUN in this corpus ("`<SHA-list of all
        # commits the close-out describes>`", `roles/worker-agent.claude.md:213`).
        #
        # An actor word in front of it is NOT enough, and assuming it was is the
        # defect this branch's round-6a gate found. "the worker commits" is
        # equally that same plural noun with an actor qualifier instead of a
        # quantifier — "review the worker commits the close-out describes" is
        # the shipped SHA-list construction with `all` swapped for `the worker`,
        # and it fired. What separates them is SUBJECT POSITION: a subject opens
        # its line, follows a clause separator, or follows a conjunction, while
        # an actor sitting behind a transitive verb is that verb's OBJECT and the
        # `commits` after it is a noun. So the opener is required, and it is
        # required as a NARROWING — every subject position that fired before
        # still fires (bullet, comma, full stop, subordinator, coordinator: five
        # selftest positives below), because deleting the form to kill the false
        # positive would buy a silent miss, which is the worse trade. The added
        # assertion is zero-width and purely additive, so no sentence that the
        # unguarded form declined can start matching: this can only narrow.
        #
        # RESIDUAL, stated rather than discovered: an actor introduced by a bare
        # transitive verb with no `that` ("Ensure the lead commits the close-out
        # to disk") is now silent HERE. That is the price of the discrimination
        # — the false positive is that same shape — and it is bounded only by
        # `that` being on the opener list, so the spelling these contracts
        # actually use ("Check that the lead commits …") is still reached.
        # NOTHING ELSE CATCHES IT: the earlier note above that rule (h) reaches
        # the actor side was wrong twice over — (h) matches push/land/merge
        # egress verbs, not a commit, and its actor list deliberately EXCLUDES
        # `lead` and `worker` because those two are the ones the gate admits.
        # A comfortable claim about a second net that does not exist is worse
        # than the residual it was written to soften.
        r"|(?i:\bcommit the\b|\bupdate the\b|\bamend(?:s|ing)? the\b"
        r"|\brename(?:s|d)? the\b"
        r"|" + SUBJECT_OPENER + ACTOR_COMMITS + r")")
    # THE KIND SET IS CLOSED, and this list is the checker's copy of it
    # (`docs/protocols/coordination-records.md` §"The thirteen kinds"). Two
    # spelling families reach the corpus and both must be here: the PROSE name
    # ("the merge close-out", "the risk triage") and the daemon's own MACHINE
    # name, which is what the surfaces actually write when they show a call —
    # `{kind:"merge_closeout"}`, `wip_handoff`, `risk_triage`, `code_review`.
    # The machine spellings differ from the prose ones only by the separator,
    # so every separator class here admits `_` as well; `code_review` had no
    # prose form on the list at all, and only its underscore spelling is added,
    # because bare "code review" is ordinary English this rule must not own.
    # `dispatch` alone is deliberately still absent — it is a verb before it is
    # a kind, and `dispatch brief` is the only unambiguous form (residual).
    COORD_ARTEFACT_RE = re.compile(
        r"\btask brief|\btask file|\bclose-?outs?\b|\bhandoffs?\b|\baddendum\b|\brisk[-_ ]triage\b"
        r"|\bcode_reviews?\b"
        # `acknowledgment` carries a lookbehind the other kinds do not need. It
        # is the one kind that is also an ordinary English ACT, and the corpus
        # writes that act as a hyphenated compound — "under standard
        # **override-with-acknowledgment path**" (`roles/qa-agent.md:349`,
        # `roles/worker-agent.claude.md:310`) is an AUTHORITY route, not a
        # record. It belongs HERE, on the canonical list, not on each derived
        # copy: (i1), (i2) and (i3) derive their kind lists from this pattern,
        # so a guard added only downstream is inherited by nobody and the false
        # positive comes straight back through (g).
        #
        # The guard NAMES the three compounds instead of excluding any hyphen,
        # and the direction is the reason. A blanket `(?<!-)` also swallows
        # `worker-acknowledgment file` — a hyphenated spelling of the RECORD —
        # and a swallowed record is a SILENT miss. Naming them fails the other
        # way: an unlisted compound flags, loudly, in CI, where it is one line
        # to add. Measured over the whole corpus, the hyphen-prefixed forms are
        # exactly `with-` (42), `pending-` (3) and `post-` (2); `-acknowledged`
        # and `-acknowledgeable` are other words and never matched at all.
        r"|\bclarification artefact\b"
        # ...and the `<kind> record` form, which is unambiguous for exactly the
        # kinds whose BARE head noun is not. `dispatch`, `task` and
        # `clarification` are each a verb or an ordinary noun before they are a
        # kind, which is why none of them is on this list bare — but "the
        # dispatch record" names the record and nothing else, and leaving the
        # qualified form off meant rule (g) could not see a write of three
        # closed kinds at all. The read rules reached two of them by their own
        # additions, which is precisely the two-hand-maintained-lists failure
        # this file keeps re-deriving away: the WRITE side had no such patch.
        # `records?` and not `record` — the plural is the kind's own plural.
        r"|\bdispatch records?\b|\btask records?\b|\bclarification records?\b"
        # ...and the same qualified form for the kinds whose PROSE name is a
        # document. "the design review" is an act and "the test strategy" is a
        # document the QA role legitimately writes, which is why their bare
        # prose sits in `COORD_VERDICT_RE` behind a document-home exemption —
        # but "the design review RECORD" says which of the two it means, so it
        # belongs on the unambiguous list where every derived rule inherits it.
        # Without this, rule (g) saw only the machine spellings and
        # "`Write` the code review record to disk" was a silent miss.
        r"|\bcode[- ]review records?\b|\bdesign[- ]review records?\b"
        r"|\btest[- ]strategy records?\b"
        r"|\b(?<!with-)(?<!pending-)(?<!post-)acknowledg(?:e?ment)s?\b|\bdispatch brief\b"
        # These kinds have NO file form at all for anybody, which is what makes
        # the rule safe with no exemption. `verdict` / `strategy` are handled
        # separately below — they DO have a legitimate document form.
        r"|\breview task brief\b|\bwip[-_ ]handoff\b|\bmerge[-_ ]close-?out\b")
    # ...and the two nouns that were excluded outright, which is how an entire
    # verdict-file workflow survived three rounds of this gate. They are not
    # unsafe, only ambiguous: the architect's long-form REPORT and ADR and the
    # designer's ux-review verdict really are documents, and those sentences
    # name their home. So the noun is policed, and the DOCUMENT SURFACE — not
    # the role — is what buys the exemption. A verdict sentence that names no
    # document home is talking about the record, and the record has no file.
    # `design_review` sits HERE, on the document-ambiguous half, in its MACHINE
    # spelling only — `{kind:"design_review"}` names the record, while "the
    # design review" is ordinary English for the act and the long-form report is
    # a real document with a real home. The write side had it on no list at all,
    # and (i1)-(i3) could not stand in: they are read and path rules, so
    # "`Write` the design_review record to docs/tmp/review.md" was a silent miss
    # in the one direction that matters.
    #
    # It was held off this list for a round because adding it flagged the
    # ADR-collision repair paragraph at `roles/architect-agent.codex.md:46`.
    # That finding was real but its cause was not the kind: the governed-object
    # run was walking across a comma into a NEW action predicate ("…, publish a
    # NEW `design_review` record…"), so the write tool was being credited with
    # an object belonging to `publish`. That defect is fixed at `OBJECT_LEAD`,
    # where it always lived; the kind is policed here, and the sentence stays
    # quiet because the object is no longer the write tool's. Suppressing a kind
    # to compensate for a window defect would have left every OTHER kind reachable
    # across the same comma.
    COORD_VERDICT_RE = re.compile(
        r"\bverdicts?\b|\btest[- _]strateg(?:y|ies)\b|\bstrategy artefact\b"
        r"|\bcomparison\.md\b|\bdesign_reviews?\b")
    DURABLE_DOC_RE = re.compile(
        r"docs/(?:design-reviews|adr|ux-reviews|design-system|plans|prd|retros|go-live"
        r"|architecture|glossary|ops-intake|incidents|memory|cto-deviations)/"
        r"|\bDESIGN\.md\b|\bADRs?\b|\blong-form\b|\breview report\b")
    STAGING_EXEMPT_RE = re.compile(r"wip-handoff-staging|staging path|staging file|staged draft")
    # The ONE artefact that has a sanctioned file form: a HANDOFF drafted at the
    # staging path. The exemption is bound to it as the write's OBJECT, so a
    # staging phrase cannot license a write of some other kind. The object test
    # is the handoff KIND rather than the literal `wip` — shipped prose calls the
    # same draft "the WIP handoff" and plain "the handoff" interchangeably
    # ("`Write` the handoff at the staging path under .wip-handoff-staging/"),
    # and requiring the qualifier flagged that sentence. The ASSOCIATION with the
    # staging surface is carried by the clause instead, which is what stops the
    # exemption crossing into a neighbouring sentence about something else.
    # `_` belongs in this class for the same reason it belongs in the kind list
    # itself, and the direction matters: this regex only EXEMPTS. Widening the
    # kind list to `wip_handoff` without widening the exemption made the
    # sanctioned draft sentence — "`Write` the wip_handoff at the staging path
    # under .wip-handoff-staging/" — a false positive, because the object no
    # longer matched the one artefact allowed to have a file.
    STAGED_OBJECT_RE = re.compile(r"\bwip[-_ ]handoff|\bhandoffs?\b")
    # A GENERIC negation guard is the wrong instrument here: "review the commit,
    # not `main`'s HEAD" sits in the same clause as a real write instruction and
    # would exempt it. What must be exempted is only the sentence that says the
    # artefact is NOT a file — so the guard matches that assertion specifically,
    # rather than any "not" near the match.
    FILE_DENIAL_RE = re.compile(
        r"\b(?:are|is|were|was)\s+(?:no longer\s+)?not\s+(?:a\s+)?files?\b"
        r"|\bnever\s+(?:a\s+)?files?\b|\bnot written as files?\b"
        r"|\brecords?\*{0,2},?\s+not\s+(?:a\s+)?files?\b"
        # ...and the denial that names the PATH rather than the file: "the
        # verdict itself is never written to a path" is the corrected sentence
        # the architect overlay must carry, and the verdict noun now in scope
        # made the correction itself a finding.
        r"|\b(?:never|not) written(?: to a path| as a file)?\b")
    # THE WRITE-AFFORDANCE BULLET. Every role overlay declares its write scope
    # in one shape — "- `Write`/`Edit` — <object list>" — and in that shape the
    # em dash is a LABEL separator, not a clause boundary. Read as a boundary it
    # ended the candidate window one character past the tool, so
    # "- `Write` — close-outs to disk." raised no candidate at all: the single
    # most likely spelling of this drift was the one spelling the rule could not
    # see. It is the exact mirror of the hole (i3) exists to close on the read
    # side, and it is closed here the narrow way rather than with a whole-line
    # (g3): a whole-line scan of a write bullet flags two correct shipped
    # sentences immediately (`roles/*-agent.codex.md`'s "…publish it with
    # `coordination.publish_artefact {kind:"design_review"}`" and "(`closeout` /
    # `addendum` records the daemon owns)"), because a write bullet routinely
    # names the record kinds it must NOT write in order to say where they go.
    #
    # So the dash is NEUTRALISED instead — one character replaced by one space,
    # so every offset still indexes the original line and `clause_bounds` /
    # `exemption_scope` need no new argument. The candidate window then runs to
    # the clause bound rather than the usual 80 characters, because in THIS
    # shape the whole clause after the label IS the tool's object list (same
    # reasoning as (i3)); the object anchor still has to reach the noun.
    #
    # Neutralising it also makes the remaining dashes pair CORRECTLY: a label
    # dash was previously pairing with a genuine clause separator further along
    # and silently neutralising that one too.
    WRITE_AFFORDANCE_DASH_RE = re.compile(
        r"^\s*(?:[-*]|\d+[.)])\s*(?:\*\*)?"
        r"(?:`(?:Write|Edit|MultiEdit)`(?!\w)[\s`/,]*)+—")
    for group in artefact_surface_groups():
        for path in group:
            r = rel(path)
            for lineno, line in substrate_lines(path, r):
                low = line.lower()
                dm = WRITE_AFFORDANCE_DASH_RE.match(line)
                if dm:
                    d = dm.end() - 1
                    low = low[:d] + " " + low[d + 1:]
                dash_scan = None
                for wm in WRITE_TOOL_RE.finditer(line):
                    # A SUBJECT AFTER AN EM DASH, only if that dash is LONE.
                    # `SUBJECT_OPENER` cannot tell a clause separator from the
                    # opening half of an apposition, because the answer lives
                    # outside the match; `_dashes_parenthetical()` is where this
                    # program already decides it, and it is reused rather than
                    # re-derived — it pairs the dashes off left to right inside
                    # each hard-bounded segment and rewrites each PAIR, leaving
                    # an odd one out as the separator it is. It returns a string
                    # of the SAME LENGTH, so the offset still indexes `line`.
                    # Without this, "the record — the worker commits the
                    # close-out describes — is not a file" hands back the exact
                    # round-6a false positive wearing a dash instead of a verb.
                    # `.groupdict().get(...)` and not `.group(...)`: the group
                    # IS the dash opener, so a pattern without the group has no
                    # dash opener either and there is nothing here to filter.
                    # `.group()` raises `IndexError: no such group` instead, and
                    # that is not a theoretical tidiness — mutating the opener
                    # out CRASHED the whole checker 150 cases before the case
                    # built to catch that mutation, so the mutant was "caught"
                    # by a traceback rather than by the thing it was aimed at.
                    # A test that fails for the wrong reason is a test that has
                    # not been run.
                    #
                    # ...and it pairs off `low`, NOT `line`. The write-affordance
                    # LABEL dash is neutralised twenty lines above, and only in
                    # `low` — that is the whole point of neutralising it, so a
                    # label dash cannot pair with a genuine separator further
                    # along and silently cancel it. Asking `line` reinstates
                    # exactly the pairing that neutralisation exists to prevent:
                    # in "- `Write` — durable documents only — the lead commits
                    # the close-out to disk." the two dashes pair in `line`, the
                    # second one is read as the closing half of an apposition,
                    # and a real third-person instruction is discarded. Every
                    # other consumer of the dash question in this file
                    # (`clause_bounds`, `exemption_scope`) is already handed
                    # `low`; this one was the odd one out. `low` and `line` have
                    # the same length and differ only where that label dash was
                    # replaced by a space, so nothing else moves.
                    if wm.groupdict().get("subject_after_dash") is not None:
                        if dash_scan is None:
                            dash_scan = _dashes_parenthetical(low)
                        if dash_scan[wm.start() - 2] != "—":
                            continue
                    # EVERY exemption below is scoped to the CLAUSE the matched
                    # write sits in, never to the line. A line-scoped exemption
                    # is bought by one clause and spent by another, so a mixed
                    # sentence passes whole: "- `Write` the close-out to disk;
                    # handoffs are not files" and "- `Write` the verdict record
                    # to disk; long-form reports live under docs/design-reviews/"
                    # each name the right thing about the wrong half.
                    c_left, c_right = clause_bounds(low, wm.start(), wm.end())
                    # CANDIDATE scope bounds the object window; EXEMPTION scope
                    # (narrower — a contrast ends it) bounds every test below.
                    exempt_scope = exemption_scope(low, wm.start(), wm.end())
                    # PROXIMITY, not co-occurrence: an instruction puts the tool
                    # and its object next to each other ("`Write` the close-out",
                    # "apply_patch a handoff at ..."). A whole-line test would
                    # equally flag the sentence that FORBIDS it — "coordination
                    # artefacts are NOT written as files, publish them" names
                    # both, far apart, and is exactly the line these surfaces
                    # should carry.
                    #
                    # THE CANDIDATE IS THE WRITE'S GRAMMATICAL OBJECT — bounded
                    # by the write's own clause and ANCHORED at the tool. That is
                    # what finally closed the mixed-sentence hole. Four rounds
                    # tried to fix it from the exemption end — clause-scope the
                    # denial, clause-scope the staging phrase — and each attempt
                    # flagged six correct shipped sentences, three of them in
                    # `lite/`, because a denial is idiomatically written as the
                    # clause AFTER the instruction it corrects ("`Write`/`Edit` —
                    # ONLY the ADR ... The verdict is NOT written as a file").
                    # The exemption was never the defect. The CANDIDATE was: a
                    # free 80-character search reached across `;` and `.` into a
                    # noun that was not the write's object at all, so "`Write`
                    # the close-out to disk; handoffs are not files" and its six
                    # innocent look-alikes became the same shape, and no
                    # exemption scope could separate them.
                    #
                    # Both bounds are load-bearing, and each was measured against
                    # the live corpus. The CLAUSE bound alone still flagged the
                    # two sentences named at `OBJECT_LEAD`, because a conjunction
                    # is not a clause boundary. The ANCHOR alone would let the
                    # 80-character reach survive inside a long clause. Together
                    # they say: the object is the noun this tool governs, right
                    # here. In all six innocent sentences the coordination noun
                    # is a later conjunct or a later corrective clause and never
                    # becomes this write's object, so they raise no candidate and
                    # need no exemption at all; in the counterexample the object
                    # is `close-out`, immediately, and the denial past the
                    # semicolon is about a different noun.
                    # ...and in the affordance-bullet shape the window is the
                    # whole clause after the label, not 80 characters of it: an
                    # affordance bullet is an ENUMERATION, and its last object
                    # ("plans under `docs/plans/`, PRDs under `docs/prd/`, and
                    # close-outs to disk") sits well past any fixed reach.
                    window = low[wm.end():(c_right if dm and wm.start() < dm.end()
                                           else min(wm.end() + 80, c_right))]
                    # EVERY governed object is judged on its own. An exemption
                    # belongs to the object that earns it: "`Write` the WIP
                    # handoff and the close-out to the staging path" gives the
                    # staging exemption to the handoff and must still flag the
                    # close-out standing beside it.
                    hit = False
                    for om in governed_objects(window, COORD_ARTEFACT_RE):
                        # The staging exemption is bound to the OBJECT, not to
                        # the line: only a write whose object IS the handoff can
                        # claim it, and only in the scope that names the staging
                        # surface. Line scope let "`Write` the close-out to disk;
                        # the WIP handoff uses a staging path instead" spend the
                        # handoff's exemption on the close-out.
                        if (STAGED_OBJECT_RE.search(om.group(0))
                                and STAGING_EXEMPT_RE.search(exempt_scope)):
                            continue
                        # ...and the file-denial exemption is scoped to the
                        # candidate's own exemption scope. Now that the object
                        # cannot cross a clause boundary, the denial must not
                        # either: a correcting sentence denies the thing IT
                        # names, and a denial past a contrast is another noun's.
                        if FILE_DENIAL_RE.search(exempt_scope):
                            continue
                        hit = True
                        break
                    if not hit:
                        # The verdict/strategy half, exempt when the scope names
                        # the document surface that verdict legitimately lives
                        # at. Checked second so the unambiguous kinds above
                        # keep firing even on a line that also names a doc.
                        for om in governed_objects(window, COORD_VERDICT_RE):
                            if DURABLE_DOC_RE.search(exempt_scope):
                                continue
                            if FILE_DENIAL_RE.search(exempt_scope):
                                continue
                            hit = True
                            break
                    if not hit:
                        continue
                    findings.append(
                        f"SUBSTRATE-RECORD-WRITE {r}:{lineno}: a coordination artefact is a "
                        f"record, never a file written with a write tool")
                    break

    # (h) SEMANTIC EGRESS ALIASES. `SUBSTRATE-ROLE` above catches a forbidden
    # TOOL NAME; it cannot see prose that assigns the same act in English — "the
    # PM publishes its branch", "the dispatcher publishes the branch", "an
    # operator/lead executes the merge". The actors here are exactly the roles
    # the daemon refuses at the socket, so naming any of them beside a
    # push/land/merge verb is a contradiction of the boundary whatever tool the
    # sentence does or does not mention. `lead` and `worker` are absent from the
    # actor list on purpose: they are the two the gate admits.
    EGRESS_ACTOR_RE = re.compile(
        r"\b(?:the |an |a )?(?:pm|architect|qa|reviewer|designer|ops|cto|operator|dispatcher)\b")
    EGRESS_VERB_RE = re.compile(
        r"\bpublish(?:es)?\s+(?:its|the|that)\s+branch\b|\bpushes\b(?!\s+back)"
        r"|\bexecutes?\s+(?:the\s+)?(?:reserved\s+)?(?:merge|landing)\b"
        r"|\blands\s+(?:it|the\s+(?:merge|branch|landing))\b")
    # A landing with NO actor named at all — "still lands in-place on `main`" —
    # has no subject for rule (h) to match, and is the most dangerous spelling
    # precisely because it reads as a property of the work rather than as an act
    # somebody performs. Matched on its own, actor-free.
    IMPLICIT_LANDING_RE = re.compile(
        r"\blands?\s+in-place\b|\bin-place on\s+`?main`?|\blands?\s+on\s+`?main`?"
        r"|\bland(?:s|ed|ing)?\s+(?:it\s+)?(?:directly\s+)?(?:to|on)\s+`?main`?")
    for group in artefact_surface_groups():
        for path in group:
            r = rel(path)
            for lineno, line in substrate_lines(path, r):
                low = line.lower()
                for im in IMPLICIT_LANDING_RE.finditer(low):
                    if NEGATION_RE.search(exemption_scope(low, im.start(), im.end())):
                        continue
                    findings.append(
                        f"SUBSTRATE-EGRESS {r}:{lineno}: a landing with no actor — every landing "
                        f"is the lead's request and the daemon's merge")
                    break
                for vm in EGRESS_VERB_RE.finditer(low):
                    lead_in = low[max(0, vm.start() - 42):vm.start()]
                    am = None
                    for am in EGRESS_ACTOR_RE.finditer(lead_in):
                        pass                      # keep the LAST actor before the verb
                    if am is None:
                        continue
                    if NEGATION_RE.search(exemption_scope(low, vm.start(), vm.end())):
                        continue
                    findings.append(
                        f"SUBSTRATE-EGRESS {r}:{lineno}: '{am.group(0).strip()}' is not a role the "
                        f"daemon admits at the push/landing socket")
                    break

    # (i) RECORD SEMANTICS ON THE READ SIDE — for EVERY role, whatever its write
    # scope. This is rule (f)'s blind spot stated as its own rule: (f) keys on an
    # EMPTY write grant, so architect, PM, lead and worker — each holding a
    # perfectly legitimate grant over some DURABLE DOCUMENT — were skipped
    # entirely, and kept routing "the lead's handoff path", citing "the verdict
    # by path" from an ADR, and filing a `comparison.md`. That grant is
    # UNRELATED to the question this rule asks: a daemon record has no path and
    # no filesystem read, for anybody, however much else the role may write. So
    # the key is the ARTEFACT, exactly as in (g), and the scan is role-blind.
    #
    # (i1) a record named in FILE grammar. `verdict` / `strategy` carry the same
    # document exemption as (g): a line naming the document home is talking
    # about the report or the ux-review artefact, which really are files.
    # SINGULAR `path`/`file` only. The plural is the OTHER sense of the word —
    # "the three WIP-handoff trigger paths" are routes, not filesystem paths —
    # and reading it as a path grammar flagged a correct sentence.
    #
    # The record NOUNS are DERIVED from `COORD_ARTEFACT_RE` — the file's ONE
    # canonical kind list, the same source `RECORD_KIND_OBJECT_RE` and
    # `RECORD_KIND_RE` below already draw from — and shared by all three path
    # productions. They were re-spelt here BY HAND until round 10, and a
    # hand-respelt copy of a list is how this rule went out of date against the
    # canonical inventory in BOTH directions at once:
    #
    #   * it was missing `task brief`, `clarification artefact`,
    #     `review task brief`, `wip-handoff` and `merge close-out` — so
    #     "- route it to the task brief path under docs/x/" was silent. That is
    #     the DANGEROUS direction: a miss looks exactly like a clean corpus.
    #   * ...and it carried the acknowledgement hyphen guard that the canonical
    #     list did NOT, so (i2), (i3) and (g) — which all derive from that list
    #     — inherited the UNGUARDED spelling and flagged "under the standard
    #     override-with-acknowledgment path", an authority route, as a record.
    #
    # Deriving closes both at the source, and closes them for whatever is added
    # next: a kind added to the canonical list reaches (i1) with no second edit,
    # and a guard written on a kind travels with that kind into every copy.
    #
    # MEASURED, and it corrects the diagnosis the hand list shipped with: the
    # miss was a MISSING KIND, not an ordering effect. Python alternation
    # BACKTRACKS, so `(?:task|task brief)\s+(?:file|path)` matches "task brief
    # path" at exactly the same span as `(?:task brief|task)\s+(?:file|path)`
    # does — order here is not load-bearing, and "longest first" is not the
    # invariant. COMPLETENESS against the canonical list is the invariant, which
    # is why it is now structural instead of a note asking the next editor to be
    # careful. (Selftest: "a multiword kind reaches its path grammar" and "a
    # two-word kind reaches its file grammar" below — the two kinds no shorter
    # head can reach, so they fail if this list ever loses them again.)
    #
    # `acknowledgment` is the one kind carrying a lookbehind, and it was
    # MEASURED rather than anticipated: adding the kind bare immediately
    # flagged two correct shipped sentences (`roles/qa-agent.md:349`,
    # `roles/worker-agent.claude.md:310`), both saying "under standard
    # override-with-acknowledgment path" — an AUTHORITY route spelt as a
    # hyphenated procedure name, not a filesystem path, the same ambiguity the
    # plural-`paths` note above records. A hyphen before the kind means the kind
    # is the tail of a compound naming something else; a space before it means
    # the record. `wip-handoff path` is deliberately NOT excluded by this — the
    # lookbehind is on the ambiguous act-noun only, exactly as `COORD_VERDICT_RE`
    # splits the ambiguous document nouns out of the unambiguous kind list. It
    # is written ONCE, on the canonical list, and arrives here by derivation.
    def canonical_record_nouns(pattern):
        """`COORD_ARTEFACT_RE`'s kinds, morphology-stripped for (i1).

        The word boundary and the plural marker come off because each path
        production below supplies its own boundary and its own suffix — the
        file/path production restores the plural as `s?`, on the KIND and on the
        optional type noun alike, because "the handoffs file" and "the prior
        handoff records file" are the same drift as their singulars and both
        were silent while the stripped marker was never put back. Nothing
        else about an alternative is touched — a lookbehind guard included,
        which is the whole point of deriving rather than re-spelling.
        """
        nouns = []
        for alt in pattern.split("|"):
            # A `|` inside a group would split one alternative in half and drop
            # half a kind SILENTLY — the exact failure class this derivation
            # exists to end, reintroduced by the derivation itself. Compiling
            # each piece is what makes that impossible: an unbalanced fragment
            # is not a regex, so the split fails loudly instead of quietly.
            re.compile(alt)
            if alt.startswith(r"\b"):
                alt = alt[2:]
            if alt.endswith(r"\b"):
                alt = alt[:-2]
            if alt.endswith("s?"):
                alt = alt[:-2]
            nouns.append(alt)
        return nouns
    # ...plus the four spellings (i1) needs that the write side does not:
    # `closeout` unhyphenated, the bare `clarification`, `task record`, and the
    # bare `task` head — "the task path" is itself one of the drift phrases.
    RECORD_NOUN = ("(?:"
                   + "|".join(canonical_record_nouns(COORD_ARTEFACT_RE.pattern)
                              + ["task record", "closeout", "clarification", "task"])
                   + ")")
    # The optional `record`/`artefact` between the kind and `file`/`path` is the
    # same miss one width out: "- open the close-out record file from disk" and
    # "- route it to the handoff artefact path" name the record in file grammar
    # just as plainly as "the close-out file" does, and both were silent. Only
    # those two nouns, and only one of them — a wider gap would let the kind
    # reach a `file` in the next phrase entirely, which is the proximity rule
    # this production exists to not be.
    # The two DOCUMENT-AMBIGUOUS kinds reach the file grammar in their MACHINE
    # spelling only, on their own branch, and carry the document-home exemption
    # with them. Their prose forms deliberately do not: "the review report file"
    # and "the strategy file" name things that legitimately ARE files, which is
    # the whole reason those nouns sit in `COORD_VERDICT_RE` rather than on the
    # unconditional list. `{kind:"design_review"}` names the record and nothing
    # else, so "the design_review file" is drift even though "the review file"
    # is not — and if it does name a home, the exemption below still applies.
    RECORD_PATH_RE = re.compile(
        r"\b" + RECORD_NOUN + r"s?(?:\s+(?:records?|artefacts?))?\s+(?:file|path)\b"
        r"|\b(?:design_reviews?|test_strateg(?:y|ies))"
        r"(?:\s+(?:record|artefact))?\s+(?:file|path)\b"
        r"|\bpath to (?:the |a |your |its )?(?:worker'?s? |lead'?s? )?"
        r"(?:" + RECORD_NOUN + r"|record|verdict|strategy)\b"
        r"|\b(?:" + RECORD_NOUN + r"|verdict|strategy|task record)\b"
        r"[^.\n]{0,24}\bby path\b"
        r"|\bcomparison\.md\b|\bsame path (?:level|convention)\b")
    # The document exemption applies to the verdict/strategy NOUN — but never to
    # the `... by path` citation form, because that is the exact sentence this
    # rule exists to catch ("the ADR cites the verdict by path"), and it names
    # the ADR, so a blanket doc exemption would exempt it by its own evidence.
    # `strategy` is unanchored, so it already reaches `test_strategy`;
    # `design_review` shares no substring with either and is named.
    RECORD_PATH_DOC_SENSITIVE_RE = re.compile(r"verdict|strategy|design_review")
    BY_PATH_RE = re.compile(r"by path")
    # (i2) a FILESYSTEM READ aimed at a record. The daemon exposes exactly one
    # way to read one — `coordination.read_artefact` — so any of these tools
    # pointed at a record kind is an instruction that cannot be carried out.
    # `MultiRead`, `Grep` and `Glob` belong here because (i3) ALREADY calls all
    # three read affordances. A tool this file treats as a filesystem read in
    # one rule and not in the other leaves a hole shaped exactly like the rule
    # that has it: (i3) only sees a bullet that LEADS with the tool, so
    # "- Verify provenance, then `MultiRead` the close-out from disk." and
    # "- Before resuming, use `Grep` across the prior handoff records from disk"
    # were reachable by neither rule and passed.
    READ_TOOL_RE = re.compile(
        r"`Read`|`MultiRead`|`Grep`|`Glob`|functions\.exec_command|`cat`|`sed`"
        r"|\bcat the\b|\bRead the\b")
    # ...but a SEARCH tool names two things, and only one of them is opened.
    # "`Grep` across the prior handoff records" searches the RECORDS — drift,
    # because a record is not a file to search. "`Grep` the source tree for the
    # word handoff" searches the SOURCE TREE, and `handoff` is the search TERM,
    # a string that happens to spell a kind. The object run these rules share
    # cannot tell them apart: it ends at a hard stop or a new predicate, and
    # `for` is neither, so the term was reached as an object and two correct
    # sentences fired the moment these tools were admitted — measured, both
    # directions, before this guard was written. The preposition that introduces
    # a search TERM is the discriminator, and only these two tools need it.
    # ...and the two phrases can come in EITHER order, which a "is there a term
    # preposition anywhere before the kind" test gets wrong in the dangerous
    # direction: "`Grep` for stale entries in the prior handoff records from
    # disk" leads with the TERM and names the records as the CORPUS afterwards,
    # and suppressing on the bare presence of `for` made that a silent miss. So
    # both prepositions are tracked and the LAST one before the kind wins — the
    # kind is the search term only while no corpus phrase has opened since.
    SEARCH_TOOL_RE = re.compile(r"`(?:Grep|Glob)`")
    SEARCH_TERM_PREP_RE = re.compile(
        r"\b(?:for|matching|mentioning|containing|named)\b")
    SEARCH_CORPUS_PREP_RE = re.compile(
        r"\b(?:in|across|within|through|over|under|among|inside)\b")

    def search_term_only(seg):
        """True when `seg` — the text between a search tool and a kind — leaves
        that kind inside the TERM phrase rather than the corpus phrase."""
        terms = [m.start() for m in SEARCH_TERM_PREP_RE.finditer(seg)]
        corpora = [m.start() for m in SEARCH_CORPUS_PREP_RE.finditer(seg)]
        if not terms:
            return False
        return max(terms) > (max(corpora) if corpora else -1)
    # The record must be the read's OBJECT, not merely nearby. A plain
    # proximity window read three correct sentences as violations — every one
    # of them a read of a SKILL FILE whose own name contains a record kind
    # (`.../coordination-wip-handoff/SKILL.md`), or a read whose output is
    # later captured "into the close-out". So the object is matched ANCHORED at
    # the tool, through a CLOSED list of connectives: any word outside that
    # list — "(e.g.,", "then", "for" — ends the match, which is what makes the
    # rule unable to reach across a sentence into an unrelated noun.
    #
    # ...and the KIND list is the canonical one, for the same reason (i1)'s
    # nouns are now written once: hand-respelt here it shipped without
    # `acknowledgement` and `dispatch brief`, so "`Read` the acknowledgement
    # from disk" — a kind (g) has always policed — was invisible to the read
    # side. Derived from `COORD_ARTEFACT_RE`, plus the four spellings this rule
    # needs that the write side does not (`closeout` unhyphenated, the bare
    # `clarification`, and the two document-ambiguous kinds `design_review` and
    # `test_strategy`). `task record` is NO LONGER spelt here — it is on the
    # canonical list now and arrives by derivation, which is the whole point of
    # deriving.
    #
    # BOTH document-ambiguous kinds are admitted in the MACHINE spelling ONLY,
    # and unlike (i1) and (i3) this rule has no document-home exemption to fall
    # back on. Admitting the space spelling therefore made a correct document
    # read fire: "`Read` the design review under docs/design-reviews/2026-08-28-x.md"
    # names the file it opens, and that file exists. `{kind:"design_review"}`
    # names the record and nothing else. The unambiguous PROSE form — the one
    # that says `record` out loud — is NOT spelt here: it is on the canonical
    # list and arrives by derivation, so this rule cannot drift away from it.
    RECORD_KIND_OBJECT_RE = re.compile(
        COORD_ARTEFACT_RE.pattern
        + r"|\bcloseouts?\b|\bclarifications?\b"
        + r"|\bdesign_reviews?\b|\btest_strateg(?:y|ies)\b")
    # A line that already names the daemon read is not instructing a filesystem
    # read, however the English around it reads — "Read the task record
    # directly (`coordination.read_artefact {id}`)" is the CORRECT sentence.
    #
    # `list_artefacts` is NOT in this exemption, and that is the point: the
    # daemon exposes exactly ONE way to READ a record, and listing is not it.
    # "- `Read` — prior handoffs; use `coordination.list_artefacts` to discover
    # their IDs" names a daemon call while still instructing a filesystem read
    # of the record itself, and a listing-inclusive exemption waved it straight
    # through. Enumerating a record is a different act from opening one.
    DAEMON_READ_RE = re.compile(r"coordination\.read_artefact")
    # (i3) support. A TOOL-AFFORDANCE bullet: a list item LEADING with a
    # backticked filesystem read tool, which is how every role overlay declares
    # what it may open. The lead-with requirement is what keeps the whole-line
    # scan below from becoming a proximity rule over ordinary prose.
    READ_AFFORDANCE_BULLET_RE = re.compile(
        r"^\s*(?:[-*]|\d+[.)])\s*(?:\*\*)?`(?:Read|Grep|Glob|MultiRead)`")
    # The record KINDS, as nouns. Derived from COORD_ARTEFACT_RE — the file's
    # ONE canonical kind list, which rule (g) already uses — rather than
    # re-spelled here, because a second hand-maintained copy is a rule that
    # goes quietly out of date: this list first shipped missing `acknowledgement`
    # and `dispatch brief`, both of which (g) has always carried, so an
    # affordance enumeration naming either escaped (i2) and (i3) alike.
    # Bare `artefact` / `record` stay OUT: "adjacent-agent artefacts"
    # legitimately covers documents too, and flagging it would punish an
    # accurate sentence. `coordination record` as a PHRASE is exact.
    RECORD_KIND_RE = re.compile(
        COORD_ARTEFACT_RE.pattern
        + r"|\btask records?\b|\bclarifications?\b"
        + r"|\bcoordination (?:records?|artefacts?)\b")
    # ...and the AMBIGUOUS nouns, which get rule (g)'s document exemption rather
    # than a place in the list above: the architect's long-form report lives at
    # `docs/design-reviews/` and the designer's verdict at `docs/ux-reviews/`,
    # so a bullet naming that document home is reading a FILE, correctly.
    RECORD_KIND_DOC_SENSITIVE_RE = re.compile(
        COORD_VERDICT_RE.pattern + r"|\bdesign[_ ]reviews?\b")
    for group in artefact_surface_groups():
        for path in group:
            r = rel(path)
            for lineno, line in substrate_lines(path, r):
                # Line-scoped, like (g)'s: a surface that legitimately names the
                # WIP staging draft says so once, and the mention it licenses is
                # routinely a clause or two away. Governs (i1), (i2) and (i3).
                low = line.lower()
                for pm_ in RECORD_PATH_RE.finditer(low):
                    # The staging exemption is OBJECT-bound and CLAUSE-scoped
                    # here, as it is in (g). A line-scoped `continue` used to
                    # skip (i1), (i2) and (i3) entirely on any line that said
                    # "staging" anywhere, so one legitimate mention of the
                    # sanctioned draft disarmed every record-read rule for the
                    # whole line. Clause scope alone was still not enough: the
                    # matched PATH must itself be the handoff's, or "Open the
                    # close-out path while the WIP handoff remains at the staging
                    # path" spends the draft's exemption on a close-out path.
                    if (STAGED_OBJECT_RE.search(pm_.group(0))
                            and STAGING_EXEMPT_RE.search(
                                exemption_scope(low, pm_.start(), pm_.end()))):
                        continue
                    # The DOCUMENT-HOME exemption, by contrast, IS clause-scoped:
                    # a home belongs beside the mention it licenses. "Read the
                    # path to the verdict from disk; permanent reports live under
                    # docs/design-reviews/" buys it in the second clause and
                    # spends it in the first.
                    clause = exemption_scope(low, pm_.start(), pm_.end())
                    if (RECORD_PATH_DOC_SENSITIVE_RE.search(pm_.group(0))
                            and not BY_PATH_RE.search(pm_.group(0))
                            and DURABLE_DOC_RE.search(clause)):
                        continue
                    # A surface CORRECTING the drift has to be able to name it
                    # ("a handoff is a record with no path", "never a close-out
                    # path"), so the clause-local negation guard applies here as
                    # it does to (h) — the denial and the instruction differ
                    # only by the negation, never by the vocabulary.
                    if NEGATION_RE.search(exemption_scope(low, pm_.start(), pm_.end())):
                        continue
                    findings.append(
                        f"SUBSTRATE-RECORD-READ {r}:{lineno}: a coordination record is read "
                        f"by id with `coordination.read_artefact` — it has no path")
                    break
                # The daemon-read exemption is CLAUSE-scoped, not line-scoped.
                # A line-scoped `continue` here exempted a MIXED bullet — one
                # that sends some kinds to the filesystem and others to the
                # daemon: "- `Read` — prior handoffs from disk; use
                # `coordination.read_artefact` for close-outs" names the right
                # call for the wrong half and passed whole. The exemption
                # belongs to the clause that actually carries the daemon call.
                for tm in READ_TOOL_RE.finditer(line):
                    # Clause-bounded like (g)'s, and for the same reason: the
                    # anchored object's leading `[\s\`,;:]*` will happily step
                    # over a `;`, so without this bound "`Read`; the close-out"
                    # reaches a noun in the next clause.
                    _, t_right = clause_bounds(low, tm.start(), tm.end())
                    window = low[tm.end():min(tm.end() + 64, t_right)]
                    # Every governed object judged on its own, as in (g): a
                    # read whose first object is the exempt staging draft must
                    # still flag a record coordinated beside it.
                    read_hit = False
                    objs = governed_objects(window, RECORD_KIND_OBJECT_RE)
                    spans = [(tm.end() + o.start(), tm.end() + o.end())
                             for o in objs]
                    for km, span in zip(objs, spans):
                        # A kind sitting behind a search-term preposition is what
                        # a SEARCH tool is looking FOR, not what it opens. Bound
                        # to the tool match, so it costs the other read tools
                        # nothing: "`Read` the close-out named in the dispatch"
                        # is still a read of the close-out.
                        if (SEARCH_TOOL_RE.fullmatch(tm.group(0))
                                and search_term_only(low[tm.end():span[0]])):
                            continue
                        a_left, a_right = _bounds(low, tm.start(), span[1],
                                                  EXEMPTION_SPLIT_RE)
                        around = low[a_left:a_right]
                        # The daemon-read exemption is bound to the OBJECT it
                        # modifies, not to the clause. Clause scope let one
                        # object's daemon call cover another standing beside
                        # it: "`Read` the handoff with coordination.read_artefact
                        # and the close-out from disk" exempted the close-out
                        # too, and passed whole. See `modifier_scope`.
                        if DAEMON_READ_RE.search(
                                modifier_scope(low, spans, span,
                                               a_left, a_right)):
                            continue
                        # The NEGATION stays clause-scoped, deliberately: a
                        # list negates from ONE shared predicate ("task briefs,
                        # handoffs, and close-outs are never read from disk"),
                        # and narrowing it flagged that correct sentence.
                        if NEGATION_RE.search(around):
                            continue
                        # The staging draft is the one record with a file form;
                        # the object must BE that handoff and the staging
                        # surface must be named in the same scope.
                        if (STAGED_OBJECT_RE.search(km.group(0))
                                and STAGING_EXEMPT_RE.search(around)):
                            continue
                        read_hit = True
                        break
                    if not read_hit:
                        continue
                    findings.append(
                        f"SUBSTRATE-RECORD-READ {r}:{lineno}: a filesystem read tool cannot "
                        f"open a daemon record — use `coordination.read_artefact {{id}}`")
                    break
                # (i3) THE TOOL-AFFORDANCE BULLET, which (i2) structurally
                # cannot reach. (i2) anchors the record kind AT the tool through
                # a closed connective list — deliberately, so it cannot wander
                # across a sentence into an unrelated noun. But an affordance
                # bullet is an ENUMERATION by construction: "`Read` — all
                # phases. For explorer artefacts at engagement start (...),
                # prior master plans, prior handoffs, user-referenced files"
                # puts the record kind ~200 characters downstream of the tool,
                # past every connective, so the anchor can never see it. That is
                # exactly where this drift was found, in three overlays at once,
                # two of them already corrected in their lite counterparts.
                # In THIS shape the whole line is the tool's object list, so
                # scanning it whole is the right width — and it stays narrow
                # because the bullet must LEAD with a filesystem read tool.
                #
                # Each occurrence is judged individually, not "the line names a
                # kind somewhere". A whole-line verdict got both directions
                # wrong: it rejected the EXCLUSION an affordance bullet should
                # carry ("- `Read` — permanent documents only; never use it for
                # handoffs") and it rejected the DOCUMENT a review legitimately
                # leaves behind ("- `Read` — prior design reviews under
                # docs/design-reviews/"). So the clause-scoped negation guard
                # the sibling rules use applies per occurrence, and the ambiguous
                # nouns take rule (g)'s document-surface exemption.
                # EVERY exemption here is clause-scoped, for the same reason:
                # a line-scoped one is bought by the CORRECT half of a mixed
                # bullet and spent on the wrong half. Measured in all three
                # directions — the daemon call ("...from disk; use
                # `coordination.read_artefact` for close-outs"), the document
                # home ("- `Read` — design review records from the daemon;
                # permanent reports under docs/design-reviews/"), and the
                # negation. So each is tested against the clause the specific
                # occurrence falls in, never against the line.
                if READ_AFFORDANCE_BULLET_RE.match(line):
                    # Every kind named in the bullet, from BOTH lists, sorted —
                    # the object a daemon call modifies is the one it stands
                    # next to, and which of the two lists that kind came from
                    # has no bearing on where it sits in the sentence.
                    kind_spans = sorted(
                        {m.span() for m in RECORD_KIND_RE.finditer(low)}
                        | {m.span() for m in
                           RECORD_KIND_DOC_SENSITIVE_RE.finditer(low)})

                    def _exempt(lo, hi):
                        a_left, a_right = _bounds(low, lo, hi,
                                                  EXEMPTION_SPLIT_RE)
                        around = low[a_left:a_right]
                        # The daemon-read exemption is bound to the OBJECT it
                        # modifies, exactly as in (i2): clause scope let
                        # "- `Read` — the handoff with coordination.read_artefact
                        # and the close-out from disk" exempt the close-out on
                        # the handoff's call. The NEGATION stays clause-scoped —
                        # a list negates from one shared predicate.
                        # The staging exemption is bound to THIS occurrence's
                        # kind, not granted to every kind in the clause: only
                        # the handoff has a sanctioned draft on disk.
                        return (DAEMON_READ_RE.search(
                                    modifier_scope(low, kind_spans, (lo, hi),
                                                   a_left, a_right))
                                or NEGATION_RE.search(around)
                                or (STAGED_OBJECT_RE.search(low[lo:hi])
                                    and STAGING_EXEMPT_RE.search(around)))
                    hit = None
                    for am in RECORD_KIND_RE.finditer(low):
                        if not _exempt(am.start(), am.end()):
                            hit = am
                            break
                    if hit is None:
                        for am in RECORD_KIND_DOC_SENSITIVE_RE.finditer(low):
                            if _exempt(am.start(), am.end()):
                                continue
                            # ...plus rule (g)'s document-surface exemption, for
                            # the ambiguous nouns only — also clause-scoped.
                            if DURABLE_DOC_RE.search(
                                    exemption_scope(line, am.start(), am.end())):
                                continue
                            hit = am
                            break
                    if hit is not None:
                        findings.append(
                            f"SUBSTRATE-RECORD-READ {r}:{lineno}: a filesystem read tool's "
                            f"object list names a coordination record — records are read by id "
                            f"with `coordination.read_artefact`")

    # (j) THE CLOSE-OUT SEQUENCE. Not a token but an ORDER, which is why every
    # token rule above read the contradictory surfaces as clean while five of
    # them taught mutually incompatible sequences. The one executable order is
    # commit locally → publish + deliver the close-out naming that commit's SHA
    # → publish the branch, and only the branch publication is rhythm-
    # conditional. Each pattern below is a spelling of an order that cannot be
    # executed: a close-out that precedes the commit it must name, or a branch
    # published before the close-out that asks for authorization to publish it.
    CLOSEOUT_ORDER_RE = re.compile(
        r"\bclose-?out\s*(?:→|->)\s*commit\b"
        r"|\bcontinuous close-?out\s*(?:→|->)"
        r"|\bpre-commit close-?out\b|\buncommitted close-?out\b"
        r"|\bpublish(?:es|ing)? the branch and (?:the )?close-?out\b"
        r"|\bbranch publication,? and close-?out\b"
        r"|\bbranch\s*(?:→|->)\s*(?:publish )?close-?out\b"
        r"|\bno commit,? no [^.\n]{0,40}\bawait green-light\b"
        r"|\bstops? pre-commit\b")
    for group in artefact_surface_groups():
        for path in group:
            r = rel(path)
            for lineno, line in substrate_lines(path, r):
                low = line.lower()
                om = CLOSEOUT_ORDER_RE.search(low)
                if not om:
                    continue
                if NEGATION_RE.search(exemption_scope(low, om.start(), om.end())):
                    continue
                findings.append(
                    f"SUBSTRATE-ORDER {r}:{lineno}: the close-out sequence is commit locally "
                    f"→ publish + deliver the close-out → publish the branch")

    # (j2) THE RHYTHM-GATED SET. The sequence rule above reads a spelled-out
    # ORDER; it cannot see the same contradiction stated as a MEMBERSHIP — an
    # enumeration of the irreversible actions a rhythm gates that includes the
    # local commit. That is how the defect actually shipped: the rhythm table's
    # apex column green-lit "commit / branch publication / landing"
    # individually, while its own sequence column committed FIRST, so both
    # columns were internally well-formed and no order pattern matched. The
    # commit is dispatch-authorized under every rhythm and reaches no shared
    # state (the daemon is the only git egress); gating it behind the close-out
    # that ASKS for the gate is unexecutable in the same way, one column over.
    # (1) `commit` as a MEMBER of an irreversible-action enumeration. Split out
    # from the shapes below so its denial set can differ from theirs — see the
    # denial pair above.
    RHYTHM_GATED_ENUM_RE = re.compile(
        r"\birreversibl\w*[^.\n(]{0,60}\([^)\n]{0,80}\bcommits?\b")
    RHYTHM_GATED_AUTH_RE = re.compile(
        # (2) the commit made conditional on the rhythm or on a green-light.
        r"\bcommit only (?:when|if)\b[^.\n]{0,80}\b(?:rhythm|green-?light|authoriz\w+)\b"
        r"|\b(?:rhythm|green-?light)\b[^.\n]{0,40}\bauthoriz\w+\b[^.\n]{0,25}\bcommits?\b"
        # (3) the commit as the OBJECT of the wait. `before` was in this
        # alternation and had to come out: "Before the branch-publication
        # green-light, commit locally and deliver the close-out" is the
        # CANONICAL sequence, and the rule rejected it — a gate that forces the
        # correct sentence to be written wrong. What makes the shape a defect is
        # the commit being what is waited FOR, so the connective must say so.
        r"|\b(?:awaits?|awaiting|pending)\b[^.\n]{0,40}\bgreen-?light\b"
        r"[^.\n]{0,20}\b(?:to|before)\s+commit(?:ting)?\b"
        r"|\bgreen-?light\b[^.\n]{0,20}\bbefore\s+(?:you\s+)?commit(?:ting)?\b"
        r"|\bno commits?\b[^.\n]{0,30}\bgreen-?light\b")
    # The denial this rule must let through: one that is ABOUT the commit, not
    # merely near it. See the guard at the loop body for why a generic negation
    # fails at every width.
    #
    # This is a CLOSED list of denial forms, each of which has the commit as the
    # negation's grammatical object. Two looser shapes were tried and both had
    # to be thrown away, because a denial about a DIFFERENT member of the gated
    # set kept reaching across and suppressing a real defect:
    #
    #   `[^.\n]{0,45}` — "…(commit / branch publication / landing) remain
    #     rhythm-gated, although landing is not separately green-lighted"
    #     suppressed. The one distance that excluded it was five characters from
    #     also excluding a legitimate correction; a rule whose correctness rests
    #     on a five-character margin is not a rule.
    #   `[\w\s,'-]{0,40}` (a prose run that cannot cross an enumeration's `/`
    #     or `)`) — better, but still only positional: "The rhythm does not
    #     authorize landing but commits remain rhythm-gated" suppressed, because
    #     nothing bound `not` to `commits` except adjacency.
    #
    # Only naming the sanctioned forms binds the object. The cost is that a
    # denial written some other way is a visible false positive rather than a
    # silent miss — the right side to fail on.
    # Each branch needs BOTH halves of the predicate — the commit as subject AND
    # what is being denied of it. Naming only the subject was still open-ended:
    # "…(commit / branch publication / landing) remain rhythm-gated, but the
    # commit is not ready" suppressed a real defect on an unrelated `is not`.
    # And a branch with no subject at all ("not a rhythm-gated irreversible")
    # was suppressible by any member of the set — "landing is not a rhythm-gated
    # irreversible" — so that branch is gone rather than repaired.
    # A DENIAL MUST DENY THE THING THAT WAS ASSERTED. One flat list could not,
    # because the two gated shapes assert different things: an enumeration says
    # the commit is a MEMBER of the gated set, while the rhythm/green-light
    # shapes say the commit is AUTHORIZED by the gate. Denying membership does
    # not deny authorization, so "The rhythm authorizes the commit even though
    # the commit is not irreversible" suppressed a real defect with an
    # irrelevant truth. The denials are therefore split and paired.
    #
    # A GATEDNESS denial ("the commit is not rhythm-gated") contradicts both
    # shapes and so appears in both sets; a MEMBERSHIP denial ("not one of
    # them", "not irreversible") answers only the enumeration.
    COMMIT_GATEDNESS_DENIAL = (
        r"\b(?:local\s+|close-?out\s+)?commits?\s+(?:is|are|was|were)\s+"
        r"(?:never|not)\s+(?:a\s+|an\s+)?"
        r"(?:rhythm-?\s?gated|gated|approval-gated|green-?li(?:t|ghted))")
    COMMIT_MEMBERSHIP_DENIAL = (
        r"\b(?:local\s+|close-?out\s+)?commits?\s+(?:is|are|was|were)\s+"
        r"(?:never|not)\s+(?:a\s+|an\s+|among\s+|one\s+of\s+)?"
        r"(?:irreversible|them\b|the\s+gated)")
    # The `does not …` branch REQUIRES the gating authority as its subject.
    # Without one it denied nothing relevant: "The worker does not authorize
    # the commit, but irreversible actions (…) remain rhythm-gated" is a
    # statement about the worker, and it suppressed the enumeration whole.
    #
    # ...and the free 25-character bridge to "is not one of them" is GONE rather
    # than shortened: any text at all between the noun and the denial can carry
    # a different subject ("Commits are local, landing is not one of them,
    # but …"). The membership branch already matches the direct form.
    COMMIT_AUTH_DENIAL = (
        r"\b(?:rhythm|cadence|gate|authority|dispatch|green-?light)\w*\s+"
        r"(?:does|do)\s+not\s+(?:gate|authoriz\w+|green-?light|hold)\s+"
        r"(?:the\s+)?(?:local\s+|close-?out\s+)?commits?\b"
        r"|\bcommits?\s+(?:is|are)\s+dispatch-authoriz\w+")
    ENUM_DENIAL_RE = re.compile(
        COMMIT_GATEDNESS_DENIAL + r"|" + COMMIT_MEMBERSHIP_DENIAL
        + r"|" + COMMIT_AUTH_DENIAL)
    AUTH_DENIAL_RE = re.compile(
        COMMIT_GATEDNESS_DENIAL + r"|" + COMMIT_AUTH_DENIAL)
    for group in artefact_surface_groups():
        for path in group:
            r = rel(path)
            for lineno, line in substrate_lines(path, r):
                low = line.lower()
                # Each gated shape is checked against ITS OWN denial set — a
                # membership denial answers the enumeration, not the
                # authorization. See the denial pair above.
                for gated_re, denial_re in ((RHYTHM_GATED_ENUM_RE, ENUM_DENIAL_RE),
                                            (RHYTHM_GATED_AUTH_RE, AUTH_DENIAL_RE)):
                    gm = gated_re.search(low)
                    if gm and not denial_re.search(
                            exemption_scope(low, gm.start(), gm.end())):
                        break
                    gm = None
                if not gm:
                    continue
                # The surface that CORRECTS this has to be able to name it —
                # "the local commit is NOT one of them", "the rhythm does not
                # gate it" — so a negation guard is needed. But the guard here
                # is about the COMMIT, not about any negation in the vicinity,
                # and both weaker forms were tried and measured to fail:
                #
                #   - the CLAUSE-scoped `NEGATION_RE` the sibling rules use let
                #     the pre-fix rhythm-B bullet through, because it ended
                #     "upfront, no per-action touchpoint" and that incidental
                #     "no" negates the touchpoint, not the commit. A real
                #     BLOCKER, silently swallowed.
                #   - narrowing the SAME generic guard to a window centred on
                #     the match only moved the hole: reordering the sentence to
                #     "No per-action touchpoint: irreversible actions (commit /
                #     branch publication / landing) remain rhythm-gated" puts
                #     the same irrelevant "no" back inside the window.
                #
                # A generic negation cannot distinguish them at any width, so
                # the guard names what must be denied, and is applied above in
                # EXEMPTION scope — a denial past ", but" is about a different
                # subject ("The worker does not authorize the commit, but
                # irreversible actions (…) remain rhythm-gated").
                findings.append(
                    f"SUBSTRATE-ORDER {r}:{lineno}: the local commit is not a rhythm-gated "
                    f"irreversible — the dispatch authorizes it under A/B/C/D alike")

    # (f) WRITE-SURFACE CONSISTENCY, derived from the policy rather than from a
    # list someone has to maintain: when a weight grants a role NO writes, that
    # weight's surfaces for the role must not instruct a file write. This is the
    # one rule that cannot go stale — it re-reads the authorization every run, so
    # emptying a write scope automatically starts policing the prose that went
    # with it. The patterns match an AFFIRMATIVE step ("- `Write` the …",
    # "3. `Edit` …") and the output-directory vocabulary; a denial that leads
    # with the negation ("- No `Write`, no `Edit`: …") does not match, because
    # forbidding the tool is exactly what these surfaces should be doing.
    WRITE_INSTRUCTION_RE = re.compile(
        r"^\s*(?:[-*]|\d+[.)])\s*(?:\*\*)?`(?:Write|Edit|MultiEdit)`"
        r"|output director(?:y|ies)|output dir\b|designated output"
        # ...and the FILE LIFECYCLE grammar, not only the write tool: a role
        # with no write scope has no filename to preserve, no path to deliver,
        # and nothing to call a write surface. Naming any of them re-teaches the
        # file era in prose the tool-token rule reads straight past.
        # Written to be exact rather than negation-guarded: a generic "does this
        # line contain a 'no'?" guard silently swallowed "Strategy filenames are
        # dated ... don't rename old ones", which IS stale. `(?<!no )write
        # surface` excludes only the correction ("no write surface"), and
        # `filenames are` never matches "a recipient token in a filename".
        r"|(?<![Nn]o )write surface|[Ff]ilenames? (?:are|is)\b|prior path|\+ committed"
        r"|written and committed"
        # READ side and path delivery, case-insensitively: a role whose only
        # artefact is a record has no path to deliver and nothing to `Read`,
        # `cat` or `sed`. The earlier lowercase-only rule read straight past a
        # capitalised "Deliver the path".
        r"|[Dd]eliver(?:s|ing)? the path|[Dd]eliver(?:s|ing)? [^.\n]{0,24}path\b"
        r"|`Read` (?:the |your |its )?(?:artefact|verdict|strategy|record|file)"
        r"|via `functions\.exec_command` \(`cat`|\(`cat` / `sed`\)"
        # ...and any remaining path / commit lifecycle around the role's own
        # artefact. A record has no path to hand over and no commit to gate on.
        # Narrow on purpose: `before commit` alone matches the WORKER's section
        # name ("Cross-model adversarial review before commit"), which these
        # roles legitimately cite, and `no strategy commit` is the correction.
        r"|counts? and path\b|commit/delivery"
        r"|(?<!no )(?:strategy|verdict) commits?\b")
    for setname, policies in ((WEIGHTS[0], full), (WEIGHTS[1], lite)):
        for role in sorted(policies):
            writes = policies[role].get("artefacts", {}).get("writes")
            if writes:                      # non-empty grant: nothing to police
                continue
            for path in role_surfaces(setname, role):
                r = rel(path)
                for lineno, line in substrate_lines(path, r):
                    m = WRITE_INSTRUCTION_RE.search(line)
                    if not m:
                        continue
                    findings.append(
                        f"SUBSTRATE-WRITE {r}:{lineno}: {role} has no write scope in "
                        f"{setname}, but this instructs a file write")

    # (e) policy grants that still prescribe a retired push/landing convention.
    for setname, policies in ((WEIGHTS[0], full), (WEIGHTS[1], lite)):
        subdir = "role-policies" if setname == WEIGHTS[0] else "lite/role-policies"
        for role in sorted(policies):
            pol = policies[role]
            prescriptive = []
            for rhythm, rule in sorted((pol.get("git", {}).get("push_rules") or {}).items()):
                prescriptive.append((f"git.push_rules.{rhythm}", rule))
            for stop in pol.get("stops_and_overrides") or []:
                if isinstance(stop, dict) and isinstance(stop.get("action"), str):
                    prescriptive.append(
                        (f"stops_and_overrides.{stop.get('condition', '?')}.action", stop["action"]))
            may_decide = pol.get("authority", {}).get("may_decide")
            if isinstance(may_decide, str):
                may_decide = [may_decide]
            for tok in may_decide or []:
                if not isinstance(tok, str) or not MAY_DECIDE_GIT_RE.search(tok):
                    continue
                if tok in MAY_DECIDE_GIT_PERMITS.get(role, frozenset()):
                    continue
                findings.append(
                    f"SUBSTRATE-POLICY {subdir}/{role}.policy.json: authority.may_decide: "
                    f"'{tok}' grants merge / push / landing execution")

            for field, value in prescriptive:
                for rx in POLICY_FORBIDDEN_FRAGMENTS:
                    m = rx.search(value)
                    if m:
                        findings.append(
                            f"SUBSTRATE-POLICY {subdir}/{role}.policy.json: {field}: "
                            f"'{value}' prescribes the retired '{m.group(0)}' convention")

    # (d) role-aware permits, derived from the COMPLETE role manifest (both
    # policy sets), so no role can escape the rule by being lite-only or
    # full-only.
    manifest = set(full) | set(lite)
    for tool, permitted in sorted(ROLE_TOOL_PERMITS.items()):
        for ghost in sorted(permitted - manifest):
            findings.append(
                f"SUBSTRATE-ROLE: '{ghost}' is permitted {tool} but is not a role in the manifest")
    forbids = {tool: manifest - permitted for tool, permitted in ROLE_TOOL_PERMITS.items()}
    for tool in sorted(forbids):
        for role in sorted(forbids[tool]):
            for weight in WEIGHTS:
                for path in role_surfaces(weight, role):
                    if tool in tools_by_file.get(path, set()):
                        findings.append(
                            f"SUBSTRATE-ROLE {rel(path)}: {tool} is forbidden for {role}")


if substrate_enabled:
    substrate_check()

findings = list(dict.fromkeys(findings))  # dedupe, order-preserving
if findings:
    for f in findings:
        print(f"CONSISTENCY-CHECK FAIL: {f}", file=sys.stderr)
    print(f"CONSISTENCY-CHECK: {len(findings)} finding(s).", file=sys.stderr)
    sys.exit(1)
print(f"consistency check OK ({len(full)} full + {len(lite)} lite policies; "
      f"{len(exceptions)} pinned parity exception(s), all in use; "
      f"substrate parity {'ON' if substrate_enabled else 'OFF'})")
PYEOF

run_check() { python3 "$PY" "$1" "${2:-$SUBSTRATE}"; }

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
# python3 (already required by the selftest) rather than shasum/sha1sum, which
# are not the same binary — or even present — on every platform this runs on.
digest() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
BASELINE=""   # "<digest> <rel>" lines — what stage()/seed left on disk
rebaseline() {  # rebaseline <rel...> — (re)pin these files as the "unmutated" state
  local f d
  for f in "$@"; do
    if [ -e "$TMP/repo/$f" ]; then d=$(digest "$TMP/repo/$f"); else d="<absent>"; fi
    BASELINE=$(printf '%s\n' "$BASELINE" | /usr/bin/grep -v " $f\$" || true)
    BASELINE="$BASELINE
$d $f"
  done
}
changed() {  # changed <rel...> — EVERY named file must differ from the baseline
  # "A mutation that changed nothing proves nothing": without this a case would
  # assert against the UNMUTATED fixture and pass for the wrong reason. Applied
  # to every case, not only the substrate ones — a no-op mutation is exactly as
  # invisible in a parity case as in a substrate one.
  local f now was
  for f in "$@"; do
    if [ -e "$TMP/repo/$f" ]; then now=$(digest "$TMP/repo/$f"); else now="<absent>"; fi
    was=$(printf '%s\n' "$BASELINE" | awk -v k="$f" '$2==k{print $1}' | tail -1)
    if [ -z "$was" ]; then
      echo "SELFTEST FAIL: changed $f — not part of the staged baseline" >&2; exit 1
    fi
    if [ "$now" = "$was" ]; then
      echo "SELFTEST FAIL: $f is byte-identical to the staged fixture — the mutation did nothing" >&2
      exit 1
    fi
  done
}
stage() {  # fresh scratch copy of both sets + the exceptions file
  rm -rf "$TMP/repo"
  BASELINE=""
  mkdir -p "$TMP/repo/scripts" "$TMP/repo/role-policies" "$TMP/repo/lite/role-policies" "$TMP/repo/roles"
  cp role-policies/*.policy.json "$TMP/repo/role-policies/"
  cp lite/role-policies/*.policy.json "$TMP/repo/lite/role-policies/"
  cp scripts/policy-parity-exceptions.json "$TMP/repo/scripts/" 2>/dev/null || true
  # CLEAN SYNTHETIC SUBSTRATE FIXTURE. The staged prose surfaces carry the same
  # FILE NAMES as the live corpus — so per-role discovery walks the same surface
  # set — but NEVER its content: they are one-line stubs, empty of tool
  # references and legacy tokens. Copying the live files would let a substrate
  # case pass off pre-existing drift (the corpus is mid-convergence) or let a
  # shipped overlay mask a mutation of its base, and prove nothing either way.
  local f
  local -a rels=()
  for f in role-policies/*.policy.json lite/role-policies/*.policy.json roles/*.md lite/*.md; do
    [ -e "$f" ] || continue
    case "$f" in *.md) printf '# fixture\n' > "$TMP/repo/$f" ;; esac
    rels+=("$f")
  done
  # The root boundary contract is a scanned surface too — stage a clean stub so
  # a case can mutate it and prove it is actually reached.
  printf '# fixture\n' > "$TMP/repo/ROLES.md"
  rels+=("ROLES.md")
  [ -e "$TMP/repo/scripts/policy-parity-exceptions.json" ] && rels+=("scripts/policy-parity-exceptions.json")
  rebaseline "${rels[@]}"
}
SEEDED_SURFACES="roles/worker-agent.md roles/worker-agent.claude.md roles/worker-agent.codex.md
lite/worker-agent.md lite/worker-agent.claude.md"
seed_substrate_fixture() {
  # Deterministic content in EVERY worker surface that participates in the
  # union — both weights, base AND overlays. Each weight's union is therefore
  # {publish_artefact, deliver, settle_artefact, workitems.list} and the seeded
  # fixture passes; each mutation below moves exactly one known element.
  printf '# fixture\ncoordination.publish_artefact\ncoordination.deliver\nworkitems.list\n' \
    > "$TMP/repo/roles/worker-agent.md"
  printf '# fixture\ncoordination.settle_artefact\n' > "$TMP/repo/roles/worker-agent.claude.md"
  printf '# fixture\ncoordination.settle_artefact\n' > "$TMP/repo/roles/worker-agent.codex.md"
  printf '# fixture\ncoordination.publish_artefact\ncoordination.deliver\nworkitems.list\n' \
    > "$TMP/repo/lite/worker-agent.md"
  # lite ships .md + .claude.md only — there is no lite codex overlay to seed.
  printf '# fixture\ncoordination.settle_artefact\n' > "$TMP/repo/lite/worker-agent.claude.md"
  # The seed is part of the fixture, not a mutation: re-pin it, so a later
  # "mutation" of a seeded file that changes nothing is still caught.
  # shellcheck disable=SC2086
  rebaseline $SEEDED_SURFACES
}
mutate() {  # mutate <staged-path> <cmd...>   (cmd runs with cwd = staged root)
  local relp="$1"; shift
  ( cd "$TMP/repo" && "$@" )
  changed "$relp"
}
CASES=0
expect() {  # expect <name> <want-exit> [<required-diagnostic-pattern>]
  # The pattern pins WHICH check fired — exit 1 alone can come from the wrong
  # check (e.g. parity masking a broken lint) or an unrelated crash. It is
  # therefore MANDATORY for every failure case; only a clean pass may omit it.
  local name="$1" want="$2" pat="${3:-}" got=0 out
  if [[ "$want" != 0 && -z "$pat" ]]; then
    echo "SELFTEST FAIL: $name — failure cases must assert a diagnostic pattern" >&2; exit 1
  fi
  # Every case runs with substrate parity ON, so the selftest keeps proving that
  # check even while the real run has it gated off during the convergence.
  out=$(run_check "$TMP/repo" 1 2>&1) || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "SELFTEST FAIL: $name — exit $got, wanted $want" >&2
    echo "$out" >&2; exit 1
  fi
  if [[ -n "$pat" ]] && ! /usr/bin/grep -qF "$pat" <<<"$out"; then
    echo "SELFTEST FAIL: $name — diagnostic '$pat' not found in output" >&2
    echo "$out" >&2; exit 1
  fi
  CASES=$((CASES + 1))
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
changed lite/role-policies/worker.policy.json
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
changed role-policies/worker.policy.json lite/role-policies/worker.policy.json
expect "typo'd must_route target fails (both sets, lint-only)" 1 "neither a role in this set nor a pinned semantic target"

stage
python3 - "$TMP/repo/scripts/policy-parity-exceptions.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["exceptions"].append({"role": "worker", "field": "authority",
                        "path": "bogus", "root": "\"x\"", "lite": "\"y\""})
json.dump(d, open(p, "w"))
MEOF
changed scripts/policy-parity-exceptions.json
expect "stale exception fails" 1 "STALE exception"

stage
python3 - "$TMP/repo/lite/role-policies/worker.policy.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["git"]["push_rules"] = {"A": "x", "B": "y"}  # partial rhythm cover
json.dump(d, open(p, "w"))
MEOF
changed lite/role-policies/worker.policy.json
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
changed lite/role-policies/worker.policy.json
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
changed role-policies/worker.policy.json lite/role-policies/worker.policy.json
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
changed role-policies/worker.policy.json lite/role-policies/worker.policy.json
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
changed role-policies/worker.policy.json lite/role-policies/worker.policy.json
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
changed lite/role-policies/worker.policy.json scripts/policy-parity-exceptions.json
expect "pinned semantic change without kind fails" 1 "missing or unknown kind"
stage; attack "citation-repoint"
changed lite/role-policies/worker.policy.json scripts/policy-parity-exceptions.json
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
changed scripts/policy-parity-exceptions.json
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
changed scripts/policy-parity-exceptions.json
expect "citation-repoint pin outside the owned set fails" 1 "checker-owned"

# Deleting a shipped lite role must fail unless declared in lite_omissions.
stage
rm "$TMP/repo/lite/role-policies/ops.policy.json"
changed lite/role-policies/ops.policy.json
expect "removed lite role fails" 1 "not a declared omission"

stage
python3 - "$TMP/repo/scripts/policy-parity-exceptions.json" <<'MEOF'
import json, sys
p = sys.argv[1]; e = json.load(open(p))
e["lite_omissions"].append({"role": "qa", "reason": "pretend"})
json.dump(e, open(p, "w"))
MEOF
changed scripts/policy-parity-exceptions.json
expect "stale lite omission fails" 1 "actually present in lite"

# ---------------------------------------------------------------------------
# Substrate parity. Every case starts from `stage; seed_substrate_fixture` — a
# FRESH clean fixture, never a mutated predecessor — and every mutation goes
# through `mutate`, which fails the selftest if the bytes did not change.
# ---------------------------------------------------------------------------
stage; seed_substrate_fixture
expect "seeded substrate fixture passes" 0

stage; seed_substrate_fixture
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("see docs/hand"+"offs/x.md\n")'
expect "legacy token in lite fails" 1 "SUBSTRATE-LEGACY lite/worker-agent.md"

# One-sided deletion. `settle_artefact` is deliberately NOT reported: the lite
# OVERLAY still names it. That is exactly the masking the fixture makes visible
# and controlled — the union is per weight, not per file.
stage; seed_substrate_fixture
mutate lite/worker-agent.md python3 -c \
  'p="lite/worker-agent.md";ls=open(p).read().splitlines(True);open(p,"w").writelines([l for l in ls if "coordination." not in l])'
expect "one-sided deletion fails" 1 \
  "SUBSTRATE-SET worker: only in roles: coordination.deliver coordination.publish_artefact"

stage; seed_substrate_fixture
mutate roles/worker-agent.md python3 -c \
  'p="roles/worker-agent.md";t=open(p).read();open(p,"w").write(t.replace("coordination.deliver","coordination.delivr"))'
expect "rename in one weight fails" 1 "SUBSTRATE-VOCAB roles/worker-agent.md"

stage; seed_substrate_fixture
mutate roles/worker-agent.md python3 -c \
  'open("roles/worker-agent.md","a").write("use workitems.get\n")'
expect "one-sided addition fails" 1 "SUBSTRATE-SET worker: only in roles: workitems.get"

stage; seed_substrate_fixture
mutate roles/reviewer-agent.md python3 -c \
  'open("roles/reviewer-agent.md","a").write("route it to docs/code-"+"reviews/x.md\n")'
expect "governance dir fails" 1 "SUBSTRATE-LEGACY roles/reviewer-agent.md"

# Overlay drift: the full-weight overlays still name the tool, the lite union
# lost it. Only a union that INCLUDES overlays can see this.
stage; seed_substrate_fixture
mutate lite/worker-agent.claude.md python3 -c \
  'p="lite/worker-agent.claude.md";ls=open(p).read().splitlines(True);open(p,"w").writelines([l for l in ls if "coordination." not in l])'
expect "lite OVERLAY drift fails" 1 "SUBSTRATE-SET worker: only in roles: coordination.settle_artefact"

# A properly fenced ```historical block is quoted history — exempt.
stage; seed_substrate_fixture
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("```historical\nsee docs/hand"+"offs/x.md\n```\n")'
expect "fenced historical block is exempt" 0

# ... but an INDENTED "fence" is not a fence (CommonMark: at most 3 leading
# spaces), so it cannot exempt the active text that follows it.
stage; seed_substrate_fixture
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("    ```historical\nsee docs/hand"+"offs/x.md\n")'
expect "over-indented historical fence does NOT exempt" 1 "SUBSTRATE-LEGACY lite/worker-agent.md"

# ... and an UNCLOSED one is itself a finding: otherwise opening ```historical
# and never closing it exempts the whole tail of the file.
stage; seed_substrate_fixture
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("```historical\nsee docs/hand"+"offs/x.md\n")'
expect "unclosed historical fence fails" 1 "SUBSTRATE-FENCE lite/worker-agent.md"

# A policy CONTRACT FIELD name in the git.* namespace gets NO exemption: an
# exemption keyed on the name alone would equally excuse an active instruction,
# and a tool renamed onto such a name would evade the closed vocabulary.
stage; seed_substrate_fixture
mutate roles/worker-agent.md python3 -c \
  'open("roles/worker-agent.md","a").write("call git.forbidden\n")'
expect "contract-field name is not exempt from the vocabulary" 1 \
  "SUBSTRATE-VOCAB roles/worker-agent.md"

# A malformed tool name must be SEEN, not lexed away. Seeded in BOTH weights so
# set-equality stays silent and only the vocabulary rule can fail the run.
stage; seed_substrate_fixture
mutate roles/worker-agent.md python3 -c \
  'open("roles/worker-agent.md","a").write("coordination.deliverNow\n")'
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("coordination.deliverNow\n")'
expect "malformed tool name (capitals) fails the vocabulary" 1 \
  "SUBSTRATE-VOCAB roles/worker-agent.md"

# The punctuation forms, each of which a prefix-stopping lexer would reduce to a
# VALID token and wave through — including the REPEATED-separator forms, which a
# lexer that allows only ONE dot per segment boundary still truncates to
# `coordination.deliver`. Seeded in both weights, so only the vocabulary rule can
# fail the run.
for bad in 'coordination.deliver-now' 'coordination.deliver.now' 'git.push_branch-v2' \
           'coordination.deliver..now' 'coordination..deliver'; do
  stage; seed_substrate_fixture
  mutate roles/worker-agent.md python3 -c \
    "open('roles/worker-agent.md','a').write('$bad\n')"
  mutate lite/worker-agent.md python3 -c \
    "open('lite/worker-agent.md','a').write('$bad\n')"
  expect "malformed tool name '$bad' fails the vocabulary" 1 \
    "SUBSTRATE-VOCAB roles/worker-agent.md"
done

# ... and a sentence-final period is punctuation, not a malformed name.
stage; seed_substrate_fixture
mutate roles/worker-agent.md python3 -c \
  'open("roles/worker-agent.md","a").write("then call coordination.deliver.\n")'
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("then call coordination.deliver.\n")'
expect "a sentence-final period is not part of the tool name" 0

# ... and neither is a TRAILING RUN of separators. This is a deliberate,
# pinned decision, not an oversight: trailing punctuation names no tool other
# than the valid one it follows, so nothing is hidden — an invented name
# (`coordination.evil..`) and a forbidden one (`git.request_landing..`) are both
# still lexed and still fail. Lexing a maximal `[A-Za-z0-9_.-]+` candidate to
# "catch" the trailing run instead turns an ordinary prose ellipsis into a hard
# SUBSTRATE-VOCAB failure on a corpus that is mostly prose. Seeded in BOTH
# weights, so this asserts the vocabulary rule and nothing else.
stage; seed_substrate_fixture
mutate roles/worker-agent.md python3 -c \
  'open("roles/worker-agent.md","a").write("then call coordination.deliver...\n")'
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("then call coordination.deliver...\n")'
expect "a trailing ellipsis is punctuation, not a malformed name" 0

# Deleting a whole base must not remove its role from the comparison. The role
# set comes from the POLICY MANIFEST, so the loss is named directly.
stage; seed_substrate_fixture
rm "$TMP/repo/lite/worker-agent.md"
changed lite/worker-agent.md
expect "missing base playbook fails" 1 "SUBSTRATE-BASE lite/worker-agent.md"

# A GENERATED block may not buy substrate exemption by quoting itself as history.
stage; seed_substrate_fixture
mutate lite/worker-agent.md python3 -c \
  'open("lite/worker-agent.md","a").write("```historical\n<!-- BEGIN GENERATED: doctrine worker -->\n```\n")'
expect "a GENERATED marker inside an exempt fence fails" 1 "SUBSTRATE-FENCE lite/worker-agent.md"

# ---------------------------------------------------------------------------
# Role-aware permits. The forbidden set is DERIVED from the role manifest, so
# the selftest iterates the manifest too — a role added later is covered without
# editing a list here (and bumps the asserted case count, which is the point).
# ---------------------------------------------------------------------------
manifest_roles() {  # the COMPLETE role manifest: both policy sets, deduped
  local p b
  for p in role-policies/*.policy.json lite/role-policies/*.policy.json; do
    [ -e "$p" ] || continue
    b=$(basename "$p"); printf '%s\n' "${b%.policy.json}"
  done | sort -u
}
seed_tool() {  # seed_tool <role> <tool> — into BOTH weights where the file exists
  local role="$1" tool="$2" w f
  for w in roles lite; do
    f="$TMP/repo/$w/${role}-agent.md"
    [ -f "$f" ] || continue
    mutate "$w/${role}-agent.md" python3 -c \
      "open('$w/${role}-agent.md','a').write('$tool\n')"
  done
}
for role in $(manifest_roles); do
  if [[ "$role" == "lead" ]]; then continue; fi
  stage; seed_substrate_fixture
  seed_tool "$role" "git.request_landing"
  expect "git.request_landing forbidden for $role" 1 \
    "SUBSTRATE-ROLE roles/${role}-agent.md: git.request_landing is forbidden for $role"
done
# The permitted case: the lead may be taught it, in both weights, and passes.
stage; seed_substrate_fixture
seed_tool lead "git.request_landing"
expect "git.request_landing permitted for lead" 0

# The second permit entry: push_branch is worker+lead only.
stage; seed_substrate_fixture
seed_tool reviewer "git.push_branch"
expect "git.push_branch forbidden for reviewer" 1 \
  "SUBSTRATE-ROLE roles/reviewer-agent.md: git.push_branch is forbidden for reviewer"

# ---- pattern rules: the two classes the exact-substring token list misses ----
# A routing token spelt with a placeholder the token list never enumerated. The
# literal `-to-<recipient` case above passes with the substring rule alone; this
# one can only be caught by shape.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "name it %s-<dispatcher-id>- and stop\n" "-to" >> roles/worker-agent.md'
expect "routing token in any spelling fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: recipient-routing token"

# A direct push instruction. The daemon is the only git egress, so the literal
# command may not appear at all — including inside a "never do this" sentence,
# since a negation-aware rule is what a later edit would slip past.
stage; seed_substrate_fixture
mutate lite/worker-agent.md \
  sh -c 'printf "then run git %s origin <branch>\n" "push" >> lite/worker-agent.md'
expect "direct git push fails" 1 \
  "SUBSTRATE-LEGACY lite/worker-agent.md:5: direct git push"

# The root boundary contract is scanned: a legacy token there must fail. Without
# this the whole ROLES.md surface could silently drop out of the scan set.
stage; seed_substrate_fixture
mutate ROLES.md sh -c 'printf "route it to docs/handoffs/x.md\n" >> ROLES.md'
expect "legacy token in the root contract fails" 1 \
  "SUBSTRATE-LEGACY ROLES.md:2: docs/handoffs"

# ---- the remaining push/landing shapes a literal `git push` rule misses ----
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "Whitelist: \`commit\`, \`%s\`, \`fetch\`\n" "push" >> roles/worker-agent.md'
expect "push granted in a command whitelist fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: push in a command whitelist"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "under D, commit and stop for the single %s\n" "pusher" >> roles/worker-agent.md'
expect "single-pusher convention fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: self-push / single-pusher convention"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "proceed to commit + %s per option B\n" "push" >> roles/worker-agent.md'
expect "commit-and-push procedure fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: commit-and-push procedure"

# ...and the enumerations that are NOT instructions must keep passing, or the
# rule above would force the rhythm tables and the denial lists to lie.
#
# The fixture's parenthesised list used to read "(commit / push / merge)",
# copied from the rhythm table as it stood — which means it had inherited that
# table's defect: the local commit listed among the actions a rhythm gates. It
# passed here only because no rule was looking. Rule (j2) now looks, and this
# case is the first thing it caught. The list is corrected to the true gated set;
# the case still proves what it was written to prove, because `push` is what the
# LEGACY rule under test keys on and it is still present in both enumerations.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "irreversible actions (branch publication / %s / merge) and refusing to commit, %s, dispatch\n" "push" "push" >> roles/worker-agent.md'
expect "a comma or spaced-slash enumeration is not an instruction" 0

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "the worker %s it under green-path delegation\n" "lands" >> roles/worker-agent.md'
expect "worker-performs-the-landing fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: worker performs the landing"

# (e) the same conventions surviving as POLICY tokens, where the prose rules
# cannot see them and the rendered contract table puts them back on screen.
stage
python3 - "$TMP/repo/role-policies/worker.policy.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["git"]["push_rules"] = {k: "self_push_one_commit_per_unit" for k in "ABCD"}
json.dump(d, open(p, "w"))
MEOF
changed role-policies/worker.policy.json
expect "policy push_rules prescribing self-push fails" 1 \
  "SUBSTRATE-POLICY role-policies/worker.policy.json: git.push_rules.A"

stage
python3 - "$TMP/repo/lite/role-policies/worker.policy.json" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
for stop in d["stops_and_overrides"]:
    stop["action"] = "land_authorized_green_path_push_per_overlay_binding"
    break
json.dump(d, open(p, "w"))
MEOF
changed lite/role-policies/worker.policy.json
expect "policy stop action prescribing a worker landing fails" 1 \
  "SUBSTRATE-POLICY lite/role-policies/worker.policy.json: stops_and_overrides."

# A `forbidden` list may name the very thing it denies — that is the field's
# job, and banning the word there would make it impossible to say "no".
# Mutating BOTH weights keeps boundary parity clean, so a non-zero exit here
# could only come from the new rule — which makes the expected 0 a real
# assertion that the rule stayed out of the forbidden lists, not a pass that
# some other check happened to mask.
stage
for f in "$TMP/repo/role-policies/worker.policy.json" "$TMP/repo/lite/role-policies/worker.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["authority"]["forbidden"] = list(d["authority"]["forbidden"]) + ["self_push_to_main"]
d["git"]["forbidden"] = list(d["git"].get("forbidden", [])) + ["worker_lands_the_merge"]
json.dump(d, open(p, "w"))
MEOF
done
changed role-policies/worker.policy.json lite/role-policies/worker.policy.json
expect "a forbidden list may name the retired convention" 0

# ---- the exact spellings that slipped past the first generalization ----
# Brace notation: the substring token list cannot see `docs/{tasks,closeouts}`
# at all, and a path-convention paragraph reaches for exactly that shorthand.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "convention: <repo>/docs/{%s,closeouts}/ with date prefixes\n" "tasks" >> roles/worker-agent.md'
expect "retired directory in brace notation fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: retired record directory in brace notation"

# Sentence-initial capitals: a case-sensitive rule waves the capitalised half of
# the corpus through, and prose capitalises at every full stop.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "Commit + %s the artefact.\n" "push" >> roles/worker-agent.md'
expect "a capitalised commit-and-push instruction fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: commit-and-push procedure"

# `_single_pusher` inside a token: `_` is a word character, so a leading \b in
# the rule never fires on the very identifier the rule exists to catch.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "push rule reads commit_and_stop_lead_is_single_%s here\n" "pusher" >> roles/worker-agent.md'
expect "single-pusher inside an identifier fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: self-push / single-pusher convention"

# A policy action still prescribing the file-era routing token.
stage
for f in "$TMP/repo/role-policies/qa.policy.json" "$TMP/repo/lite/role-policies/qa.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["stops_and_overrides"][0]["action"] = "emit_artefact_with_routing_token_and_stop"
json.dump(d, open(p, "w"))
MEOF
done
changed role-policies/qa.policy.json lite/role-policies/qa.policy.json
expect "policy action prescribing a routing token fails" 1 \
  "SUBSTRATE-POLICY role-policies/qa.policy.json: stops_and_overrides."

# ...and `green_path` must NOT trip the file-era `_path` rule, or every policy
# that names the green path would fail for the wrong reason.
stage
for f in "$TMP/repo/role-policies/qa.policy.json" "$TMP/repo/lite/role-policies/qa.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["stops_and_overrides"][0]["action"] = "buffer_to_operator_never_green_path_eligible"
json.dump(d, open(p, "w"))
MEOF
done
changed role-policies/qa.policy.json lite/role-policies/qa.policy.json
expect "green_path is not the file-era path convention" 0

# Plural: the shipped drift said "commits + pushes", and a rule anchored on the
# singular verb read it as clean.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "option B commits + %s continuously\n" "pushes" >> roles/worker-agent.md'
expect "a plural commits-and-pushes instruction fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: commit-and-push procedure"

# A GRANT, not a prescription: `authority.may_decide` handed the lead a worktree
# merge outright, in a field the prescriptive scan did not read at all.
stage
for f in "$TMP/repo/role-policies/lead.policy.json" "$TMP/repo/lite/role-policies/lead.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["authority"]["may_decide"] = list(d["authority"]["may_decide"]) + ["worktree_merge_and_gated_cleanup"]
json.dump(d, open(p, "w"))
MEOF
done
changed role-policies/lead.policy.json lite/role-policies/lead.policy.json
expect "may_decide granting merge execution fails" 1 \
  "SUBSTRATE-POLICY role-policies/lead.policy.json: authority.may_decide: 'worktree_merge_and_gated_cleanup'"

# ...and the permitted entries stay permitted, or the rule would forbid the CTO
# from AUTHORIZING a landing and the lead from REQUESTING one.
stage; expect "the permitted may_decide git entries pass" 0

# The permit is role-scoped: the lead's entry does not license the CTO's seat.
stage
for f in "$TMP/repo/role-policies/cto.policy.json" "$TMP/repo/lite/role-policies/cto.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["authority"]["may_decide"] = list(d["authority"]["may_decide"]) + ["landing_request_and_gated_cleanup"]
json.dump(d, open(p, "w"))
MEOF
done
changed role-policies/cto.policy.json lite/role-policies/cto.policy.json
expect "the lead's permit does not license another role" 1 \
  "SUBSTRATE-POLICY role-policies/cto.policy.json: authority.may_decide: 'landing_request_and_gated_cleanup'"

# The gerund spelling of the same procedure.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "committing/%s coordination artefacts via Bash\n" "pushing" >> roles/worker-agent.md'
expect "the gerund commit/push spelling fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: commit-and-push procedure"

# The landing grant hyphenated into one verb.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "a merge you may green-path-%s when all-green\n" "land" >> roles/worker-agent.md'
expect "the hyphenated green-path-land grant fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: worker performs the landing"

# The file era naming itself.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "respond via chat or file-based %s without routing\n" "exchange" >> roles/worker-agent.md'
expect "file-era coordination vocabulary fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: file-era coordination vocabulary"

# (f) WRITE-SURFACE CONSISTENCY. The fixture's qa policy is emptied of writes,
# then a write instruction is seeded into its surface: the rule must derive the
# violation from the POLICY, not from a maintained list of roles.
stage; seed_substrate_fixture
for f in "$TMP/repo/role-policies/qa.policy.json" "$TMP/repo/lite/role-policies/qa.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["artefacts"]["writes"] = []
json.dump(d, open(p, "w"))
MEOF
done
mutate roles/qa-agent.md sh -c 'printf -- "- \`Write\` the strategy in the output directory.\n" >> roles/qa-agent.md'
expect "a write instruction with no write scope fails" 1 \
  "SUBSTRATE-WRITE roles/qa-agent.md:2: qa has no write scope in roles"

# ...and DENYING the tool is not instructing it, or the rule would forbid these
# surfaces from saying the one thing they must say.
stage; seed_substrate_fixture
for f in "$TMP/repo/role-policies/qa.policy.json" "$TMP/repo/lite/role-policies/qa.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["artefacts"]["writes"] = []
json.dump(d, open(p, "w"))
MEOF
done
mutate roles/qa-agent.md sh -c 'printf -- "- No \`Write\`, no \`Edit\`: this role writes nothing.\n" >> roles/qa-agent.md'
expect "denying the write tool is not instructing it" 0

# ...and a role that DOES hold a write scope keeps its file instructions.
stage; seed_substrate_fixture
mutate roles/architect-agent.md sh -c 'printf -- "- \`Write\` the ADR in the output directory.\n" >> roles/architect-agent.md'
expect "a write instruction with a write scope passes" 0

# The reversed word order the noun-list form missed.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "Default communication is file-%s.\n" "based" >> roles/worker-agent.md'
expect "file-based in reversed word order fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: file-era coordination vocabulary"

# Egress spellings that name no git command.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "network beyond %s, branch fetch, review gate\n" "push" >> roles/worker-agent.md'
expect "a network-beyond-push carve-out fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: agent-side git egress"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "commit or %s coordination artefacts when the rhythm allows\n" "push" >> roles/worker-agent.md'
expect "commit-or-push authorization fails" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: agent-side git egress"

# ...but the sentence that FORBIDS it names the same words and must pass.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "There is nothing to stage, commit or %s.\n" "push" >> roles/worker-agent.md'
expect "denying the egress is not authorizing it" 0

# (g) a coordination artefact written to the filesystem — by a role that DOES
# hold a write scope, which is exactly the case rule (f) skips.
stage; seed_substrate_fixture
mutate roles/lead-agent.md \
  sh -c 'printf -- "- when you \`Write\` a reviewer task brief, include the SHA\n" >> roles/lead-agent.md'
expect "writing a coordination artefact to a file fails" 1 \
  "SUBSTRATE-RECORD-WRITE roles/lead-agent.md:2"

# ...and the line that says they are NOT files must pass, or the correction
# itself becomes the violation.
stage; seed_substrate_fixture
mutate roles/lead-agent.md \
  sh -c 'printf -- "- \`Write\` only durable docs; close-outs and handoffs are NOT files.\n" >> roles/lead-agent.md'
expect "saying coordination artefacts are not files passes" 0

# ...and the WIP staging draft stays the one sanctioned on-disk exception.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the handoff at the staging path under .wip-handoff-staging/\n" >> roles/worker-agent.md'
expect "the wip staging draft stays writable" 0

# CLAUSE-LOCAL negation. A whole-line guard let a correct clause at the start of
# a long line mask a stale affirmative clause at the end of it.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "You never push. Later in the same line: commit or %s coordination artefacts freely when the rhythm allows it.\n" "push" >> roles/worker-agent.md'
expect "a correct clause does not mask a stale one later on the line" 1 \
  "SUBSTRATE-LEGACY roles/worker-agent.md:5: agent-side git egress"

# The write-tool spelling rule (g) missed because the artefact sat past its
# window and an unrelated "not" elsewhere on the line tripped the old guard.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- when you \`Write\` an architect/QA/designer/reviewer task brief, cite the SHA, not \`main\`.\n" >> roles/worker-agent.md'
expect "a distant artefact with an unrelated negation still fails" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# File LIFECYCLE grammar in a role with no write scope — no write tool named.
stage; seed_substrate_fixture
for f in "$TMP/repo/role-policies/qa.policy.json" "$TMP/repo/lite/role-policies/qa.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["artefacts"]["writes"] = []
json.dump(d, open(p, "w"))
MEOF
done
mutate roles/qa-agent.md sh -c 'printf -- "- Strategy filenames are dated; cite the prior path when superseding.\n" >> roles/qa-agent.md'
expect "file lifecycle grammar with no write scope fails" 1 \
  "SUBSTRATE-WRITE roles/qa-agent.md:2"

# ...and the correction that DENIES a write surface must still pass.
stage; seed_substrate_fixture
for f in "$TMP/repo/role-policies/qa.policy.json" "$TMP/repo/lite/role-policies/qa.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["artefacts"]["writes"] = []
json.dump(d, open(p, "w"))
MEOF
done
mutate roles/qa-agent.md sh -c 'printf -- "- No write surface: this role has no write surface at all.\n" >> roles/qa-agent.md'
expect "denying a write surface is not claiming one" 0

# ...and the assertion that the artefact is NOT a file must still pass, since
# that is the sentence the corrected surfaces carry.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` durable docs only; your close-outs are a record, not a file.\n" >> roles/worker-agent.md'
expect "asserting the artefact is not a file passes" 0

# (h) SEMANTIC EGRESS ALIASES: the act assigned in English, with no tool named.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "commit and STOP; the dispatcher %s the branch\n" "publishes" >> roles/worker-agent.md'
expect "an egress alias with no tool named fails" 1 \
  "SUBSTRATE-EGRESS roles/worker-agent.md:5: 'the dispatcher'"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "relay the go for an operator/lead to %s the merge\n" "execute" >> roles/worker-agent.md'
expect "an operator executing the merge fails" 1 \
  "SUBSTRATE-EGRESS roles/worker-agent.md:5"

# ...and the two roles the daemon DOES admit keep their sentences.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "commit and STOP; the lead %s the branch\n" "publishes" >> roles/worker-agent.md'
expect "the lead publishing a branch is permitted" 0

# ...and "pushes back" is a figure of speech, not git egress.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "PM %s back on whether the plan should exist\n" "pushes" >> roles/worker-agent.md'
expect "pushing back is not pushing" 0

# (g) lifecycle verbs that move a record around as if it were a file.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "expect the move-and-commit publication of the close-out in the cycle batch\n" >> roles/worker-agent.md'
expect "a move-and-commit record publication fails" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# A landing with NO actor named — the most dangerous spelling, because it reads
# as a property of the work rather than as an act somebody performs, and rule
# (h)'s actor list has nothing to match on.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "a conflict-disjoint docs deliverable still lands in-place on %s\n" "main" >> roles/worker-agent.md'
expect "an actor-free direct-main landing fails" 1 \
  "SUBSTRATE-EGRESS roles/worker-agent.md:5: a landing with no actor"

# Path/commit lifecycle on the artefact of a role with no write scope, in the
# read/deliver direction rule (f) originally ignored.
stage; seed_substrate_fixture
for f in "$TMP/repo/role-policies/reviewer.policy.json" "$TMP/repo/lite/role-policies/reviewer.policy.json"; do
python3 - "$f" <<'MEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["artefacts"]["writes"] = []
json.dump(d, open(p, "w"))
MEOF
done
mutate roles/reviewer-agent.md sh -c 'printf -- "5. Deliver the verdict to the lead with counts and %s.\n" "path" >> roles/reviewer-agent.md'
expect "delivering a path with no write scope fails" 1 \
  "SUBSTRATE-WRITE roles/reviewer-agent.md:2"

# (i1) RECORD PATH GRAMMAR — role-independent. The lead holds a durable-document
# write grant, so rule (f) skipped its surfaces entirely and a handoff PATH
# survived every round. A handoff has no path for anybody.
stage; seed_substrate_fixture
mutate roles/lead-agent.md \
  sh -c 'printf "route it to the operator with the lead-to-PM handoff %s and your reading\n" "path" >> roles/lead-agent.md'
expect "a handoff path in a role WITH a write grant fails" 1 \
  "SUBSTRATE-RECORD-READ roles/lead-agent.md:2"

# (i2) A FILESYSTEM READ aimed at a record, again in a role rule (f) skips.
stage; seed_substrate_fixture
mutate roles/lead-agent.md \
  sh -c 'printf -- "- \`Read\` the worker close-out before you clear the gate\n" >> roles/lead-agent.md'
expect "a filesystem read of a close-out fails" 1 \
  "SUBSTRATE-RECORD-READ roles/lead-agent.md:2"

# ...and the SAME sentence with the daemon read named must pass, or the
# corrected surfaces cannot say what they now say.
# Appended to BOTH weights: `coordination.read_artefact` is a vocabulary token,
# so adding it to one weight alone would fail the union-parity check instead of
# the rule under test, and the case would pass for the wrong reason.
stage; seed_substrate_fixture
( cd "$TMP/repo" && printf -- "- Read the worker close-out with \`coordination.read_artefact {id}\` before you clear the gate\n" | tee -a roles/worker-agent.md >> lite/worker-agent.md )
changed roles/worker-agent.md lite/worker-agent.md
expect "reading the record through the daemon passes" 0

# ...and a read of a SKILL FILE whose own name contains a record kind is not a
# read of a record. This is the false positive a bare proximity window produced
# on three correct lines.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- invoking means reading .claude/agent/skills/coordination-wip-handoff/SKILL.md via \`functions.exec_command\` (e.g., \`cat .claude/agent/skills/coordination-wip-handoff/SKILL.md\`)\n" >> roles/worker-agent.md'
expect "reading a skill file named after a record kind passes" 0

# ...and the PLURAL is the other sense of the word: trigger paths are routes.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "the three WIP-handoff trigger %s share one artefact shape\n" "paths" >> roles/worker-agent.md'
expect "wip-handoff trigger paths are routes, not filesystem paths" 0

# (i1) THE ADR-CITES-A-VERDICT-BY-PATH form. It names the ADR, so a blanket
# document exemption would exempt the drift by its own evidence.
stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf "the ADR cites the verdict by %s in the same commit\n" "path" >> roles/architect-agent.md'
expect "an ADR citing a verdict by path fails" 1 \
  "SUBSTRATE-RECORD-READ roles/architect-agent.md:2"

# (i1) THE COMPARATIVE VERDICT FILED AS A FILE.
stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf "emit one artefact per input plus a comparison.md at the same %s level\n" "path" >> roles/architect-agent.md'
expect "a comparison.md beside per-input review files fails" 1 \
  "SUBSTRATE-RECORD-READ roles/architect-agent.md:2"

# (g) THE VERDICT NOUN, previously excluded outright — which is how a whole
# verdict-file workflow survived. Policed now, with the DOCUMENT SURFACE (not
# the role) buying the exemption.
stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf -- "- \`Write\` the verdict into the review file you commit\n" >> roles/architect-agent.md'
expect "writing a verdict to a file fails" 1 \
  "SUBSTRATE-RECORD-WRITE roles/architect-agent.md:2"

# ...and the long-form REPORT and the ADR really are documents: naming their
# home is what separates them from the verdict record.
stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf -- "- \`Write\` the long-form review report under docs/design-reviews/ alongside the verdict\n" >> roles/architect-agent.md'
expect "writing the long-form report at its document home passes" 0

# (j) THE CLOSE-OUT SEQUENCE, which is an ORDER and not a token — five surfaces
# taught mutually incompatible orders while every token rule read them clean.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "treat the cadence as continuous close-out %s commit %s branch publication\n" "->" "->" >> roles/worker-agent.md'
expect "a close-out placed before its commit fails" 1 \
  "SUBSTRATE-ORDER roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "commit the in-scope code, then publish the branch and the close-%s\n" "out" >> roles/worker-agent.md'
expect "a branch published before the close-out fails" 1 \
  "SUBSTRATE-ORDER roles/worker-agent.md:5"

# ...and the ONE executable order must pass, or the fix cannot be written down.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf "commit locally, publish and deliver the close-out naming that SHA, then publish the %s\n" "branch" >> roles/worker-agent.md'
expect "the canonical close-out sequence passes" 0

# The ARTEFACT-KEYED rules must REACH the root boundary contract. They are
# role-independent by construction, but the iteration that scoped them was
# weight-shaped, so ROLES.md — the canonical semantics table every role reads —
# was the one surface they could not see. Its legacy-token case above proves the
# vocabulary scan reaches it; this proves rules (g)/(h)/(i)/(j) do too.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "cadence: continuous close-out %s commit %s branch publication\n" "->" "->" >> ROLES.md'
expect "an order violation in the root contract fails" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# (j2) THE RHYTHM-GATED SET, stated as MEMBERSHIP rather than as an order. This
# is the shape that actually shipped: both table columns internally well-formed,
# contradicting each other one column apart, and no order pattern matching.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "the operator green-lights each irreversible action (%s / branch publication / landing) individually\n" "commit" >> ROLES.md'
expect "a commit listed among rhythm-gated irreversibles fails" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# ...and the same enumeration with an INCIDENTAL negation elsewhere in the
# clause. Measured regression: the pre-fix rhythm-B bullet ended "upfront, no
# per-action touchpoint", and that "no" — negating the touchpoint, not the
# commit — made the clause-scoped guard swallow a real BLOCKER. The guard for
# this rule is therefore centred on the match, and this case pins that.
stage; seed_substrate_fixture
mutate roles/lead-agent.md \
  sh -c 'printf -- "- **B:** pre-authorizes all irreversible actions (%s / branch publication / landing) upfront, no per-action touchpoint\n" "commit" >> roles/lead-agent.md'
expect "an incidental negation elsewhere in the clause does not mask it" 1 \
  "SUBSTRATE-ORDER roles/lead-agent.md:2"

# ...the rhythm-conditional spelling of the same defect.
stage; seed_substrate_fixture
mutate roles/worker-agent.codex.md \
  sh -c 'printf -- "- Commit only when the dispatch and active authority rhythm authorize %s\n" "it" >> roles/worker-agent.codex.md'
expect "a commit gated on the authority rhythm fails" 1 \
  "SUBSTRATE-ORDER roles/worker-agent.codex.md:3"

# ...and the CORRECTED sentences must pass, or the fix cannot be written down.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "irreversible actions (branch publication / landing / release). The local %s is NOT one of them\n" "commit" >> ROLES.md'
expect "the corrected rhythm-gated set passes" 0

# (i3) THE TOOL-AFFORDANCE BULLET. (i2) anchors the record kind at the tool
# through a closed connective list, so an ENUMERATION that names the record
# ~200 characters downstream is structurally out of its reach — which is where
# this drift was found in three overlays at once.
stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — all phases. For explorer artefacts, prior master plans, prior %s, user-referenced files\n" "handoffs" >> roles/pm-agent.claude.md'
expect "a read affordance listing a record kind fails" 1 \
  "SUBSTRATE-RECORD-READ roles/pm-agent.claude.md:2"

# ...the same bullet naming the daemon read is the CORRECTED sentence. Appended
# to BOTH weights: `coordination.read_artefact` is a vocabulary token, so adding
# it to one weight alone fails the union-parity check instead of the rule under
# test, and the case would pass for the wrong reason.
stage; seed_substrate_fixture
( cd "$TMP/repo" && printf -- "- \`Read\` — permanent documents only; inbound handoffs are read with \`coordination.read_artefact {id}\`\n" | tee -a roles/worker-agent.md >> lite/worker-agent.md )
changed roles/worker-agent.md lite/worker-agent.md
expect "a read affordance deferring records to the daemon read passes" 0

# ...and the noun list stays NARROW: "adjacent-agent artefacts" legitimately
# covers documents, so a bare `artefact`/`record` noun must not fire. Flagging
# it would punish an accurate sentence, which is how a rule gets weakened.
stage; seed_substrate_fixture
mutate roles/qa-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — source, tests, fixtures, harness config, adjacent-agent %s\n" "artefacts" >> roles/qa-agent.claude.md'
expect "a read affordance naming adjacent-agent artefacts passes" 0

# ---- (j2)/(i3) hardening: five defects a cross-model gate found in the rules
# themselves. Each case below reproduces the exact string that defeated them.

# (j2) A generic negation cannot guard this rule at ANY width. The clause-scoped
# form let the pre-fix rhythm-B bullet through on its trailing "no per-action
# touchpoint"; narrowing to a window centred on the match only moved the hole,
# because REORDERING the sentence puts that same irrelevant "no" back inside it.
# The guard now names what must be denied — the commit — so both spellings fail.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "No per-action touchpoint: irreversible actions (%s / branch publication / landing) remain rhythm-gated\n" "commit" >> ROLES.md'
expect "an incidental negation BEFORE the enumeration does not mask it" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# ...and a denial that IS about the commit must still pass, in its own words,
# anywhere in the clause — or the fix cannot be written down.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "the gated set lists irreversible actions (%s / branch publication / landing) but the local commit is not one of them\n" "commit" >> ROLES.md'
expect "a denial about the commit passes anywhere in its clause" 0

# (j2) `before` had to come OUT of the wait branch: it rejected the CANONICAL
# sequence. A gate that forces the correct sentence to be written wrong is worse
# than no gate, so this case pins the canonical wording as passing.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "Before the branch-publication green-light, commit locally and deliver the close-%s\n" "out" >> ROLES.md'
expect "the canonical before-the-green-light sequence passes" 0

# ...while the commit actually being the OBJECT of the wait still fails. This is
# the wait branch's only direct coverage — it had none before.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "the worker awaits the lead green-light to %s the work\n" "commit" >> ROLES.md'
expect "a commit waiting on a green-light fails" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# ...and the rhythm-authorizes-the-commit branch, likewise previously untested.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "the active authority rhythm authorizes the close-out %s\n" "commit" >> ROLES.md'
expect "a commit authorized by the rhythm fails" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# (i3) LISTING IS NOT READING. The daemon exposes exactly one way to read a
# record; `coordination.list_artefacts` enumerates, it does not open. A
# listing-inclusive exemption waved a real filesystem read of a record through.
stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — prior %s; use \`coordination.list_artefacts\` to discover their ids\n" "handoffs" >> roles/pm-agent.claude.md'
expect "listing artefacts does not exempt a filesystem read of a record" 1 \
  "SUBSTRATE-RECORD-READ roles/pm-agent.claude.md:2"

# (i3) ...and the EXCLUSION an affordance bullet ought to carry must pass. A
# whole-line verdict rejected it, which would have forced the correcting
# sentence out of the corpus.
stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — permanent documents only; never use it for %s\n" "handoffs" >> roles/pm-agent.claude.md'
expect "a read affordance excluding records passes" 0

# (i3) ...and the DOCUMENT a review legitimately leaves behind. `design review`
# is ambiguous — the architect's long-form report really does live at
# docs/design-reviews/ — so it takes rule (g)'s document-surface exemption.
stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — prior design %s under docs/design-reviews/\n" "reviews" >> roles/pm-agent.claude.md'
expect "a read affordance naming the design-review document home passes" 0

# ...but the same noun with NO document home is talking about the record.
stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — the architect design %s from last cycle\n" "review" >> roles/pm-agent.claude.md'
expect "a read affordance naming a design review with no document home fails" 1 \
  "SUBSTRATE-RECORD-READ roles/pm-agent.claude.md:2"

# (i3) THE KIND LIST IS DERIVED, NOT RE-SPELLED. A second hand-maintained copy
# goes quietly out of date: this one first shipped without `acknowledgement` and
# `dispatch brief`, both of which rule (g)'s canonical list has always carried,
# so an affordance enumeration naming either escaped (i2) and (i3) alike.
stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — plans, notes, and prior %s from the lead\n" "acknowledgements" >> roles/pm-agent.claude.md'
expect "a read affordance naming acknowledgements fails" 1 \
  "SUBSTRATE-RECORD-READ roles/pm-agent.claude.md:2"

stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — explorer artefacts, master plans, and the dispatch %s\n" "brief" >> roles/pm-agent.claude.md'
expect "a read affordance naming the dispatch brief fails" 1 \
  "SUBSTRATE-RECORD-READ roles/pm-agent.claude.md:2"

# ---- MIXED BULLETS. Every exemption above is clause-scoped rather than
# line-scoped because a line-scoped one is BOUGHT by the correct half of a
# mixed bullet and SPENT on the wrong half. Both halves below name the right
# mechanism for one kind and the wrong one for another, and both passed whole.

stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — prior %s from disk; use \`coordination.read_artefact\` for close-outs\n" "handoffs" >> roles/pm-agent.claude.md'
expect "a daemon call in one clause does not exempt a record read in another" 1 \
  "SUBSTRATE-RECORD-READ roles/pm-agent.claude.md:2"

stage; seed_substrate_fixture
mutate roles/pm-agent.claude.md \
  sh -c 'printf -- "- \`Read\` — design %s records from the daemon; permanent reports under docs/design-reviews/\n" "review" >> roles/pm-agent.claude.md'
expect "a document home in one clause does not exempt a record read in another" 1 \
  "SUBSTRATE-RECORD-READ roles/pm-agent.claude.md:2"

# ...and the clause model itself. A period inside an identifier is not a
# sentence end, and treating it as one was a LATENT defect in every
# clause-scoped guard here: the clause around a mention of
# `coordination.read_artefact` used to stop at `coordination`, so no guard could
# see the tool name it exists to recognise. That is precisely why the exemption
# had to be line-scoped, which is what the two cases above exploit. This case
# fails if the identifier-dot handling is ever reverted.
stage; seed_substrate_fixture
( cd "$TMP/repo" && printf -- "- \`Read\` — permanent documents; inbound handoffs are read with \`coordination.read_artefact {id}\`\n" | tee -a roles/worker-agent.md >> lite/worker-agent.md )
changed roles/worker-agent.md lite/worker-agent.md
expect "a clause-scoped daemon exemption sees the dotted tool name" 0

# ---- (j2) the denial must be about the COMMIT, bound structurally rather than
# by distance: a run of prose cannot cross the `/` or `)` of an enumeration.

stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "Irreversible actions (%s / branch publication / landing) remain rhythm-gated, although landing is not separately green-lighted\n" "commit" >> ROLES.md'
expect "a denial about a DIFFERENT member does not suppress the finding" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "The rhythm does not authorize the local %s\n" "commit." >> ROLES.md'
expect "a denial that the rhythm authorizes the commit passes" 0

# ...and the form that defeated the prose-run binding: a denial whose
# grammatical OBJECT is a different member of the gated set. Position alone
# could never separate this from the case above; only a closed list of
# commit-bound denial forms can.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "The rhythm does not authorize landing but %s remain rhythm-gated.\n" "commits" >> ROLES.md'
expect "a denial about a different gated action does not suppress it" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# ...and the two shapes that named only HALF the predicate. A subject with no
# denied property ("the commit is not ready") and a property with no subject
# ("landing is not a rhythm-gated irreversible") each suppressed a real defect.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "Irreversible actions (%s / branch publication / landing) remain rhythm-gated, but the commit is not ready.\n" "commit" >> ROLES.md'
expect "an unrelated denial about the commit does not suppress it" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf "Irreversible actions (%s / branch publication / landing) remain rhythm-gated, although landing is not a rhythm-gated irreversible.\n" "commit" >> ROLES.md'
expect "a subjectless gatedness denial does not suppress it" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# ---- the DOCUMENT-HOME exemption is clause-scoped in (g) and (i1) too. Same
# mixed-clause vulnerability, two more rules.
stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf -- "- \`Write\` the %s record to disk; long-form reports live under docs/design-reviews/\n" "verdict" >> roles/architect-agent.md'
expect "a document home in another clause does not exempt a record write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/architect-agent.md:2"

stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf "Read the path to the %s from disk; permanent reports live under docs/design-reviews/\n" "verdict" >> roles/architect-agent.md'
expect "a document home in another clause does not exempt a record path" 1 \
  "SUBSTRATE-RECORD-READ roles/architect-agent.md:2"

# ---- (g)'s CANDIDATE is the write's grammatical object: bounded by its clause
# and anchored at the tool. Both bounds are pinned in both directions, because
# each alone was measured insufficient — the clause bound alone flagged the two
# coordinated-conjunct sentences below, and the anchor alone leaves the
# 80-character reach alive inside one long clause.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s to disk; handoffs are not files.\n" "close-out" >> roles/worker-agent.md'
expect "a file denial in another clause does not exempt a record write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s to disk; the WIP handoff uses a staging path instead.\n" "close-out" >> roles/worker-agent.md'
expect "a staging phrase does not exempt a write of a different kind" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...nor a write of the SAME kind a clause away, which is the harder half: the
# object test alone would pass this, and only the clause bound denies it.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s to disk; the WIP handoff uses a staging path instead.\n" "handoff" >> roles/worker-agent.md'
expect "a staging phrase one clause away does not exempt a record write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and the one artefact that DOES have a sanctioned file form still passes,
# so the object-bound exemption is proved to still exempt, not merely to deny.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s to the staging path before publishing it.\n" "WIP handoff" >> roles/worker-agent.md'
expect "the WIP-handoff staging draft is still exempt" 0

# ...and the same in the READ direction, where the staging exemption used to
# skip the WHOLE line for (i1), (i2) and (i3) at once — so one legitimate
# mention of the sanctioned draft disarmed every record-read rule on that line.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` the %s from disk; the WIP handoff uses a staging path instead.\n" "close-out" >> roles/worker-agent.md'
expect "a staging phrase one clause away does not exempt a record read" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` the %s at the staging path during the hold.\n" "WIP handoff" >> roles/worker-agent.md'
expect "reading the WIP staging draft is still exempt" 0

# A COORDINATED CONJUNCT is not the tool's object. Both of these are correct
# shipped sentences (`lite/pm-agent.claude.md:12`, `lite/architect-agent.claude.md:15`)
# that a clause-bounded free search flagged — a conjunction is not a clause
# boundary, so only anchoring the object at the tool tells them apart.
stage; seed_substrate_fixture
mutate roles/pm-agent.md \
  sh -c 'printf -- "Post-acceptance changes are \`Edit\`s in place plus a new %s record.\n" "handoff" >> roles/pm-agent.md'
expect "a conjunct under another verb is not the write tool's object" 0

stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf -- "On collision rename the ADR document and publish a new superseding %s record.\n" "verdict" >> roles/architect-agent.md'
expect "a conjunct under publish is not the rename object" 0

# ---- A COORDINATOR joins OBJECTS as readily as it introduces a predicate, so
# stopping at one outright made a plain two-object write silent. What decides is
# whether a VERB follows it. Both directions pinned, plus the `and/or` spelling
# that a `[\s,]`-terminated stop test could not see.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the report and the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a coordinated second object is still the write's object" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Edit\` the ADR and/or publish a %s record.\n" "handoff" >> roles/worker-agent.md'
expect "a coordinator followed by a verb still starts a new predicate" 0

# ...and the modifier CAP decided verdicts the grammar should have decided: the
# object sat well inside the character window and only the count excluded it.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the new full final approved local worker cycle %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a long modifier pile does not outrun the object match" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ---- A COMMA BEFORE A COORDINATING CONJUNCTION is a clause boundary. Without
# it every clause-scoped exemption in the file was spendable across ", but".
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s to disk, but handoffs are not files.\n" "close-out" >> roles/worker-agent.md'
expect "a file denial past a comma-conjunction does not exempt a write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ---- (i1)'s staging exemption is bound to the matched PATH, not the clause
# alone: the draft's exemption must not be spendable on another kind's path.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Open the %s path while the WIP handoff remains at the staging path.\n" "close-out" >> roles/worker-agent.md'
expect "a staging phrase does not exempt another kind's record path" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- the commit-denial list needs the GATING AUTHORITY as the denial's
# subject, and no free bridge to reach the denial from an unrelated noun.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf -- "The worker does not authorize the %s, but irreversible actions (%s / branch publication / landing) remain rhythm-gated.\n" "commit" "commit" >> ROLES.md'
expect "a denial by a non-gating subject does not suppress it" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf -- "Commits are local, landing is not one of them, but irreversible actions (%s / branch publication / landing) remain rhythm-gated.\n" "commit" >> ROLES.md'
expect "a denial about another member does not reach across a bridge" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# ---- the object run must reach through MARKDOWN EMPHASIS (bold is how these
# contracts mark the very nouns this rule looks for), and a hyphenated word that
# merely STARTS with an action verb is not a predicate.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` **the %s** to disk.\n" "close-out" >> roles/worker-agent.md'
expect "markdown emphasis does not hide the object" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the report and draft-stage %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a hyphenated verb-lookalike does not start a new predicate" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ---- a CONTRASTIVE coordinator still joins objects when no verb follows, and
# an OXFORD LIST is not a clause boundary — the two halves of the same line.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the report, but also the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a contrastive coordinator still joins two objects" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` — task briefs, handoffs, and %ss are never read from disk.\n" "close-out" >> roles/worker-agent.md'
expect "an oxford list keeps its own negation guard" 0

# ...and the candidate binds to the NEAREST matching noun. Greedy, it bound to a
# later occurrence and dragged the exemption scope across the contrast with it.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- You must \`Read\` the %s from disk, but the WIP handoff draft uses a staging path.\n" "handoff" >> roles/worker-agent.md'
expect "the object binds to the nearest noun, not a later one" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- a denial must deny WHAT WAS ASSERTED: denying enumeration membership does
# not deny rhythm authorization.
stage; seed_substrate_fixture
mutate ROLES.md \
  sh -c 'printf -- "The rhythm authorizes the %s even though the %s is not irreversible.\n" "commit" "commit" >> ROLES.md'
expect "a membership denial does not suppress an authorization gate" 1 \
  "SUBSTRATE-ORDER ROLES.md:2"

# ---- a SUBORDINATOR introduces a clause with or without a comma; English does
# not punctuate "because". Requiring the comma let a denial cross the boundary.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` the %s from disk because the daemon is not available.\n" "close-out" >> roles/worker-agent.md'
expect "a comma-free subordinator still bounds an exemption" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- EVERY governed object is judged on its own. An exempt first object must
# not carry a forbidden second one through with it.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the WIP handoff and the %s to the staging path.\n" "close-out" >> roles/worker-agent.md'
expect "an exempt object does not shield a coordinated one" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ---- MARKDOWN DELIMITERS. A linked or parenthesised object is still an object;
# a noun inside an UNCLOSED parenthesis is an apposition and is not.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the [%s](closeout.md) to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a markdown link does not hide the object" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the (draft) %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a closed parenthetical modifier stays inside the object" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- read the SKILL.md via \`functions.exec_command\` for the templates (worker %s / merge %s).\n" "close-out" "close-out" >> roles/worker-agent.md'
expect "a noun in an unclosed parenthetical is an apposition, not an object" 0

# ---- THE EM DASH HAS TWO ROLES. A PAIR brackets an apposition whose host
# clause runs through it; a LONE one separates. Treating every dash as a
# boundary lost the negation out of a correct sentence.
stage; seed_substrate_fixture
mutate roles/pm-agent.md \
  sh -c 'printf "The PM never — even under option D — %s its branch.\n" "publishes" >> roles/pm-agent.md'
expect "a negation outside a paired-dash apposition still guards" 0

stage; seed_substrate_fixture
mutate roles/pm-agent.md \
  sh -c 'printf "The PM %s its branch — that is the rule\n" "publishes" >> roles/pm-agent.md'
expect "a lone em dash still separates clauses" 1 \
  "SUBSTRATE-EGRESS roles/pm-agent.md:2"

# ---- THE WRITE-AFFORDANCE BULLET. The em dash after a leading write-tool
# label is a LABEL separator, not a clause boundary — read as a boundary it
# ended the candidate window one character past the tool, so the single most
# likely spelling of this drift was the one the rule could not see.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` — %s to disk.\n" "close-outs" >> roles/worker-agent.md'
expect "a write-affordance label dash does not end the candidate" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and in THAT shape the window is the clause, not 80 characters of it: an
# affordance bullet is an enumeration, and its last object sits past any fixed
# reach. This object starts at character 88.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` — plans under \`docs/plans/\`, PRDs under \`docs/prd/\`, retros under \`docs/retros/\`, and %s to disk.\n" "close-outs" >> roles/worker-agent.md'
expect "a write-affordance object list is scanned to the clause bound" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and both EXEMPTIONS must still reach across that dash, which is why it is
# neutralised rather than special-cased at the window: widening only the window
# would have left the exemption scope cut off at the dash and flagged these two.
stage; seed_substrate_fixture
mutate roles/architect-agent.md \
  sh -c 'printf -- "- \`Write\` — the long-form review report under docs/design-reviews/ and its %s\n" "verdict" >> roles/architect-agent.md'
expect "a document home survives the write-affordance label dash" 0

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` — the %s at the staging path under .wip-handoff-staging/\n" "WIP handoff" >> roles/worker-agent.md'
expect "the staging exemption survives the write-affordance label dash" 0

# ---- A DAEMON-READ EXEMPTION BELONGS TO THE OBJECT IT MODIFIES. Clause scope
# let one object's call cover another standing beside it, so a mixed list
# passed whole.
# Both cases append to BOTH weights, per the note at "reading the record through
# the daemon passes": `coordination.read_artefact` is a vocabulary token, so
# adding it to one weight alone fails the union-parity check instead of the rule
# under test — which is exactly how the PASS case below first failed.
stage; seed_substrate_fixture
( cd "$TMP/repo" && printf -- "- \`Read\` the handoff with coordination.read_artefact and the close-out from disk.\n" | tee -a roles/worker-agent.md >> lite/worker-agent.md )
changed roles/worker-agent.md lite/worker-agent.md
expect "a daemon read between two objects does not exempt the later one" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ...and the shared post-modifier still covers the whole list, which is the
# other direction and the reason the scope is positional rather than per-conjunct.
stage; seed_substrate_fixture
( cd "$TMP/repo" && printf -- "- \`Read\` the handoff and the close-out with \`coordination.read_artefact {id}\`\n" | tee -a roles/worker-agent.md >> lite/worker-agent.md )
changed roles/worker-agent.md lite/worker-agent.md
expect "a daemon read after the last object exempts the whole list" 0

# ---- THE CANONICAL KIND LIST. (i1) and (i2) each re-spelt it by hand and each
# shipped without these two kinds, which rule (g) has always carried.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` the %s file from disk.\n" "acknowledgement" >> roles/worker-agent.md'
expect "an acknowledgement named in file grammar is a record read" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- route it to the %s path under docs/x/\n" "dispatch brief" >> roles/worker-agent.md'
expect "a dispatch brief named in path grammar is a record read" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ...and the hyphenated AUTHORITY route that adding that kind bare flagged, in
# two correct shipped sentences. A hyphen before the kind means the kind is the
# tail of a compound naming something else.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "Lead may override with explicit acknowledgment under the standard override-with-%s path.\n" "acknowledgment" >> roles/worker-agent.md'
expect "a hyphenated authority route is not a record path" 0

# ---- EVERY CANONICAL KIND MUST REACH (i1)'s PATH GRAMMAR. The multiword kinds
# were simply MISSING from the hand-respelt noun list, so the whole kind was
# silent in path grammar while rule (g) policed it — the drift that made the
# list derived. These two DISCRIMINATE: no shorter head can match them, because
# the head is followed by the qualifier rather than by `file`/`path`. (A
# `merge close-out file` case was written and then dropped for the opposite
# reason — `close-out file` matches it whatever the multiword kind does, so it
# would have passed for a partly wrong reason, which is not a test.)
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- route it to the %s path under docs/x/\n" "task brief" >> roles/worker-agent.md'
expect "a multiword kind reaches its path grammar" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- open the %s file from disk\n" "clarification artefact" >> roles/worker-agent.md'
expect "a two-word kind reaches its file grammar" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ...and the acknowledgement hyphen guard belongs on the CANONICAL list, so the
# rules that DERIVE from it inherit it. Guarded only downstream, the
# authority-route false positive came straight back through (i2), (i3) and (g)
# — one control per rule side, because that is how many sides inherited it.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` — ROLES.md before using the standard override-with-%s path.\n" "acknowledgment" >> roles/worker-agent.md'
expect "an affordance bullet naming an authority route is not a record read" 0

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` the note under the standard override-with-%s path.\n" "acknowledgment" >> roles/worker-agent.md'
expect "an anchored read of an authority route is not a record read" 0

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the note under the standard override-with-%s path.\n" "acknowledgment" >> roles/worker-agent.md'
expect "a write beside an authority route is not a record write" 0

# ...and the guard must NARROW the kind, never remove it: the same kind
# unhyphenated is still a record on both sides. Without these two controls, a
# "fix" that deleted `acknowledgement` from the canonical list would pass every
# case above — a silent MISS bought with a false positive.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` the %s from disk before you clear the gate\n" "acknowledgement" >> roles/worker-agent.md'
expect "an unhyphenated acknowledgement is still a record read" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s at docs/x/y.md and stage it\n" "acknowledgement" >> roles/worker-agent.md'
expect "an unhyphenated acknowledgement is still a record write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and the guard NAMES its compounds, so a hyphenated spelling of the RECORD
# is still caught. A blanket "any hyphen" guard swallowed this one SILENTLY.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- open the worker-%s file from disk\n" "acknowledgment" >> roles/worker-agent.md'
expect "a hyphenated spelling of the record itself is not exempt" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` — the post-%s state of the dispatch\n" "acknowledgment" >> roles/worker-agent.md'
expect "post-acknowledgment names a state, not a record" 0

# ---- THE DAEMON'S MACHINE KIND NAMES. The surfaces write `{kind:"..."}` more
# often than they write the prose name, and the underscore spellings were on no
# list. Both cases DISCRIMINATE: `_` is a word character, so no `\b` opens in
# front of `closeout` in `merge_closeout` and no shorter kind can reach it.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- open the %s file from disk\n" "merge_closeout" >> roles/worker-agent.md'
expect "a machine kind name in file grammar is a record read" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` the %s from disk before you clear the gate\n" "code_review" >> roles/worker-agent.md'
expect "a machine kind name is a record on the read side" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ...and ONLY the machine spelling: bare "code review" is ordinary English and
# this rule must not own it, which is why the underscore form alone was added.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Read\` — the %s conventions this repository follows\n" "code review" >> roles/worker-agent.md'
expect "prose 'code review' is not the record kind" 0

# ---- A GENERIC TYPE NOUN BETWEEN THE KIND AND ITS FILE GRAMMAR. "the close-out
# record file" names the record in file grammar as plainly as "the close-out
# file", and was silent. One noun wide, so the kind cannot reach a `file` in a
# later phrase — the proximity rule this production exists to not be.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- open the %s record file from disk\n" "close-out" >> roles/worker-agent.md'
expect "a type noun between the kind and 'file' does not hide it" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- publish the %s, then commit the plan document and open its file\n" "close-out" >> roles/worker-agent.md'
expect "a file two phrases later is not the kind's file grammar" 0

# ...and the OTHER type noun, so the pair is not tested by one of them.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- route it to the handoff %s path under docs/x/\n" "artefact" >> roles/worker-agent.md'
expect "'artefact' between the kind and 'path' does not hide it either" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- THE STAGING EXEMPTION TRACKS THE KIND LIST. Widening the kinds to
# `wip_handoff` without widening `STAGED_OBJECT_RE` turned the ONE sanctioned
# file form into a false positive, because the object stopped matching the one
# artefact allowed to have a file.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s at the staging path under .wip-handoff-staging/\n" "wip_handoff" >> roles/worker-agent.md'
expect "the staging exemption reaches the machine kind spelling" 0

# ...and is still OBJECT-bound, so it does not spend itself on a neighbour.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s at the staging path and the close-out to disk.\n" "wip_handoff" >> roles/worker-agent.md'
expect "the machine-spelt staging draft does not exempt a close-out beside it" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ---- A MACHINE KIND ON THE WRITE SIDE, and one on the READ side that CANNOT be
# an (i3) affordance bullet, because it does not lead with the tool. Without
# that second case an (i2) break hides behind (i3), which fires on the same line.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s at docs/x/y.md and stage it\n" "merge_closeout" >> roles/worker-agent.md'
expect "a machine kind name is a record on the write side" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- clear the gate only after you \`Read\` the %s from disk\n" "code_review" >> roles/worker-agent.md'
expect "a machine kind read that is not an affordance bullet is (i2) alone" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- THE TWO DOCUMENT-AMBIGUOUS KINDS reach the file grammar in their MACHINE
# spelling, and carry the document-home exemption with them.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- open the %s record file from disk\n" "test_strategy" >> roles/worker-agent.md'
expect "a document-ambiguous kind in its machine spelling is a record read" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- open the %s file under docs/design-reviews/\n" "design_review" >> roles/worker-agent.md'
expect "a document home still exempts the machine spelling" 0

# ---- A NEW ACTION PREDICATE AFTER A COMMA ends the write's object run, exactly
# as one after a coordinator already did. The negative is the shape measured in
# the corpus (`roles/architect-agent.codex.md:46`): a write tool, a comma, then
# `publish` taking the record as ITS object.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`functions.apply_patch\` its internal references, publish a NEW \`%s\` record citing the prior id\n" "design_review" >> roles/worker-agent.md'
expect "a comma before a new action predicate ends the object run" 0

# ...and the guard must not have become "any comma": commas between the members
# of an OBJECT LIST are not predicate boundaries, and the list must still fire.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the close-out, the handoff, and the %s to docs/x/y.md.\n" "addendum" >> roles/worker-agent.md'
expect "a comma between two objects is not a predicate boundary" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...nor a comma before an ordinary MODIFIER rather than a verb.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the reviewed, signed %s to docs/x/y.md.\n" "close-out" >> roles/worker-agent.md'
expect "a comma inside the object phrase is not a predicate boundary" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ---- THE TWO SPELLINGS OF THE SAME BOUNDARY MUST AGREE, and an ATTRIBUTIVE
# participle is not a predicate in either of them. Both FIRE. The pair is the
# point: one shared verb list means one fix, and a later editor narrowing one
# spelling and not the other is what would silently diverge.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the plan and updated %s to docs/x/y.md.\n" "close-out" >> roles/worker-agent.md'
expect "an attributive participle after a coordinator is not a predicate" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the plan, updated %s to docs/x/y.md.\n" "close-out" >> roles/worker-agent.md'
expect "an attributive participle after a comma is not one either" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and the plain WRITE AFFORDANCE that the stem-matching verb list silently
# emptied of its object.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` — PRDs, updated %s, and ADRs.\n" "close-outs" >> roles/worker-agent.md'
expect "a write affordance keeps its object past a participle" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...while a BASE-FORM verb after the comma still opens a new predicate, which
# is the whole reason the boundary exists.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the ADR, publish the %s record citing the prior id\n" "design_review" >> roles/worker-agent.md'
expect "a base-form verb after a comma still opens a new predicate" 0

# ---- `commit the` IS A WRITE. Cutting the first instruction's reach at the
# comma left the second one named by nothing.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the ADR, commit the %s to disk\n" "close-out" >> roles/worker-agent.md'
expect "a second predicate that commits a record is itself a write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and committing a DURABLE DOCUMENT raises no candidate, which is what makes
# admitting the verb safe.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- commit the ADR under docs/adr/ and publish the %s\n" "record" >> roles/worker-agent.md'
expect "committing a durable document is not a record write" 0

# ...and `commits` is the plural NOUN in this corpus, never the verb — the exact
# shipped line that made the plural spelling unsafe.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- **Option B:** \`<SHA-list of all commits the %s describes>\`\n" "close-out" >> roles/worker-agent.md'
expect "a commit LIST a close-out describes is not a write" 0

# ---- A SEARCH TOOL NAMES TWO THINGS, and only one of them is opened. Neither
# bullet leads with the tool, so (i3) cannot reach either.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Before resuming, use \`Grep\` across the prior %s records from disk\n" "handoff" >> roles/worker-agent.md'
expect "searching the records themselves is a filesystem read of a record" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Before resuming, \`Grep\` the source tree for the word %s\n" "handoff" >> roles/worker-agent.md'
expect "a kind behind a search-term preposition is the term, not the object" 0

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Before resuming, \`Glob\` the docs tree for anything mentioning a %s\n" "handoff" >> roles/worker-agent.md'
expect "the same holds for the other search tool" 0

# ---- (i2) HAS NO DOCUMENT-HOME EXEMPTION, so it owns the MACHINE spelling of a
# document-ambiguous kind and not the prose one. Neither bullet leads with the
# tool, so (i3)'s exemption cannot cover for this.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Once provenance is verified, \`Read\` the %s under docs/design-reviews/2026-08-28-x.md\n" "design review" >> roles/worker-agent.md'
expect "the prose spelling at its document home is a file read, correctly" 0

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Once provenance is verified, \`Read\` the %s from disk\n" "design_review" >> roles/worker-agent.md'
expect "the machine spelling is still the record, on the same rule" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- THE DOCUMENT-AMBIGUOUS MACHINE KIND ON THE WRITE SIDE. (i1)-(i3) are read
# and path rules and cannot stand in for write detection, which is why holding
# this kind off rule (g) was a silent miss in the dangerous direction.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s record to docs/tmp/review.md and commit it.\n" "design_review" >> roles/worker-agent.md'
expect "a document-ambiguous machine kind is a record on the write side" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and only the MACHINE spelling is owned: the act and the long-form report
# are ordinary English the QA and architect surfaces legitimately write.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s notes under docs/plans/ and commit them.\n" "design review" >> roles/worker-agent.md'
expect "the prose spelling of the same kind is not owned by the write rule" 0

# ---- THE `<kind> record` FORM for the three kinds whose BARE head noun is a
# verb or an ordinary noun. Each is tested on the WRITE side, which is the side
# that had no list entry at all.
for kind in "dispatch" "task" "clarification"; do
  stage; seed_substrate_fixture
  mutate roles/worker-agent.md \
    sh -c 'printf -- "- \`Write\` the %s record to docs/x/y.md and stage it\n" "'"$kind"'" >> roles/worker-agent.md'
  expect "a '$kind' record is a record on the write side" 1 \
    "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"
done

# ...and the bare VERB is still not a kind, which is why the qualified form is
# what was added rather than the head noun.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the note, then %s the worker to its lane\n" "dispatch" >> roles/worker-agent.md'
expect "the bare verb is still not a kind" 0

# ---- A FILESYSTEM READ TOOL (i3) RECOGNISES MUST REACH (i2) TOO. The bullet
# does not lead with the tool, so (i3) cannot cover for a broken (i2).
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Verify provenance, then \`%s\` the close-out from disk.\n" "MultiRead" >> roles/worker-agent.md'
expect "a read tool (i3) knows is a read tool for (i2) as well" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ...and the daemon-read exemption still reaches that same tool, so recognising
# `MultiRead` widened DETECTION without narrowing the exemption that makes the
# correct sentence legal. BOTH weights, per the note above: `coordination.read_artefact`
# is a vocabulary token, and seeding one weight alone fails the union-parity
# check instead of the rule under test — which is exactly how this case first
# failed, the same way the two cases above first did.
stage; seed_substrate_fixture
( cd "$TMP/repo" && printf -- "- Verify provenance, then \`MultiRead\` the close-out with \`coordination.read_artefact {id}\`.\n" | tee -a roles/worker-agent.md >> lite/worker-agent.md )
changed roles/worker-agent.md lite/worker-agent.md
expect "naming the daemon read still exempts the newly-recognised tool" 0

# ---- THE ENGLISH LIFECYCLE VERBS ARE CASE-INSENSITIVE. This rule scans the raw
# line, so the ordinary imperative register of a bullet was silent.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Commit the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a capitalised lifecycle verb is still a write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Update the %s and stage it.\n" "close-out" >> roles/worker-agent.md'
expect "and so is the capitalised update, which has no daemon operation at all" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and the THIRD-PERSON form, subject-anchored so the plural noun stays out.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- The lead commits the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a subject-anchored third-person commit is a write" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and an ACTOR IN FRONT OF `commits` IS NOT ENOUGH. This is the shipped
# SHA-list construction with the quantifier `all` swapped for the qualifier
# `the worker`: `commits` is still the plural noun, and the sentence is correct
# prose. It is the false positive the subject-position requirement exists to
# kill, and it is the zero-finding half of the pair — the four cases below are
# the detection that requirement must NOT cost.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Review the worker commits the %s describes before approval.\n" "close-out" >> roles/worker-agent.md'
expect "an actor qualifying the plural noun is not a subject" 0

# ...so each of the four remaining subject positions is pinned on its own. A
# narrowing that quietly kept only the bullet would leave every one of these
# passing on the wrong side, and each fails alone if its opener is dropped.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Stage the work, the lead commits the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a subject after a comma is still a subject" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Stage the work. The lead commits the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "and after a full stop" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Once the lead commits the %s, publish the branch.\n" "close-out" >> roles/worker-agent.md'
expect "and after a subordinator" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Publish the branch and the worker commits the %s.\n" "close-out" >> roles/worker-agent.md'
expect "and after a coordinator" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...including the one the comment above leans on to bound its own residual. An
# actor after a bare transitive verb is no longer reached, and the reason that
# is a narrow price rather than a hole is that `that` opens a subject clause —
# which is a claim, so it is a case.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Check that the lead commits the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a requirement clause opened by 'that' still names its subject" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and the EM DASH, which `CLAUSE_SPLIT_RE` calls a clause separator and the
# first cut of this opener list did not — a silent miss the narrowing introduced
# and the round-7 gate caught. A LONE dash opens a subject.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- The sequence is explicit — the lead commits the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a lone em dash separates clauses, so a subject may open after one" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ...and a PAIR does not, because it brackets an apposition whose host clause
# runs straight through it. This is the round-6a false positive in a different
# costume: admit the dash without the pairing test and the actor-qualified
# plural noun comes back through it.
#
# THE SENTENCE IS CHOSEN, and the first one written here was VACUOUS.
# "- The record — the worker commits the close-out describes — is not a file."
# returns zero WITH the pairing test and WITHOUT it: `is not a file` is a file
# denial, so the exemption holds the finding down however the opener behaves,
# and the case would have proved nothing while looking exactly like proof.
# Mutation M20 is what exposed it — M20 moved a different probe and left this
# sentence untouched. The sentence below carries no denial and names no document
# home, so its zero can come only from the pairing test, and M20 makes this case
# fail.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Coordination records — the worker commits the %s lists — stay in the daemon store.\n" "close-out" >> roles/worker-agent.md'
expect "a paired em dash brackets an apposition, and opens nothing" 0

# ...and the pairing question is asked of `low`, where the write-affordance LABEL
# dash has already been neutralised — not of the raw line, where it is still a
# dash and pairs with the next genuine separator. Asking the raw line reinstates
# exactly what that neutralisation exists to prevent, and the cost is a silent
# miss: the label dash and the real separator pair off, the separator is read as
# the closing half of an apposition, and a live third-person instruction sitting
# after it is discarded. Found by the round-8 gate.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` — durable documents only — the lead commits the %s to disk.\n" "close-out" >> roles/worker-agent.md'
expect "a neutralised label dash does not cancel a later separator" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

# ---- A SEARCH NAMES ITS TERM AND ITS CORPUS IN EITHER ORDER. Suppressing on the
# mere presence of a term preposition made the term-first spelling a silent miss.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- Before resuming, \`Grep\` for stale entries in the prior %s records from disk.\n" "handoff" >> roles/worker-agent.md'
expect "a term phrase first does not make the corpus a search term" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- THE QUALIFIED PROSE FORM of a kind whose bare prose is a document. On the
# canonical list, so every derived rule inherits it — deleting it from any ONE
# rule cannot leave these passing.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- \`Write\` the %s record to disk\n" "code review" >> roles/worker-agent.md'
expect "a qualified prose record is a record on the write side" 1 \
  "SUBSTRATE-RECORD-WRITE roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- clear the gate only after you \`Read\` the %s record from disk\n" "test strategy" >> roles/worker-agent.md'
expect "and on the read side, where it is not an affordance bullet" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# ---- (i1) STRIPS THE CANONICAL PLURAL, so the path production must put it back
# — on the kind and on the optional type noun alike.
stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- the %s file is the source of truth\n" "handoffs" >> roles/worker-agent.md'
expect "a plural kind still reaches its file grammar" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

stage; seed_substrate_fixture
mutate roles/worker-agent.md \
  sh -c 'printf -- "- the prior handoff %s file is the source of truth\n" "records" >> roles/worker-agent.md'
expect "and so does a plural type noun between the kind and 'file'" 1 \
  "SUBSTRATE-RECORD-READ roles/worker-agent.md:5"

# The count is ASSERTED, not merely printed: a case added without bumping this
# literal (or a case silently lost) fails the selftest.
EXPECTED_CASES=233
if [[ "$CASES" -ne "$EXPECTED_CASES" ]]; then
  echo "SELFTEST FAIL: ran $CASES case(s), expected $EXPECTED_CASES — update the literal deliberately" >&2
  exit 1
fi
echo "selftest OK ($CASES cases)"
