//go:build darwin

package ebpf

import "fmt"

func AttachTCCounter(ifName string, bpffsPath string) error {
	return fmt.Errorf("eBPF attach requires Linux kernel")
}
func DetachTC(ifName string) error { return nil }
