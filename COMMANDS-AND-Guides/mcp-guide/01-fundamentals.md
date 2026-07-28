# MCP Fundamentals - Core Concepts

## What is MCP?

**MCP = Model Context Protocol**

It's a standardized way for AI models (like Claude) to interact with external systems. Instead of Claude having all knowledge and tools built-in, MCP lets you dynamically connect tools, data sources, and custom services.

### The Problem It Solves

Without MCP, here's how you'd give Claude access to a database:

```
❌ Old Way:
Claude Developer → Write custom API wrapper code
                 → Handle authentication
                 → Parse responses
                 → Add error handling
                 → Repeat for each tool
```

With MCP:

```
✅ MCP Way:
Tool Creator    → Build MCP Server (once)
                → Claude automatically knows how to use it
Claude          → No custom code needed
```

## How MCP Works - The Flow

Let's trace what happens when Claude needs to access a database:

```
1. User: "What's in the user table?"
   └─→ Claude receives the question

2. Claude: "I need to query a database. Let me use the 'query-db' tool"
   └─→ Claude decides which tool to use

3. Claude → (via MCP) → Database Server
   Message: { "method": "tools/call", "params": { "name": "query-db", ... } }
   └─→ Sends JSON-RPC request over MCP

4. Database Server processes the request
   └─→ Queries the database
       Returns results

5. Server → (via MCP) → Claude
   Message: { "result": [ { "id": 1, "name": "Alice" }, ... ] }
   └─→ Sends JSON-RPC response

6. Claude: "The user table contains..."
   └─→ Answers the user using the results
```

**Key insight**: MCP is JSON-RPC (Remote Procedure Call) over transport (stdio, HTTP, etc.)

## The Three Main Concepts

### 1. Tools

**What**: Functions that Claude can call

**Example**: A tool named `get-weather` that takes a city name and returns the weather

```json
{
  "name": "get-weather",
  "description": "Get current weather for a city",
  "inputSchema": {
    "type": "object",
    "properties": {
      "city": { "type": "string" }
    },
    "required": ["city"]
  }
}
```

**Why it matters**: Claude understands what the tool does, what inputs it needs, and when to use it

**Real-world example**: 
- Query a database
- Write a file
- Call an external API
- Execute a shell command

### 2. Resources

**What**: Readable data/information the server provides

**Example**: A resource named `user-guide` that contains documentation

Unlike tools (which are called with arguments), resources are just read. Claude can include them in its context to better understand how to solve problems.

**Why it matters**: Helps Claude make better decisions by understanding your system's structure

**Real-world example**:
- Database schema documentation
- File contents
- API documentation
- System configuration

### 3. Sampling (Notifications)

**What**: Server-initiated messages to Claude (not just Claude calling the server)

**Why it matters**: Enables real-time notifications, event subscriptions, and streaming data

**Real-world example**:
- Alert when a server goes down
- Stream log messages to Claude
- Notify about job completion

## Architecture Overview

```
┌────────────────────────────────────────┐
│         Claude (Client)                │
│  "I need to access external systems"   │
└──────────────┬───────────────────────┘
               │
               │ MCP Protocol (JSON-RPC)
               │ Transport: stdio, HTTP, WebSocket, etc.
               │
    ┌──────────┼──────────┬──────────┐
    │          │          │          │
┌───▼──┐  ┌───▼──┐  ┌────▼───┐  ┌──▼────┐
│ File │  │ HTTP │  │Database│  │Custom │
│Server│  │Server│  │ Server │  │ Tools │
└──────┘  └──────┘  └────────┘  └───────┘
   │         │          │          │
   └─────────┼──────────┼──────────┘
             │          │
          (Each is an MCP Server)
```

Each box (File Server, HTTP Server, etc.) is an **MCP Server** that Claude communicates with.

## Request-Response Flow (Simplified)

### 1. Claude Calls a Tool

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "query-users",
    "arguments": {
      "status": "active"
    }
  }
}
```

**Breaking it down**:
- `jsonrpc: "2.0"` - Protocol version (JSON-RPC standard)
- `id: 1` - Request ID (to match with response)
- `method: "tools/call"` - What we're asking for
- `params` - The actual parameters (tool name + arguments)

### 2. Server Responds

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": [
    { "id": 1, "name": "Alice", "status": "active" },
    { "id": 2, "name": "Bob", "status": "active" }
  ]
}
```

**Breaking it down**:
- `jsonrpc: "2.0"` - Same protocol version
- `id: 1` - Matches the request ID
- `result` - The actual result from the tool

That's it! MCP is just a structured way to send requests and get responses.

## Transport Layer

MCP doesn't care *how* you send the messages. You can use:

| Transport | Use When | Example |
|-----------|----------|---------|
| **stdio** | Local development, simple setup | Claude talks to server via stdin/stdout |
| **HTTP** | Remote servers, web-based | Claude talks to server via HTTP requests |
| **WebSocket** | Real-time communication | Live streaming of data to Claude |
| **Custom** | Special needs | Use any protocol you want |

**Most common**: stdio (for local development) and HTTP (for production)

## Why MCP Matters for You

### From Claude's Perspective
✅ Can use external tools without developer rebuilding Claude  
✅ Tools are self-describing (built-in help)  
✅ No authentication logic needed  

### From Your Perspective
✅ One standard way to integrate tools (not different APIs for each)  
✅ Easy to add/remove tools without changing Claude  
✅ Your tools can be used by any MCP client (not just Claude)  

### From a DevOps Perspective
✅ Modular architecture (compose multiple tools)  
✅ Process isolation (each server is separate)  
✅ Configuration-driven (not hardcoded integrations)  

## A Real Example: The Database MCP Server

Let's imagine you have a PostgreSQL database. You build an MCP server that:

**Exposes these tools**:
1. `query-users` - Search the users table
2. `update-user` - Update a user record
3. `create-user` - Add a new user

**Exposes these resources**:
1. `database-schema` - Documentation of the database structure
2. `user-roles` - List of available user roles

Now when you tell Claude "find all inactive users and update them", Claude:
1. Reads the `database-schema` resource to understand the structure
2. Calls `query-users` tool with `status: "inactive"`
3. Gets back a list of inactive users
4. Calls `update-user` for each user (or in a batch)
5. Reports back to you with results

**All without any custom code!**

## Key Takeaway

MCP is a bridge between Claude and your tools. It's:
- **Standardized** - One way to integrate everything
- **Simple** - Just JSON-RPC messages
- **Composable** - Combine multiple servers
- **Flexible** - Works with any language and transport

---

**Next Step**: Ready to see how MCP actually works internally? Read [02-architecture.md](02-architecture.md)

Or skip ahead if you want to start using it: [04-configuration.md](04-configuration.md)
