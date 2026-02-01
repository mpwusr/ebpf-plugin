#!/usr/bin/env bash
set -euo pipefail
VM_NAME="${VM_NAME:-ebpf-dev}"
exec limactl shell "$VM_NAME"
