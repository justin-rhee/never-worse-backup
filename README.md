# never-worse-backup

[![test](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml)

An automatic git backup can lose work as easily as it saves it. Mine committed another session's half-finished file under my name, then did it again a week later. It can go wrong in a handful of ways: committing over someone who's mid-edit, sweeping up a draft that's still being written, carrying along a file you deleted by accident, or pushing private notes to the wrong place. So I built one that stops the moment it might do any of that, and tells you why. It's about 50 lines of bash and git.

Here's what that looks like:

```console
# someone is still typing (file touched < 10 min ago)
$ never-worse-backup.sh
backup: live edits (touched <10 min), skip:
  docs/wip.md

# the edit has settled, now it's safe to checkpoint
$ never-worse-backup.sh
backup: sweeping:
  docs/wip.md
backup: committed locally
backup: no BACKUP_EXPECTED_REMOTE set, committed locally, push skipped
```

It never committed while the file was still being edited, and it wouldn't push anywhere until I told it exactly where it was allowed to.

## Use it if

You've got files you haven't committed yet, notes, plans, generated docs, and you want them saved automatically without the backup ever being the thing that loses your work. It runs from a hook, a scheduled job, or by hand.

```
BACKUP_REPO=~/notes BACKUP_PATH=drafts/ bash never-worse-backup.sh
```

| var | default | what it does |
|---|---|---|
| `BACKUP_REPO` | `$PWD` | the repo to back up |
| `BACKUP_PATH` | `.` | which folder in it to back up (e.g. `docs/`) |
| `BACKUP_EXPECTED_REMOTE` | *(unset)* | text the `origin` URL must contain before it'll push. Leave it unset and it only saves locally, never pushes. |
| `BACKUP_ALLOW_PUBLIC` | `0` | set to `1` to allow pushing to a repo that isn't private |

## What it does

Every time it runs, in order:

- If another process is in the middle of staging changes, it steps back and leaves them for the next run.
- If a file was touched in the last ten minutes, it treats that as someone still typing, so it gets named and skipped, not committed.
- It never carries along a deletion. A file you deleted by mistake isn't something a backup should help you lose.
- It names everything it saves, so if it grabbed the wrong thing you'll see it right away, not days later.
- It only pushes if you opt in and pin the remote (see above), and it scans the diff for secrets first.
- Every path exits 0, so it can never break whatever called it.

## What it won't do

- It's not a replacement for real backups, or for committing your own work. It's a net for *uncommitted* files, not a workflow.
- It won't force-push, resolve conflicts, or propagate deletions. On any doubt it commits locally and stops.
- Its live-draft guard is 10-minute recency, not real ownership. It can't know whose edit it is, only whether someone touched the file recently.

## How I tested it

You can run the test suite offline, no accounts or keys needed:

```
bash tests/test-never-worse-backup.sh    # 10 checks
```

It covers every guard above, including the two I most wanted to be sure of: a pinned, matching remote actually pushes, and a secret in the outgoing diff gets committed locally but never pushed. The reasoning behind each guard is in [docs/ADR.md](docs/ADR.md).

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

---

One of a set of small tools I've pulled out of a bigger system I run, where agents write the code and plain scripts decide when it's actually done. They all share one rule: the machine suggests, a person decides, and nothing quietly goes wrong behind your back. More of them on my [GitHub profile](https://github.com/justin-rhee).
