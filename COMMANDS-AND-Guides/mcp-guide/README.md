# MCP (Model Context Protocol) - Complete Guide

Welcome to this comprehensive guide on **Model Context Protocol (MCP)**, the protocol that extends Claude's capabilities with external tools, data sources, and integrations.

## What You'll Learn

This guide takes you from "What is MCP?" to building your own MCP servers and integrating them with Claude. Each section builds on the previous one, with practical examples throughout.

## Directory Structure

```
mcp-guide/
├── README.md (you are here)
├── 01-fundamentals.md          # Core concepts and how MCP works
├── 02-architecture.md          # Deep dive into MCP internals
├── 03-getting-started.md       # Installation and basic setup
├── 04-configuration.md         # Configuring MCP with Claude
├── 05-using-with-claude.md     # Practical examples with Claude
├── 06-mcp-standalone.md        # Using MCP without Claude
├── 07-building-custom-tools.md # Creating your own MCP servers
├── 08-real-world-examples.md   # Production-ready configurations
└── 09-troubleshooting.md       # Common issues and solutions
```

## Quick Navigation

**I'm new to MCP**
→ Start with [01-fundamentals.md](01-fundamentals.md)

**I want to use Claude with MCP quickly**
→ Jump to [04-configuration.md](04-configuration.md) then [05-using-with-claude.md](05-using-with-claude.md)

**I want to build my own MCP server**
→ Read [02-architecture.md](02-architecture.md) then [07-building-custom-tools.md](07-building-custom-tools.md)

**I want to use MCP outside of Claude**
→ See [06-mcp-standalone.md](06-mcp-standalone.md)

**Something broke**
→ Check [09-troubleshooting.md](09-troubleshooting.md)

## The Big Picture

MCP is a **standardized protocol** that lets applications (like Claude) talk to external systems (databases, APIs, files, custom services). Think of it as a universal adapter for AI models.

```
┌─────────────────────────────────────────────────────────┐
│                    Claude (Client)                       │
│              "I need to access a database"               │
└───────────────────────────┬─────────────────────────────┘
                            │
                    MCP Protocol (JSON-RPC)
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
    ┌───▼────┐          ┌───▼────┐         ┌───▼────┐
    │Database│          │  File  │         │ Custom │
    │ Server │          │ System │         │ Server │
    └────────┘          └────────┘         └────────┘
```

## Key Concepts (Explained Simply)

| Term | What It Is | Why It Matters |
|------|-----------|----------------|
| **Server** | A program that exposes tools/resources | Provides the actual functionality |
| **Client** | A program that calls the server | Claude, or your own app |
| **Tools** | Functions the server exposes | Claude can call them to do things |
| **Resources** | Data/information the server provides | Claude can read them to understand context |
| **Sampling** | Server-initiated messages to the client | For notifications or real-time updates |

## What Makes MCP Special

✅ **Standardized** - One protocol for all tools (no custom integrations needed)  
✅ **Flexible** - Works with any programming language  
✅ **Composable** - Combine multiple MCP servers for rich functionality  
✅ **Secure** - Built-in authentication and isolation  
✅ **Debuggable** - Human-readable JSON-RPC messages  

## Before You Start

You'll need:
- Basic understanding of APIs and protocols
- Node.js (for examples, but MCP works with any language)
- Claude (for the "with Claude" sections)
- A terminal/command line

**Note**: DevOps background? You'll recognize patterns from gRPC, HTTP APIs, and message queues. MCP is essentially a lighter-weight alternative optimized for AI model integration.

---

**Next Step**: Read [01-fundamentals.md](01-fundamentals.md) to understand how MCP works at a high level.
