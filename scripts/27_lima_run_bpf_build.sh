#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-ebpf-dev}"
VM_REPO_DIR="${VM_REPO_DIR:-$HOME/ebpf-plugin}"

# VM-side settings
IFACE="${IFACE:-eth0}"
PIN_DIR="${PIN_DIR:-/sys/fs/bpf/ebpf-plugin}"
PIN_MAP="${PIN_MAP:-$PIN_DIR/counter}"
BPF_OBJ_REL="${BPF_OBJ_REL:-bpf/tc_counter.o}"      # relative to repo root inside VM
LOADER_BIN_REL="${LOADER_BIN_REL:-loader/tc_loader}" # relative to repo root inside VM

limactl shell "$VM_NAME" -- bash -lc "
  set -euo pipefail
  export GOTOOLCHAIN=local

  echo '[vm] repo dir: $VM_REPO_DIR'
  echo '[vm] iface:    $IFACE'
  echo '[vm] pin dir:  $PIN_DIR'
  echo '[vm] pin map:  $PIN_MAP'

  #
  # 1) Build eBPF object in bpf/
  #
  cd $VM_REPO_DIR/bpf
  echo
  echo '[bpf] pwd:' \$(pwd)
  echo '[bpf] files:'
  ls -la

  # Generate kernel-specific vmlinux.h inside the VM
  # (You can keep the file, but regenerate if you want by deleting it)
  if [ ! -f vmlinux.h ]; then
    echo '[bpf] Generating vmlinux.h from /sys/kernel/btf/vmlinux'
    bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
  else
    echo '[bpf] vmlinux.h already exists (skipping)'
  fi

  make clean || true
  make

  echo
  echo '[bpf] built object:'
  ls -la tc_counter.o
  file tc_counter.o || true

  #
  # 2) Build loader in loader/
  #
  cd $VM_REPO_DIR/loader
  echo
  echo '[loader] pwd:' \$(pwd)
  echo '[loader] files:'
  ls -la

  make clean || true
  make

  if [ ! -x ./${LOADER_BIN_REL##*/} ]; then
    echo '[loader] ERROR: expected loader binary not found/executable: ./${LOADER_BIN_REL##*/}'
    echo '[loader] Hint: ensure loader/Makefile outputs tc_loader'
    exit 1
  fi

  echo
  echo '[loader] built binary:'
  ls -la ./${LOADER_BIN_REL##*/}
  file ./${LOADER_BIN_REL##*/} || true

  #
  # 3) Hard reset old attachments + pinned map (idempotent)
  #
  echo
  echo '[tc] resetting clsact + pinned map (idempotent)'
  sudo tc qdisc del dev \"$IFACE\" clsact 2>/dev/null || true
  sudo rm -f \"$PIN_MAP\" 2>/dev/null || true
  sudo mkdir -p \"$PIN_DIR\"

  #
  # 4) Run loader (loads object ONCE and attaches ingress+egress => shared map)
  #
  echo
  echo '[tc] running loader (shared map path)'
  sudo IFACE=\"$IFACE\" \\
       PIN_DIR=\"$PIN_DIR\" \\
       BPF_OBJ=\"$VM_REPO_DIR/$BPF_OBJ_REL\" \\
       ./${
         LOADER_BIN_REL##*/
       } \\
       >/tmp/tc_loader.log 2>&1 &

  LOADER_PID=\$!
  echo \"[tc] loader pid: \$LOADER_PID\"
  sleep 1

  echo
  echo '[tc] loader log (first 200 lines):'
  sed -n '1,200p' /tmp/tc_loader.log || true

  echo
  echo '[tc] tc filters now:'
  echo '--- ingress ---'
  sudo tc filter show dev \"$IFACE\" ingress || true
  echo '--- egress ---'
  sudo tc filter show dev \"$IFACE\" egress || true

  echo
  echo '[map] pinned counter map (before traffic):'
  sudo bpftool map show pinned \"$PIN_MAP\" || true
  sudo bpftool map dump pinned \"$PIN_MAP\" || true

  #
  # 5) Generate traffic and show increments
  #
  echo
  echo '[traffic] generating traffic...'
  ping -c 5 1.1.1.1 >/dev/null 2>&1 || true
  curl -sS https://example.com >/dev/null 2>&1 || true

  echo
  echo '[map] pinned counter map (after traffic):'
  sudo bpftool map dump pinned \"$PIN_MAP\" || true

  #
  # 6) Leave loader running by default (so attachments stay alive)
  #    If you want the script to stop it automatically, uncomment kill block below.
  #
  echo
  echo \"[tc] loader is running in background (pid=\$LOADER_PID).\"
  echo \"[tc] To stop + detach: sudo kill -INT \$LOADER_PID\"
  echo \"[tc] Log: /tmp/tc_loader.log\"

  # Uncomment if you want auto-detach at end of script:
  # echo '[tc] stopping loader (auto-detach)'
  # sudo kill -INT \$LOADER_PID || true
  # sleep 1
  # echo '[tc] after detach:'
  # sudo tc filter show dev \"$IFACE\" ingress || true
  # sudo tc filter show dev \"$IFACE\" egress || true
"
