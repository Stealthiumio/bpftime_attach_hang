# Repro script for `bpftime attach` w/ uprobe hanging the target process

The target process hangs when bpftime attaches during a glibc malloc call,
while the malloc arena lock is held. The included target.c is a malloc-heavy
program to make the reproduction simple, but the hang can happen to any
multithreaded processes doing malloc on the main thread.

Frida's injector bootstrapper calls pthread_create() on the main thread, which
internally needs to allocate a new stack and hence lock the glibc mem arena lock.
That lock is not recursive, and the allocation deadlocks.

The gdb bt full during the hang is:

```
#0  futex_wait (private=0, expected=2, futex_word=0x7f1bb4604ac0 <main_arena>) at ../sysdeps/nptl/futex-internal.h:146
#0  futex_wait (private=0, expected=2, futex_word=0x7f1bb4604ac0 <main_arena>) at ../sysdeps/nptl/futex-internal.h:146
#1  __GI___lll_lock_wait_private (futex=futex@entry=0x7f1bb4604ac0 <main_arena>) at ./nptl/lowlevellock.c:34
#2  0x00007f1bb44aec30 in __libc_calloc (n=<optimized out>, elem_size=<optimized out>) at ./malloc/malloc.c:3725
#3  0x00007f1bb480b59c in calloc (b=16, a=17) at ../include/rtld-malloc.h:44
#4  allocate_dtv (result=0x7f1bb3bfe6c0) at ../elf/dl-tls.c:370
#5  __GI__dl_allocate_tls (mem=mem@entry=0x7f1bb3bfe6c0) at ../elf/dl-tls.c:629
#6  0x00007f1bb449d6d7 in allocate_stack (stacksize=<synthetic pointer>, stack=<synthetic pointer>, pdp=<synthetic pointer>, attr=0x7ffc056acaa0) at ./nptl/allocatestack.c:429
#7  __pthread_create_2_1 (newthread=<optimized out>, attr=<optimized out>, start_routine=<optimized out>, arg=<optimized out>) at ./nptl/pthread_create.c:655
#8  0x0000000000000320 in ?? ()
#9  0x00007ffc056accd0 in ?? ()
#10 0x00007f1bb449cdda in __pthread_create_2_1 (newthread=<optimized out>, attr=<optimized out>, start_routine=<optimized out>, arg=<optimized out>) at ./nptl/pthread_create.c:898
#11 0x00007f1bb44ae95e in __libc_calloc (n=<optimized out>, elem_size=<optimized out>) at ./malloc/malloc.c:3754
#12 0x000055df288ec1a5 in main ()
```

`./repro.sh` builds & runs a simple malloc-heavy application then injects an uprobe
(for usleep, which does bpf_printk, but that's irrelevant). The usual outcome is

```
starting target
attaching
[...]
[2026-11-19 12:26:35][info][581245] Attach successfully
bpftime attach returned 0
main thread: R (running), wchan 0
main thread cpu ticks: 104
usleep called from pid 581236
usleep called from pid 581236
usleep called from pid 581236
usleep called from pid 581236
main thread cpu ticks: 205
[...]
```

occasionally the attach fails and the main thread of the target app is left
in a deadlocked state:

```
starting target
attaching
bpftime attach returned 1
main thread cpu ticks: 101
main thread cpu ticks: 101
main thread cpu ticks: 101
main thread cpu ticks: 101
main thread cpu ticks: 101
```

The gdb bt full is printed afterwards.
