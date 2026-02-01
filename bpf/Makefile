CLANG ?= clang
CFLAGS := -O2 -g -target bpf -Wall -Werror \
  -I. \
  -I/usr/include/bpf \
  -Wno-macro-redefined

all: tc_counter.o

tc_counter.o: tc_counter.c vmlinux.h
	$(CLANG) $(CFLAGS) -c $< -o $@

vmlinux.h:
	bpftool btf dump file /sys/kernel/btf/vmlinux format c > $@

clean:
	rm -f tc_counter.o vmlinux.h

