#!/usr/bin/env bash
# check-bridge-prefix.sh — the retired launcher bridge-server prefix must never
# re-enter shipped content.
#
# One bridge server name exists. The prefix this gate bans is the RETIRED one:
# once the surviving name is the only one, any reappearance of the old prefix is
# a copy-paste fossil that teaches an agent to call a tool that is not there —
# and prose is exactly where such a fossil survives silently, because nothing
# executes it.
#
# The pattern is ASSEMBLED FROM FRAGMENTS at runtime (the `check-denylist.py`
# idiom), so this script's own bytes never contain the banned string and it
# needs no self-exemption. A gate that has to exempt itself is a gate with a
# hole shaped exactly like itself.
#
# Every TRACKED entry is scanned, NUL-safely (`git ls-files -z` — a path with a
# newline cannot split a record), across three passes whose union is the answer:
# the working tree, the index, and symlink blobs. See `scan()` for why no one of
# them suffices. Both text passes force text mode (`grep -a`, `git grep --text`)
# because the shell's bundled grep hard-codes `-I`, so a single NUL byte would
# make a file invisible with a clean exit 1 — a wrong negative that reads
# exactly like absence.
#
# Exit 0 = clean; 1 = at least one occurrence; 2 = setup error.
# Usage: scripts/check-bridge-prefix.sh [--selftest]
set -euo pipefail
cd "$(dirname "$0")/.."

command -v python3 >/dev/null || { echo "check-bridge-prefix needs python3" >&2; exit 2; }

# Assembled, never written whole. Two adjacent string literals concatenate.
PREFIX="mcp__""mythical__"

scan() {
  # $1 = directory to scan (must be a git work tree). Prints `path:line:text`
  # for every hit; returns 0 clean, 1 matched, 2 setup/tool error.
  #
  # THREE passes, because no single one sees everything a tracked entry can be:
  #
  #   * WORKING TREE, regular files only (`git ls-files` + `/usr/bin/grep -a`) —
  #     the content a contributor is actually about to commit, staged or not.
  #     Symlinks are EXCLUDED here on purpose: filesystem grep dereferences the
  #     path and reads the TARGET, so a link whose own text carries the prefix
  #     but points at a clean file reads as clean, and a dangling link is a
  #     spurious error.
  #   * INDEX, regular files (`git grep --cached --text`) — catches content that
  #     is staged but no longer in the working tree.
  #   * SYMLINK BLOBS (`git ls-files -s` mode 120000 + `git cat-file blob`) —
  #     `git grep` deliberately skips mode-120000 entries, so the one pass that
  #     could have covered them does not. A symlink's blob IS its link text;
  #     this pass is the only thing that reads it.
  #
  # Their union is the answer; a hit in any of the three fails.
  #
  # A tool error must NOT read as "clean": `grep` exits 1 for no-match and 2 for
  # a real failure, and `xargs` collapses both to 123, so the exit status alone
  # cannot tell them apart. Anything on stderr is therefore treated as a setup
  # error — the one signal the collapse preserves. The redirection is INSIDE the
  # command substitution (`$( { …; } 2>"$err" )`); attached to the assignment it
  # would not capture the substitution's stderr at all, and the guard would be
  # inert. `/dev/null` is passed as an extra operand so grep always prefixes
  # filenames, even in a batch of one.
  local root="$1" out idx lnk err rc=0 irc=0 lrc=0
  err=$(mktemp -t check-bridge-prefix-err.XXXXXX) || return 2

  out=$( {
    git -C "$root" ls-files -z \
      | (cd "$root" && python3 -c '
import os, sys
# Classify by what is on DISK now (lstat), never by the index mode. An unstaged
# type change — an indexed symlink replaced by a regular file, or the reverse —
# would otherwise route the entry to the wrong pass, and BOTH passes would look
# away from the content that is actually there.
for rec in sys.stdin.buffer.read().split(b"\0"):
    if not rec:
        continue
    try:
        st = os.lstat(rec)
    except FileNotFoundError:
        continue          # deleted-but-tracked: nothing on disk to read
    except OSError as exc:
        # ANY other lstat failure — a permission denial, an I/O error, an
        # unreadable parent — must NOT be swallowed. Suppressing it here would
        # drop the entry from the working-tree pass and let the clean index blob
        # answer for content nobody could read: a false PASS with no signal.
        sys.stderr.write("lstat failed for %s: %s\n" % (os.fsdecode(rec), exc))
        sys.exit(2)
    import stat as _s
    if _s.S_ISREG(st.st_mode):
        sys.stdout.buffer.write(rec + b"\0")
') \
      | (cd "$root" && xargs -0 -r /usr/bin/grep -a -n -F -- "$PREFIX" /dev/null)
  } 2>"$err" ) || rc=$?
  if [[ -s "$err" ]]; then
    cat "$err" >&2; rm -f "$err"; return 2
  fi

  idx=$( { git -C "$root" grep --cached --text --no-color -n -F -e "$PREFIX" -- .; } 2>"$err" ) || irc=$?
  if [[ -s "$err" ]]; then
    cat "$err" >&2; rm -f "$err"; return 2
  fi
  if [[ "$irc" -gt 1 ]]; then
    rm -f "$err"; echo "scan: git grep --cached exited $irc" >&2; return 2
  fi

  lnk=$( { git -C "$root" ls-files -s -z | python3 -c '
import os, stat, subprocess, sys
root = sys.argv[1]
prefix = sys.argv[2].encode()
hits = 0
seen = set()
reported = set()
def report(path, text):
    global hits
    if path in reported:
        return
    reported.add(path)
    hits += 1
    sys.stdout.write("%s:1: -> %s\n" % (path.decode("utf-8", "replace"),
                                        text.decode("utf-8", "replace")))
for rec in sys.stdin.buffer.read().split(b"\0"):
    if not rec:
        continue
    meta, _, path = rec.partition(b"\t")
    if path in seen:
        continue
    seen.add(path)
    # WORKING-TREE link text, when the path is a symlink RIGHT NOW — this is
    # what an unstaged file->symlink change produces, and the index mode would
    # miss it entirely.
    full = os.path.join(root, os.fsdecode(path))
    try:
        is_link = stat.S_ISLNK(os.lstat(full).st_mode)
    except FileNotFoundError:
        is_link = False       # deleted-but-tracked: fall through to the index
    except OSError as exc:
        sys.stderr.write("lstat failed for %s: %s\n" % (full, exc))
        sys.exit(2)
    if is_link:
        try:
            text = os.fsencode(os.readlink(full))
        except OSError as exc:
            sys.stderr.write("readlink failed for %s: %s\n" % (full, exc))
            sys.exit(2)
        if prefix in text:
            report(path, text)
        # NO `continue`: the INDEX blob is inspected too, below. A staged
        # symlink carrying the prefix, replaced unstaged by a clean symlink,
        # is otherwise invisible to all three passes - the working-tree read
        # answers "clean" and nothing ever looks at what is actually staged.
        # The two are independent states and both must be scanned.
    # INDEX link text, for a symlink that is staged (and possibly no longer on
    # disk). `git grep` skips mode-120000 blobs, so this is the only pass that
    # ever reads them.
    if meta.startswith(b"120000"):
        sha = meta.split()[1].decode()
        blob = subprocess.run(["git", "-C", root, "cat-file", "blob", sha],
                              stdout=subprocess.PIPE, check=True).stdout
        if prefix in blob:
            report(path, blob)
sys.exit(1 if hits else 0)
' "$root" "$PREFIX"; } 2>"$err" ) || lrc=$?
  if [[ -s "$err" ]]; then
    cat "$err" >&2; rm -f "$err"; return 2
  fi
  rm -f "$err"
  if [[ "$lrc" -gt 1 ]]; then
    echo "scan: symlink-blob pass exited $lrc" >&2; return 2
  fi

  if [[ -n "$out" || -n "$idx" || -n "$lnk" ]]; then
    [[ -n "$out" ]] && printf '%s\n' "$out"
    [[ -n "$idx" ]] && printf '%s\n' "$idx"
    [[ -n "$lnk" ]] && printf '%s\n' "$lnk"
    return 1
  fi
  # 0 (matched, but empty output — impossible), 1 (single batch, no match) and
  # 123 (some batch reported no match) are the only clean statuses.
  case "$rc" in
    0|1|123) return 0 ;;
    *) echo "scan: unexpected exit status $rc" >&2; return 2 ;;
  esac
}

selftest() {
  local tmp rc out
  tmp=$(mktemp -d -t check-bridge-prefix.XXXXXX) || { echo "selftest: mktemp failed" >&2; exit 2; }
  trap 'rm -rf "$tmp"' RETURN

  # A staged copy of the tracked tree, as its own git work tree.
  git ls-files -z | (cd "$PWD" && xargs -0 -r -I{} sh -c '
      mkdir -p "$2/$(dirname "$1")" && cp "$1" "$2/$1"
    ' _ {} "$tmp") || { echo "selftest: staging failed" >&2; exit 2; }
  git -C "$tmp" init -q
  git -C "$tmp" add -A
  [[ -f "$tmp/roles/worker-agent.md" ]] || { echo "selftest: fixture file missing" >&2; exit 2; }

  # 1. The unseeded copy must be clean — otherwise the seeded case below proves
  #    nothing (it would fail for a pre-existing reason).
  rc=0; out=$(scan "$tmp") || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "selftest FAIL: unseeded copy exited $rc, expected 0:" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  # 2. Seed exactly one occurrence and require the scan to name that file:line.
  printf '\ncall %s%s to coordinate.\n' "$PREFIX" "coordination_ask" >> "$tmp/roles/worker-agent.md"
  git -C "$tmp" add -A
  local seeded_line
  seeded_line=$(/usr/bin/grep -a -c '' "$tmp/roles/worker-agent.md")
  rc=0; out=$(scan "$tmp") || rc=$?
  if [[ "$rc" -ne 1 ]]; then
    echo "selftest FAIL: seeded copy exited $rc, expected 1" >&2
    exit 1
  fi
  if ! printf '%s\n' "$out" | /usr/bin/grep -aq "^roles/worker-agent.md:${seeded_line}:"; then
    echo "selftest FAIL: seeded hit not reported at roles/worker-agent.md:${seeded_line}" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  # 3. A tracked SYMLINK whose own link text carries the prefix, pointing at a
  #    path that is not the banned content. The filesystem pass skips symlinks
  #    and `git grep` skips mode-120000 entries, so this case exists to prove
  #    the symlink-blob pass — the only one that reads the link text — catches it.
  #    Staged on a fresh copy so it is the ONLY seeded occurrence.
  rm -rf "$tmp"; mkdir -p "$tmp/roles"
  printf '# clean\n' > "$tmp/roles/worker-agent.md"
  git -C "$tmp" init -q
  ln -s "${PREFIX}target/worker-agent.md" "$tmp/roles/link.md" 2>/dev/null \
    || { echo "selftest: cannot create symlink fixture" >&2; exit 2; }
  git -C "$tmp" add -A
  [[ -L "$tmp/roles/link.md" ]] || { echo "selftest: symlink fixture is not a symlink" >&2; exit 2; }
  rc=0; out=$(scan "$tmp") || rc=$?
  if [[ "$rc" -ne 1 ]]; then
    echo "selftest FAIL: tracked-symlink copy exited $rc, expected 1 (the link TEXT carries the prefix)" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  if ! printf '%s\n' "$out" | /usr/bin/grep -aq '^roles/link.md:'; then
    echo "selftest FAIL: symlink hit not reported at roles/link.md" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  # 4. A blob containing a NUL byte must still be scanned. `grep` in this shell
  #    hard-codes -I (skip binary), which turns a NUL-bearing file into a clean
  #    exit 1 — indistinguishable from absence. Both passes must see through it.
  printf 'a\000 %s%s b\n' "$PREFIX" "coordination_ask" > "$tmp/roles/nul.md"
  git -C "$tmp" add -A
  rc=0; out=$(scan "$tmp") || rc=$?
  if ! printf '%s\n' "$out" | /usr/bin/grep -aq '^roles/nul.md:'; then
    echo "selftest FAIL: NUL-bearing file was skipped instead of scanned" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  # 5. A CLEAN tracked symlink must not be reported. Without this the symlink
  #    pass could "pass" case 3 by flagging every link it sees.
  rm -rf "$tmp"; mkdir -p "$tmp/roles"
  printf '# clean\n' > "$tmp/roles/worker-agent.md"
  git -C "$tmp" init -q
  ln -s worker-agent.md "$tmp/roles/link.md"
  git -C "$tmp" add -A
  rc=0; out=$(scan "$tmp") || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "selftest FAIL: a clean tracked symlink was reported (exit $rc)" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  # 6. UNSTAGED TYPE CHANGE, symlink -> regular file. The index still says
  #    mode 120000 and its blob is clean; the file on disk carries the prefix.
  #    Classifying by index mode would send this entry to the symlink pass,
  #    which would read the clean blob and pass.
  printf 'see %s%s\n' "$PREFIX" "coordination_ask" > "$tmp/roles/replaced.md.tmp"
  ln -s worker-agent.md "$tmp/roles/replaced.md"
  git -C "$tmp" add -A
  rm -f "$tmp/roles/replaced.md"
  mv "$tmp/roles/replaced.md.tmp" "$tmp/roles/replaced.md"
  rc=0; out=$(scan "$tmp") || rc=$?
  if [[ "$rc" -ne 1 ]] || ! printf '%s\n' "$out" | /usr/bin/grep -aq '^roles/replaced.md:'; then
    echo "selftest FAIL: unstaged symlink->file change was not scanned (exit $rc)" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  # 7. UNSTAGED TYPE CHANGE, regular file -> symlink. The index blob is a clean
  #    regular file; the link text on disk carries the prefix. The working-tree
  #    grep pass skips symlinks, so only an lstat-classified link read sees it.
  rm -rf "$tmp"; mkdir -p "$tmp/roles"
  printf '# clean\n' > "$tmp/roles/worker-agent.md"
  printf '# clean\n' > "$tmp/roles/flipped.md"
  git -C "$tmp" init -q
  git -C "$tmp" add -A
  rm -f "$tmp/roles/flipped.md"
  ln -s "${PREFIX}target/worker-agent.md" "$tmp/roles/flipped.md"
  rc=0; out=$(scan "$tmp") || rc=$?
  if [[ "$rc" -ne 1 ]] || ! printf '%s\n' "$out" | /usr/bin/grep -aq '^roles/flipped.md:'; then
    echo "selftest FAIL: unstaged file->symlink change was not scanned (exit $rc)" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  # 8. An lstat failure must be reported, never swallowed into a clean pass.
  #    Skipped (loudly) when the test process can stat regardless — running as
  #    root, or on a filesystem that ignores the mode — because then the fixture
  #    proves nothing and a silent "ok" would be the very lie this case exists
  #    to prevent.
  rm -rf "$tmp"; mkdir -p "$tmp/roles/locked"
  printf '# clean\n' > "$tmp/roles/worker-agent.md"
  printf '# clean\n' > "$tmp/roles/locked/inner.md"
  git -C "$tmp" init -q
  git -C "$tmp" add -A
  chmod 000 "$tmp/roles/locked"
  if python3 -c 'import os,sys; os.lstat(sys.argv[1])' "$tmp/roles/locked/inner.md" 2>/dev/null; then
    echo "selftest SKIP: lstat still succeeds on a 000 directory (root, or a permissive fs)" >&2
    chmod 755 "$tmp/roles/locked"
  else
    rc=0; out=$(scan "$tmp" 2>&1) || rc=$?
    chmod 755 "$tmp/roles/locked"
    if [[ "$rc" -ne 2 ]]; then
      echo "selftest FAIL: an unreadable tracked path exited $rc, expected 2 (setup error)" >&2
      printf '%s\n' "$out" >&2
      exit 1
    fi
  fi

  # 9. STAGED symlink carries the prefix; the working tree has since replaced it
  #    with a CLEAN symlink. The working-tree read answers "clean" — only an
  #    independent index-blob read sees what is actually staged, which is what
  #    a commit would carry.
  rm -rf "$tmp"; mkdir -p "$tmp/roles"
  printf '# clean\n' > "$tmp/roles/worker-agent.md"
  git -C "$tmp" init -q
  ln -s "${PREFIX}target/worker-agent.md" "$tmp/roles/swapped.md"
  git -C "$tmp" add -A
  rm -f "$tmp/roles/swapped.md"
  ln -s worker-agent.md "$tmp/roles/swapped.md"
  rc=0; out=$(scan "$tmp") || rc=$?
  if [[ "$rc" -ne 1 ]] || ! printf '%s\n' "$out" | /usr/bin/grep -aq '^roles/swapped.md:'; then
    echo "selftest FAIL: a staged banned symlink hidden by a clean working-tree symlink was missed (exit $rc)" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi

  echo "check-bridge-prefix selftest OK (9 cases)"
}

if [[ "${1:-}" == "--selftest" ]]; then
  selftest
  exit 0
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [--selftest]" >&2
  exit 2
fi

rc=0
out=$(scan "$PWD") || rc=$?
if [[ "$rc" -eq 2 ]]; then
  echo "BRIDGE-PREFIX: scan could not run — treating as a setup error, not a pass." >&2
  exit 2
fi
if [[ "$rc" -ne 0 ]]; then
  printf '%s\n' "$out" >&2
  echo "BRIDGE-PREFIX FAIL: the retired launcher bridge prefix appears in tracked content (see above)." >&2
  exit 1
fi
echo "bridge-prefix gate OK (0 occurrences in tracked files)"
