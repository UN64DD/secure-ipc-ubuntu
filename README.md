# Secure IPC in Ubuntu Using Bash (POSIX FIFO)

## 1) Project title and overview

**Project:** Secure IPC in Ubuntu Using Bash  
**Repository name:** `secure-ipc-ubuntu`

This project demonstrates secure **local Inter-Process Communication (IPC)** on Ubuntu/Linux using a **POSIX named pipe (FIFO)**. A Bash **producer** process sends a small set of job messages to a Bash **consumer** process through a FIFO. A wrapper script (`run_demo.sh`) creates a private temporary workspace, sets safe permissions, starts both processes, validates the IPC channel, and prints timestamped logs.

The focus is on:
- Clear producer/consumer separation
- Safe local IPC with FIFOs
- Practical Bash hardening (strict mode, permissions, validation, cleanup)

---

## 2) Problem statement and project objectives

### Problem statement
Processes often need to exchange data on the same machine. In simple classroom or lab scenarios, it is useful to show how two independent processes communicate through a kernel-managed channel while applying basic security practices (least privilege on files, validation, and controlled cleanup).

### Objectives
- Show a working example of **local IPC** using a **named pipe (FIFO)**.
- Separate responsibilities into **producer** and **consumer** scripts.
- Demonstrate **secure handling** of the FIFO and temporary files.
- Provide a **one-command demo** (`run_demo.sh`) that is easy to run and explain.
- Keep behavior **simple, predictable, and beginner-friendly**.

---

## 3) Explanation of IPC and POSIX named pipes (FIFO)

### What is IPC?
**Inter-Process Communication (IPC)** means ways for processes to exchange data or signals. On Linux, common IPC methods include pipes, FIFOs, sockets, shared memory, message queues, and signals. This project uses a **FIFO**, which is a file-system-visible IPC channel for byte streams.

### What is a POSIX named pipe (FIFO)?
A **FIFO** (First In, First Out), also called a **named pipe**, is a special file type created with `mkfifo`. Unlike regular files, a FIFO does **not** store data permanently on disk in the usual way; data written to it is passed through the kernel to readers.

Key points:
- The FIFO appears as a path in the filesystem (e.g., `/tmp/.../jobs.fifo`).
- One process opens it for **writing** (producer), another for **reading** (consumer).
- Readers/writers are synchronized by the kernel (a reader may block until data is available, depending on how it is opened/used).
- Data flows in order (FIFO behavior).

In this project:
- `producer.sh` writes messages into the FIFO.
- `consumer.sh` reads lines from the FIFO and validates them.

---

## 4) System architecture

### Components
1. **Producer process (`producer.sh`)**
   - Started by `run_demo.sh` (or manually with a FIFO path).
   - Verifies the provided path is a FIFO.
   - Sends 5 records: `JOB-1`, `JOB-2`, `JOB-3`, `JOB-4`, `JOB-5`
   - Sends a termination marker: `END`
   - Logs progress messages to **stderr** (so they do not mix with FIFO data on stdout).

2. **Consumer process (`consumer.sh`)**
   - Started by `run_demo.sh` in the background (or manually).
   - Verifies the provided path is a FIFO.
   - Reads lines from the FIFO.
   - Accepts only:
     - `JOB-1` through `JOB-5` (regex: `^JOB-[1-5]$`)
     - `END` (then prints shutdown message and exits successfully)
   - Any other message is **rejected** (printed) but does **not** stop the loop unless the stream ends.

3. **FIFO communication channel**
   - Created by `run_demo.sh` with `mkfifo -m 600`.
   - Path example (inside a private temp directory): `.../secure-ipc.XXXXXXXX/jobs.fifo`

4. **Linux kernel’s role in IPC**
   - The kernel implements the FIFO mechanism and buffers/coordinates data transfer between processes.
   - The kernel enforces filesystem permissions on the FIFO special file (read/write access depends on mode, owner, and process privileges).
   - Process scheduling determines when producer/consumer run; the FIFO provides the synchronization point for data exchange.

---

## 5) Project directory structure

```text
secure-ipc-ubuntu/
├── consumer.sh          # Consumer process (reads and validates messages)
├── docs/                # Documentation placeholders (optional)
│   ├── architecture.md
│   ├── security-design.md
│   └── testing.md
├── logs/                # Reserved folder (empty in repo)
├── producer.sh          # Producer process (writes JOB-1..JOB-5 + END)
├── README.md
├── run_demo.sh          # Orchestrator: creates secure temp dir + FIFO, runs demo
└── screenshots/         # Reserved folder (empty in repo)
```

> Note: `run_demo.sh` creates a temporary working directory at runtime (e.g., under `/tmp/secure-ipc.*`) and removes FIFO/log temp files during cleanup.

---

## 6) Technologies and tools used

- **OS:** Ubuntu/Linux (commands like `stat -c` are used in `run_demo.sh`)
- **Shell:** Bash (`#!/usr/bin/env bash`)
- **IPC mechanism:** POSIX FIFO via `mkfifo`
- **Core utilities:** `mktemp`, `chmod`, `stat`, `kill`, `wait`, `rm`, `rmdir`, `date`
- **Scripting features:** strict mode (`set -Eeuo pipefail`), `umask 077`, traps for cleanup

---

## 7) Explanation of each Bash script

### `producer.sh`
- **Input:** exactly one argument: `<fifo_path>`
- **Validation:** exits with an error if the argument count is wrong or the path is not a FIFO (`[[ ! -p ... ]]`).
- **Behavior:**
  - Prints `Producer started.` and `Producer PID: $$` to stdout.
  - Sends 5 lines to the FIFO: `JOB-1` through `JOB-5`.
  - Sends `END`.
  - Prints `Producer completed.` to stdout.
- **Notes:** informational/sent messages are also echoed to **stderr** in the script (e.g., `Sent: JOB-1`) to keep FIFO payload clean.

### `consumer.sh`
- **Input:** exactly one argument: `<fifo_path>`
- **Validation:** exits with an error if argument count is wrong or path is not a FIFO.
- **Behavior:**
  - Prints `Consumer started.` and `Consumer PID: $$`.
  - Reads lines from the FIFO.
  - If line matches `JOB-1`..`JOB-5`: prints `Received: <message>`
  - If line is `END`: prints `Received END marker.` and `Consumer shutting down.`, then exits `0`
  - Otherwise: prints `Rejected invalid message: <message>` (continues reading)
  - If the FIFO is closed before `END` is received: prints an error to stderr and exits `1`

### `run_demo.sh`
- **Safety flags:** `set -Eeuo pipefail`, `umask 077`
- **Checks:** ensures `producer.sh` and `consumer.sh` exist next to the script.
- **Workspace:** creates a private temp directory via `mktemp -d "${TMPDIR:-/tmp}/secure-ipc.XXXXXXXX"` and runs `chmod 700` on it.
- **FIFO:** creates FIFO at `$WORKDIR/jobs.fifo` with `mkfifo -m 600`.
- **Validations (Linux):**
  - Confirms it is a FIFO (`[[ ! -p ... ]]`)
  - Confirms owner is current user (`stat -c '%U'`)
  - Confirms permissions are `600` (`stat -c '%a'`)
- **Execution flow:**
  1. Starts `consumer.sh` in background, logs to `$WORKDIR/consumer.log`
  2. Runs `producer.sh`, logs to `$WORKDIR/producer.log`
  3. Waits for consumer process to finish
  4. Prints timestamped contents of both logs
- **Cleanup trap:** on exit/interrupt/termination removes FIFO and log files, then attempts to remove the temp directory.

---

## 8) Installation and prerequisites

### Prerequisites
- Ubuntu (or another Linux distro with similar tools)
- Bash
- Standard GNU coreutils (`mkfifo`, `stat`, `mktemp`, etc.)

### Install/check (example on Ubuntu)
```bash
bash --version
mkfifo --version | head -n 1
```

### Get the project
Clone your repository (replace the URL with your actual GitHub URL):

```bash
git clone <YOUR_GITHUB_REPO_URL>
cd secure-ipc-ubuntu
```

Make scripts executable (if needed):

```bash
chmod +x producer.sh consumer.sh run_demo.sh
```

---

## 9) Exact instructions to clone and run the project

### Option A: Run the full demo (recommended)
From the project root:

```bash
./run_demo.sh
```

### Option B: Manual run (two terminals)

Terminal 1 (consumer first, then it waits for data):

```bash
./consumer.sh /tmp/demo.fifo
```

Terminal 2 (create FIFO and run producer):

```bash
mkfifo -m 600 /tmp/demo.fifo
./producer.sh /tmp/demo.fifo
```

When finished, remove the FIFO if you created it manually:

```bash
rm -f /tmp/demo.fifo
```

> Tip: `run_demo.sh` handles FIFO creation, validation, permissions, logs, and cleanup automatically.

---

## 10) Expected terminal output

When you run `./run_demo.sh`, you should see output similar to the following (timestamps and PIDs will vary):

```text
==================================
 Secure IPC Demonstration
==================================
Working directory: /tmp/secure-ipc.XXXXXX
FIFO path: /tmp/secure-ipc.XXXXXX/jobs.fifo
FIFO permissions: prw------- (600)

Consumer PID: 12345
Producer completed successfully.
Consumer completed successfully.

==================================
 Producer Log
==================================
[2026-11-21 23:10:01] Producer started.
[2026-11-21 23:10:01] Producer PID: 12346
[2026-11-21 23:10:01] Sent: JOB-1
[2026-11-21 23:10:01] Sent: JOB-2
[2026-11-21 23:10:01] Sent: JOB-3
[2026-11-21 23:10:01] Sent: JOB-4
[2026-11-21 23:10:01] Sent: JOB-5
[2026-11-21 23:10:01] Sent: END
[2026-11-21 23:10:01] Producer completed.

==================================
 Consumer Log
==================================
[2026-11-21 23:10:01] Consumer started.
[2026-11-21 23:10:01] Consumer PID: 12345
[2026-11-21 23:10:01] Received: JOB-1
[2026-11-21 23:10:01] Received: JOB-2
[2026-11-21 23:10:01] Received: JOB-3
[2026-11-21 23:10:01] Received: JOB-4
[2026-11-21 23:10:01] Received: JOB-5
[2026-11-21 23:10:01] Received END marker.
[2026-11-21 23:10:01] Consumer shutting down.

IPC demonstration completed.
```

---

## 11) Security implementation

This project applies several practical safeguards:

- **Private temporary directory (`chmod 700`)**  
  `run_demo.sh` creates a temp directory with `mktemp -d` and sets permissions to `700`, reducing access from other local users.

- **FIFO permissions (`600`)**  
  The FIFO is created with `mkfifo -m 600` so only the owner can read/write it (subject to OS enforcement).

- **`umask 077`**  
  `run_demo.sh` sets `umask 077` so newly created files are restricted by default.

- **FIFO type and ownership verification**  
  Before running the demo, `run_demo.sh` checks:
  - the path is a FIFO (`[[ ! -p ... ]]`)
  - ownership matches the current user (`stat -c '%U'`)
  - permissions are exactly `600` (`stat -c '%a'`)

- **Input validation (scripts)**  
  - `producer.sh` and `consumer.sh` require exactly one argument and verify the path is a FIFO.
  - `consumer.sh` validates message format (`JOB-1`..`JOB-5` or `END`) and reports invalid messages.

- **Controlled cleanup**  
  `run_demo.sh` uses traps to clean up FIFO and temporary log files and remove the working directory when possible.

### Security notes (important)
- This is a **learning/demo project** for local IPC on a trusted machine. It is **not** a hardened production IPC framework.
- `run_demo.sh` uses Linux-specific `stat -c ...` formatting; behavior may differ on non-Linux systems.