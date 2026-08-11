#!/usr/bin/env bash
# never-worse-backup, checkpoint uncommitted work under a path in a git repo so
# in-progress files can't rot, WITHOUT ever making things worse. Best-effort by
# design: on ANY issue it leaves changes committed LOCALLY and skips the push,
# printing why. It must never fail or block whatever called it, every exit is 0.
#
# The whole ethic is in one sentence: an automatic backup that can lose a
# colleague's draft, propagate a delete, or push a secret is worse than no backup.
# So each step below yields rather than risks.
#
# Config (all environment variables):
#   BACKUP_REPO             repo to checkpoint                  (default: $PWD)
#   BACKUP_PATH             path within the repo to back up     (default: .)
#   BACKUP_EXPECTED_REMOTE  substring the `origin` URL MUST contain before a push
#                           is attempted. REQUIRED for push, unset means commit
#                           locally and NEVER push. (This is the pin: you cannot
#                           accidentally push to a remote you did not name.)
#   BACKUP_ALLOW_PUBLIC     set to 1 to allow pushing to a non-private repo.
#                           Default refuses, backing up private drafts to a public
#                           remote is exactly the harm this tool exists to avoid.
set -u
R="${BACKUP_REPO:-$PWD}"
P="${BACKUP_PATH:-.}"
[ -d "$R/.git" ] || { echo "backup: no git repo at $R, skip"; exit 0; }

# A parallel process mid `git add -p` owns the index; committing now would sweep its
# staged hunks into our commit. Yield, the next run retries.
git -C "$R" diff --cached --quiet || { echo "backup: index busy (staged changes present), skip"; exit 0; }

# The guard above sees STAGED sibling work only. A parallel process's UNSTAGED draft
# is invisible to it and got swept twice in practice. Treat a file touched in the last
# 10 minutes as LIVE: yield and name it. Recency, not ownership, the script cannot
# know whose edit it is, but it can know whether someone is still typing. `-z` because
# porcelain QUOTES spaced paths. -uall: porcelain COLLAPSES untracked dirs to the dir
# name, and `find` on a directory matches its mtime (bumped by any child), so the guard
# would yield forever; -maxdepth 0 -type f pins the test to the named file itself.
live=$(git -C "$R" status --porcelain -z -uall -- "$P" | tr '\0' '\n' | while IFS= read -r e; do
  [ -n "$e" ] || continue
  f=${e:3}
  [ -f "$R/$f" ] && [ -n "$(find "$R/$f" -maxdepth 0 -type f -mmin -10 2>/dev/null)" ] && printf '%s\n' "$f"
done)
if [ -n "$live" ]; then
  echo "backup: live edits (touched <10 min), skip:"
  printf '%s\n' "$live" | sed 's/^/  /'
  exit 0
fi

# Stage NEW + MODIFIED but NOT deletions (--ignore-removal): an accidental delete is
# never auto-propagated. A file you meant to keep, deleted by a slip, is not something
# a backup should help you lose.
git -C "$R" add --ignore-removal -- "$P"

if git -C "$R" diff --cached --quiet; then echo "backup: nothing to back up"; exit 0; fi
# Name what is being swept: a wrongly-caught draft must be visible immediately, not
# discovered days later.
echo "backup: sweeping:"
git -C "$R" diff --cached --name-only | sed 's/^/  /'
git -C "$R" commit -q -m "backup: checkpoint uncommitted files (auto)" || { echo "backup: commit failed, skip"; exit 0; }
echo "backup: committed locally"

# --- push is OPT-IN and PINNED. Everything below can only SKIP, never lose work. ---
[ -n "${BACKUP_EXPECTED_REMOTE:-}" ] || { echo "backup: no BACKUP_EXPECTED_REMOTE set, committed locally, push skipped"; exit 0; }
url=$(git -C "$R" remote get-url origin 2>/dev/null || echo "")
case "$url" in
  *"$BACKUP_EXPECTED_REMOTE"*) ;;
  *) echo "backup: origin ($url) does not match BACKUP_EXPECTED_REMOTE, push skipped (committed locally)"; exit 0 ;;
esac
git -C "$R" fetch -q origin main 2>/dev/null || true
behind=$(git -C "$R" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
if [ "${behind:-0}" -gt 0 ]; then
  git -C "$R" rebase origin/main >/dev/null 2>&1 || { git -C "$R" rebase --abort 2>/dev/null || true; echo "backup: behind origin + rebase conflict, push skipped"; exit 0; }
fi
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  vis=$(gh repo view "$url" --json visibility -q .visibility 2>/dev/null || echo "")
  if [ -n "$vis" ] && [ "$vis" != "PRIVATE" ] && [ "${BACKUP_ALLOW_PUBLIC:-0}" != "1" ]; then
    echo "backup: repo visibility=$vis and BACKUP_ALLOW_PUBLIC!=1, push skipped (refusing to back up private drafts to a public remote)"; exit 0
  fi
fi
# Secret scan on the outgoing diff. `grep -q` on a pipe is SAFE here precisely because
# there is NO `set -o pipefail`: grep's exit (0 = a secret was found) is authoritative,
# and a match is the only thing that fires the branch, the classic pipefail+SIGPIPE
# false-miss cannot occur without pipefail.
if git -C "$R" diff origin/main..HEAD | grep -qE '(sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{16}|gh[pos]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.)'; then
  echo "backup: possible secret in outgoing diff, push skipped (committed locally)"; exit 0
fi
git -C "$R" push origin main >/dev/null 2>&1 && echo "backup: pushed to origin" || echo "backup: push failed, committed locally"
exit 0
