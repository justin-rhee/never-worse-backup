#!/usr/bin/env bash
# test-never-worse-backup.sh, offline suite. Builds throwaway git repos (and a
# local bare "origin") to exercise every never-worse guarantee without network.
# Each repo disables hooks so a host gitleaks/pre-commit hook can't skew results.
#   bash tests/test-never-worse-backup.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NWB="$HERE/../src/never-worse-backup.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/nwbci.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
NOHOOKS="$WORK/nohooks"; mkdir -p "$NOHOOKS"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok    $*"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }
g() { git -C "$1" -c user.name=t -c user.email=t@e.x "${@:2}"; }

mkrepo() { # mkrepo <dir>, git repo (hooks disabled) with a committed docs/seed.md
  local d=$1; mkdir -p "$d/docs"; git init -q -b main "$d"
  git -C "$d" config core.hooksPath "$NOHOOKS"
  printf 'seed\n' > "$d/docs/seed.md"; g "$d" add -A; g "$d" commit -qm init
}
old() { touch -t 202601010000 "$1"; }   # mtime well older than the 10-min live window

echo "== 1. no repo -> skip, exit 0 =="
out=$(BACKUP_REPO="$WORK/nope" bash "$NWB" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q 'no git repo' <<<"$out"; } && ok "no repo skips cleanly" || bad "no repo (rc=$rc)"

echo "== 2. index busy (sibling staged) -> yield, no new commit =="
d="$WORK/busy"; mkrepo "$d"; printf 'draft\n' > "$d/docs/new.md"; g "$d" add docs/new.md
before=$(g "$d" rev-parse HEAD)
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs bash "$NWB" 2>&1); rc=$?
after=$(g "$d" rev-parse HEAD)
{ [ "$rc" = 0 ] && [ "$before" = "$after" ] && grep -q 'index busy' <<<"$out"; } \
  && ok "index busy: yields, no commit" || bad "index busy (rc=$rc)"

echo "== 3. recently-touched file is LIVE -> yield + named =="
d="$WORK/live"; mkrepo "$d"; printf 'typing\n' > "$d/docs/wip.md"   # fresh mtime
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs bash "$NWB" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q 'live edits' <<<"$out" && grep -q 'wip.md' <<<"$out"; } \
  && ok "live file: yields and names it" || bad "live file (rc=$rc)"

echo "== 4. old uncommitted file -> committed locally =="
d="$WORK/old"; mkrepo "$d"; printf 'settled\n' > "$d/docs/done.md"; old "$d/docs/done.md"
before=$(g "$d" rev-parse HEAD)
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs bash "$NWB" 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ "$before" != "$(g "$d" rev-parse HEAD)" ] && grep -q 'committed locally' <<<"$out"; } \
  && ok "old file: committed locally" || bad "old file (rc=$rc)"
# 5. same repo is now clean
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs bash "$NWB" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q 'nothing to back up' <<<"$out"; } && ok "clean repo: nothing to back up" || bad "nothing (rc=$rc)"

echo "== 6. a deletion is NOT propagated =="
d="$WORK/del"; mkrepo "$d"; rm "$d/docs/seed.md"
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs bash "$NWB" 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ -n "$(g "$d" ls-files docs/seed.md)" ]; } \
  && ok "deletion not auto-propagated (file still tracked)" || bad "deletion propagated (rc=$rc)"

echo "== 7. no BACKUP_EXPECTED_REMOTE -> local only, push skipped =="
d="$WORK/noremote"; mkrepo "$d"; printf 'x\n' > "$d/docs/a.md"; old "$d/docs/a.md"
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs bash "$NWB" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q 'no BACKUP_EXPECTED_REMOTE' <<<"$out"; } \
  && ok "no expected-remote: local only" || bad "no expected-remote (rc=$rc)"

echo "== 8. wrong remote -> push skipped =="
d="$WORK/wrong"; mkrepo "$d"; g "$d" remote add origin "https://example.invalid/someone/other.git"
printf 'x\n' > "$d/docs/b.md"; old "$d/docs/b.md"
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs BACKUP_EXPECTED_REMOTE="me/myrepo" bash "$NWB" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q 'does not match' <<<"$out"; } \
  && ok "wrong remote: push skipped" || bad "wrong remote (rc=$rc)"

echo "== 9. matching remote (local bare origin) -> pushes =="
bare="$WORK/origin.git"; git init -q --bare -b main "$bare"
d="$WORK/good"; mkrepo "$d"; g "$d" remote add origin "$bare"; g "$d" push -q -u origin main
printf 'realwork\n' > "$d/docs/c.md"; old "$d/docs/c.md"
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs BACKUP_EXPECTED_REMOTE="origin.git" BACKUP_ALLOW_PUBLIC=1 bash "$NWB" 2>&1); rc=$?
pushed=$(git -C "$bare" log --oneline 2>/dev/null | grep -c 'checkpoint uncommitted' || true)
{ [ "$rc" = 0 ] && [ "${pushed:-0}" -ge 1 ] && grep -q 'pushed to origin' <<<"$out"; } \
  && ok "matching remote: pushes to origin" || bad "push (rc=$rc pushed=$pushed): $out"

echo "== 10. secret in the outgoing diff -> committed locally, NOT pushed =="
bare2="$WORK/origin2.git"; git init -q --bare -b main "$bare2"
d="$WORK/secret"; mkrepo "$d"; g "$d" remote add origin "$bare2"; g "$d" push -q -u origin main
# Assemble the fake token from fragments so THIS test file does not itself trip a
# secret scanner (ours, GitHub's, gitleaks). The tool under test must still catch it
# at runtime, that is the whole point of this case. Defang the specimen; never
# exempt the scanner.
faketok="sk-$(printf '%s%s' 'ABCDEFGHIJKLMNOP' '1234')"
printf 'token=%s\n' "$faketok" > "$d/docs/leak.md"; old "$d/docs/leak.md"
out=$(BACKUP_REPO="$d" BACKUP_PATH=docs BACKUP_EXPECTED_REMOTE="origin2.git" BACKUP_ALLOW_PUBLIC=1 bash "$NWB" 2>&1); rc=$?
pushed=$(git -C "$bare2" log --oneline 2>/dev/null | grep -c 'checkpoint' || true)
local_c=$(g "$d" log --oneline | grep -c 'checkpoint uncommitted' || true)
{ [ "$rc" = 0 ] && [ "${pushed:-0}" = 0 ] && [ "${local_c:-0}" -ge 1 ] && grep -q 'possible secret' <<<"$out"; } \
  && ok "secret: committed locally, push skipped" || bad "secret path (rc=$rc pushed=$pushed local=$local_c): $out"

echo "test-never-worse-backup: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
