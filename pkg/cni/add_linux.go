package cni

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/containernetworking/cni/pkg/skel"
	cnitypes "github.com/containernetworking/cni/pkg/types"
	current "github.com/containernetworking/cni/pkg/types/100"
	"github.com/containernetworking/plugins/pkg/ipam"
	"github.com/containernetworking/plugins/pkg/ns"
	"github.com/vishvananda/netlink"

	"ebpf-plugin/pkg/ebpf"
)

type NetConf struct {
	cnitypes.NetConf
	Bridge string `json:"bridge,omitempty"`
	// Whether to attach TC eBPF program (default true)
	AttachEBPF *bool `json:"attachEbpf,omitempty"`
	// Path where pinned maps/programs go
	BPFFSPath string `json:"bpffsPath,omitempty"`
}

func defaultBool(ptr *bool, def bool) bool {
	if ptr == nil {
		return def
	}
	return *ptr
}

func CmdAdd(args *skel.CmdArgs) error {
	conf := &NetConf{}
	if err := json.Unmarshal(args.StdinData, conf); err != nil {
		return fmt.Errorf("parse netconf: %w", err)
	}
	attach := defaultBool(conf.AttachEBPF, true)
	if conf.BPFFSPath == "" {
		conf.BPFFSPath = "/sys/fs/bpf/myebpf-cni"
	}

	// 1) Run IPAM (uses whatever IPAM is in config: host-local, whereabouts, etc.)
	ipamResult, err := ipam.ExecAdd(conf.IPAM.Type, args.StdinData)
	if err != nil {
		return fmt.Errorf("ipam add: %w", err)
	}
	defer func() {
		// If we fail later, release IPAM allocation
		if err != nil {
			_ = ipam.ExecDel(conf.IPAM.Type, args.StdinData)
		}
	}()

	result, err := current.NewResultFromResult(ipamResult)
	if err != nil {
		return fmt.Errorf("convert ipam result: %w", err)
	}
	if len(result.IPs) == 0 {
		return fmt.Errorf("ipam returned no IPs")
	}

	// 2) Create veth pair: one end in container netns, other on host
	hostVethName := fmt.Sprintf("veth%s", args.ContainerID[:5])
	contVethName := "eth0"

	netns, err := ns.GetNS(args.Netns)
	if err != nil {
		return fmt.Errorf("open netns: %w", err)
	}
	defer netns.Close()

	var hostVeth netlink.Link

	err = netns.Do(func(_ ns.NetNS) error {
		la := netlink.NewLinkAttrs()
		la.Name = contVethName
		v := &netlink.Veth{
			LinkAttrs: la,
			PeerName:  hostVethName,
		}
		if err := netlink.LinkAdd(v); err != nil {
			return fmt.Errorf("add veth: %w", err)
		}

		contLink, err := netlink.LinkByName(contVethName)
		if err != nil {
			return fmt.Errorf("get cont link: %w", err)
		}
		peer, err := netlink.LinkByName(hostVethName)
		if err != nil {
			return fmt.Errorf("get host peer: %w", err)
		}
		hostVeth = peer

		// Bring up container interface
		if err := netlink.LinkSetUp(contLink); err != nil {
			return fmt.Errorf("set cont link up: %w", err)
		}

		// Assign IP to container interface
		ipn := result.IPs[0].Address // first IP
		addr := &netlink.Addr{IPNet: &net.IPNet{IP: ipn.IP, Mask: ipn.Mask}}
		if err := netlink.AddrAdd(contLink, addr); err != nil {
			return fmt.Errorf("addr add: %w", err)
		}

		// Default route via gateway if present
		if result.IPs[0].Gateway != nil {
			route := &netlink.Route{
				LinkIndex: contLink.Attrs().Index,
				Gw:        result.IPs[0].Gateway,
			}
			if err := netlink.RouteAdd(route); err != nil {
				// route may already exist depending on runtime
				_ = err
			}
		}

		return nil
	})
	if err != nil {
		return err
	}

	// 3) On host: bring host veth up
	if hostVeth == nil {
		// best-effort lookup
		hostVeth, _ = netlink.LinkByName(hostVethName)
	}
	if hostVeth != nil {
		_ = netlink.LinkSetUp(hostVeth)
	}

	// 4) Attach eBPF (TC ingress) to host veth (simple counter program)
	if attach && hostVeth != nil {
		if err := ebpf.AttachTCCounter(hostVeth.Attrs().Name, conf.BPFFSPath); err != nil {
			return fmt.Errorf("attach ebpf tc: %w", err)
		}
	}

	// 5) Return CNI result
	result.Interfaces = []*current.Interface{
		{
			Name:    contVethName,
			Sandbox: args.Netns,
		},
	}
	return cnitypes.PrintResult(result, conf.CNIVersion)
}

func CmdDel(args *skel.CmdArgs) error {
	conf := &NetConf{}
	_ = json.Unmarshal(args.StdinData, conf)
	if conf.BPFFSPath == "" {
		conf.BPFFSPath = "/sys/fs/bpf/myebpf-cni"
	}

	// best-effort cleanup
	_ = ipam.ExecDel(conf.IPAM.Type, args.StdinData)

	// Detach ebpf (best-effort)
	hostVethName := fmt.Sprintf("veth%s", args.ContainerID[:5])
	_ = ebpf.DetachTC(hostVethName)

	// Delete veth from container netns (deletes peer too)
	if args.Netns != "" {
		if netns, err := ns.GetNS(args.Netns); err == nil {
			_ = netns.Do(func(_ ns.NetNS) error {
				if l, err := netlink.LinkByName("eth0"); err == nil {
					_ = netlink.LinkDel(l)
				}
				return nil
			})
			netns.Close()
		}
	}
	return nil
}

func CmdCheck(args *skel.CmdArgs) error {
	// Minimal CHECK (optional for now)
	return nil
}
