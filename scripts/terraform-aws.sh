#!/usr/bin/env bash
set -euo pipefail

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

python3 - "$AWS_PROFILE" "$AWS_REGION" "$TERRAFORM_BIN" "$@" <<'PY'
import json
import os
import subprocess
import sys

profile, region, terraform_bin, *terraform_args = sys.argv[1:]
if not terraform_args:
    raise SystemExit("Pass Terraform arguments, for example: plan -out=studyspace.tfplan")

result = subprocess.run(
    ["aws", "configure", "export-credentials", "--profile", profile, "--format", "process"],
    check=False,
    capture_output=True,
    text=True,
)
if result.returncode:
    sys.stderr.write(result.stderr)
    raise SystemExit(result.returncode)

credentials = json.loads(result.stdout)
env = os.environ.copy()
env.pop("AWS_PROFILE", None)
env.pop("AWS_DEFAULT_PROFILE", None)
env.update(
    AWS_ACCESS_KEY_ID=credentials["AccessKeyId"],
    AWS_SECRET_ACCESS_KEY=credentials["SecretAccessKey"],
    AWS_SESSION_TOKEN=credentials["SessionToken"],
    AWS_REGION=region,
    AWS_DEFAULT_REGION=region,
)
raise SystemExit(
    subprocess.run(
        [terraform_bin, *terraform_args],
        env=env,
        check=False,
    ).returncode
)
PY
