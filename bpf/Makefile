CLANG ?= clang
CFLAGS := -O2 -g -target bpf -Wall -Werror

all:
	$(CLANG) $(CFLAGS) -c tc_counter.c -o tc_counter.o

clean:
	rm -f tc_counter.o
