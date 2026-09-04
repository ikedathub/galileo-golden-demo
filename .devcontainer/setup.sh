#!/usr/bin/env bash
# One-time provisioning: OS packages for `unstructured`, then Python deps.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends libmagic1
sudo rm -rf /var/lib/apt/lists/*

python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

echo "✓ dependencies installed"
