#!/usr/bin/env bash
set -euo pipefail
IFACE="${IFACE:-eth0}"

sudo tc filter del dev "$IFACE" ingress 2>/dev/null || true
sudo tc qdisc del dev "$IFACE" clsact 2>/dev/null || true
echo "Cleaned TC hooks on $IFACE"
