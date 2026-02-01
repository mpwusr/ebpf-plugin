#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-ebpf-dev}"
TEMPLATE="${TEMPLATE:-template://ubuntu-lts}"

if limactl list | awk '{print $1}' | grep -qx "$VM_NAME"; then
  echo "VM already exists: $VM_NAME"
else
  limactl start --name="$VM_NAME" "$TEMPLATE"
fi

limactl list
