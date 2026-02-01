package ebpf

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cilium/ebpf"
	"github.com/cilium/ebpf/link"
)

type Objects struct {
	TcIngress *ebpf.Program `ebpf:"tc_ingress"`
	Counter   *ebpf.Map     `ebpf:"counter"`
}

var attachedLinks = map[string]link.Link{}

func AttachTCCounter(ifName string, bpffsPath string) error {
	// Ensure bpffs pin dir exists
	if err := os.MkdirAll(bpffsPath, 0755); err != nil {
		return fmt.Errorf("mkdir bpffsPath: %w", err)
	}

	spec, err := ebpf.LoadCollectionSpec("bpf/tc_counter.o")
	if err != nil {
		return fmt.Errorf("load spec: %w", err)
	}

	var objs Objects
	if err := spec.LoadAndAssign(&objs, nil); err != nil {
		return fmt.Errorf("load and assign: %w", err)
	}

	// Pin the map so we can inspect it
	mapPin := filepath.Join(bpffsPath, "counter")
	_ = objs.Counter.Pin(mapPin)

	// Attach TC ingress
	l, err := link.AttachTC(link.TCOptions{
		Interface:   ifName,
		AttachPoint: link.ingress, // note: in real code use correct constant in your version
		Program:     objs.TcIngress,
	})
	if err != nil {
		return fmt.Errorf("attach tc: %w", err)
	}
	attachedLinks[ifName] = l
	return nil
}

func DetachTC(ifName string) error {
	if l, ok := attachedLinks[ifName]; ok {
		_ = l.Close()
		delete(attachedLinks, ifName)
	}
	return nil
}
