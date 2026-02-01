CLANG ?= clang
ARCH := $(shell uname -m | sed 's/x86_64/x86/' | sed 's/aarch64/arm64/' | sed 's/armv7l/arm/')
KERNEL_RELEASE := $(shell uname -r)

INCLUDES := \
  -I/usr/include \
  -I/usr/include/$(ARCH)-linux-gnu \
  -I/usr/src/linux-headers-$(KERNEL_RELEASE)/include \
  -I/usr/src/linux-headers-$(KERNEL_RELEASE)/include/uapi \
  -I/usr/src/linux-headers-$(KERNEL_RELEASE)/include/generated/uapi \
  -I/usr/src/linux-headers-$(KERNEL_RELEASE)/arch/$(ARCH)/include \
  -I/usr/src/linux-headers-$(KERNEL_RELEASE)/arch/$(ARCH)/include/uapi \
  -I/usr/src/linux-headers-$(KERNEL_RELEASE)/arch/$(ARCH)/include/generated \
  -I/usr/src/linux-headers-$(KERNEL_RELEASE)/arch/$(ARCH)/include/generated/uapi

CFLAGS := -O2 -g -target bpf -Wall -Werror $(INCLUDES)

all:
	$(CLANG) $(CFLAGS) -c tc_counter.c -o tc_counter.o

clean:
	rm -f tc_counter.o
