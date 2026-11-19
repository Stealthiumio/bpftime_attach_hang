#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

#include "usleep.skel.h"

static volatile bool exiting = false;

static void sig_handler(int sig) { exiting = true; }

static int libbpf_print_fn(enum libbpf_print_level l, const char* format, va_list args) {
	return vfprintf(stderr, format, args);
}

int main(int argc, char** argv) {
	struct usleep_bpf* skel;
	int err;

	libbpf_set_print(libbpf_print_fn);

	signal(SIGINT, sig_handler);
	signal(SIGTERM, sig_handler);

	skel = usleep_bpf__open();
	if (!skel) {
		fprintf(stderr, "usleep_bpf__open failed\n");
		return 1;
	}

	err = usleep_bpf__load(skel);
	if (err) {
		fprintf(stderr, "usleep_bpf__load failed\n");
		goto cleanup;
	}
	LIBBPF_OPTS(bpf_uprobe_opts, attach_opts, .func_name = "usleep", .retprobe = false);
	struct bpf_link* attach =
		bpf_program__attach_uprobe_opts(skel->progs.do_count, -1, "libc.so.6", 0, &attach_opts);
	if (!attach) {
		fprintf(stderr, "bpf_program__attach_uprobe_opts failed\n");
		err = -1;
		goto cleanup;
	}
	while (!exiting) {
		sleep(1);
	}

cleanup:
	usleep_bpf__destroy(skel);
	return err < 0 ? -err : 0;
}
