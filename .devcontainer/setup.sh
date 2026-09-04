#!/usr/bin/env bash
# One-time provisioning: Python dependencies.
#
# Deliberately exits 0 even on failure. A non-zero exit here aborts container
# creation and drops the Codespace into recovery mode, which hides the actual
# error; leaving the container up lets the install be retried and inspected.
set -uo pipefail

python3 -m pip install --upgrade pip || echo "⚠️  pip upgrade failed"

if python3 -m pip install -r requirements.txt; then
  echo "✓ dependencies installed"
else
  echo "⚠️  dependency install failed — retry with:"
  echo "    python3 -m pip install -r requirements.txt"
fi

exit 0
