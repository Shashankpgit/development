# Memory Management

---

## The Problem

RAM is finite. A computer might have 16GB. But all your running processes combined might want 40GB of memory. And each process needs to believe its memory is private — it can't see another process's data.

How does the OS solve this? Through a concept called **virtual memory**.

---

## Virtual Memory

Every process gets its own **virtual address space** — a private, imaginary range of memory addresses. The process thinks it owns, say, addresses 0 to 8GB. But those aren't real physical RAM addresses — they're virtual.

The OS (with hardware help from the CPU's MMU — Memory Management Unit) **translates** virtual addresses to real physical RAM addresses behind the scenes.

```
Process A thinks it has:    [0 ─────────────── 8GB]  (virtual)
Process B thinks it has:    [0 ─────────────── 8GB]  (virtual)
                                    ↓ OS maps ↓
Actual physical RAM:        [some of A here][some of B there][OS here]
```

Both processes use address `0x1000` in their virtual space — but those map to completely different physical RAM locations. They never collide.

Benefits:
- **Isolation** — processes can't accidentally (or maliciously) read each other's memory
- **More memory than you have** — virtual address space can be larger than physical RAM (the OS uses disk as overflow — see "swap" below)
- **Simpler programs** — programs don't need to know where in physical RAM they are

---

## Paging

Virtual memory is implemented through **paging**. Memory is divided into fixed-size chunks called **pages** (typically 4KB each).

```
Virtual address space → divided into pages
Physical RAM          → divided into page frames (same size)

Page table: maps virtual page numbers → physical frame numbers
```

The CPU's MMU consults the **page table** for every memory access to translate the virtual address to a physical one. This happens in nanoseconds, in hardware.

If a process tries to access a virtual page that isn't in RAM (it's on disk, or doesn't exist), a **page fault** occurs. The OS handles it:
- If the page exists on disk: load it into RAM, update the page table, resume the process
- If the address is invalid: kill the process (segfault / access violation)

---

## Memory Layout of a Process

Inside a process's virtual address space, memory is organized into distinct regions:

```
High addresses ─────────────────────────────
                    Kernel space
                    (not accessible to user code)
────────────────────────────────────────────
                    Stack
                    (grows downward)
                    - local variables
                    - function call frames
                    - return addresses
                         ↓ grows down

                    (empty space)

                         ↑ grows up
                    Heap
                    (dynamically allocated memory)
                    - malloc / new
                    - objects, data structures

                    Data segment
                    (global and static variables)

                    Code segment (text)
                    (the program's compiled instructions)
Low addresses ──────────────────────────────
```

**Stack** — automatically managed. When a function is called, a "stack frame" is pushed. When it returns, it's popped. Very fast. Limited size (usually 8MB).

**Heap** — manually managed (or garbage collected). `malloc()` in C, `new` in Java, object creation in Python — all allocate from the heap. The heap can grow large (limited by available virtual address space and RAM).

A **stack overflow** happens when the stack grows too large — usually from infinite recursion. A program is "out of memory" when the heap can't grow anymore.

---

## Swap

When physical RAM is full, the OS can write **rarely-used pages to disk** and free up their physical RAM for more urgent use. This disk area is called **swap space** (or the page file on Windows).

```
RAM full → OS picks a cold page → writes it to swap (disk) → frees the RAM → uses RAM for something urgent

Later: process needs that page → page fault → OS reads it back from swap into RAM
```

Swap lets you run more than fits in RAM. But disk is much slower than RAM — if the OS is constantly swapping, performance degrades badly. This is called **thrashing**.

Signs you need more RAM: high swap usage, system feels sluggish even with CPU idle.

---

## The OOM Killer

When the OS runs out of both RAM and swap, it faces a hard choice: kill a process to free memory.

On Linux, this is the **OOM Killer** (Out Of Memory Killer). It picks a process to kill based on:
- How much memory it's using
- How long it's been running
- OOM score (adjustable per-process)

You may have seen this in cloud deployments: a container suddenly dies with `Killed` — the OOM killer terminated it because it exceeded its memory limit.

On Windows, new allocations start failing with `ERROR_NOT_ENOUGH_MEMORY`. On macOS, the system may force-quit background processes.

---

## Why This Matters for Developers

**Memory leaks** — if your program allocates heap memory and never frees it (in languages without garbage collection), the process's memory grows forever until OOM.

**Buffer overflows** — writing past the end of an allocated buffer overwrites adjacent memory. In C/C++, this is a security vulnerability (attackers can overwrite the return address on the stack to redirect execution).

**Garbage collection** — languages like Java, Python, Go, JavaScript manage heap memory automatically. The GC periodically scans for unreachable objects and frees them. Understanding the GC matters for performance-sensitive code — GC pauses can cause latency spikes.

**Virtual memory and fork** — when Linux forks a process, it doesn't immediately copy all the parent's memory. It uses **copy-on-write (CoW)**: both parent and child share the same physical pages until one of them writes to a page — then it gets its own copy. This makes fork very fast.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Swap | Swap partition or swap file | Compressed memory + swap file | Page file (pagefile.sys) |
| OOM handling | OOM Killer (kills a process) | Memory pressure + force quit | Allocation failure |
| Default page size | 4KB (large pages: 2MB/1GB) | 4KB (large pages: 2MB) | 4KB (large pages: 2MB) |
| Memory check command | `free -h`, `vmstat` | `memory_pressure`, `vm_stat` | `Get-CimInstance Win32_OS` |

Deep dive:
- Linux memory management → `../linux/03-memory-management.md`

→ Next: `05-filesystem.md`
