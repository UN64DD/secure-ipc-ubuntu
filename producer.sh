#!/usr/bin/env bash

# Ensure that exactly one FIFO path is provided
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <fifo_path>" >&2
    exit 1
fi

FIFO_PATH="$1"

# Verify that the supplied path is a FIFO
if [[ ! -p "$FIFO_PATH" ]]; then
    echo "Error: The specified path is not a FIFO." >&2
    exit 1
fi

# Print producer process information
echo "Producer started."
echo "Producer PID: $$"

# Send all records through one FIFO connection
{
    for i in {1..5}; do
        MESSAGE="JOB-$i"

        printf '%s\n' "$MESSAGE"
        echo "Sent: $MESSAGE" >&2
    done

    # Send termination marker
    printf '%s\n' "END"
    echo "Sent: END" >&2

} > "$FIFO_PATH"

echo "Producer completed."