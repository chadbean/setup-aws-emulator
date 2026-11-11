# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **composite** GitHub Action (`action.yml`) that installs [aws-emulator](https://github.com/aws/aws-emulator), starts it in the background, waits for readiness, and exports a client environment so later job steps talk to it. Linux only (x64/arm64). There is nothing to build or bundle: all logic is bash in `scripts/`. See `docs/adr/` for why (composite over JS/Docker; extract the `.deb` instead of `dpkg -i` or Docker). Domain terms (Install, Start, Ready, Client environment, Telemetry opt-out, Version) are defined in `GLOSSARY.md`; use them consistently.

## Commands

```sh
shellcheck -x scripts/*.sh .github/scripts/*.sh   # lint (CI also runs actionlint on workflows)
```

There is no local test suite. Tests are the jobs in `.github/workflows/test.yml`, which run the action via `uses: ./` across runners, containers, option combinations and failure cases. Scripts can be run outside Actions (Linux only) by setting the env vars they read, e.g.:

```sh
GITHUB_OUTPUT=/dev/stdout GITHUB_ENV=/dev/stdout GITHUB_PATH=/dev/stdout \
  INPUT_VERSION=latest scripts/install.sh
```

`install.sh` falls back to `$HOME/.cache/setup-aws-emulator` when `RUNNER_TOOL_CACHE` is unset.

## Architecture

- `action.yml` has two steps, `install` → `start` (skipped when `start: false`). Inputs are passed as `INPUT_*` env vars; action outputs are wired from each step's `$GITHUB_OUTPUT`.
- `scripts/lib.sh` is sourced by both scripts: download URLs, the pinned GPG fingerprint, `fail`/`warn` (emit `::error`/`::warning` annotations), `bool_input` validation, `require_linux`, `deb_arch`, `require_commands` (lists *all* missing tools; `a|b` means either), `set_output`/`set_env`.
- `scripts/install.sh`: resolves `latest` from upstream `versions.json` (upstream lists 4-part versions; package URLs and our outputs use the first 3 parts). Reimplements the tool-cache layout `$RUNNER_TOOL_CACHE/aws-emulator/<version>/<arch>` + `<arch>.complete` marker. On a miss: downloads the `.deb`, optionally verifies the GPG signature by requiring a `VALIDSIG` for the pinned primary fingerprint (with a short `GNUPGHOME` because of socket path length limits), extracts with `dpkg-deb -x` or falls back to `ar` + `tar`, and moves `opt/aws-emulator` into the cache. Also exports `EMULATOR_TELEMETRY=off` unless telemetry is enabled.
- `scripts/start.sh`: launches the binary with `nohup` (logs to `$RUNNER_TEMP/aws-emulator-<port>.log`), then polls until `~/.aws/emulator/<port>/ca.pem` exists and `/__admin/health` answers, failing (and printing the log) if the process exits or `wait-timeout` passes. Then sets outputs and, if `export-env`, the client environment.

Key constraints:
- No `post:` step exists, so the action can't stop the emulator or upload logs; the runner reaps the process.
- The action never installs system packages; it fails with a list of missing tools instead.
- Do not export `SSL_CERT_FILE` or `JAVA_TOOL_OPTIONS`: they replace the system trust store and break other HTTPS calls in the job (documented in README).
- Error messages are asserted in CI by substring (`run-expect.sh --fail "Missing required tools: curl"`, `"runs natively only on Linux"`, `--pass "in the tool cache"`). Changing that wording means updating `test.yml`.
- Behaviour visible to users (inputs, outputs, exported env) is documented in both `action.yml` and the README tables; keep them in sync.

## CI conventions

- Multi-line `run:` logic in workflows goes into shellchecked `.github/scripts/*.sh`, not inline bash.
- `test.yml` also runs weekly on a schedule to catch upstream breakage, and tests a "pinned" version (second-newest, from `pick-pinned-version.sh`) alongside `latest`.

## Releases

release-please (`release-type: simple`) on pushes to `main`, so use Conventional Commit messages. After a release, `.github/scripts/move-major-tag.sh` force-moves the major tag (e.g. `v1`) to the new release.
