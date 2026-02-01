#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-ebpf-dev}"
VM_REPO_DIR="${VM_REPO_DIR:-\$HOME/ebpf-plugin}"

limactl shell "$VM_NAME" -- bash -lc "
  set -euo pipefail
  cd $VM_REPO_DIR/bpf
  make
  ls -l tc_counter.o
  echo '[vm] BPF build complete'
"
