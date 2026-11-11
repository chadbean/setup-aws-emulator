#!/usr/bin/env bash
# Shared helpers for the setup-aws-emulator action scripts.

# shellcheck disable=SC2034 # used by the scripts that source this file
DOWNLOAD_BASE="https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS"
# shellcheck disable=SC2034
GPG_KEY_URL="https://downloads.aws.com/keys/gpg/current.asc"
# shellcheck disable=SC2034
GPG_FINGERPRINT="98BCF336A3BE53B734E967C52E5BF49BD940F624"

info() { echo "$*"; }
warn() { echo "::warning title=setup-aws-emulator::$*" >&2; }
fail() {
  echo "::error title=setup-aws-emulator::$*" >&2
  exit 1
}

# Lowercases and trims a boolean-ish input; fails on anything else.
bool_input() {
  local name="$1" value
  value="$(echo "${2:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$value" in
    true | false) echo "$value" ;;
    *) fail "Input '$name' must be 'true' or 'false', got '$2'." ;;
  esac
}

require_linux() {
  if [[ "${RUNNER_OS:-$(uname -s)}" != "Linux" ]]; then
    fail "aws-emulator runs natively only on Linux; this runner is ${RUNNER_OS:-$(uname -s)}. Use an ubuntu-* runner."
  fi
}

# Maps the runner architecture to the Debian architecture used in package names.
deb_arch() {
  local arch="${RUNNER_ARCH:-$(uname -m)}"
  case "$arch" in
    X64 | x86_64 | amd64) echo "amd64" ;;
    ARM64 | aarch64 | arm64) echo "arm64" ;;
    *) fail "Unsupported architecture '$arch'. aws-emulator ships for x64 and arm64 only." ;;
  esac
}

# Fails listing every missing command. Each argument is a command name, or
# several names joined by '|' when any one of them will do.
require_commands() {
  local missing=() spec alt found
  for spec in "$@"; do
    found=false
    IFS='|' read -ra alts <<<"$spec"
    for alt in "${alts[@]}"; do
      if command -v "$alt" >/dev/null 2>&1; then
        found=true
        break
      fi
    done
    [[ "$found" == true ]] || missing+=("${spec//|/ or }")
  done
  if ((${#missing[@]} > 0)); then
    fail "Missing required tools: ${missing[*]}. Install them before this step; the action does not install system packages."
  fi
}

# Upstream lists versions in a 4-part form (1.0.322.1) but package URLs use the
# first three parts (1.0.322). Prints the 3-part form of every listed version.
# Tolerates whitespace in the JSON; prints nothing if the fetch or parse fails.
list_versions() {
  curl -fsSL --retry 3 "$DOWNLOAD_BASE/versions.json" |
    grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' |
    sed -E 's/.*"([^"]*)"$/\1/' |
    cut -d. -f1-3 |
    sort -uV || true
}

set_output() { echo "$1=$2" >>"$GITHUB_OUTPUT"; }
set_env() { echo "$1=$2" >>"$GITHUB_ENV"; }
