#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-ebpf-dev}"
VM_REPO_DIR="${VM_REPO_DIR:-\$HOME/ebpf-plugin}"

limactl shell "$VM_NAME" -- bash -lc "
  set -euo pipefail
  cd $VM_REPO_DIR
  go mod tidy
  go build ./...
  go test ./... || true
  echo '[vm] Build complete'
"