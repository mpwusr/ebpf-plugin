#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

struct {
  __uint(type, BPF_MAP_TYPE_ARRAY);
  __uint(max_entries, 2);
  __type(key, __u32);
  __type(value, __u64);
} counter SEC(".maps");

static __always_inline void inc(__u32 key) {
  __u64 *val = bpf_map_lookup_elem(&counter, &key);
  if (val) __sync_fetch_and_add(val, 1);
}

SEC("tc/ingress")
int tc_ingress(struct __sk_buff *skb) {
  inc(0);
  return 0;
}

SEC("tc/egress")
int tc_egress(struct __sk_buff *skb) {
  inc(1);
  return 0;
}

char LICENSE[] SEC("license") = "GPL";
