#!/bin/bash
# usage: repro.sh [calloc size]
cd "$(dirname "$0")"
set -eou pipefail

size=${1:-24}
bpftime=bpftime/build/tools/cli/bpftime
trap 'kill -9 0' INT TERM EXIT

make -s

rm -f /dev/shm/bpftime_maps_shm
BPFTIME_LOG_OUTPUT=console "$bpftime" load uprobe/usleep &
loader=$!
sleep 2

echo starting target
./target "$size" &
target=$!
sleep 1

echo attaching
rc=0
"$bpftime" attach "$target" || rc=$?
echo "bpftime attach returned $rc"

echo "main thread: $(grep State /proc/$target/task/$target/status | cut -f2), wchan $(cat /proc/$target/task/$target/wchan)"
if [ "$rc" != 0 ]; then
  timeout -s KILL 30 gdb -q -batch -p "$target" -ex "thread 1" -ex "bt full" 2>&1 | grep -E "^#" || true
fi

while kill -0 "$target" 2>/dev/null; do
  echo "main thread cpu ticks: $(awk '{print $14+$15}' /proc/$target/task/$target/stat 2>/dev/null)"
  sleep 1
done &

wait "$target"
kill "$loader"
trap - INT TERM EXIT
