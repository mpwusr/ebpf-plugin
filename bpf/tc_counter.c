#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

struct {
  __uint(type, BPF_MAP_TYPE_ARRAY);
  __uint(max_entries, 1);
  __type(key, __u32);
  __type(value, __u64);
} counter SEC(".maps");

SEC("tc")
int tc_ingress(struct __sk_buff *skb) {
  __u32 key = 0;
  __u64 *val = bpf_map_lookup_elem(&counter, &key);
  if (val) {
    __sync_fetch_and_add(val, 1);
  }
  return 0; // allow packet
}

char LICENSE[] SEC("license") = "GPL";
