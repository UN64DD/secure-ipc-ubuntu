#!/usr/bin/env bash

# Exit on errors, undefined variables and failed commands in pipelines
set -Eeuo pipefail

# Restrict newly created files to the current user
umask 077

# Find the directory containing this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PRODUCER="$SCRIPT_DIR/producer.sh"
CONSUMER="$SCRIPT_DIR/consumer.sh"

# Verify that both scripts exist
if [[ ! -f "$PRODUCER" || ! -f "$CONSUMER" ]]; then
    echo "Error: producer.sh or consumer.sh is missing." >&2
    exit 1
fi

# Create a private temporary working directory
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/secure-ipc.XXXXXXXX")"
chmod 700 "$WORKDIR"

FIFO_PATH="$WORKDIR/jobs.fifo"
PRODUCER_LOG="$WORKDIR/producer.log"
CONSUMER_LOG="$WORKDIR/consumer.log"

CONSUMER_PID=""

# Clean up only resources created by this script
cleanup() {
    local exit_status=$?

    trap - EXIT INT TERM

    # Remove the FIFO only after the consumer has stopped
    if [[ -n "$CONSUMER_PID" ]]; then
        if kill -0 "$CONSUMER_PID" 2>/dev/null; then
            echo "Waiting for consumer to finish..."
            wait "$CONSUMER_PID" || exit_status=1
        fi
    fi

    rm -f -- "$FIFO_PATH"
    rm -f -- "$PRODUCER_LOG" "$CONSUMER_LOG"
    rmdir -- "$WORKDIR" 2>/dev/null || true

    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Create the named pipe with owner-only permissions
mkfifo -m 600 "$FIFO_PATH"

# Confirm FIFO type, ownership and permissions
if [[ ! -p "$FIFO_PATH" ]]; then
    echo "Error: IPC path is not a FIFO." >&2
    exit 1
fi

if [[ "$(stat -c '%U' -- "$FIFO_PATH")" != "$(id -un)" ]]; then
    echo "Error: FIFO is not owned by the current user." >&2
    exit 1
fi

if [[ "$(stat -c '%a' -- "$FIFO_PATH")" != "600" ]]; then
    echo "Error: FIFO permissions are not secure." >&2
    exit 1
fi

echo "=================================="
echo " Secure IPC Demonstration"
echo "=================================="
echo "Working directory: $WORKDIR"
echo "FIFO path: $FIFO_PATH"
echo "FIFO permissions: $(stat -c '%A (%a)' -- "$FIFO_PATH")"
echo

# Start consumer as a separate background process
"$CONSUMER" "$FIFO_PATH" > "$CONSUMER_LOG" 2>&1 &
CONSUMER_PID=$!

echo "Consumer PID: $CONSUMER_PID"

# Start producer as a separate process
if "$PRODUCER" "$FIFO_PATH" > "$PRODUCER_LOG" 2>&1; then
    echo "Producer completed successfully."
else
    echo "Error: Producer failed." >&2
    exit 1
fi

# Wait for consumer to finish
if wait "$CONSUMER_PID"; then
    echo "Consumer completed successfully."
    CONSUMER_PID=""
else
    echo "Error: Consumer failed." >&2
    CONSUMER_PID=""
    exit 1
fi

echo
echo "=================================="
echo " Producer Log"
echo "=================================="

# Display producer log with timestamps
while IFS= read -r line; do
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
done < "$PRODUCER_LOG"

echo
echo "=================================="
echo " Consumer Log"
echo "=================================="

# Display consumer log with timestamps
while IFS= read -r line; do
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
done < "$CONSUMER_LOG"

echo
echo "IPC demonstration completed."