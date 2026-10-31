#!/bin/sh
# Railway mounts /nexus-data root-owned; Nexus runs as uid 200. Chown once, size the JVM from the
# cgroup limit (the JVM and Nexus's own defaults read the HOST's RAM), bind Jetty to $PORT, then drop
# privileges with su-exec so signals reach the JVM directly and Nexus shuts down cleanly on redeploy.
set -eu

DATA=/nexus-data
NEXUS_UID=200
NEXUS_GID=200

mkdir -p "$DATA"
owner="$(stat -c %u "$DATA")"
echo "railway-entrypoint: $DATA owner=$owner (want $NEXUS_UID)"
if [ "$owner" != "$NEXUS_UID" ]; then
  chown -R "$NEXUS_UID:$NEXUS_GID" "$DATA"
fi

# Container memory limit in MB: cgroup v2, then v1, then /proc/meminfo.
limit=""
if [ -r /sys/fs/cgroup/memory.max ]; then limit="$(cat /sys/fs/cgroup/memory.max)"; fi
if [ -z "$limit" ] || [ "$limit" = "max" ]; then
  if [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)"; fi
fi
host_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
host_mb=$((host_kb / 1024))
case "$limit" in
  ''|max) limit_mb="$host_mb" ;;
  *[!0-9]*) limit_mb="$host_mb" ;;
  *) limit_mb=$((limit / 1048576)) ;;
esac
[ "$limit_mb" -gt "$host_mb" ] && limit_mb="$host_mb"

# Heap 40% and direct memory 30% of the container, each capped at the 2703 MB Sonatype documents,
# heap floor 512 MB. NEXUS_HEAP_MB / NEXUS_DIRECT_MB override.
heap="${NEXUS_HEAP_MB:-$((limit_mb * 40 / 100))}"
direct="${NEXUS_DIRECT_MB:-$((limit_mb * 30 / 100))}"
[ "$heap" -gt 2703 ] && heap=2703
[ "$heap" -lt 512 ] && heap=512
[ "$direct" -gt 2703 ] && direct=2703
[ "$direct" -lt 256 ] && direct=256
echo "railway-entrypoint: container limit ${limit_mb} MB -> Xms=Xmx=${heap}m MaxDirectMemorySize=${direct}m, port ${PORT:-8081}"

export INSTALL4J_ADD_VM_PARAMS="-Xms${heap}m -Xmx${heap}m -XX:MaxDirectMemorySize=${direct}m -Djava.util.prefs.userRoot=${DATA}/javaprefs -Dapplication-host=:: -Dapplication-port=${PORT:-8081}"

if [ -z "${NEXUS_SECURITY_INITIAL_PASSWORD:-}" ]; then
  echo "railway-entrypoint: NEXUS_SECURITY_INITIAL_PASSWORD is unset; Nexus writes a random admin password to $DATA/admin.password on first boot"
fi

exec su-exec "$NEXUS_UID:$NEXUS_GID" "$@"
