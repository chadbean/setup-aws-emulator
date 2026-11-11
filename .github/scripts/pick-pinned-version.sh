#!/usr/bin/env bash
# Writes `pinned=<version>` to GITHUB_OUTPUT: the second-newest published
# version, so CI covers installing something other than latest.
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"

versions="$(list_versions)"
pinned="$(tail -n 2 <<<"$versions" | head -n 1)"
[[ -n "$pinned" ]] || { echo "::error::Could not pick a pinned version"; exit 1; }

echo "Pinned version: $pinned"
echo "pinned=$pinned" >>"$GITHUB_OUTPUT"
