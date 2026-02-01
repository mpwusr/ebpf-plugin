#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-eth0}"

# Ensure clsact qdisc exists
sudo tc qdisc add dev "$IFACE" clsact 2>/dev/null || true

# Attach the program
sudo tc filter add dev "$IFACE" ingress bpf da obj bpf/tc_counter.o sec tc

echo "Attached to $IFACE ingress."
sudo tc filter show dev "$IFACE" ingress || true
