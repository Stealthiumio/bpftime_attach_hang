#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/prctl.h>
#include <time.h>
#include <unistd.h>

static void* idle(void* arg) {
	for (;;) usleep(100000);
	return NULL;
}

int main(int argc, char* argv[]) {
	size_t size = (argc > 1) ? strtoul(argv[1], NULL, 0) : 24;
	pthread_t t;
	size_t calls = 0;
	int i;

	prctl(PR_SET_PTRACER, PR_SET_PTRACER_ANY);
	pthread_create(&t, NULL, idle, NULL);

	for (;;) {
		for (i = 0; i != 40000000; i++) {
			void* volatile p = calloc(1, size);
			free(p);
		}
		calls += 40000000;
		fprintf(stderr, "done: %lu calloc calls of %zu bytes\n", calls, size);
	}

	return 0;
}
