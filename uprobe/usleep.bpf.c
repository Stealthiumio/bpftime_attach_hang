#define BPF_NO_GLOBAL_DATA
#include <vmlinux.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

SEC("uprobe/libc.so.6:usleep")
int do_count(struct pt_regs *ctx)
{
	u32 pid = bpf_get_current_pid_tgid() >> 32;

	bpf_printk("usleep called from pid %d\n", pid);

	return 0;
}

char LICENSE[] SEC("license") = "GPL";
