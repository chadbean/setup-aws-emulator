#!/usr/bin/env bash
# Points the major tag (e.g. v1) at a release tag (e.g. v1.2.3) and pushes it.
#
# Usage: move-major-tag.sh <release-tag>
set -euo pipefail

release_tag="$1"
[[ "$release_tag" =~ ^v([0-9]+)\.[0-9]+\.[0-9]+$ ]] || {
  echo "::error::Expected a tag like v1.2.3, got '$release_tag'"
  exit 1
}
major_tag="v${BASH_REMATCH[1]}"

git fetch --tags --force origin
git tag -f "$major_tag" "$release_tag^{commit}"
git push -f origin "refs/tags/$major_tag"
echo "Moved $major_tag to $release_tag"
