#!/usr/bin/env bash
set -euo pipefail

command -v limactl >/dev/null || { echo "Missing limactl. Install with: brew install lima"; exit 1; }

echo "OK: limactl $(limactl --version || true)"
