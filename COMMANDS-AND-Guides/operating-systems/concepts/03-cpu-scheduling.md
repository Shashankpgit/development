# CPU Scheduling

---

## The Problem

A modern computer runs dozens or hundreds of processes. But a CPU core can only execute one instruction at a time.

How does the OS decide which process runs when?

That's the job of the **CPU scheduler** — a part of the kernel that decides which ready process gets CPU time next, and for how long.

---

## The Analogy: A Bank With One Teller

Imagine a bank with one teller and many customers waiting in line. The teller can only serve one customer at a time. The bank manager (scheduler) decides:
- Who goes next?
- How long does each customer get before the next one is served?
- Do urgent customers cut in line?

The scheduler answers these questions for the CPU.

---

## Two Scheduling Models

### Cooperative (Non-Preemptive)

The running process voluntarily gives up the CPU when it's done or waiting. The OS waits for the process to yield.

```
Process A runs... yields → Process B runs... yields → Process C runs...
```

**Problem:** If a process bugs out and never yields, it hogs the CPU forever — the whole system freezes. Early Windows (3.1) used this model, which is why one bad app could hang everything.

### Preemptive

The OS forcefully takes the CPU away from a process after its **time slice** (also called a "quantum") expires. A hardware timer fires an interrupt, the CPU stops the current process, and the scheduler picks the next one.

```
Process A runs [timer fires] → scheduler runs → Process B runs [timer fires] → ...
```

All modern operating systems use preemptive scheduling. No process can hog the CPU indefinitely.

---

## Scheduling Algorithms

The scheduler needs a policy: which ready process should run next?

### First Come First Served (FCFS)

Run processes in the order they arrive. Simple, but bad for short processes that arrive behind a long one.

```
Queue: [Long task - 10s] [Short task - 1s] [Short task - 1s]
Result: short tasks wait 10 seconds before getting any time
```

### Round Robin

Give each process a fixed time slice (e.g., 10ms), then move to the next. Loop around when you reach the end.

```
P1 runs 10ms → P2 runs 10ms → P3 runs 10ms → P1 runs 10ms → ...
```

This is fair and responsive — no process waits too long. Most general-purpose OS schedulers use a variation of this.

### Priority Scheduling

Each process has a priority. Higher-priority processes run first. Round robin is used among processes of equal priority.

```
Priority 10: System kernel threads
Priority 5:  Your application
Priority 1:  Background indexing job
```

Operating systems typically give higher priority to:
- System processes
- Processes that are waiting on I/O (they're about to become runnable again)
- Interactive processes (so the UI feels responsive)

### Completely Fair Scheduler (CFS)

Linux's actual scheduler. Instead of strict time slices, it aims to give every process an equal share of CPU time over a period. It tracks how much CPU time each process has used and always runs the one that has used the least — so all processes "catch up" to each other.

---

## Why This Matters for Developers

### CPU-bound vs I/O-bound

**CPU-bound** — the process is constantly computing (video encoding, machine learning training, sorting huge arrays). It wants as much CPU time as possible.

**I/O-bound** — the process spends most of its time waiting (for disk reads, network responses, user input). It often voluntarily sleeps, so the scheduler can give CPU time to others.

Most web servers and apps are I/O-bound. The scheduler handles them efficiently — when your app waits for a database response, it voluntarily gives up the CPU, and the scheduler runs another process.

### Process Priorities

You can hint to the OS how important your process is:

```bash
# Linux/macOS: lower nice value = higher priority (-20 to 19)
nice -n -10 ./my-important-task    # high priority
nice -n 19 ./background-job        # low priority

# Renice a running process
renice 10 -p 1234
```

```powershell
# Windows: set process priority
Get-Process myapp | ForEach-Object { $_.PriorityClass = "High" }
```

### The Scheduler and Concurrency

Understanding scheduling explains why concurrent code can have unexpected behavior:
- Two threads can run on two CPU cores truly simultaneously — **parallelism**
- Or they can be interleaved on one core — the scheduler can switch between them at any point
- This is why you need **locks and mutexes** when threads share data: the scheduler can interrupt a thread mid-operation

```
Thread 1: reads x (x=5)
  [scheduler switches]
Thread 2: reads x (x=5), increments (x=6), writes x
  [scheduler switches]
Thread 1: increments its old value (5+1=6), writes x  ← wrong! should be 7
```

This is a **race condition** — caused by the scheduler switching at an unlucky moment.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Scheduler | CFS (Completely Fair Scheduler) | XNU multilevel feedback queue | NT multilevel priority queue |
| Priority levels | -20 to +19 (nice values) | -20 to +20 | 0–31 (0=idle, 31=realtime) |
| Time slice length | ~1–10ms (adaptive) | ~10ms | ~15ms |
| Real-time support | SCHED_FIFO, SCHED_RR | Mach real-time threads | REALTIME_PRIORITY_CLASS |

→ Next: `04-memory-management.md`
