// loader/tc_loader.c
#define _GNU_SOURCE
#include <errno.h>
#include <net/if.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>

#ifndef BPF_TC_F_REPLACE
#define BPF_TC_F_REPLACE (1U << 0)
#endif

static volatile sig_atomic_t g_stop = 0;

static void on_sigint(int sig) {
  (void)sig;
  g_stop = 1;
}

static void die(const char *msg) {
  perror(msg);
  exit(1);
}

static int libbpf_print_fn(enum libbpf_print_level level,
                           const char *format, va_list args)
{
    /* Silence debug noise if you want */
    if (level == LIBBPF_DEBUG)
        return 0;

    return vfprintf(stderr, format, args);
}

static int ensure_dir(const char *path) {
  // naive "mkdir -p" for one level; good enough for /sys/fs/bpf/ebpf-plugin
  if (access(path, F_OK) == 0) return 0;
  if (mkdir(path, 0755) == 0) return 0;
  return -1;
}

static int attach_tc(int ifindex, int prog_fd, enum bpf_tc_attach_point ap, __u32 handle, __u32 priority) {
  DECLARE_LIBBPF_OPTS(bpf_tc_hook, hook,
                     .ifindex = ifindex,
                     .attach_point = ap);

  // create clsact hook (idempotent)
  int err = bpf_tc_hook_create(&hook);
  if (err && err != -EEXIST) {
    fprintf(stderr, "bpf_tc_hook_create failed: %d (%s)\n", err, strerror(-err));
    return err;
  }

  DECLARE_LIBBPF_OPTS(bpf_tc_opts, opts,
                      .handle = handle,
                      .priority = priority,
                      .prog_fd = prog_fd,
                      .flags = BPF_TC_F_REPLACE);

  err = bpf_tc_attach(&hook, &opts);
  if (err) {
    fprintf(stderr, "bpf_tc_attach failed: %d (%s)\n", err, strerror(-err));
    return err;
  }
  return 0;
}

static int detach_tc(int ifindex, enum bpf_tc_attach_point ap, __u32 handle, __u32 priority) {
  DECLARE_LIBBPF_OPTS(bpf_tc_hook, hook,
                     .ifindex = ifindex,
                     .attach_point = ap);

  DECLARE_LIBBPF_OPTS(bpf_tc_opts, opts,
                      .handle = handle,
                      .priority = priority);

  int err = bpf_tc_detach(&hook, &opts);
  if (err && err != -ENOENT) {
    fprintf(stderr, "bpf_tc_detach failed: %d (%s)\n", err, strerror(-err));
    return err;
  }
  return 0;
}

int main(int argc, char **argv) {
  (void)argc;
  (void)argv;
  const char *iface = getenv("IFACE");
  const char *obj_path = getenv("BPF_OBJ");
  const char *pin_dir = getenv("PIN_DIR");

  if (!iface) iface = "eth0";
  if (!obj_path) obj_path = "./tc_counter.o";
  if (!pin_dir) pin_dir = "/sys/fs/bpf/ebpf-plugin";

  int ifindex = if_nametoindex(iface);
  if (ifindex == 0) {
    fprintf(stderr, "if_nametoindex(%s) failed\n", iface);
    return 2;
  }

  libbpf_set_print(libbpf_print_fn);

  struct bpf_object_open_opts open_opts = {};
  struct bpf_object *obj = bpf_object__open_file(obj_path, &open_opts);
  if (!obj) die("bpf_object__open_file");

  // load object once => maps created once => shared by both programs
  int err = bpf_object__load(obj);
  if (err) {
    fprintf(stderr, "bpf_object__load failed: %d (%s)\n", err, strerror(-err));
    return 3;
  }

  // Optional: pin shared map for easy inspection
  struct bpf_map *counter = bpf_object__find_map_by_name(obj, "counter");
  if (!counter) {
    fprintf(stderr, "could not find map 'counter'\n");
    return 4;
  }

  if (ensure_dir(pin_dir) != 0) {
    fprintf(stderr, "failed to create pin dir %s: %s\n", pin_dir, strerror(errno));
    return 5;
  }

  char pin_path[512];
  snprintf(pin_path, sizeof(pin_path), "%s/counter", pin_dir);
  // pin is idempotent-ish: if it exists, libbpf will error; we’ll unlink and repin.
  unlink(pin_path);
  err = bpf_map__pin(counter, pin_path);
  if (err) {
    fprintf(stderr, "bpf_map__pin(%s) failed: %d\n", pin_path, err);
    return 6;
  }

  struct bpf_program *p_ing = bpf_object__find_program_by_name(obj, "tc_ingress");
  struct bpf_program *p_egr = bpf_object__find_program_by_name(obj, "tc_egress");
  if (!p_ing || !p_egr) {
    fprintf(stderr, "could not find programs tc_ingress/tc_egress\n");
    return 7;
  }

  int fd_ing = bpf_program__fd(p_ing);
  int fd_egr = bpf_program__fd(p_egr);
  if (fd_ing < 0 || fd_egr < 0) {
    fprintf(stderr, "bad program fds: ingress=%d egress=%d\n", fd_ing, fd_egr);
    return 8;
  }

  // Choose deterministic handle/priority so detach works
  const __u32 HANDLE = 0x1;
  const __u32 PRIO_ING = 1;
  const __u32 PRIO_EGR = 1;

  err = attach_tc(ifindex, fd_ing, BPF_TC_INGRESS, HANDLE, PRIO_ING);
  if (err) return 9;
  err = attach_tc(ifindex, fd_egr, BPF_TC_EGRESS,  HANDLE, PRIO_EGR);
  if (err) return 10;

  printf("attached OK\n");
  printf("  iface=%s (ifindex=%d)\n", iface, ifindex);
  printf("  obj=%s\n", obj_path);
  printf("  pinned map: %s\n", pin_path);
  printf("press Ctrl-C to detach and exit\n");

  signal(SIGINT, on_sigint);
  signal(SIGTERM, on_sigint);

  while (!g_stop) sleep(1);

  printf("\nDetaching...\n");
  detach_tc(ifindex, BPF_TC_INGRESS, HANDLE, PRIO_ING);
  detach_tc(ifindex, BPF_TC_EGRESS,  HANDLE, PRIO_EGR);

  // keep pin so you can inspect after exit; uncomment to remove:
  // unlink(pin_path);

  bpf_object__close(obj);
  printf("done\n");
  return 0;
}
