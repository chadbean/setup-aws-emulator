# 2. Linux only, installed by extracting the .deb

Date: 2026-11-11

## Status

Accepted

## Context

aws-emulator runs natively only on Linux (x86_64 and aarch64). AWS ships it as `.deb` and `.rpm` packages on `downloads.aws.com`, with a GPG `.sig` next to each, and doesn't attach binaries to GitHub releases. On macOS and Windows the only option is a self-built Docker image. GitHub's macOS runners have no Docker, and Windows runners run Windows containers.

The `.deb` holds a single relocatable file, `/opt/aws-emulator/bin/aws-emulator`. Its `postinst` only creates the `/usr/bin` symlink.

The options were:
- `sudo dpkg -i`
- a Docker fallback for macOS and Windows
- extracting the package ourselves

## Decision

- Support Linux runners only, and fail fast elsewhere with a clear message.
- Install by extracting the `.deb` (`dpkg-deb -x`, or `ar` + `tar` when `dpkg-deb` is missing) into the runner tool cache. Skip `dpkg -i`.

## Consequences

- It needs no sudo, so it works in containers without sudo, on self-hosted runners and on non-Debian Linux.
- It caches the same way `setup-go` does on self-hosted runners.
- The action relies on the package staying relocatable. If upstream adds files or install-time setup, the extraction step has to follow.
- macOS and Windows users get no support. Adding a Docker-based path later would be a separate decision.
