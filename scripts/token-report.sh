#!/usr/bin/env bash
# Estimated-token report for playbook surfaces (bytes/4).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
total=0
printf '%-12s %8s %8s %8s\n' role base claude codex
for r in cto architect lead pm worker qa reviewer explorer designer ops devil spm; do
  b=$(( $( [ -f "roles/${r}-agent.md" ] && wc -c < "roles/${r}-agent.md" || echo 0 ) / 4 ))
  c=$(( $( [ -f "roles/${r}-agent.claude.md" ] && wc -c < "roles/${r}-agent.claude.md" || echo 0 ) / 4 ))
  x=$(( $( [ -f "roles/${r}-agent.codex.md" ] && wc -c < "roles/${r}-agent.codex.md" || echo 0 ) / 4 ))
  total=$(( total + b + c + x ))
  printf '%-12s %8s %8s %8s\n' "$r" "$b" "$c" "$x"
done
for f in ROLES.md README.md; do
  t=$(( $(wc -c < "$f") / 4 )); total=$(( total + t ))
  printf '%-12s %8s\n' "$f" "$t"
done
echo "fleet-total: $total"
