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

# Print consumer process information
echo "Consumer started."
echo "Consumer PID: $$"

# Read messages from the FIFO
while IFS= read -r MESSAGE; do

    # Accept only the five expected job records
    if [[ "$MESSAGE" =~ ^JOB-[1-5]$ ]]; then
        echo "Received: $MESSAGE"

    elif [[ "$MESSAGE" == "END" ]]; then
        echo "Received END marker."
        echo "Consumer shutting down."
        exit 0

    else
        echo "Rejected invalid message: $MESSAGE"
    fi

done < "$FIFO_PATH"

echo "Error: FIFO closed before END was received." >&2
exit 1