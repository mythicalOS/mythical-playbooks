#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# render-contracts.sh — regenerate the GENERATED blocks that live inside the
# surface files named by each role policy's `generated_surfaces` array.
#
# Two modes:
#   (default)  render/splice in place
#   --check    verify freshness only; mutate nothing; non-zero on stale/missing
#
# Block types (detected by BEGIN marker lines inside the target file):
#   contract <role>        — markdown contract tables
#   allowed-skills <role>  — one bullet per skills.allowed[] entry
#
# The renderer NEVER creates files and NEVER touches a file that is not listed
# in some policy's generated_surfaces. A policy with generated_surfaces:[] is
# skipped entirely.

MODE="render"
if [ "${1:-}" = "--check" ]; then
  MODE="check"
elif [ -n "${1:-}" ]; then
  echo "usage: render-contracts.sh [--check]" >&2
  exit 2
fi

fail=0

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
# Block presence detection. We match BEGIN markers by stable prefix so the
# parenthetical source-note on the contract BEGIN line does not break detection.
# ---------------------------------------------------------------------------

has_begin() {
  # has_begin <file> <begin-prefix>
  grep -qF "$2" "$1"
}

# Splice a freshly rendered body between an existing BEGIN/END marker pair.
# The marker lines themselves are preserved verbatim. Body is read from a file.
splice_block() {
  # splice_block <target> <begin-prefix> <end-line> <body-file>
  local target="$1" begin_prefix="$2" end_line="$3" body_file="$4"
  local tmp
  tmp=$(mktemp)
  awk -v bp="$begin_prefix" -v el="$end_line" -v bf="$body_file" '
    {
      if (in_block == 0 && index($0, bp) > 0) {
        print $0
        while ((getline line < bf) > 0) print line
        close(bf)
        in_block = 1
        next
      }
      if (in_block == 1 && $0 == el) {
        print $0
        in_block = 0
        next
      }
      if (in_block == 1) { next }
      print $0
    }
  ' "$target" > "$tmp"
  mv "$tmp" "$target"
}

# Extract the CURRENT body between a BEGIN/END marker pair (markers excluded).
extract_block() {
  # extract_block <begin-prefix> <end-line> <target>
  awk -v bp="$1" -v el="$2" '
    {
      if (in_block == 0 && index($0, bp) > 0) { in_block = 1; next }
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
  #   type ∈ { contract, allowed-skills }
  local policy="$1" role="$2" target="$3" type="$4"
  local begin_prefix end_line body_file rendered_file

  case "$type" in
    contract)
      begin_prefix="BEGIN GENERATED: contract ${role}"
      end_line="<!-- END GENERATED: contract ${role} -->"
      ;;
    allowed-skills)
      begin_prefix="BEGIN GENERATED: allowed-skills ${role}"
      end_line="<!-- END GENERATED: allowed-skills ${role} -->"
      ;;
    *) echo "internal error: unknown block type $type" >&2; exit 2 ;;
  esac

  body_file=$(mktemp)
  case "$type" in
    contract)       render_contract "$policy" > "$body_file" ;;
    allowed-skills) render_allowed_skills "$policy" "$target" > "$body_file" ;;
  esac

  if [ "$MODE" = "check" ]; then
    local current
    rendered_file=$(mktemp)
    extract_block "$begin_prefix" "$end_line" "$target" > "$rendered_file"
    if ! diff -q "$rendered_file" "$body_file" >/dev/null 2>&1; then
      echo "STALE $target: $type $role"
      fail=1
    fi
    rm -f "$rendered_file"
  else
    splice_block "$target" "$begin_prefix" "$end_line" "$body_file"
  fi
  rm -f "$body_file"
}

# Process one (policy, surface) pair. Detects which recognized BEGIN markers for
# THIS role are present and regenerates each. Returns 1 (and records) if none.
process_surface() {
  # process_surface <policy> <role> <target>
  local policy="$1" role="$2" target="$3"
  local found=0

  if has_begin "$target" "BEGIN GENERATED: contract ${role}"; then
    process_block "$policy" "$role" "$target" contract
    found=1
  fi
  if has_begin "$target" "BEGIN GENERATED: allowed-skills ${role}"; then
    process_block "$policy" "$role" "$target" allowed-skills
    found=1
  fi

  if [ "$found" -eq 0 ]; then
    # Same outcome in both modes: a surface listed by a policy but carrying no
    # recognized marker is a corpus defect, not a rendering decision.
    echo "MARKERS MISSING $target"
    fail=1
  fi
}

# Cross-role authority matrix. This block lives in ROLES.md and is NOT driven by
# any policy's generated_surfaces — it is one cross-role block keyed by the stable
# BEGIN prefix below. ROLES.md is a required matrix host: a missing marker is a
# MARKERS MISSING failure (both modes), matching per-surface marker discipline.
process_matrix() {
  local target="ROLES.md"
  local begin_prefix="BEGIN GENERATED: authority-matrix"
  local end_line="<!-- END GENERATED: authority-matrix -->"

  [ -f "$target" ] || return 0
  if ! has_begin "$target" "$begin_prefix"; then
    echo "MARKERS MISSING $target: authority-matrix"
    fail=1
    return 0
  fi

  local body_file
  body_file=$(mktemp)
  render_matrix > "$body_file"

  if [ "$MODE" = "check" ]; then
    local rendered_file
    rendered_file=$(mktemp)
    extract_block "$begin_prefix" "$end_line" "$target" > "$rendered_file"
    if ! diff -q "$rendered_file" "$body_file" >/dev/null 2>&1; then
      echo "STALE $target: authority-matrix"
      fail=1
    fi
    rm -f "$rendered_file"
  else
    splice_block "$target" "$begin_prefix" "$end_line" "$body_file"
  fi
  rm -f "$body_file"
}

# ---------------------------------------------------------------------------
# Main loop — drive entirely off generated_surfaces.
# ---------------------------------------------------------------------------

for policy in role-policies/*.policy.json; do
  [ -e "$policy" ] || continue
  role=$(jq -r '.role.id' "$policy")

  # Iterate the surface list. A "" (empty array) yields no iterations → skipped.
  while IFS= read -r surface; do
    [ -z "$surface" ] && continue
    if [ ! -f "$surface" ]; then
      # A listed surface that does not exist on disk: the renderer never creates
      # files. Treat as a missing-markers condition for that surface.
      echo "MARKERS MISSING $surface"
      fail=1
      continue
    fi
    process_surface "$policy" "$role" "$surface"
  done < <(jq -r '.generated_surfaces[]?' "$policy")
done

# Cross-role matrix lives in ROLES.md, outside the generated_surfaces loop.
process_matrix

exit "$fail"
