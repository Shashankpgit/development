# Processes and Threads

---

## What Is a Process?

When you run a program, the OS doesn't just execute the code — it creates a **process**: an isolated, running instance of that program with its own private resources.

Think of a program as a recipe and a process as the act of actually cooking it. You can cook the same recipe multiple times simultaneously (multiple processes from the same program). Each cook has their own kitchen (memory), their own ingredients (resources), and doesn't interfere with the others.

A process includes:
- The program's code (instructions)
- Its own private memory space (stack, heap, data)
- Open files and network connections
- A current state (running, waiting, sleeping)
- An identity — the **PID** (Process ID), a unique number the OS assigns

```
Program on disk:   node server.js   (just a file)
                         ↓
Process in memory: PID 4821, memory allocated, CPU time assigned
```

---

## Process Isolation

Processes are strictly isolated from each other. One process cannot read or write another process's memory — the OS enforces this through hardware (the CPU's memory management unit).

This is why:
- One crashing app doesn't crash all other apps
- One app can't steal data from another app's memory
- You can run the same app multiple times without them interfering

If a process tries to access memory it doesn't own, the OS delivers a signal and kills it — on Linux/macOS you see a "Segmentation fault," on Windows an "Access Violation."

---

## Process Lifecycle

Every process goes through these states:

```
            ┌─────────────────────────────────────────────────────┐
            │                                                       │
  fork/exec │                                                       │ exit
            ↓                                                       │
         [Created] → [Ready] ⇄ [Running] → [Waiting] → [Ready]  [Terminated]
                         ↑         │             ↑
                    Scheduler      │        Waiting for
                    picks it       │        I/O, sleep,
                                   │        or lock
                                   ↓
                              [Preempted]
                         (time slice expired,
                          put back in Ready)
```

- **Created** — OS sets up the process's memory and data structures
- **Ready** — waiting for the CPU (has everything it needs, just not scheduled yet)
- **Running** — actually executing instructions on the CPU
- **Waiting** — blocked, waiting for something (a file to load, network data, a timer)
- **Terminated** — finished, but waiting for parent to collect exit code

---

## How Processes Are Created

On Unix-based systems (Linux, macOS), new processes are created with **fork** and **exec**:

- **fork** — the OS copies the current process, creating an exact duplicate. Now there are two identical processes.
- **exec** — the new (child) process replaces itself with a different program.

```
Shell process (PID 100)
    │
    ├── fork() → creates copy (PID 101)
    │               │
    │               └── exec("node server.js") → PID 101 becomes node
    │
    └── continues running the shell
```

This fork/exec model explains why every process has a **parent process** — it was forked from something. On Linux, process 1 (`init` or `systemd`) is the ancestor of all processes.

On Windows, the model is different — `CreateProcess()` creates a new process directly without the fork step.

---

## What Is a Thread?

A **thread** is a unit of execution *within* a process. Where a process has its own isolated memory, threads within the same process **share memory**.

```
Process (1 memory space)
  ├── Thread 1 (its own stack, registers, program counter)
  ├── Thread 2 (its own stack, registers, program counter)
  └── Thread 3 (its own stack, registers, program counter)
       (all three share the heap and global data)
```

Threads are lighter than processes:
- Creating a thread is faster than creating a process (no memory copy needed)
- Threads within one process can communicate directly via shared memory
- Context switching between threads in the same process is faster

---

## Processes vs Threads — When to Use Which

| | Process | Thread |
|--|---------|--------|
| Memory | Own isolated memory | Shared with other threads in process |
| Creation cost | Higher (copy memory) | Lower (just a new stack) |
| Communication | Needs IPC (pipes, sockets, shared memory) | Direct (shared variables) |
| Crash isolation | A crashed process doesn't affect others | A crashed thread can crash the whole process |
| Use case | Independent programs, security boundaries | Parallelism within one program |

**Real-world examples:**
- Chrome uses **multiple processes** — one per tab — so a crashing tab doesn't kill the browser
- A Node.js HTTP server uses **threads** (worker threads) to handle CPU work without blocking the event loop
- A database uses threads to handle many concurrent queries against the same shared data

---

## Context Switching

The CPU can only run one thread at a time per core. The OS simulates "simultaneous" execution by switching between threads very fast — this is called a **context switch**.

A context switch saves the current thread's state (registers, program counter, stack pointer) and loads the next thread's state. This happens thousands of times per second, imperceptible to humans.

```
Thread A running → timer interrupt → OS saves A's state → loads B's state → Thread B running
```

Context switches have a small cost (saving/restoring state, possible cache invalidation). This is why having thousands of OS threads can hurt performance — too much time spent switching, not enough actually running.

This is why Node.js uses a single-threaded event loop instead of one thread per request — avoiding context switch overhead.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Process create | `fork()` + `exec()` | `fork()` + `exec()` | `CreateProcess()` |
| Thread library | pthreads | pthreads | Win32 threads |
| View processes | `ps aux`, `top` | `ps aux`, Activity Monitor | Task Manager, `Get-Process` |
| Process ID | PID (integer) | PID (integer) | PID (integer) |
| Thread scheduling | OS kernel | OS kernel | OS kernel |

Deep dives:
- Linux processes and signals → `../linux/02-processes-and-signals.md`
- Windows Task Manager and services → `../windows/03-processes-and-services.md`
- macOS processes and launchd → `../macos/03-processes-and-launchd.md`

→ Next: `03-cpu-scheduling.md`
