# Architecture Decision Records (ADRs)

Short notes on the design decisions behind this tool, one per real problem I hit.
The tests enforce these; this is the reasoning.

## 1. A backup has to yield to whoever is still working

I had this auto-checkpoint docs between sessions so they wouldn't get lost. Twice,
it committed another session's unsaved draft into a backup that wasn't theirs. The
draft got swept up and buried in an unrelated commit. My first guard, skip if
there are staged changes, missed it, because the other session's work wasn't staged
yet, just open and being edited.

So now it treats any file touched in the last ten minutes as someone still typing:
it skips the whole run and names the file. It's using recency as a stand-in for
ownership. The script can't know whose edit it is, but it can tell that someone
touched the file recently.

The result is that the backup never commits over active work. It's honest about the
limit (recency, not real ownership) and it names anything it skips, so a file that
got wrongly held back is visible right away instead of silently delayed. Getting
this to work meant sorting out two git quirks: the status output quotes paths that
have spaces in them, and it collapses untracked folders down to the folder name, so
a naive version would have skipped forever.

## 2. Never carry along a deletion

A backup that saves everything will faithfully record a file you deleted by
accident, and then push that deletion, helping you lose the very file it was meant
to protect.

So it only stages new and changed files, never deletions.

Its worst case is now "kept a file you meant to delete" (harmless, you just delete
it again) instead of "lost a file you meant to keep." When the two mistakes aren't
equally bad, it makes the recoverable one.

## 3. The push is opt-in, pinned, and checked for secrets

Pushing is where a backup can do real, remote, sometimes public damage: pushing
private drafts to the wrong repo, to a public repo, or pushing a file that happens
to contain a password or a key. A convenient default here is a liability.

So it only pushes when you set an expected remote and the origin URL matches it (you
can't push somewhere you didn't name), it refuses a repo that isn't private unless
you explicitly allow it, and it scans what it's about to send for common secret
patterns, keeping the commit local if it finds one. Every failure just stops and
leaves your work committed locally.

The worst case degrades to "committed locally, didn't push, told you why," never
"published something you didn't mean to." The secret scan is a backstop, not a
guarantee (the security notes say so), the real protection is the opt-in and the
pinned destination.
