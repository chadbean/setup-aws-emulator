#!/usr/bin/env bash
# Starts aws-emulator in the background, waits until it is ready, and exports
# the client environment for later steps.
#
# Inputs (env): EMULATOR_PATH, INPUT_PORT, INPUT_AUTH, INPUT_IDLE_TIMEOUT,
#   INPUT_WAIT_TIMEOUT, INPUT_TELEMETRY, INPUT_EXPORT_ENV
set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_commands curl

bin="${EMULATOR_PATH:?EMULATOR_PATH is required}/bin/aws-emulator"
port="${INPUT_PORT:-9297}"
auth="$(echo "${INPUT_AUTH:-on}" | tr '[:upper:]' '[:lower:]')"
idle_timeout="${INPUT_IDLE_TIMEOUT:-}"
wait_timeout="${INPUT_WAIT_TIMEOUT:-60}"
telemetry="$(bool_input telemetry "${INPUT_TELEMETRY:-false}")"
export_env="$(bool_input export-env "${INPUT_EXPORT_ENV:-true}")"

if ! [[ "$port" =~ ^[0-9]+$ ]] || ((10#$port < 1 || 10#$port > 65535)); then
  fail "Input 'port' must be between 1 and 65535, got '$port'."
fi
port=$((10#$port)) # drop leading zeros so paths and URLs match the real port
[[ "$auth" == on || "$auth" == off ]] ||
  fail "Input 'auth' must be 'on' or 'off', got '${INPUT_AUTH}'."
[[ -z "$idle_timeout" || "$idle_timeout" =~ ^[0-9]+$ ]] ||
  fail "Input 'idle-timeout' must be a number of seconds, got '$idle_timeout'."
[[ "$wait_timeout" =~ ^[0-9]+$ ]] ||
  fail "Input 'wait-timeout' must be a number of seconds, got '$wait_timeout'."

args=(--port "$port" --auth "$auth")
[[ "$telemetry" == false ]] && args+=(--telemetry off)
[[ -n "$idle_timeout" ]] && args+=(--idle-timeout "$idle_timeout")

state_dir="$HOME/.aws/emulator/$port"
ca_file="$state_dir/ca.pem"
endpoint="https://127.0.0.1:$port"
log_file="${RUNNER_TEMP:-/tmp}/aws-emulator-$port.log"

print_log() {
  echo "::group::aws-emulator log ($log_file)"
  cat "$log_file" || true
  echo "::endgroup::"
}

# Otherwise the readiness check below would be answered by the old process.
if curl -fsSk --max-time 5 "$endpoint/__admin/health" >/dev/null 2>&1; then
  fail "Something is already serving on port $port. Stop it or choose another 'port'."
fi

# An earlier call in this job may have exported EMULATOR_TELEMETRY=off.
[[ "$telemetry" == true ]] && unset EMULATOR_TELEMETRY

info "Starting: $bin ${args[*]}"
nohup "$bin" "${args[@]}" >"$log_file" 2>&1 </dev/null &
pid=$!

deadline=$((SECONDS + wait_timeout))
while true; do
  # Check liveness first so a process that died can't pass on someone else's port.
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" && code=0 || code=$?
    print_log
    fail "aws-emulator exited with code $code before it was ready."
  fi
  if [[ -f "$ca_file" ]] && curl -fsS --cacert "$ca_file" "$endpoint/__admin/health" >/dev/null 2>&1; then
    break
  fi
  if ((SECONDS >= deadline)); then
    print_log
    kill "$pid" 2>/dev/null || true
    fail "aws-emulator was not ready at $endpoint within ${wait_timeout}s."
  fi
  sleep 1
done
info "aws-emulator is ready at $endpoint (pid $pid)"

set_output endpoint-url "$endpoint"
set_output ca-file "$ca_file"
set_output credentials-file "$state_dir/emulator_credentials"
set_output config-file "$state_dir/config"
set_output pid "$pid"
set_output log-file "$log_file"

if [[ "$export_env" == true ]]; then
  set_env AWS_ENDPOINT_URL "$endpoint"
  set_env AWS_SHARED_CREDENTIALS_FILE "$state_dir/emulator_credentials"
  set_env AWS_CONFIG_FILE "$state_dir/config"
  set_env AWS_CA_BUNDLE "$ca_file"
  set_env AWS_REGION us-east-1
  set_env AWS_DEFAULT_REGION us-east-1
  set_env AWS_EC2_METADATA_DISABLED true
  set_env AWS_DISABLE_HOST_PREFIX_INJECTION true
  set_env NODE_EXTRA_CA_CERTS "$ca_file"

  for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE; do
    if [[ -n "${!var:-}" ]]; then
      warn "$var is set and takes precedence over the emulator's credentials file. Unset it in steps that should talk to the emulator."
    fi
  done
fi
