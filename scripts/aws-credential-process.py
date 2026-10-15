#!/usr/bin/env python3
"""Expose fresh AWS CLI login credentials to Terraform's credential_process."""

import os
import subprocess
import sys


profile, region = sys.argv[1:3]
env = os.environ.copy()
for key in ("AWS_CONFIG_FILE", "AWS_PROFILE", "AWS_DEFAULT_PROFILE"):
    env.pop(key, None)
env["AWS_REGION"] = region
env["AWS_DEFAULT_REGION"] = region

result = subprocess.run(
    ["aws", "configure", "export-credentials", "--profile", profile, "--format", "process"],
    check=False,
    capture_output=True,
    text=True,
    env=env,
)
if result.returncode:
    sys.stderr.write(result.stderr)
    raise SystemExit(result.returncode)

sys.stdout.write(result.stdout)
