#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--credential-process" ]]; then
  shift
  exec python3 "$(dirname "$0")/aws-credential-process.py" "${AWS_CLI_LOGIN_PROFILE:-studyspace}" "${AWS_REGION:-ap-southeast-2}"
fi

if [[ "$#" -eq 0 ]]; then
  echo "Usage: AWS_PROFILE=studyspace $0 <terraform arguments...>" >&2
  exit 2
fi

AWS_PROFILE="${AWS_PROFILE:-studyspace}"
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"

for command in aws python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done
if ! command -v "$TERRAFORM_BIN" >/dev/null 2>&1; then
  printf 'Terraform executable not found: %s (set TERRAFORM_BIN to its path)\n' "$TERRAFORM_BIN" >&2
  exit 1
fi

TEMP_AWS_CONFIG="$(mktemp "${TMPDIR:-/tmp}/studyspace-aws-config.XXXXXX")"
cleanup() { rm -f "$TEMP_AWS_CONFIG"; }
trap cleanup EXIT

HELPER_PATH="$(cd "$(dirname "$0")" && pwd)/aws-credential-process.py"
cat >"$TEMP_AWS_CONFIG" <<EOF
[profile terraform-aws-bridge]
region = $AWS_REGION
credential_process = python3 "$HELPER_PATH" "$AWS_PROFILE" "$AWS_REGION"
EOF

env -u AWS_ACCESS_KEY_ID \
  -u AWS_SECRET_ACCESS_KEY \
  -u AWS_SESSION_TOKEN \
  -u AWS_PROFILE \
  -u AWS_DEFAULT_PROFILE \
  AWS_CONFIG_FILE="$TEMP_AWS_CONFIG" \
  AWS_PROFILE=terraform-aws-bridge \
  AWS_SDK_LOAD_CONFIG=1 \
  AWS_REGION="$AWS_REGION" \
  AWS_DEFAULT_REGION="$AWS_REGION" \
  "$TERRAFORM_BIN" "$@"
