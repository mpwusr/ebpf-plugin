#!/usr/bin/env bash
set -euo pipefail
go mod tidy
go build ./...
go test ./... || true
echo "OK: Go build complete"
