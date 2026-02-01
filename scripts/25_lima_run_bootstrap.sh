#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-ebpf-dev}"
REPO_URL="${REPO_URL:-https://github.com/mpwusr/ebpf-plugin.git}"
VM_REPO_DIR="${VM_REPO_DIR:-\$HOME/ebpf-plugin}"

limactl shell "$VM_NAME" -- bash -lc "
  set -euo pipefail

  # Ensure git exists (minimal bootstrap)
  if ! command -v git >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y git
  fi

  if [ ! -d $VM_REPO_DIR/.git ]; then
    echo '[vm] Cloning repo into $VM_REPO_DIR'
    git clone $REPO_URL $VM_REPO_DIR
  else
    echo '[vm] Updating repo in $VM_REPO_DIR'
    git -C $VM_REPO_DIR pull --ff-only || true
  fi

  cd $VM_REPO_DIR
  chmod +x scripts/30_lima_bootstrap.sh || true
  ./scripts/30_lima_bootstrap.sh
"
