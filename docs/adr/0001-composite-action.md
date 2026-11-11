# 1. Composite action, not JavaScript or Docker

Date: 2026-11-11

## Status

Accepted

## Context

`actions/setup-*` actions are JavaScript actions. They use `@actions/tool-cache` and can run a `post:` step after the job. This action also has to leave a server running for the steps after it.

- A **Docker container action** runs in its own container, which stops when the step ends. The emulator would stop with it. It also only works on Linux runners.
- A **JavaScript action** brings a Node toolchain, `dist/` bundling and dependency updates, all to download a file, unpack it and start a process.
- A **composite action** runs bash steps directly on the runner. It has no `post:` step.

## Decision

Use a composite action. The logic lives in `scripts/*.sh`, which are shellchecked and called from `action.yml`.

## Consequences

- There's nothing to build or bundle, and the scripts can be run and tested outside Actions.
- There's no post step, so the action can't stop the emulator or upload its log at job end. That's acceptable: the runner kills leftover processes when the job finishes, and the `log-file` output lets users upload the log themselves.
- The tool-cache layout (`<tool>/<version>/<arch>` plus a `.complete` marker) is reimplemented in bash instead of coming from `@actions/tool-cache`.
