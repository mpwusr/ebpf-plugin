CC ?= clang
CFLAGS := -O2 -g -Wall -Wextra -Werror

# libbpf-dev on Ubuntu provides pkg-config for libbpf
LIBBPF_CFLAGS  := $(shell pkg-config --cflags libbpf)
LIBBPF_LDFLAGS := $(shell pkg-config --libs libbpf)

all: tc_loader

tc_loader: tc_loader.c
	$(CC) $(CFLAGS) $(LIBBPF_CFLAGS) -o $@ $< $(LIBBPF_LDFLAGS)

clean:
	rm -f tc_loader
