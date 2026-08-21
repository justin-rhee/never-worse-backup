# never-worse-backup

[![test](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml)

My backup script committed another agent session's half-finished work under my name, twice in two weeks, and both times it was doing exactly what I asked it to do. Find changed files, commit them. With parallel sessions on one tree it couldn't tell my finished work from something mid-keystroke.

So I wrote one that refuses to run when it might save the wrong thing, and says why.

## Use it if

You've got files you haven't committed yet, notes, plans, generated docs, and you want them saved automatically without the backup ever being the thing that loses your work. It runs from a hook, a scheduled job, or by hand.

## How it works

It runs, decides whether saving is safe right now, and either saves or explains why not.

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

The checks, in the order they run:

- if another process is partway through staging changes, it backs off and leaves them for next time
- if a file was touched in the last ten minutes, it treats that as someone still working, names it, and skips it
- it never carries a deletion, since a file you removed by mistake is the one thing a backup should not help you lose
- it names everything it saves, so a wrong grab is visible immediately rather than days later
- it only pushes if you opt in and say which remote is allowed, and it reads the outgoing changes for secrets first
- every path exits successfully, so it can never break whatever called it

About 50 lines of shell and git.

## Install

Nothing to install. Run it from a hook, a scheduled job, or by hand:

```
BACKUP_REPO=~/notes BACKUP_PATH=drafts/ bash never-worse-backup.sh
```

| var | default | what it does |
|---|---|---|
| `BACKUP_REPO` | current folder | the repo to back up |
| `BACKUP_PATH` | everything | which folder inside it to back up, like `docs/` |
| `BACKUP_EXPECTED_REMOTE` | unset | text the `origin` URL has to contain before it will push. Leave it unset and it only ever saves locally. |
| `BACKUP_ALLOW_PUBLIC` | `0` | set to `1` to allow pushing to a repo that is not private |

Leaving `BACKUP_EXPECTED_REMOTE` unset is the safe default and a fine way to start. It will commit locally and never push anywhere until you tell it exactly where it is allowed to.

## What it won't do

- replace real backups, or replace committing your own work, since it's a net under
  uncommitted files rather than a way of working
- force-push, resolve conflicts, or carry deletions across, and given any doubt it
  commits locally and stops
- know whose edit it is, only that a file was touched recently, so ten minutes is a
  guess about human behaviour rather than a fact about ownership

## How I tested it

The suite runs offline, no accounts or keys:

```
bash tests/test-never-worse-backup.sh
```

10 cases, one for each guard above. The two I most wanted proof of: that a pinned, matching remote does actually push, and that a secret in the outgoing changes gets committed locally and never leaves the machine. The reasoning behind each guard is in [docs/ADR.md](docs/ADR.md).

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

---

This little tool is one of a handful I pulled out of my own day-to-day agent setup. I use them all myself, so when something breaks I usually notice fast. But if you run into any issues, or anything that looks off, open an issue. I read every one. More tools on my [GitHub profile](https://github.com/justin-rhee).
