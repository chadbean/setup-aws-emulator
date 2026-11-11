#!/usr/bin/env bash
# Asserts the action installed the expected version on PATH with telemetry off.
#
# Usage: check-install.sh <expected-version> <reported-version>
#   expected-version: "latest" or a 3-part version
#   reported-version: the action's `version` output
set -euo pipefail

expected="$1" reported="$2"

command -v aws-emulator >/dev/null || { echo "::error::aws-emulator is not on PATH"; exit 1; }
echo "aws-emulator: $(command -v aws-emulator)"
aws-emulator -v

if [[ "$expected" != latest && "$reported" != "$expected" ]]; then
  echo "::error::Expected version $expected, action reported $reported"
  exit 1
fi
if [[ "${EMULATOR_TELEMETRY:-}" != off ]]; then
  echo "::error::Expected EMULATOR_TELEMETRY=off, got '${EMULATOR_TELEMETRY:-}'"
  exit 1
fi
echo "OK: version $reported, telemetry off"
