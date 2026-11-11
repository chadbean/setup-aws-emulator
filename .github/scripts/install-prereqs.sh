#!/usr/bin/env bash
# Installs the action's prerequisites in a bare CI container (apt or dnf).
set -euo pipefail

if command -v apt-get >/dev/null; then
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends ca-certificates curl gpg
elif command -v dnf >/dev/null; then
  # No dpkg-deb on Fedora, so this exercises the `ar` extraction fallback.
  dnf install -y -q binutils ca-certificates curl gnupg2 tar xz
else
  echo "::error::No supported package manager found"
  exit 1
fi
