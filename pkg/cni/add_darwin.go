//go:build darwin

package cni

import (
	"fmt"
	"github.com/containernetworking/cni/pkg/skel"
)

func CmdAdd(args *skel.CmdArgs) error   { return fmt.Errorf("my CNI runs on Linux only") }
func CmdDel(args *skel.CmdArgs) error   { return nil }
func CmdCheck(args *skel.CmdArgs) error { return nil }
func CmdVersion() error                 { return nil }
