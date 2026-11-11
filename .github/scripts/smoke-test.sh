#!/usr/bin/env bash
# Exercises a running emulator through the client environment the action exported.
#
# Env: REQUIRE_AWS_CLI=true fails if the AWS CLI is missing instead of
#   falling back to the health check only.
set -euo pipefail

: "${AWS_ENDPOINT_URL:?AWS_ENDPOINT_URL was not exported}"
: "${AWS_CA_BUNDLE:?AWS_CA_BUNDLE was not exported}"

echo "Health check: $AWS_ENDPOINT_URL/__admin/health"
curl -fsS --cacert "$AWS_CA_BUNDLE" "$AWS_ENDPOINT_URL/__admin/health"
echo

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
