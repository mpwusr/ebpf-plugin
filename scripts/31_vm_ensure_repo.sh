#!/usr/bin/env bash
set -euo pipefail

# Where we'd like the repo to live inside the VM
VM_REPO_DIR="${VM_REPO_DIR:-$HOME/ebpf-plugin}"

# If the repo is mounted from macOS, use it
MAC_MOUNT_REPO="/Users/michaelwilliams/working/ebpf-plugin"

if [ -d "$MAC_MOUNT_REPO" ]; then
  echo "Found macOS-mounted repo at: $MAC_MOUNT_REPO"
  echo "$MAC_MOUNT_REPO"
  exit 0
fi

# Otherwise clone (or update) inside the VM
if [ ! -d "$VM_REPO_DIR/.git" ]; then
  echo "Repo not mounted; cloning into: $VM_REPO_DIR"
  git clone https://github.com/mpwusr/ebpf-plugin.git "$VM_REPO_DIR"
else
  echo "Repo already cloned; pulling latest in: $VM_REPO_DIR"
  git -C "$VM_REPO_DIR" pull --ff-only || true
fi

echo "$VM_REPO_DIR"
