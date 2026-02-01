#!/usr/bin/env bash
set -euo pipefail

echo "Interfaces:"
ip link show

echo "eBPF programs:"
sudo bpftool prog show || true

echo "eBPF maps:"
sudo bpftool map show || true

echo "Generate traffic:"
ping -c 3 8.8.8.8 || true

echo "Done."
