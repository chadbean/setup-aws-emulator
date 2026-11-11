#!/usr/bin/env bash
# Installs aws-emulator into the runner tool cache and puts it on PATH.
#
# Inputs (env): INPUT_VERSION, INPUT_VERIFY_SIGNATURE, INPUT_TELEMETRY
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_linux
arch="$(deb_arch)"
start="$(bool_input start "${INPUT_START:-true}")"
verify="$(bool_input verify-signature "${INPUT_VERIFY_SIGNATURE:-true}")"
telemetry="$(bool_input telemetry "${INPUT_TELEMETRY:-false}")"
requested="$(echo "${INPUT_VERSION:-latest}" | tr -d '[:space:]')"
tool_cache="${RUNNER_TOOL_CACHE:-$HOME/.cache/setup-aws-emulator}"
temp_root="${RUNNER_TEMP:-$(mktemp -d)}"

normalise_version() {
  local v="${1#v}"
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] ||
    fail "Input 'version' must be 'latest' or a version like 1.0.322, got '$1'."
  echo "$v" | cut -d. -f1-3
}

if [[ "$requested" == "latest" ]]; then
  require_commands curl
  version="$(list_versions | tail -n 1)"
  [[ -n "$version" ]] || fail "Could not resolve the latest version from $DOWNLOAD_BASE/versions.json."
  info "Resolved 'latest' to $version"
else
  version="$(normalise_version "$requested")"
fi

version_dir="$tool_cache/aws-emulator/$version"
install_dir="$version_dir/$arch"
marker="$version_dir/$arch.complete"

if [[ -f "$marker" && -x "$install_dir/bin/aws-emulator" ]]; then
  info "Found aws-emulator $version ($arch) in the tool cache: $install_dir"
else
  required=(curl "dpkg-deb|ar" tar)
  command -v dpkg-deb >/dev/null 2>&1 || required+=(xz)
  [[ "$verify" == true ]] && required+=(gpg)
  require_commands "${required[@]}"

  SECONDS=0
  work="$(mktemp -d "$temp_root/aws-emulator-install.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
  package="aws-emulator_${version}-1_${arch}.deb"
  info "Downloading $DOWNLOAD_BASE/$package"
  # Download first rather than checking versions.json, which may not list
  # older versions that are still downloadable.
  http_code="$(curl -sSL --retry 3 -o "$work/$package" -w '%{http_code}' "$DOWNLOAD_BASE/$package")" || true
  case "$http_code" in
    200) ;;
    403 | 404) # S3/CloudFront often answers 403 for a missing object
      recent="$(list_versions | tail -n 5 | tr '\n' ' ')"
      fail "aws-emulator $version is not published (no $package).${recent:+ Recent versions: $recent}"
      ;;
    *) fail "Could not download $DOWNLOAD_BASE/$package (HTTP $http_code)." ;;
  esac

  if [[ "$verify" == true ]]; then
    curl -fsSL --retry 3 -o "$work/$package.sig" "$DOWNLOAD_BASE/$package.sig"
    curl -fsSL --retry 3 -o "$work/key.asc" "$GPG_KEY_URL"
    # Keep GNUPGHOME short: gpg-agent's socket lives inside it and Unix socket
    # paths are limited to ~104 bytes, which deep RUNNER_TEMP paths exceed.
    GNUPGHOME="$(mktemp -d)"
    export GNUPGHOME
    # Stop any gpg-agent/keyboxd started in GNUPGHOME before deleting it.
    trap 'gpgconf --kill all >/dev/null 2>&1 || true; rm -rf "$work" "$GNUPGHOME"' EXIT
    gpg --batch --quiet --import "$work/key.asc" ||
      fail "Could not import the AWS signing key from $GPG_KEY_URL."
    # Accept the signature only if it was made by the pinned primary key.
    status="$(gpg --batch --status-fd 1 --verify "$work/$package.sig" "$work/$package" 2>/dev/null || true)"
    if ! grep -E "^\[GNUPG:\] VALIDSIG .* $GPG_FINGERPRINT\$" <<<"$status" >/dev/null; then
      fail "Signature verification failed for $package. Expected a valid signature from key $GPG_FINGERPRINT."
    fi
    info "Verified signature from $GPG_FINGERPRINT"
  else
    warn "Skipping signature verification (verify-signature: false)."
  fi

  extract="$work/extract"
  mkdir -p "$extract"
  if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -x "$work/$package" "$extract"
  else
    (cd "$work" && ar x "$package")
    tar -xf "$work"/data.tar.* -C "$extract"
  fi
  [[ -x "$extract/opt/aws-emulator/bin/aws-emulator" ]] ||
    fail "Package $package did not contain opt/aws-emulator/bin/aws-emulator."

  rm -rf "$install_dir" "$marker"
  mkdir -p "$version_dir"
  mv "$extract/opt/aws-emulator" "$install_dir"
  touch "$marker"
  info "Installed aws-emulator $version ($arch) to $install_dir in ${SECONDS}s"
fi

echo "$install_dir/bin" >>"$GITHUB_PATH"
set_output version "$version"
set_output path "$install_dir"
# Validated here so action.yml can gate the start step on it.
set_output start "$start"

if [[ "$telemetry" == false ]]; then
  set_env EMULATOR_TELEMETRY off
  info "Telemetry disabled (EMULATOR_TELEMETRY=off)"
fi
