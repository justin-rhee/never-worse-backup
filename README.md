# never-worse-backup

[![tests](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/never-worse-backup/actions/workflows/test.yml) [![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) ![shell + git](https://img.shields.io/badge/shell-%2B%20git-blue.svg) ![zero dependencies](https://img.shields.io/badge/dependencies-0-brightgreen.svg)

Saves your uncommitted work to git on a schedule, without ever grabbing someone else's half-typed changes or committing a deletion.

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

My backup script committed another agent session's half-finished work under my name, twice in two weeks. Both times it did exactly what I asked: find changed files, commit them. With parallel sessions on one folder, it couldn't tell finished work from something mid-keystroke.

## Use it if

- you want uncommitted files saved automatically, without the backup ever being what loses your work
- parallel sessions or jobs share one folder
- you want it to run from a hook, a scheduled job or by hand

## Install

Nothing to install: about 50 lines of shell and git, and every path exits successfully, so it can never break whatever called it.

```
BACKUP_REPO=~/notes BACKUP_PATH=drafts/ bash never-worse-backup.sh
```

| var | default | what it does |
|---|---|---|
| `BACKUP_REPO` | current folder | the repo to back up |
| `BACKUP_PATH` | everything | which folder inside it to back up, like `docs/` |
| `BACKUP_EXPECTED_REMOTE` | unset | text the `origin` URL must contain before it pushes; unset means it only saves locally |
| `BACKUP_ALLOW_PUBLIC` | `0` | set to `1` to allow pushing to a repo that isn't private |

## How it works

1. if another process is partway through staging changes, it backs off until next time
2. a file touched in the last ten minutes counts as someone still working, so it names it and skips it
3. it commits what's left, never carrying a deletion, and names everything it saved
4. it pushes only if you opted in and named the allowed remote, after scanning the outgoing changes for secrets

## What it won't do

- replace real backups or committing your own work, since it's a net under uncommitted files
- force-push, resolve conflicts or carry deletions, and given any doubt it commits locally and stops
- know whose edit it is, only that a file was touched recently, so ten minutes is a guess about people rather than a fact about ownership
- run on Windows yet

## How I tested it

- 10 offline cases, one per guard, no accounts or keys: `bash tests/test-never-worse-backup.sh`
- a pinned, matching remote really does push
- a secret in the outgoing changes gets committed locally and never leaves the machine; the reasoning behind each guard is in [docs/ADR.md](docs/ADR.md)

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

<!-- related:start -->
## Related

- [touchset-gate](https://github.com/justin-rhee/touchset-gate): flags any file an agent changed outside its task
- [take-once](https://github.com/justin-rhee/take-once): lets several coding agents share one task list without two of them grabbing the same task

Part of a small set of tools I pulled out of my own agent harness. I use them myself and read every issue. More on my [GitHub profile](https://github.com/justin-rhee).
<!-- related:end -->
