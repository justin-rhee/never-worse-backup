# Security policy: never-worse-backup

## Posture

never-worse-backup is provided as-is, with NO WARRANTY (see LICENSE). It is a
convenience safety net, not a security control.

The honest ceiling: the outgoing-diff secret scan matches a handful of common
credential shapes (API-key prefixes, private-key headers, JWTs). It will **not**
catch every secret, a novel token format, a secret split across lines, or a
credential in a file the scan's diff doesn't cover can pass. Treat the scan as a
backstop that reduces accidental exposure, never as a guarantee that a push is
secret-free. The primary control is not committing secrets in the first place.

The push path is opt-in and pinned (`BACKUP_EXPECTED_REMOTE`) and refuses a
non-private remote by default, specifically so the tool cannot surprise you by
publishing private drafts. If you set `BACKUP_ALLOW_PUBLIC=1`, that protection is
off and you own the consequences.

## Validation status

The standalone suite `tests/test-never-worse-backup.sh` runs offline (bash + git +
coreutils, no network, no keys) and passes 10/10, including the remote-pin,
non-private-refusal, and secret-in-diff paths. Run it before relying on the tool:

    bash tests/test-never-worse-backup.sh

## Reporting a vulnerability

Please report suspected vulnerabilities privately through this repository's
**Security → Report a vulnerability** tab (GitHub private vulnerability
reporting). Do not open a public issue for a suspected vulnerability, this keeps
the report private until a fix is available.
