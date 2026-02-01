#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-ebpf-dev}"
VM_REPO_DIR="${VM_REPO_DIR:-\$HOME/ebpf-plugin}"

limactl shell "$VM_NAME" -- bash -lc "
  set -euo pipefail
  export GOTOOLCHAIN=local

  cd $VM_REPO_DIR/bpf

  echo '[bpf] pwd:' \$(pwd)
  echo '[bpf] files:'
  ls -la

  # Generate kernel-specific vmlinux.h inside the VM (macOS won't have bpftool)
  if [ ! -f vmlinux.h ]; then
    echo '[bpf] Generating vmlinux.h from /sys/kernel/btf/vmlinux'
    bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
  else
    echo '[bpf] vmlinux.h already exists (skipping)'
  fi

  make clean || true
  make
"
