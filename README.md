# never-worse-backup

[![test](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml)

A git checkpoint script that refuses to run when it might save the wrong thing.

## Why I built it

My backup script committed someone else's half-finished work under my name. A week later it did it again.

Both times it did exactly what I had asked it to do: find changed files, commit them. It had no way to tell work I had finished from work somebody was still in the middle of typing.

If you automate saving your work, this is the shape of it. The thing meant to protect you is running unattended, on files you haven't looked at, at a moment you didn't choose. Once I started listing the ways that can go wrong, the list got uncomfortable. It can commit over someone mid-edit. It can sweep up a draft that is still being written. It can carry along a file you deleted by mistake, which is the one case where a backup helps you lose something. It can push private notes somewhere public.

So I wrote one that stops the moment any of those is possible, and says which one.

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

It isn't a replacement for real backups, or for committing your own work. It's a net under uncommitted files, not a way of working.

It won't force-push, resolve conflicts, or carry deletions across. Given any doubt it commits locally and stops.

Its guard against interrupting someone is that the file was touched recently, not that it knows whose edit it is. Ten minutes is a guess about human behaviour, not a fact about ownership.

## How I tested it

The suite runs offline, no accounts or keys:

```
bash tests/test-never-worse-backup.sh
```

10 cases, one for each guard above. The two I most wanted proof of: that a pinned, matching remote does actually push, and that a secret in the outgoing changes gets committed locally and never leaves the machine. The reasoning behind each guard is in [docs/ADR.md](docs/ADR.md).

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

---

One of a set of small tools I've pulled out of a bigger system I run, where agents write the code and plain scripts decide when it's actually done. They all share one rule: the machine suggests, a person decides, and nothing quietly goes wrong behind your back. More of them on my [GitHub profile](https://github.com/justin-rhee).
