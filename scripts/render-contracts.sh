#!/usr/bin/env bash
set -euo pipefail

# render-contracts.sh — regenerate the GENERATED blocks that live inside the
# surface files named by each role policy's `generated_surfaces` array.
#
# Three modes:
#   (default)   render/splice in place
#   --check     verify freshness only; mutate nothing; non-zero on stale/missing
#   --selftest  prove the refusal paths actually refuse, on a scratch copy
#
# Block types (detected by BEGIN marker lines inside the target file):
#   contract <role>        — markdown contract tables
#   allowed-skills <role>  — one bullet per skills.allowed[] entry
#   doctrine <role>        — the verbatim body of the policy's doctrine_source
#
# Both policy sets drive rendering: the full set (role-policies/) and the
# container-lean set (lite/role-policies/). Every generated_surfaces entry is
# REPO-ROOT-RELATIVE in both sets, so a lite policy names `lite/<role>-agent.md`.
# That is what lets ONE doctrine file render into both weights.
#
# The renderer NEVER creates files and NEVER touches a file that is not listed
# in some policy's generated_surfaces. A policy with generated_surfaces:[] renders
# nothing — and is REFUSED, because every policy must declare a doctrine_source
# and that doctrine must have exactly one host (see the block-host counts in
# render_pass); a policy that lists no surface has nowhere to render it.

MODE="render"
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check)    MODE="check"; shift ;;
    --selftest) MODE="selftest"; shift ;;
    --root)     ROOT="$2"; shift 2 ;;
    *) echo "usage: render-contracts.sh [--check | --selftest] [--root <dir>]" >&2; exit 2 ;;
  esac
done
[ -n "$ROOT" ] || ROOT="$(git rev-parse --show-toplevel)"

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$ROOT"

fail=0

# A temp-file failure is a SETUP error (exit 2), NEVER a content verdict. Exit 1
# means "the corpus is stale or malformed"; an unwritable TMPDIR must not be able
# to dress itself up as one. (Measured: an unguarded `mktemp` in a sandbox that
# denies TMPDIR writes produced `MARKER MALFORMED` on every valid marker in the
# tree.) Must be called from the MAIN shell — `$(…)` would exit only a subshell.
die_tempfile() {
  echo "TEMPFILE FAILED: cannot create a temporary file for $1 (is TMPDIR writable?)" >&2
  exit 2
}

# Whatever ends this process — a refusal, `set -e` on an unforeseen failure, a
# signal — no stage file is left behind. `discard_staged` is a no-op once
# `install_staged` has consumed the registry.
trap 'discard_staged 2>/dev/null || true' EXIT

# ---------------------------------------------------------------------------
# Cell helpers — keep markdown table cells well-formed and deterministic.
# ---------------------------------------------------------------------------

# Escape pipes so a value can never break the markdown table grid.
esc_cell() {
  # shellcheck disable=SC2001
  printf '%s' "$1" | sed 's/|/\\|/g'
}

# Join the lines of stdin with ", "; emit "—" when there is nothing.
join_or_dash() {
  local out
  out=$(paste -sd, - | sed 's/,/, /g')
  if [ -z "$out" ]; then printf '%s' "—"; else printf '%s' "$out"; fi
}

# ---------------------------------------------------------------------------
# Block renderers. Each writes a deterministic block BODY to stdout — the text
# that belongs strictly between the BEGIN and END marker lines (markers excluded).
# A leading and trailing blank line frame the body for readable diffs.
# ---------------------------------------------------------------------------

render_contract() {
  local policy="$1"

  printf '\n'

  # 1. Authority --------------------------------------------------------------
  printf '#### Authority\n\n'
  printf '| Field | Value |\n'
  printf '| --- | --- |\n'
  local may_decide must_route forbidden
  may_decide=$(jq -r '.authority.may_decide[]?' "$policy" | join_or_dash)
  printf '| may-decide | %s |\n' "$(esc_cell "$may_decide")"
  must_route=$(jq -r '.authority.must_route // {} | to_entries[] | "\(.key) → \(.value)"' "$policy" | join_or_dash)
  printf '| must-route | %s |\n' "$(esc_cell "$must_route")"
  forbidden=$(jq -r '.authority.forbidden[]?' "$policy" | join_or_dash)
  printf '| forbidden | %s |\n' "$(esc_cell "$forbidden")"
  printf '\n'

  # 2. Channels ---------------------------------------------------------------
  printf '#### Channels\n\n'
  printf '| Field | Value |\n'
  printf '| --- | --- |\n'
  local direct bounded chforbidden
  direct=$(jq -r '.channels.direct[]? | "\(.role): \(.purpose)"' "$policy" | join_or_dash)
  printf '| direct | %s |\n' "$(esc_cell "$direct")"
  bounded=$(jq -r '.channels.bounded_clarification[]? | "\(.role): \(.purpose)"' "$policy" | join_or_dash)
  printf '| bounded_clarification | %s |\n' "$(esc_cell "$bounded")"
  chforbidden=$(jq -r '.channels.forbidden[]?' "$policy" | join_or_dash)
  printf '| forbidden | %s |\n' "$(esc_cell "$chforbidden")"
  printf '\n'

  # 3. Artefacts --------------------------------------------------------------
  printf '#### Artefacts\n\n'
  printf '| Field | Value |\n'
  printf '| --- | --- |\n'
  local reads writes owns
  reads=$(jq -r '.artefacts.reads[]?' "$policy" | join_or_dash)
  printf '| reads | %s |\n' "$(esc_cell "$reads")"
  writes=$(jq -r '.artefacts.writes[]?' "$policy" | join_or_dash)
  printf '| writes | %s |\n' "$(esc_cell "$writes")"
  owns=$(jq -r '.artefacts.owns[]?' "$policy" | join_or_dash)
  printf '| owns | %s |\n' "$(esc_cell "$owns")"
  printf '\n'

  # 4. Git --------------------------------------------------------------------
  printf '#### Git\n\n'
  printf '| Field | Value |\n'
  printf '| --- | --- |\n'
  local edit_scope commit_scope stage_only gitforbidden
  edit_scope=$(jq -r '.git.edit_scope[]?' "$policy" | join_or_dash)
  printf '| edit_scope | %s |\n' "$(esc_cell "$edit_scope")"
  commit_scope=$(jq -r '.git.commit_scope[]?' "$policy" | join_or_dash)
  printf '| commit_scope | %s |\n' "$(esc_cell "$commit_scope")"
  stage_only=$(jq -r '.git.stage_explicit_paths_only' "$policy")
  printf '| stage_explicit_paths_only | %s |\n' "$(esc_cell "$stage_only")"
  gitforbidden=$(jq -r '.git.forbidden[]?' "$policy" | join_or_dash)
  printf '| forbidden | %s |\n' "$(esc_cell "$gitforbidden")"
  printf '\n'

  printf '| push rhythm | rule |\n'
  printf '| --- | --- |\n'
  local r v
  for r in A B C D; do
    v=$(jq -r --arg r "$r" '.git.push_rules[$r] // empty' "$policy")
    [ -z "$v" ] && v="—"
    printf '| %s | %s |\n' "$r" "$(esc_cell "$v")"
  done
  printf '\n'

  # 5. MCP access -------------------------------------------------------------
  # The per-role MCP ceiling (by registry key; never inline server defs). Default-tight:
  # bus-only today; privileged lanes default-deny third-party. Absent block renders "—".
  printf '#### MCP access\n\n'
  printf '| Field | Value |\n'
  printf '| --- | --- |\n'
  local mcp_allowed mcp_exhaustive
  mcp_allowed=$(jq -r '.mcp_access.allowed[]? | "\(.key) (\(.authorization))"' "$policy" | join_or_dash)
  printf '| allowed | %s |\n' "$(esc_cell "$mcp_allowed")"
  mcp_exhaustive=$(jq -r 'if (.mcp_access | type) == "object" then (.mcp_access.list_is_exhaustive | tostring) else "—" end' "$policy")
  printf '| list_is_exhaustive | %s |\n' "$(esc_cell "$mcp_exhaustive")"
  printf '\n'

  # 6. Stops & overrides ------------------------------------------------------
  printf '#### Stops & overrides\n\n'
  printf '| condition | action | override_authority | rhythm_d_route |\n'
  printf '| --- | --- | --- | --- |\n'
  jq -r '.stops_and_overrides[]? |
           [ .condition, .action, .override_authority, (.rhythm_d_route // "—") ]
           | @tsv' "$policy" | while IFS=$'\t' read -r cond act auth route; do
    printf '| %s | %s | %s | %s |\n' \
      "$(esc_cell "$cond")" "$(esc_cell "$act")" "$(esc_cell "$auth")" "$(esc_cell "$route")"
  done
  printf '\n'
}

# Codex farmed-path prefix the read-by-path framing cites — the project-local plugin staging tree
# the deployment's setup tooling generates. Overridable for a non-default workspace layout.
MYTHICAL_CODEX_PATH="${MYTHICAL_CODEX_PATH:-.claude/mythical/skills}"
# Second namespace (agent:) Codex read-by-path prefix — the project-local agent plugin tree.
# Authored-only; same override convention as MYTHICAL_CODEX_PATH.
AGENT_CODEX_PATH="${AGENT_CODEX_PATH:-.claude/agent/skills}"

render_allowed_skills() {
  local policy="$1" target="${2:-}"
  # Per-harness framing for namespaced (mythical:) ids (§C.3). Derive the harness from the
  # surface filename: a .codex overlay frames read-by-path (NEVER native); a .claude overlay frames
  # native; any other surface (base/neutral) names the token only. BARE ids render identically on
  # every surface — no regression for existing playbook skills.
  local harness=neutral
  case "$target" in
    *.codex.md)  harness=codex ;;
    *.claude.md) harness=claude ;;
  esac
  printf '\n'
  jq -r --arg harness "$harness" --arg mp "$MYTHICAL_CODEX_PATH" --arg ap "$AGENT_CODEX_PATH" '
    def cpath($id): if   ($id|startswith("mythical:")) then $mp
                    elif ($id|startswith("agent:"))          then $ap
                    else null end;
    .skills.allowed[]? as $s
    | (if (($s.triggers) // []) | length > 0 then ($s.triggers | join(", ")) else "none" end) as $tr
    | (cpath($s.id)) as $cp
    | if $cp != null then
        ($s.id | sub("^[a-z0-9]+:";"")) as $name
        | if   $harness == "claude" then "- \($s.id) (native skill; \($s.authorization); triggers: \($tr))"
          elif $harness == "codex"  then "- \($s.id) (read-by-path: cat \($cp)/\($name)/SKILL.md; \($s.authorization); triggers: \($tr))"
          else "- \($s.id) (\($s.authorization); triggers: \($tr))" end
      else
        "- \($s.id) (\($s.authorization); triggers: \($tr))"
      end' "$policy"
  printf '\n'
}

# Shared doctrine. ONE source file per role (`doctrine/<role>.md`, named by the
# policy's `doctrine_source`), rendered verbatim into every surface of EITHER
# weight that carries the marker — that is the whole point: the governance
# doctrine a role teaches is authored once and cannot drift between the full
# and the container-lean set. The caller has already proven the source exists.
render_doctrine() {
  local policy="$1" src
  src=$(jq -r '.doctrine_source // empty' "$policy")
  printf '\n'
  cat "$src"
  printf '\n'
}

# A doctrine source must be usable BEFORE anything is spliced. An unreadable or
# blank source would otherwise render as framing whitespace — the doctrine
# silently erased, and `--check` then calling the emptied block "fresh".
# Returns 0 when the policy's source is fit to render; else prints why.
doctrine_source_ok() {
  # doctrine_source_ok <policy> <target>
  local policy="$1" target="$2" src
  src=$(jq -r '.doctrine_source // empty' "$policy")
  if [ -z "$src" ]; then
    echo "DOCTRINE SOURCE UNDECLARED $target: $policy carries a doctrine block but no doctrine_source"
    return 1
  fi
  if [ ! -f "$src" ]; then
    echo "DOCTRINE SOURCE MISSING $target: $src (declared by $policy)"
    return 1
  fi
  if ! /usr/bin/grep -qa '[^[:space:]]' "$src"; then
    echo "DOCTRINE SOURCE EMPTY $target: $src (declared by $policy) has no non-whitespace content"
    return 1
  fi
  # The body is DATA, spliced in verbatim. A doctrine file carrying its own
  # GENERATED marker line renders at exit 0 and leaves the surface with a
  # duplicated or broken pair — refused only by the NEXT run, after the corrupt
  # file is already installed and committed.
  if /usr/bin/grep -qaE -- '(BEGIN|END) GENERATED:' "$src"; then
    echo "DOCTRINE SOURCE MARKER $target: $src (declared by $policy) contains a GENERATED marker line; rendering it would splice a second marker into the surface"
    return 1
  fi
  return 0
}

# Cross-role authority matrix. Unlike the per-policy renderers above, this reads
# ALL role-policies/*.policy.json and emits ONE deterministic table. Roles are
# emitted in a FIXED order matching ROLES.md's role-section order; a role whose
# policy file is absent is silently skipped (no row).
render_matrix() {
  local order="cto spm pm lead worker architect qa reviewer designer explorer devil ops"
  printf '\n'
  printf '| Role | Class | May-decide | Owns | Green-path | Reserved surface |\n'
  printf '| --- | --- | --- | --- | --- | --- |\n'
  local r policy id class may_decide owns green reserved
  for r in $order; do
    policy="role-policies/${r}.policy.json"
    [ -f "$policy" ] || continue
    id=$(jq -r '.role.id' "$policy")
    class=$(jq -r '.role.class' "$policy")
    may_decide=$(jq -r '.authority.may_decide[]?' "$policy" | join_or_dash)
    owns=$(jq -r '.artefacts.owns[]?' "$policy" | join_or_dash)
    green=$(jq -r 'if (.authority | has("green_path"))
                   then (.authority.green_path.may_authorize | tostring)
                   else "—" end' "$policy")
    reserved=$(jq -r '.authority.reserved_surface[]?' "$policy" | join_or_dash)
    printf '| %s | %s | %s | %s | %s | %s |\n' \
      "$(esc_cell "$id")" "$(esc_cell "$class")" "$(esc_cell "$may_decide")" \
      "$(esc_cell "$owns")" "$(esc_cell "$green")" "$(esc_cell "$reserved")"
  done
  printf '\n'
}

# ---------------------------------------------------------------------------
# Marker grammar. A marker is a WHOLE LINE in exactly one of two shapes:
#
#   <!-- BEGIN GENERATED: <key> -->
#   <!-- BEGIN GENERATED: <key> (source: <note>) -->
#   <!-- END GENERATED: <key> -->
#
# where <key> is "contract <role>", "allowed-skills <role>", "doctrine <role>"
# or "authority-matrix". Anchoring the whole line matters: a prefix match would
# accept `... doctrine qa-extra -->` as the `doctrine qa` marker, and a
# line-COUNT of a prefix would read two markers on one line as one.
# ---------------------------------------------------------------------------

marker_re() {  # marker_re BEGIN|END <key>
  if [ "$1" = "BEGIN" ]; then
    printf '^<!-- BEGIN GENERATED: %s( \\(source: [^)]*\\))? -->$' "$2"
  else
    printf '^<!-- END GENERATED: %s -->$' "$2"
  fi
}

# /usr/bin/grep everywhere below, not the shell's: a bundled ugrep with a
# hard-coded -I skips a file containing a single NUL byte OUTRIGHT and exits 1 —
# a clean, silent "no marker here" on a file that has one.
has_begin() {
  # has_begin <file> <key>
  /usr/bin/grep -qaE -- "$(marker_re BEGIN "$2")" "$1"
}

has_end() {
  # has_end <file> <key>
  /usr/bin/grep -qaE -- "$(marker_re END "$2")" "$1"
}

# Marker integrity, checked BEFORE any splice. Every way a pair goes wrong is
# destructive: a duplicated BEGIN (which body wins?), a missing or misordered
# END (on which splice_block would drop everything after BEGIN).
markers_ok() {
  # markers_ok <target> <key>
  local target="$1" key="$2" nb ne lb le
  nb=$(/usr/bin/grep -caE -- "$(marker_re BEGIN "$key")" "$target" || true)
  ne=$(/usr/bin/grep -caE -- "$(marker_re END "$key")" "$target" || true)
  if [ "$nb" != 1 ] || [ "$ne" != 1 ]; then
    echo "MARKER PAIR BROKEN $target: $nb BEGIN / $ne END for '$key' (want exactly 1 of each)"
    return 1
  fi
  lb=$(/usr/bin/grep -naE -- "$(marker_re BEGIN "$key")" "$target" | head -1 | cut -d: -f1)
  le=$(/usr/bin/grep -naE -- "$(marker_re END "$key")" "$target" | head -1 | cut -d: -f1)
  if [ "$lb" -ge "$le" ]; then
    echo "MARKER PAIR BROKEN $target: END (line $le) does not follow BEGIN (line $lb) for '$key'"
    return 1
  fi
  return 0
}

# Every marker-shaped line in a surface must be a WELL-FORMED marker for one of
# that surface's own keys. Without this a typo'd or renamed marker is simply
# "not present" — the surface's other markers keep the run green and the block
# it was supposed to drive is never rendered again.
markers_wellformed() {
  # markers_wellformed <target> <key...>
  local target="$1"; shift
  # The allowed patterns are held in an ARRAY, not a temp file. A `mktemp` here
  # that fails (an unwritable TMPDIR, a sandbox) left `allowed` EMPTY, and every
  # append then redirected to "" — so nothing matched and every perfectly good
  # marker in the corpus was reported `MARKER MALFORMED`. A setup failure must
  # never be able to masquerade as a content verdict, and this comparison never
  # needed a file in the first place.
  local -a allowed=()
  local key line re ok rc=0
  for key in "$@"; do
    allowed[${#allowed[@]}]=$(marker_re BEGIN "$key")
    allowed[${#allowed[@]}]=$(marker_re END   "$key")
  done
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    ok=0
    for re in "${allowed[@]}"; do
      if printf '%s\n' "$line" | /usr/bin/grep -qaE -- "$re"; then ok=1; break; fi
    done
    if [ "$ok" -eq 0 ]; then
      echo "MARKER MALFORMED $target: $line"
      rc=1
    fi
  done < <(/usr/bin/grep -aE '(BEGIN|END) GENERATED:' "$target" || true)
  return "$rc"
}

# Two well-formed pairs on ONE surface must not OVERLAP. Each pair is validated
# on its own, so `contract BEGIN … doctrine BEGIN … contract END … doctrine END`
# passes every per-key rule — and then the contract splice, which replaces
# everything between ITS markers, DELETES the doctrine BEGIN. The doctrine splice
# that follows finds no BEGIN in the stage file, inserts nothing, and the run
# exits 0: the doctrine is silently erased, which is the one outcome this whole
# layer exists to prevent. (Measured before this check: exit 0, no diagnostic,
# `doctrine qa` BEGIN gone.) Interval overlap covers every interleaving —
# nesting, partial overlap, either order.
markers_disjoint() {
  # markers_disjoint <target> <key...> — only meaningful once markers_ok passed
  local target="$1"; shift
  local key lb le spans=""
  for key in "$@"; do
    has_begin "$target" "$key" || continue
    lb=$(/usr/bin/grep -naE -- "$(marker_re BEGIN "$key")" "$target" | head -1 | cut -d: -f1)
    le=$(/usr/bin/grep -naE -- "$(marker_re END "$key")" "$target" | head -1 | cut -d: -f1)
    [ -n "$lb" ] && [ -n "$le" ] || continue
    spans="$spans
${lb} ${le} ${key}"
  done
  printf '%s\n' "$spans" | awk -v t="$target" '
    NF >= 3 {
      n++; b[n] = $1; e[n] = $2
      s = ""
      for (f = 3; f <= NF; f++) s = s (f > 3 ? " " : "") $f
      k[n] = s
    }
    END {
      rc = 0
      for (i = 1; i <= n; i++)
        for (j = i + 1; j <= n; j++)
          if (b[i] <= e[j] && b[j] <= e[i]) {
            printf "MARKER PAIRS OVERLAP %s: [%s] lines %d-%d and [%s] lines %d-%d - one splice would delete the other marker\n", \
              t, k[i], b[i], e[i], k[j], b[j], e[j]
            rc = 1
          }
      exit rc
    }'
}

# A marker may never sit inside a fenced code block. The renderer has no fence
# awareness, so it would happily render into one — while every reader (and the
# substrate checker, which exempts ```historical) treats the content as quoted
# sample text. Whole-line fence scan, CommonMark's 3-space indent limit, no
# interval regex (BSD awk).
markers_unfenced() {
  # markers_unfenced <target>
  local out
  out=$(awk '
    function runlen(s, c,   n) { n = 0; while (substr(s, n + 1, 1) == c) n++; return n }
    {
      line = $0
      i = 1
      while (substr(line, i, 1) == " ") i++
      indent = i - 1
      body = substr(line, i)
      first = substr(body, 1, 1)
      run = 0
      if (first == "`" || first == "~") run = runlen(body, first)
      isf = (indent <= 3 && run >= 3)
      if (open == 0) {
        if (isf) { open = 1; ch = first; openrun = run }
        next
      }
      # CommonMark: a closing fence is the SAME character and AT LEAST as long
      # as the opener, with nothing but whitespace after it. Accepting a shorter
      # run closes a ````fence on an inner ``` and everything after it reads as
      # unfenced.
      if (isf && first == ch && run >= openrun) {
        rest = substr(body, run + 1)
        gsub(/[ \t]/, "", rest)
        if (rest == "") { open = 0; next }
      }
      if (index(line, "BEGIN GENERATED:") > 0 || index(line, "END GENERATED:") > 0)
        printf "%d\t%s\n", NR, line
    }
  ' "$target")
  [ -z "$out" ] && return 0
  printf '%s\n' "$out" | while IFS=$'\t' read -r n l; do
    echo "MARKER FENCED $target:$n: $l"
  done
  return 1
}

# --- Staged rendering -------------------------------------------------------
# NOTHING is installed while rendering. Each target gets one STAGE file beside
# it (same filesystem ⇒ the final rename is atomic; seeded by `cp -p` so it
# carries the target's mode — `mktemp` alone creates 0600 and would silently
# re-permission every rendered surface, and writing THROUGH the target would
# truncate it before the new content lands). Successive blocks on the same
# surface accumulate in that one stage file. `install_staged` renames them all
# at the very end and ONLY if the whole run rendered cleanly; otherwise
# `discard_staged` removes them and the tree is exactly as it was.
# Residual, documented: a rename that fails partway through installation still
# leaves a partly-installed tree — the render is idempotent, so re-running after
# fixing the cause completes it, and `--check` names what is still stale.
STAGED=""
STAGE_OUT=""
TAB=$(printf '\t')

# Sets STAGE_OUT (an OUT-VARIABLE, not stdout: `$(stage_file …)` would run this
# in a subshell and every STAGED registration would be lost, leaking one stage
# file per block and installing none of them).
stage_file() {  # stage_file <target> — 0 and STAGE_OUT set, or 1
  local target="$1" stage
  stage=$(printf '%s\n' "$STAGED" | awk -F'\t' -v k="$target" '$1==k{print $2}' | tail -1)
  if [ -n "$stage" ]; then STAGE_OUT="$stage"; return 0; fi
  stage=$(mktemp "${target}.render-XXXXXX") || return 1
  if ! cp -p "$target" "$stage"; then rm -f "$stage"; return 1; fi
  STAGED="$STAGED
${target}	${stage}"
  STAGE_OUT="$stage"
  return 0
}

discard_staged() {
  printf '%s\n' "$STAGED" | awk -F'\t' 'NF==2{print $2}' | while IFS= read -r s; do
    [ -n "$s" ] && rm -f "$s"
  done
  STAGED=""
}

install_staged() {
  local t s left=""
  while IFS=$'\t' read -r t s; do
    [ -n "$t" ] && [ -n "$s" ] || continue
    if ! mv "$s" "$t"; then
      echo "INSTALL FAILED $t"
      fail=1
      # KEEP the entry: clearing the registry unconditionally would strand the
      # file the rename could not consume, with nothing left to clean it up.
      left="$left
${t}	${s}"
    fi
  done < <(printf '%s\n' "$STAGED" | awk -F'\t' 'NF==2{print}')
  STAGED="$left"
}

# Splice a freshly rendered body between an existing BEGIN/END marker pair, into
# the target's STAGE file. The marker lines are preserved verbatim.
# `begin_line` is the EXACT validated marker line, not a prefix.
splice_block() {
  # splice_block <target> <begin-line> <end-line> <body-file>
  local target="$1" begin_line="$2" end_line="$3" body_file="$4" stage tmp
  if ! stage_file "$target"; then
    echo "RENDER FAILED $target: cannot stage a rewrite beside it"
    fail=1
    return 0
  fi
  stage="$STAGE_OUT"
  tmp=$(mktemp "${target}.render-XXXXXX") || {
    echo "RENDER FAILED $target"; fail=1; return 0; }
  # The stage file is what earlier blocks on this surface already rewrote, so it
  # is the only honest place to confirm the pair is still there. Preflight's
  # disjointness rule should make this unreachable; it stays as the last line of
  # defence, because the failure it guards is a SILENT one (no BEGIN in the stage
  # ⇒ awk copies the file through unchanged, the body is never inserted, and the
  # run exits 0 with the block quietly gone).
  local awk_rc=0
  awk -v bl="$begin_line" -v el="$end_line" -v bf="$body_file" '
    {
      if (in_block == 0 && nb == 0 && $0 == bl) {
        print $0
        while ((getline line < bf) > 0) print line
        close(bf)
        in_block = 1
        nb++
        next
      }
      if (in_block == 1 && $0 == el) {
        print $0
        in_block = 0
        ne++
        next
      }
      if (in_block == 1) { next }
      print $0
    }
    END { if (nb != 1 || ne != 1) exit 3 }
  ' "$stage" > "$tmp" || awk_rc=$?
  if [ "$awk_rc" -eq 3 ]; then
    rm -f "$tmp"
    echo "MARKER PAIR LOST $target: the staged copy no longer holds exactly one BEGIN/END pair for this block (another block's splice consumed it)"
    fail=1
    return 0
  fi
  if [ "$awk_rc" -ne 0 ]; then
    rm -f "$tmp"
    echo "RENDER FAILED $target"
    fail=1
    return 0
  fi
  # Write THROUGH the stage file (it already carries the target's mode) and
  # drop the working copy. Nothing outside the stage set is touched. Guarded:
  # unguarded under `set -e`, a full disk here would exit before any cleanup.
  if ! cat "$tmp" > "$stage"; then
    rm -f "$tmp"
    echo "RENDER FAILED $target"
    fail=1
    return 0
  fi
  rm -f "$tmp"
}

# Extract the CURRENT body between a BEGIN/END marker pair (markers excluded).
extract_block() {
  # extract_block <begin-line> <end-line> <target>
  awk -v bl="$1" -v el="$2" '
    {
      if (in_block == 0 && $0 == bl) { in_block = 1; next }
      if (in_block == 1 && $0 == el) { in_block = 0; next }
      if (in_block == 1) print $0
    }
  ' "$3" "/dev/null" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Per (policy, surface, block-type) processing.
# ---------------------------------------------------------------------------

process_block() {
  # process_block <policy> <role> <target> <type>
  #   type ∈ { contract, allowed-skills, doctrine }
  local policy="$1" role="$2" target="$3" type="$4"
  local key begin_line end_line body_file rendered_file

  case "$type" in
    contract|allowed-skills|doctrine) key="${type} ${role}" ;;
    *) echo "internal error: unknown block type $type" >&2; exit 2 ;;
  esac
  end_line="<!-- END GENERATED: ${key} -->"

  # PREFLIGHT PHASE validates only; nothing in the tree is touched until every
  # policy/surface/source/marker in the whole run has been checked (see the main
  # loop). Otherwise a stale block on surface A is rewritten before a refusal on
  # surface B aborts the run — a partial render dressed up as a clean refusal.
  # Preflight validates the pair in process_surface, for EVERY key rather than
  # only the ones whose BEGIN survived (so an orphan END is caught too). Doing it
  # again here would print the same diagnostic twice for the same defect.
  [ "$PHASE" = "preflight" ] && return 0

  if ! markers_ok "$target" "$key"; then
    fail=1
    return 0
  fi

  begin_line=$(/usr/bin/grep -aE -- "$(marker_re BEGIN "$key")" "$target" | head -1)

  body_file=$(mktemp) || body_file=""
  [ -n "$body_file" ] || die_tempfile "the rendered $type block"
  case "$type" in
    contract)       render_contract "$policy" > "$body_file" ;;
    allowed-skills) render_allowed_skills "$policy" "$target" > "$body_file" ;;
    doctrine)       render_doctrine "$policy" > "$body_file" ;;
  esac

  if [ "$MODE" = "check" ]; then
    rendered_file=$(mktemp) || rendered_file=""
    [ -n "$rendered_file" ] || die_tempfile "the current $type block"
    extract_block "$begin_line" "$end_line" "$target" > "$rendered_file"
    if ! diff -q "$rendered_file" "$body_file" >/dev/null 2>&1; then
      echo "STALE $target: $type $role"
      fail=1
    fi
    rm -f "$rendered_file"
  else
    splice_block "$target" "$begin_line" "$end_line" "$body_file"
  fi
  rm -f "$body_file"
}

# Re-run the marker rules against the STAGED copy, after rendering and BEFORE
# anything is installed. Preflight can only validate what is already on disk; a
# block BODY is data (a doctrine file, a policy field value) and data that
# happens to contain a marker line is spliced in verbatim. Without this the run
# exits 0, installs a surface whose markers are now duplicated or broken, and the
# defect surfaces only on the NEXT run — against a corpus that is already
# committed. Diagnostics are re-pointed at the TARGET path; the stage file is an
# implementation detail.
verify_staged() {
  # verify_staged <target> <stage> <key...>
  local target="$1" stage="$2"; shift 2
  local out rc=0
  out=$(
    r=0
    markers_wellformed "$stage" "$@" || r=1
    markers_unfenced "$stage" || r=1
    for k in "$@"; do
      if has_begin "$stage" "$k" || has_end "$stage" "$k"; then
        markers_ok "$stage" "$k" || r=1
      fi
    done
    markers_disjoint "$stage" "$@" || r=1
    exit "$r"
  ) || rc=1
  if [ "$rc" -ne 0 ]; then
    [ -n "$out" ] && printf '%s\n' "$out" | sed "s|${stage}|${target}|g"
    echo "RENDERED BODY BROKE THE MARKERS $target: the freshly rendered content is not a valid marker layout (a block body carrying a GENERATED marker line?) — nothing installed"
    fail=1
  fi
}

# Process one (policy, surface) pair. Detects which recognized BEGIN markers for
# THIS role are present and regenerates each. Returns 1 (and records) if none.
process_surface() {
  # process_surface <policy> <role> <target>
  local policy="$1" role="$2" target="$3"
  local found=0

  if [ "$PHASE" = "preflight" ]; then
    markers_wellformed "$target" "contract ${role}" "allowed-skills ${role}" "doctrine ${role}" \
      || fail=1
    markers_unfenced "$target" || fail=1
    # Pair validation must fire when EITHER marker is present, not only when
    # BEGIN is: deleting just the BEGIN leaves a valid orphan END, and the
    # surface's OTHER block would then satisfy `found` and carry the run green.
    local k
    for k in "contract ${role}" "allowed-skills ${role}" "doctrine ${role}"; do
      if has_begin "$target" "$k" || has_end "$target" "$k"; then
        markers_ok "$target" "$k" || fail=1
      fi
    done
    markers_disjoint "$target" "contract ${role}" "allowed-skills ${role}" "doctrine ${role}" \
      || fail=1
  fi

  # WHERE a block lives is part of the shape, not only HOW MANY there are:
  # swapping the contract onto an overlay and the allowed-skills onto the base
  # leaves both totals correct while every reader looks in the wrong file.
  local is_overlay=0
  case "$target" in *.claude.md|*.codex.md) is_overlay=1 ;; esac

  if has_begin "$target" "contract ${role}"; then
    contract_hosts=$((contract_hosts + 1))
    [ "$is_overlay" -eq 0 ] && contract_base_hosts=$((contract_base_hosts + 1))
    process_block "$policy" "$role" "$target" contract
    found=1
  fi
  if has_begin "$target" "allowed-skills ${role}"; then
    skills_hosts=$((skills_hosts + 1))
    [ "$is_overlay" -eq 1 ] && skills_overlay_hosts=$((skills_overlay_hosts + 1))
    process_block "$policy" "$role" "$target" allowed-skills
    found=1
  fi
  if has_begin "$target" "doctrine ${role}"; then
    doctrine_hosts=$((doctrine_hosts + 1))
    [ "$is_overlay" -eq 0 ] && doctrine_base_hosts=$((doctrine_base_hosts + 1))
    if doctrine_source_ok "$policy" "$target"; then
      process_block "$policy" "$role" "$target" doctrine
    else
      fail=1
    fi
    found=1
  fi

  if [ "$found" -eq 0 ]; then
    # Same outcome in both modes: a surface listed by a policy but carrying no
    # recognized marker is a corpus defect, not a rendering decision.
    echo "MARKERS MISSING $target"
    fail=1
  fi

  if [ "$PHASE" = "run" ] && [ "$MODE" != "check" ]; then
    local stage
    stage=$(printf '%s\n' "$STAGED" | awk -F'\t' -v k="$target" '$1==k{print $2}' | tail -1)
    [ -n "$stage" ] && verify_staged "$target" "$stage" \
      "contract ${role}" "allowed-skills ${role}" "doctrine ${role}"
  fi
}

# Cross-role authority matrix. This block lives in ROLES.md and is NOT driven by
# any policy's generated_surfaces — it is one cross-role block keyed by the stable
# BEGIN prefix below. ROLES.md is a required matrix host: a missing marker is a
# MARKERS MISSING failure (both modes), matching per-surface marker discipline.
process_matrix() {
  local target="ROLES.md"
  local key="authority-matrix"
  local end_line="<!-- END GENERATED: ${key} -->"

  if [ ! -f "$target" ] || [ -L "$target" ]; then
    # ROLES.md is a REQUIRED matrix host, not an optional one: returning 0 on an
    # absent file made deleting it a clean pass.
    echo "MARKERS MISSING $target: authority-matrix (required matrix host, must be a regular file)"
    fail=1
    return 0
  fi
  if ! has_begin "$target" "$key"; then
    echo "MARKERS MISSING $target: authority-matrix"
    fail=1
    return 0
  fi
  if [ "$PHASE" = "preflight" ]; then
    markers_wellformed "$target" "$key" || fail=1
    markers_unfenced "$target" || fail=1
  fi
  if ! markers_ok "$target" "$key"; then
    fail=1
    return 0
  fi
  [ "$PHASE" = "preflight" ] && return 0

  local begin_line
  begin_line=$(/usr/bin/grep -aE -- "$(marker_re BEGIN "$key")" "$target" | head -1)

  local body_file
  body_file=$(mktemp) || body_file=""
  [ -n "$body_file" ] || die_tempfile "the rendered authority matrix"
  render_matrix > "$body_file"

  if [ "$MODE" = "check" ]; then
    local rendered_file
    rendered_file=$(mktemp) || rendered_file=""
    [ -n "$rendered_file" ] || die_tempfile "the current authority matrix"
    extract_block "$begin_line" "$end_line" "$target" > "$rendered_file"
    if ! diff -q "$rendered_file" "$body_file" >/dev/null 2>&1; then
      echo "STALE $target: authority-matrix"
      fail=1
    fi
    rm -f "$rendered_file"
  else
    splice_block "$target" "$begin_line" "$end_line" "$body_file"
    # Same post-render verification the per-role surfaces get: the matrix body is
    # rendered from POLICY FIELDS, so a field carrying a marker string reaches
    # ROLES.md and preflight cannot see it (it is not on disk yet). Without this
    # the matrix host was the one write path outside the staged-verification
    # guarantee: the run exited 0, installed the malformed line, and only the
    # NEXT `--check` complained.
    local stage
    stage=$(printf '%s\n' "$STAGED" | awk -F'\t' -v k="$target" '$1==k{print $2}' | tail -1)
    [ -n "$stage" ] && verify_staged "$target" "$stage" "$key"
  fi
  rm -f "$body_file"
}

# ---------------------------------------------------------------------------
# --selftest — prove the REFUSAL paths actually refuse, and that a refusal
# mutates nothing. These guards protect against silent doctrine ERASURE, so an
# unproven guard is worth about as much as no guard.
# ---------------------------------------------------------------------------

PHASE=preflight

if [ "$MODE" = "selftest" ]; then
  ST_SRC="$PWD"
  ST_TMP=$(mktemp -d) || ST_TMP=""
  [ -n "$ST_TMP" ] || die_tempfile "the selftest scratch tree"
  trap 'rm -rf "$ST_TMP"' EXIT
  st_cases=0
  st_stage() {  # fresh scratch copy of everything the renderer reads or writes
    rm -rf "$ST_TMP/repo"
    mkdir -p "$ST_TMP/repo"
    ( cd "$ST_SRC" && tar cf - role-policies lite roles doctrine ROLES.md ) \
      | ( cd "$ST_TMP/repo" && tar xf - )
  }
  st_digest() { python3 -c 'import hashlib,sys,os
h=hashlib.sha256()
for d,_,fs in sorted(os.walk(sys.argv[1])):
    for f in sorted(fs):
        p=os.path.join(d,f); h.update(p.encode()); h.update(open(p,"rb").read())
print(h.hexdigest())' "$1"; }
  st_expect() {  # st_expect <name> <want-exit> [<pattern>] [--unchanged]
    local name="$1" want="$2" pat="${3:-}" guard="${4:-}" got=0 out before after
    before=$(st_digest "$ST_TMP/repo")
    out=$(bash "$SELF" --root "$ST_TMP/repo" 2>&1) || got=$?
    after=$(st_digest "$ST_TMP/repo")
    if [ "$got" != "$want" ]; then
      echo "RENDER-SELFTEST FAIL: $name — exit $got, wanted $want" >&2; echo "$out" >&2; exit 1
    fi
    if [ -n "$pat" ] && ! /usr/bin/grep -qF -- "$pat" <<<"$out"; then
      echo "RENDER-SELFTEST FAIL: $name — '$pat' not in output" >&2; echo "$out" >&2; exit 1
    fi
    if [ "$guard" = "--unchanged" ] && [ "$before" != "$after" ]; then
      echo "RENDER-SELFTEST FAIL: $name — the refusal path MUTATED the tree" >&2; exit 1
    fi
    # A stage file left behind is a leak on EVERY path — success, refusal, or an
    # unforeseen `set -e` abort — so this is asserted for every case rather than
    # being one case of its own. (The tree digest would also move, but reports it
    # as "the refusal path MUTATED the tree", which points at the wrong defect.)
    local leaked
    leaked=$(find "$ST_TMP/repo" -name '*.render-*' -print 2>/dev/null || true)
    if [ -n "$leaked" ]; then
      echo "RENDER-SELFTEST FAIL: $name — stage file(s) leaked:" >&2
      printf '%s\n' "$leaked" >&2; exit 1
    fi
    st_cases=$((st_cases + 1))
    echo "render-selftest ok: $name"
  }
  st_hash() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
  st_mutate() {  # st_mutate <rel> <cmd...> — bytes must actually change
    local rel="$1"; shift
    local p="$ST_TMP/repo/$rel" b a
    [ -e "$p" ] || { echo "RENDER-SELFTEST FAIL: no staged $rel" >&2; exit 1; }
    b=$(st_hash "$p")
    ( cd "$ST_TMP/repo" && "$@" )
    a=$(st_hash "$p")
    [ "$b" != "$a" ] || { echo "RENDER-SELFTEST FAIL: $rel unchanged by its mutation" >&2; exit 1; }
  }
  st_mutate2() {  # st_mutate2 <relA> <relB> <cmd...> — BOTH files must change
    local ra="$1" rb="$2"; shift 2
    local pa="$ST_TMP/repo/$ra" pb="$ST_TMP/repo/$rb" a1 b1 a2 b2
    [ -e "$pa" ] && [ -e "$pb" ] || { echo "RENDER-SELFTEST FAIL: no staged $ra / $rb" >&2; exit 1; }
    a1=$(st_hash "$pa"); b1=$(st_hash "$pb")
    ( cd "$ST_TMP/repo" && "$@" )
    a2=$(st_hash "$pa"); b2=$(st_hash "$pb")
    [ "$a1" != "$a2" ] || { echo "RENDER-SELFTEST FAIL: $ra unchanged by its mutation" >&2; exit 1; }
    [ "$b1" != "$b2" ] || { echo "RENDER-SELFTEST FAIL: $rb unchanged by its mutation" >&2; exit 1; }
  }

  st_stage; st_expect "clean copy renders idempotently (no diff)" 0 "" --unchanged

  # A blank doctrine source must be REFUSED, not rendered as framing whitespace.
  st_stage
  st_mutate doctrine/qa.md python3 -c 'open("doctrine/qa.md","w").write("   \n\n\t\n")'
  st_expect "whitespace-only doctrine source refused" 1 "DOCTRINE SOURCE EMPTY" --unchanged

  st_stage
  st_mutate doctrine/qa.md python3 -c 'open("doctrine/qa.md","w").write("")'
  st_expect "zero-byte doctrine source refused" 1 "DOCTRINE SOURCE EMPTY" --unchanged

  st_stage
  rm "$ST_TMP/repo/doctrine/qa.md"
  st_expect "absent doctrine source refused" 1 "DOCTRINE SOURCE MISSING" --unchanged

  # Losing the END marker must NOT let splice_block eat the rest of the file.
  st_stage
  st_mutate lite/qa-agent.md python3 -c \
    'p="lite/qa-agent.md";ls=open(p).read().splitlines(True);open(p,"w").writelines([l for l in ls if "END GENERATED: doctrine" not in l])'
  st_expect "missing END marker refused (file not truncated)" 1 "MARKER PAIR BROKEN" --unchanged

  # A duplicated BEGIN is ambiguous, not a rendering decision.
  st_stage
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";t=open(p).read();i=t.index("<!-- BEGIN GENERATED: doctrine");j=t.index("\n",i)+1;open(p,"w").write(t[:j]+t[i:j]+t[j:])'
  st_expect "duplicated BEGIN marker refused" 1 "MARKER PAIR BROKEN" --unchanged

  # Deleting a whole doctrine block must not pass just because the SAME surface
  # still carries its contract marker.
  st_stage
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";t=open(p).read();a=t.index("<!-- BEGIN GENERATED: doctrine");e="<!-- END GENERATED: doctrine qa -->";b=t.index(e)+len(e);open(p,"w").write(t[:a]+t[b:])'
  st_expect "deleted doctrine block refused" 1 "DOCTRINE BLOCK HOSTS" --unchanged

  # A near-miss marker must be REFUSED, not silently "absent": a prefix match
  # would accept `doctrine qa-extra` AS the `doctrine qa` marker.
  st_stage
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";t=open(p).read();open(p,"w").write(t.replace("<!-- BEGIN GENERATED: doctrine qa ","<!-- BEGIN GENERATED: doctrine qa-extra ",1))'
  st_expect "malformed BEGIN marker refused" 1 "MARKER MALFORMED" --unchanged

  # Two markers on ONE line: a line COUNT would read this as a single marker.
  st_stage
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";t=open(p).read();m="<!-- BEGIN GENERATED: doctrine qa -->";i=t.index("<!-- BEGIN GENERATED: doctrine qa ");j=t.index("\n",i);open(p,"w").write(t[:j]+" "+m+t[j:])'
  st_expect "two BEGIN markers on one line refused" 1 "MARKER MALFORMED" --unchanged

  # Dropping the DECLARATION as well as the block must not read as "this role
  # simply has no doctrine" — every policy declares one, in both weights.
  st_stage
  st_mutate role-policies/qa.policy.json python3 -c \
    'import json;p="role-policies/qa.policy.json";d=json.load(open(p));del d["doctrine_source"];json.dump(d,open(p,"w"),indent=2)'
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";t=open(p).read();a=t.index("<!-- BEGIN GENERATED: doctrine");e="<!-- END GENERATED: doctrine qa -->";b=t.index(e)+len(e);open(p,"w").write(t[:a]+t[b:])'
  st_expect "undeclared doctrine_source refused" 1 "DOCTRINE SOURCE UNDECLARED" --unchanged

  # WHOLE-RUN refusal: a STALE block that would render fine, plus a refusal
  # elsewhere. A single-pass renderer rewrites the stale one before it reaches
  # the refusal — a partial render reported as a clean refusal.
  st_stage
  st_mutate lite/architect-agent.md python3 -c \
    'p="lite/architect-agent.md";ls=open(p).read().splitlines(True)
i=[n for n,l in enumerate(ls) if l.startswith("<!-- BEGIN GENERATED: doctrine")][0]
ls.insert(i+1,"STALE INJECTED LINE\n");open(p,"w").writelines(ls)'
  st_mutate doctrine/qa.md python3 -c 'open("doctrine/qa.md","w").write("\n")'
  st_expect "a refusal anywhere leaves the WHOLE tree untouched" 1 "DOCTRINE SOURCE EMPTY" --unchanged

  # The MATRIX host gets the same marker discipline as every other surface.
  st_stage
  st_mutate ROLES.md python3 -c \
    'p="ROLES.md";t=open(p).read();m="<!-- BEGIN GENERATED: authority-matrix-extra -->\n";open(p,"w").write(m+t)'
  st_expect "malformed matrix marker refused" 1 "MARKER MALFORMED" --unchanged

  st_stage
  rm "$ST_TMP/repo/ROLES.md"
  st_expect "absent matrix host refused" 1 "MARKERS MISSING" --unchanged

  # A block wrapped in a code fence renders normally but reads as sample text —
  # and the substrate checker's ```historical exemption then looks away from it.
  st_stage
  st_mutate lite/qa-agent.md python3 -c \
    'p="lite/qa-agent.md";ls=open(p).read().splitlines(True)
i=[n for n,l in enumerate(ls) if l.startswith("<!-- BEGIN GENERATED: doctrine")][0]
j=[n for n,l in enumerate(ls) if l.startswith("<!-- END GENERATED: doctrine")][0]
ls.insert(j+1,"```\n");ls.insert(i,"```historical\n");open(p,"w").writelines(ls)'
  st_expect "a marker inside a code fence refused" 1 "MARKER FENCED" --unchanged

  # A SYMLINKED surface would be replaced by a regular file, silently detaching
  # it from whatever it pointed at.
  st_stage
  ( cd "$ST_TMP/repo/lite" && mv qa-agent.md qa-agent.real.md && ln -s qa-agent.real.md qa-agent.md )
  st_expect "symlinked surface refused" 1 "SURFACE SYMLINK" --unchanged

  # A run-phase WRITE failure must discard every staged rewrite, not leave the
  # corpus half-rendered: preflight passes, an early surface renders, and a
  # later unwritable directory aborts the run.
  st_stage
  st_mutate roles/architect-agent.md python3 -c \
    'p="roles/architect-agent.md";ls=open(p).read().splitlines(True)
i=[n for n,l in enumerate(ls) if l.startswith("<!-- BEGIN GENERATED: doctrine")][0]
ls.insert(i+1,"STALE INJECTED LINE\n");open(p,"w").writelines(ls)'
  chmod 0555 "$ST_TMP/repo/lite"
  st_expect "a run-phase write failure installs NOTHING" 1 "RENDER FAILED" --unchanged
  chmod 0755 "$ST_TMP/repo/lite"

  # Deleting only the BEGIN leaves a valid orphan END; the surface's OTHER block
  # would otherwise satisfy `found` and carry the run green.
  st_stage
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";ls=open(p).read().splitlines(True);open(p,"w").writelines([l for l in ls if not l.startswith("<!-- BEGIN GENERATED: contract")])'
  st_expect "orphan END (BEGIN deleted) refused" 1 "MARKER PAIR BROKEN" --unchanged

  # ... and deleting BOTH markers must not simply make the block disappear.
  st_stage
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";t=open(p).read();a=t.index("<!-- BEGIN GENERATED: contract");e="<!-- END GENERATED: contract qa -->";b=t.index(e)+len(e);open(p,"w").write(t[:a]+t[b:])'
  st_expect "whole contract block deleted refused" 1 "CONTRACT BLOCK HOSTS" --unchanged

  st_stage
  st_mutate roles/qa-agent.claude.md python3 -c \
    'p="roles/qa-agent.claude.md";t=open(p).read();a=t.index("<!-- BEGIN GENERATED: allowed-skills");e="<!-- END GENERATED: allowed-skills qa -->";b=t.index(e)+len(e);open(p,"w").write(t[:a]+t[b:])'
  st_expect "whole allowed-skills block deleted refused" 1 "ALLOWED-SKILLS BLOCK HOSTS" --unchanged

  # CommonMark: a closing fence must be at least as long as its opener. A
  # scanner that closes a ```` fence on an inner ``` reads everything after it
  # as unfenced — and a marker hidden there escapes the fence rule.
  st_stage
  st_mutate lite/qa-agent.md python3 -c \
    'p="lite/qa-agent.md";ls=open(p).read().splitlines(True)
i=[n for n,l in enumerate(ls) if l.startswith("<!-- BEGIN GENERATED: doctrine")][0]
j=[n for n,l in enumerate(ls) if l.startswith("<!-- END GENERATED: doctrine")][0]
ls.insert(j+1,"````\n");ls.insert(i,"```\n");ls.insert(i,"````historical\n");open(p,"w").writelines(ls)'
  st_expect "a shorter inner fence does not end the outer fence" 1 "MARKER FENCED" --unchanged

  # The stage registry is TAB-separated, so a tab in a target path makes its row
  # unparseable — `install_staged` and `discard_staged` both drop it, which
  # silently skips the install AND leaks the stage file. Refuse the path.
  st_stage
  st_mutate role-policies/qa.policy.json python3 -c \
    'import json;p="role-policies/qa.policy.json";d=json.load(open(p));d["generated_surfaces"].append("roles/tab\there.md");json.dump(d,open(p,"w"),indent=2)'
  printf '# fixture\n' > "$ST_TMP/repo/roles/tab${TAB}here.md"
  st_expect "a tab in a generated surface path refused" 1 "SURFACE PATH" --unchanged

  # Two well-formed pairs that INTERLEAVE. Every per-key rule passes, and then
  # the contract splice — which replaces everything between ITS markers — deletes
  # the doctrine BEGIN. Measured before the disjointness check: exit 0, no
  # diagnostic, doctrine BEGIN gone, doctrine never rendered again.
  st_stage
  st_mutate roles/qa-agent.md python3 -c \
    'p="roles/qa-agent.md";ls=open(p).read().splitlines(True)
db=[n for n,l in enumerate(ls) if l.startswith("<!-- BEGIN GENERATED: doctrine")][0]
m=ls.pop(db)
ce=[n for n,l in enumerate(ls) if l.startswith("<!-- END GENERATED: contract")][0]
ls.insert(ce,m);open(p,"w").writelines(ls)'
  st_expect "interleaved marker pairs refused (silent block erasure)" 1 \
    "MARKER PAIRS OVERLAP" --unchanged

  # Block PLACEMENT, not only block COUNT: swapping the contract onto an overlay
  # and that overlay's allowed-skills onto the base leaves both totals correct
  # while every reader looks in the wrong file.
  st_stage
  st_mutate2 roles/qa-agent.md roles/qa-agent.claude.md python3 -c \
    'b=open("roles/qa-agent.md").read(); o=open("roles/qa-agent.claude.md").read()
ce_t="<!-- END GENERATED: contract qa -->"; se_t="<!-- END GENERATED: allowed-skills qa -->"
cb=b.index("<!-- BEGIN GENERATED: contract"); ce=b.index(ce_t)+len(ce_t)
sb=o.index("<!-- BEGIN GENERATED: allowed-skills"); se=o.index(se_t)+len(se_t)
contract=b[cb:ce]; skills=o[sb:se]
open("roles/qa-agent.md","w").write(b[:cb]+skills+b[ce:])
open("roles/qa-agent.claude.md","w").write(o[:sb]+contract+o[se:])'
  st_expect "contract/allowed-skills swapped between base and overlay refused" 1 \
    "CONTRACT BLOCK HOSTS" --unchanged

  # A block BODY is data. A doctrine source carrying its own GENERATED marker
  # line renders at exit 0 and leaves a duplicated pair behind, refused only by
  # the NEXT run — after the corrupt file is installed.
  st_stage
  st_mutate doctrine/qa.md python3 -c \
    'p="doctrine/qa.md";t=open(p).read();open(p,"w").write(t+"\n<!-- BEGIN GENERATED: doctrine qa -->\n")'
  st_expect "doctrine source carrying a GENERATED marker refused" 1 \
    "DOCTRINE SOURCE MARKER" --unchanged

  # ... and the same class through a NON-doctrine body: a policy field value that
  # contains a marker string is rendered into the contract table. Preflight
  # cannot see it (it is not on disk yet), so only the post-render check of the
  # STAGED copy catches it, before anything is installed.
  st_stage
  st_mutate role-policies/qa.policy.json python3 -c \
    'import json;p="role-policies/qa.policy.json";d=json.load(open(p));d["authority"]["forbidden"].append("<!-- BEGIN GENERATED: doctrine qa -->");json.dump(d,open(p,"w"),indent=2)'
  st_expect "a rendered body carrying a GENERATED marker installs nothing" 1 \
    "RENDERED BODY BROKE THE MARKERS" --unchanged

  # Doctrine PLACEMENT: moving the block to a host overlay keeps the total at
  # one while the base playbook — and therefore every other host — loses it.
  st_stage
  st_mutate2 roles/qa-agent.md roles/qa-agent.codex.md python3 -c \
    'b=open("roles/qa-agent.md").read()
e="<!-- END GENERATED: doctrine qa -->"; i=b.index("<!-- BEGIN GENERATED: doctrine"); j=b.index(e)+len(e)
open("roles/qa-agent.md","w").write(b[:i]+b[j:])
open("roles/qa-agent.codex.md","a").write("\n"+b[i:j]+"\n")'
  st_expect "doctrine block moved to a host overlay refused" 1 \
    "DOCTRINE BLOCK HOSTS" --unchanged

  # The MATRIX body is rendered from policy fields too, and ROLES.md was the one
  # write path outside the staged-verification guarantee. `reserved_surface`
  # feeds the matrix ONLY, so this isolates that path.
  st_stage
  st_mutate role-policies/cto.policy.json python3 -c \
    'import json;p="role-policies/cto.policy.json";d=json.load(open(p));d["authority"]["reserved_surface"].append("<!-- BEGIN GENERATED: authority-matrix -->");json.dump(d,open(p,"w"),indent=2)'
  st_expect "a marker injected into the authority matrix installs nothing" 1 \
    "RENDERED BODY BROKE THE MARKERS" --unchanged

  EXPECTED_ST_CASES=27
  if [ "$st_cases" -ne "$EXPECTED_ST_CASES" ]; then
    echo "RENDER-SELFTEST FAIL: ran $st_cases case(s), expected $EXPECTED_ST_CASES — update the literal deliberately" >&2
    exit 1
  fi
  echo "render-selftest OK ($st_cases cases)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Main loop — drive entirely off generated_surfaces.
# ---------------------------------------------------------------------------

render_pass() {
  local policy role surface
  for policy in role-policies/*.policy.json lite/role-policies/*.policy.json; do
    [ -e "$policy" ] || continue
    role=$(jq -r '.role.id' "$policy")
    doctrine_hosts=0
    doctrine_base_hosts=0
    contract_hosts=0
    contract_base_hosts=0
    skills_hosts=0
    skills_overlay_hosts=0
    overlay_surfaces=0

    # Iterate the surface list. A "" (empty array) yields no iterations → skipped.
    while IFS= read -r surface; do
      [ -z "$surface" ] && continue
      if [ ! -f "$surface" ]; then
        # A listed surface that does not exist on disk: the renderer never
        # creates files. Treat as a missing-markers condition for that surface.
        echo "MARKERS MISSING $surface"
        fail=1
        continue
      fi
      if [ -L "$surface" ]; then
        # `-f` follows symlinks, and `cp -p` + `mv` would then REPLACE the link
        # with a regular file — quietly detaching the surface from whatever it
        # pointed at. Symlinked surfaces are not a supported shape.
        echo "SURFACE SYMLINK $surface: a generated surface must be a regular file"
        fail=1
        continue
      fi
      case "$surface" in
        *"$TAB"*)
          # The stage registry is TAB-separated (`<target>\t<stage>`), so a tab in
          # a target path would make its row unparseable: `install_staged` and
          # `discard_staged` both drop it, which SILENTLY skips the install AND
          # leaks the stage file. Refuse the path instead of rendering into a
          # registry that cannot represent it. (A newline cannot get this far —
          # the surface list is read line by line.)
          echo "SURFACE PATH $surface: a generated surface path may not contain a tab"
          fail=1
          continue ;;
      esac
      case "$surface" in *.claude.md|*.codex.md) overlay_surfaces=$((overlay_surfaces + 1)) ;; esac
      process_surface "$policy" "$role" "$surface"
    done < <(jq -r '.generated_surfaces[]?' "$policy")

    # A policy that ships HOST OVERLAYS is the full-weight shape: its base
    # renders the contract table and each overlay renders that role's allowed
    # skills. Without this, deleting BOTH markers of a block just makes it
    # disappear — the surface's remaining block satisfies `found` and the run
    # stays green. (A weight that ships no overlays — the container-lean set,
    # and the spm stub — renders neither, by design, and is not held to it.)
    if [ "$overlay_surfaces" -gt 0 ]; then
      if [ "$contract_hosts" -ne 1 ] || [ "$contract_base_hosts" -ne 1 ]; then
        echo "CONTRACT BLOCK HOSTS $policy: $contract_hosts contract block(s), $contract_base_hosts of them on a base surface (want exactly 1, on the base)"
        fail=1
      fi
      if [ "$skills_hosts" -ne "$overlay_surfaces" ] || [ "$skills_overlay_hosts" -ne "$overlay_surfaces" ]; then
        echo "ALLOWED-SKILLS BLOCK HOSTS $policy: $skills_hosts allowed-skills block(s), $skills_overlay_hosts of them on a host overlay (want one on each of its $overlay_surfaces host overlays)"
        fail=1
      fi
    fi

    # EVERY role policy declares a doctrine source, in BOTH weights. Optional
    # would mean a whole weight can drop its doctrine cleanly: delete the key
    # AND the block and nothing objects — the base still has its contract
    # marker, and the reverse "declared by at least one policy" check is still
    # satisfied by the OTHER weight, which keeps rendering.
    local dsrc
    dsrc=$(jq -r '.doctrine_source // empty' "$policy")
    if [ -z "$dsrc" ]; then
      echo "DOCTRINE SOURCE UNDECLARED $policy: every role policy must declare doctrine_source"
      fail=1
    elif [ "$doctrine_hosts" -ne 1 ] || [ "$doctrine_base_hosts" -ne 1 ]; then
      # A declared doctrine must have a HOME, exactly one per policy, and that
      # home must be the BASE playbook. Zero = the block was deleted and the
      # doctrine silently vanished from that weight. More than one = the same
      # doctrine rendered twice in one weight. One, but on a host overlay = the
      # base playbook — and therefore every other host — silently lost it, while
      # the total still reads as correct.
      echo "DOCTRINE BLOCK HOSTS $policy: $doctrine_hosts doctrine block(s), $doctrine_base_hosts of them on a base surface (want exactly 1, on the base)"
      fail=1
    fi
  done

  # Cross-role matrix lives in ROLES.md, outside the generated_surfaces loop.
  process_matrix
}

# TWO PASSES. The first validates everything and writes nothing; only if the
# WHOLE corpus is coherent does the second pass render. A single pass that
# refuses partway through has already rewritten every surface it got to first —
# a partial render that reports itself as a clean refusal.
PHASE=preflight
render_pass
if [ "$fail" -ne 0 ]; then
  exit "$fail"
fi

PHASE=run
render_pass

# Install only a fully successful render. A failure during the run phase (an
# unwritable directory, a full disk) discards every staged rewrite instead of
# leaving the corpus half-rendered.
if [ "$MODE" != "check" ]; then
  if [ "$fail" -ne 0 ]; then
    discard_staged
  else
    install_staged
  fi
fi

exit "$fail"
