#!/usr/bin/env bash
# Runs a command and asserts on its exit status and output.
#
# Usage: run-expect.sh --pass|--fail <expected-substring> <command> [args...]
set -euo pipefail

mode="$1" expected="$2"
shift 2

set +e
output="$("$@" 2>&1)"
code=$?
set -e
echo "$output"

case "$mode" in
  --pass) ((code == 0)) || { echo "::error::Expected success, got exit code $code"; exit 1; } ;;
  --fail) ((code != 0)) || { echo "::error::Expected failure, got exit code 0"; exit 1; } ;;
  *) echo "::error::Unknown mode '$mode'"; exit 2 ;;
esac

if ! grep -qF -- "$expected" <<<"$output"; then
  echo "::error::Output did not contain: $expected"
  exit 1
fi
echo "OK: exit code $code, output contained '$expected'"
