#!/usr/bin/env bash
# Exercises a running emulator through the client environment the action exported.
#
# Env: REQUIRE_AWS_CLI=true fails if the AWS CLI is missing instead of
#   falling back to the health check only. REQUIRE_NODE=true does the same
#   for Node.js, which checks the exported NODE_EXTRA_CA_CERTS.
set -euo pipefail

: "${AWS_ENDPOINT_URL:?AWS_ENDPOINT_URL was not exported}"
: "${AWS_CA_BUNDLE:?AWS_CA_BUNDLE was not exported}"

echo "Health check: $AWS_ENDPOINT_URL/__admin/health"
curl -fsS --cacert "$AWS_CA_BUNDLE" "$AWS_ENDPOINT_URL/__admin/health"
echo

# Node ignores AWS_CA_BUNDLE; it trusts the emulator only via NODE_EXTRA_CA_CERTS.
node_get_health='
require("https")
  .get(process.env.AWS_ENDPOINT_URL + "/__admin/health", (res) => {
    if (res.statusCode !== 200) {
      console.error("HTTP " + res.statusCode);
      process.exit(1);
    }
    res.resume();
  })
  .on("error", (err) => {
    console.error(err.code || err.message);
    process.exit(1);
  });
'
if command -v node >/dev/null; then
  : "${NODE_EXTRA_CA_CERTS:?NODE_EXTRA_CA_CERTS was not exported}"
  echo "Node health check with NODE_EXTRA_CA_CERTS=$NODE_EXTRA_CA_CERTS"
  node -e "$node_get_health"
  # Without the variable the same request must fail, or the check above proves nothing.
  if env -u NODE_EXTRA_CA_CERTS node -e "$node_get_health" 2>/dev/null; then
    echo "::error::Node trusted the emulator without NODE_EXTRA_CA_CERTS; the check is not meaningful"
    exit 1
  fi
  echo "OK: Node trusts the emulator only with NODE_EXTRA_CA_CERTS"
elif [[ "${REQUIRE_NODE:-false}" == true ]]; then
  echo "::error::Node.js not found"
  exit 1
else
  echo "::notice::Node.js not found; skipped the NODE_EXTRA_CA_CERTS check"
fi

if ! command -v aws >/dev/null; then
  if [[ "${REQUIRE_AWS_CLI:-false}" == true ]]; then
    echo "::error::AWS CLI not found"
    exit 1
  fi
  echo "::notice::AWS CLI not found; ran the health check only"
  exit 0
fi

bucket="ci-bucket-$RANDOM"
aws sts get-caller-identity
aws s3 mb "s3://$bucket"
aws s3 ls | grep -F "$bucket"
echo "OK: STS and S3 calls succeeded"
