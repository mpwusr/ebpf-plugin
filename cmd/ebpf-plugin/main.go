package main

import (
	"fmt"
	"os"

	"github.com/containernetworking/cni/pkg/skel"
	cniv "github.com/containernetworking/cni/pkg/version"

	"ebpf-plugin/pkg/cni"
)

func main() {
	skel.PluginMain(cni.CmdAdd, cni.CmdCheck, cni.CmdDel, cniv.All, "myebpf-cni v0.1")
}

func die(msg string, err error) {
	if err != nil {
		_, _ = fmt.Fprintf(os.Stderr, "%s: %v\n", msg, err)
	} else {
		_, _ = fmt.Fprintln(os.Stderr, msg)
	}
	os.Exit(1)
}
