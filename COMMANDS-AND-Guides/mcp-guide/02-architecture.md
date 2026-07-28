# MCP Architecture - The Deep Dive

This document explains how MCP works under the hood. Understanding the architecture helps you debug issues and build better integrations.

**Audience**: Developers building MCP servers or wanting to understand the protocol deeply

## The Client-Server Model

```
         ┌─────────────────┐
         │  MCP Client     │
         │   (Claude)      │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  MCP Protocol   │
         │  (JSON-RPC)     │
         └────────┬────────┘
                  │
    (stdio/HTTP/WebSocket/custom)
                  │
         ┌────────▼────────┐
         │  MCP Server     │
         │  (Your Tool)    │
         └─────────────────┘
```

**Client** = Claude (or any MCP client)  
**Server** = Your tool/service that exposes functionality  
**Protocol** = JSON-RPC over a transport layer

## Connection Lifecycle

### Phase 1: Initialization

When Claude connects to an MCP server:

```
1. Client: "Hello, I'm Claude (client)"
   └─→ Sends initialization request

2. Server: "Hello! Here's what I can do"
   └─→ Responds with available tools and resources

3. Both: "Great, we're connected and ready"
   └─→ Connection established
```

**Actual JSON** (from client to server):

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "roots": {}
    },
    "clientInfo": {
      "name": "Claude",
      "version": "1.0"
    }
  }
}
```

**Server responds**:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {},
      "resources": {}
    },
    "serverInfo": {
      "name": "database-server",
      "version": "1.0"
    }
  }
}
```

### Phase 2: Active Communication

Once connected, the client can:
1. **List tools** - Ask what tools are available
2. **Call tools** - Execute a specific tool
3. **List resources** - Ask what resources are available
4. **Read resources** - Get resource contents
5. **Server notifications** - Receive real-time updates

### Phase 3: Shutdown

The client disconnects when done. The server cleans up resources.

## The Four Core Request Types

### 1. Tools - The Executable Functions

**Purpose**: Let Claude call functions you define

**Structure**:

```json
{
  "name": "query-database",
  "description": "Execute a SQL query on the database",
  "inputSchema": {
    "type": "object",
    "properties": {
      "sql": {
        "type": "string",
        "description": "The SQL query to execute"
      },
      "timeout": {
        "type": "number",
        "description": "Query timeout in seconds (default: 30)"
      }
    },
    "required": ["sql"]
  }
}
```

**Breaking it down**:
- `name` - Tool identifier (used when calling)
- `description` - What it does (Claude reads this to know when to use it)
- `inputSchema` - JSON Schema describing input parameters

**When Claude calls this tool**:

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "method": "tools/call",
  "params": {
    "name": "query-database",
    "arguments": {
      "sql": "SELECT * FROM users WHERE status = 'active'"
    }
  }
}
```

**Server executes the query and responds**:

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "result": {
    "type": "text",
    "text": "[{\"id\": 1, \"name\": \"Alice\"}, {\"id\": 2, \"name\": \"Bob\"}]"
  }
}
```

### 2. Resources - The Information

**Purpose**: Provide context information Claude needs

**Structure**:

```json
{
  "uri": "file:///app/docs/database-schema.md",
  "name": "database-schema",
  "description": "Complete database schema and table structure",
  "mimeType": "text/markdown"
}
```

**Breaking it down**:
- `uri` - Unique resource identifier
- `name` - Human-readable name
- `description` - What information it contains
- `mimeType` - Content type (text/markdown, application/json, etc.)

**When Claude reads this resource**:

```json
{
  "jsonrpc": "2.0",
  "id": 43,
  "method": "resources/read",
  "params": {
    "uri": "file:///app/docs/database-schema.md"
  }
}
```

**Server returns the content**:

```json
{
  "jsonrpc": "2.0",
  "id": 43,
  "result": {
    "contents": [
      {
        "uri": "file:///app/docs/database-schema.md",
        "mimeType": "text/markdown",
        "text": "# Database Schema\n\n## Users Table\n- id: INTEGER PRIMARY KEY\n- name: VARCHAR(255)\n- status: VARCHAR(50)"
      }
    ]
  }
}
```

**Why separate tools and resources?**
- **Tools** are for *actions* ("do something")
- **Resources** are for *information* ("read something")

Think: Tools = verbs, Resources = nouns

### 3. Tool Listing - Discovery

Claude needs to discover what tools you have:

```json
{
  "jsonrpc": "2.0",
  "id": 44,
  "method": "tools/list",
  "params": {}
}
```

**Server responds with all available tools**:

```json
{
  "jsonrpc": "2.0",
  "id": 44,
  "result": {
    "tools": [
      {
        "name": "query-database",
        "description": "Execute SQL queries",
        "inputSchema": { /* ... */ }
      },
      {
        "name": "backup-database",
        "description": "Create a backup",
        "inputSchema": { /* ... */ }
      }
    ]
  }
}
```

### 4. Resource Listing - Discovery

Similar to tool listing:

```json
{
  "jsonrpc": "2.0",
  "id": 45,
  "method": "resources/list",
  "params": {}
}
```

## JSON-RPC Protocol Details

MCP uses **JSON-RPC 2.0**, a lightweight protocol for remote procedure calls.

### Request Structure

```json
{
  "jsonrpc": "2.0",
  "id": <number>,
  "method": "<method-name>",
  "params": <object>
}
```

- `jsonrpc` - Always "2.0"
- `id` - Unique identifier to match with response (client generates this)
- `method` - What you're asking for
- `params` - Parameters for that method

### Response Structure

**Success**:
```json
{
  "jsonrpc": "2.0",
  "id": <number>,
  "result": <any>
}
```

**Error**:
```json
{
  "jsonrpc": "2.0",
  "id": <number>,
  "error": {
    "code": -32600,
    "message": "Invalid Request",
    "data": "Additional error details"
  }
}
```

## Transport Layer

The protocol itself doesn't care how messages are transmitted. Common transports:

### stdio (Standard Input/Output)

Most common for local development.

```
Client writes JSON to server's stdin
Server reads JSON from stdin
Server writes JSON to stdout
Client reads JSON from stdout
```

**Advantages**:
- Simple to debug (messages are human-readable)
- No network complexity
- Process isolation built-in

**Disadvantages**:
- Limited to local communication
- Can't stream binary data

### HTTP

Common for remote/cloud deployments.

```
Client: POST /mcp/call
Body: { "jsonrpc": "2.0", "method": "tools/call", ... }

Server: 200 OK
Body: { "jsonrpc": "2.0", "result": ... }
```

**Advantages**:
- Works over network
- Easy to scale
- Standard HTTP infrastructure

**Disadvantages**:
- Higher latency
- Need to handle HTTP details

## Error Handling

Errors follow JSON-RPC standard error codes:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "Invalid Request"
  }
}
```

**Common error codes**:
- `-32700` - Parse error (invalid JSON)
- `-32600` - Invalid request (missing required fields)
- `-32601` - Method not found
- `-32602` - Invalid params
- `-32603` - Internal error

## Capabilities System

Not all clients support all features. The initialization includes capability negotiation:

```json
{
  "capabilities": {
    "tools": {},
    "resources": {},
    "sampling": {}
  }
}
```

This means: "I support tools, resources, and sampling"

## Real-World Example: Database MCP Flow

User: "What users are active?"

```
1. Claude initializes:
   → Server: "I have 'query-db' tool and 'schema' resource"
   ← Server responds with capabilities

2. Claude reads schema resource:
   → Server: "Get the schema resource"
   ← Server: "Tables: users(id, name, status), ..."

3. Claude calls query-db tool:
   → Server: "Execute: SELECT * FROM users WHERE status='active'"
   ← Server: "Results: [{id: 1, name: 'Alice'}, ...]"

4. Claude responds to user:
   "The active users are Alice and Bob"
```

Each step is a JSON-RPC request-response pair.

## Key Architectural Insights

1. **Stateless**: Each request can be processed independently
2. **Synchronous**: Request → Response (no async streams in base protocol)
3. **Composable**: You can combine multiple MCP servers
4. **Introspectable**: Claude can discover what tools you have
5. **Safe**: Server decides what tools to expose

---

**Next Step**: Ready to build something? Jump to [07-building-custom-tools.md](07-building-custom-tools.md)

Or continue with [03-getting-started.md](03-getting-started.md) for installation
