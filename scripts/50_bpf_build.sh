#!/usr/bin/env bash
set -euo pipefail
cd bpf
make
ls -l tc_counter.o
echo "OK: BPF object built"
