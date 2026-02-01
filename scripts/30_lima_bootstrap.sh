#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap] Kernel: $(uname -r)"

sudo apt-get update

# Core deps (note: bpftool is handled separately below)
sudo apt-get install -y \
  git curl ca-certificates \
  clang llvm make \
  iproute2 \
  golang-go \
  libbpf-dev \
  "linux-headers-$(uname -r)" || true

sudo apt-get install -y \
  build-essential \
  linux-libc-dev \
  libc6-dev

# Install bpftool provider (Ubuntu: linux-tools-$(uname -r))
# Some images don't ship exact kernel tools packages, so we fallback to linux-tools-generic.
if ! command -v bpftool >/dev/null 2>&1; then
  echo "[bootstrap] Installing bpftool via linux-tools..."
  if sudo apt-get install -y linux-tools-common "linux-tools-$(uname -r)"; then
    :
  else
    echo "[bootstrap] Fallback: linux-tools-generic"
    sudo apt-get install -y linux-tools-common linux-tools-generic
  fi
fi

# Mount bpffs
if ! mount | grep -qE ' /sys/fs/bpf '; then
  echo "[bootstrap] Mounting bpffs at /sys/fs/bpf"
  sudo mount -t bpf bpf /sys/fs/bpf || true
fi

echo "[bootstrap] Tool versions:"
echo "  clang:   $(clang --version | head -n1)"
echo "  go:      $(go version)"
echo "  tc:      $(tc -V 2>&1 || true)"
echo "  bpftool: $(bpftool version 2>&1 || true)"
echo "  bpffs:   $(mount | grep -E ' /sys/fs/bpf ' || echo 'not mounted')"

