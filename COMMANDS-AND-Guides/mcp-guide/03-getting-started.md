# Getting Started with MCP

Installation, setup, and your first MCP connection.

## Prerequisites

- Node.js 16+ (for examples, though MCP works with any language)
- npm or yarn
- Basic understanding of APIs and JSON
- Claude (for Claude integration examples)

## Quick Installation

### Option 1: For Claude Integration

If you want to use MCP with Claude immediately:

```bash
# Install the MCP SDK
npm install -g @modelcontextprotocol/sdk

# Verify installation
mcp --version
```

### Option 2: For Building MCP Servers

If you want to build your own MCP server:

```bash
# Create a new project
mkdir my-mcp-server
cd my-mcp-server
npm init -y

# Install MCP SDK
npm install @modelcontextprotocol/sdk

# Install other dependencies (example for a file server)
npm install zod
```

### Option 3: From Source

If you want to use the latest development version:

```bash
git clone https://github.com/modelcontextprotocol/typescript-sdk.git
cd typescript-sdk
npm install
npm run build
```

## Your First MCP Connection

### The Hello World MCP Server

Let's create the simplest possible MCP server.

**File**: `hello-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');

// Create a server instance
const server = new Server({
  name: 'hello-world',
  version: '1.0.0',
});

// Add a simple tool
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'greet',
        description: 'Says hello to someone',
        inputSchema: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'The person to greet' },
          },
          required: ['name'],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler('tools/call', async (request) => {
  if (request.params.name === 'greet') {
    const name = request.params.arguments.name;
    return {
      content: [
        {
          type: 'text',
          text: `Hello, ${name}! Welcome to MCP.`,
        },
      ],
    };
  }
  throw new Error(`Unknown tool: ${request.params.name}`);
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Hello World MCP Server running on stdio');
}

main().catch(console.error);
```

**Run it**:

```bash
node hello-server.js
```

You should see: `Hello World MCP Server running on stdio`

(It will wait for connections. Press Ctrl+C to stop.)

### Understanding the Code

```javascript
// Create a server - this is your MCP endpoint
const server = new Server({
  name: 'hello-world',      // Name of your server
  version: '1.0.0',         // Version for compatibility
});

// Tell clients what tools you have
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'greet',                    // Tool name (used when calling)
        description: 'Says hello to...',  // Claude reads this to decide when to use it
        inputSchema: {
          /* ... describes what inputs it accepts */
        },
      },
    ],
  };
});

// Handle when a tool is called
server.setRequestHandler('tools/call', async (request) => {
  if (request.params.name === 'greet') {
    // Do the work
    const name = request.params.arguments.name;
    return {
      content: [{ type: 'text', text: `Hello, ${name}!` }],
    };
  }
});

// Use stdio transport (reads from stdin, writes to stdout)
const transport = new StdioServerTransport();
await server.connect(transport);
```

## Connecting to Your Server (Without Claude)

Let's create a simple client to test your server:

**File**: `hello-client.js`

```javascript
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const { spawn } = require('child_process');

async function main() {
  // Start the server as a child process
  const serverProcess = spawn('node', ['hello-server.js']);

  // Create a client
  const transport = new StdioClientTransport({
    command: 'node',
    args: ['hello-server.js'],
  });

  const client = new Client({
    name: 'hello-client',
    version: '1.0.0',
  });

  try {
    // Connect
    await client.connect(transport);
    console.log('Connected to server!');

    // Initialize
    const init = await client.initialize();
    console.log('Server info:', init.serverInfo);

    // List available tools
    const tools = await client.listTools();
    console.log('Available tools:', tools.tools.map((t) => t.name));

    // Call the greet tool
    const result = await client.callTool({
      name: 'greet',
      arguments: { name: 'Alice' },
    });
    console.log('Result:', result.content[0].text);
  } catch (error) {
    console.error('Error:', error);
  }
}

main().catch(console.error);
```

**Run it**:

```bash
node hello-client.js
```

**Output**:

```
Connected to server!
Server info: { name: 'hello-world', version: '1.0.0' }
Available tools: [ 'greet' ]
Result: Hello, Alice! Welcome to MCP.
```

## What Just Happened?

1. **Server started** - Waiting on stdio for requests
2. **Client connected** - Opened a connection to the server
3. **Client initialized** - Sent initialization request, got server info
4. **Client listed tools** - Asked what tools are available
5. **Client called tool** - Invoked the 'greet' tool with arguments
6. **Server responded** - Returned the result

This is exactly how Claude communicates with MCP servers!

## Adding Resources

Let's add a resource to our server:

**File**: `hello-server-with-resources.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');

const server = new Server({
  name: 'hello-world',
  version: '1.0.0',
});

// List resources (like tools, but for data)
server.setRequestHandler('resources/list', async () => {
  return {
    resources: [
      {
        uri: 'hello://info',
        name: 'server-info',
        description: 'Information about this server',
        mimeType: 'text/plain',
      },
    ],
  };
});

// Read a resource
server.setRequestHandler('resources/read', async (request) => {
  if (request.params.uri === 'hello://info') {
    return {
      contents: [
        {
          uri: 'hello://info',
          mimeType: 'text/plain',
          text: 'This is the Hello World MCP Server\nVersion 1.0.0\nSupports: tools, resources',
        },
      ],
    };
  }
  throw new Error(`Unknown resource: ${request.params.uri}`);
});

// ... rest of the code (tools/list, tools/call)

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Hello World MCP Server (with resources) running on stdio');
}

main().catch(console.error);
```

**Test it with client**:

```javascript
// In your client, after initialization:
const resources = await client.listResources();
console.log('Available resources:', resources.resources.map((r) => r.name));

const content = await client.readResource({
  uri: 'hello://info',
});
console.log('Resource content:', content.contents[0].text);
```

## Adding Error Handling

Real MCP servers need error handling:

```javascript
server.setRequestHandler('tools/call', async (request) => {
  try {
    if (request.params.name === 'greet') {
      const name = request.params.arguments.name;
      if (!name || name.trim() === '') {
        throw new Error('Name cannot be empty');
      }
      return {
        content: [{ type: 'text', text: `Hello, ${name}!` }],
      };
    }
    throw new Error(`Unknown tool: ${request.params.name}`);
  } catch (error) {
    // Return error in MCP format
    return {
      isError: true,
      content: [
        {
          type: 'text',
          text: `Error: ${error.message}`,
        },
      ],
    };
  }
});
```

## Next Steps

- **Using with Claude**: [04-configuration.md](04-configuration.md)
- **Building real tools**: [07-building-custom-tools.md](07-building-custom-tools.md)
- **Production examples**: [08-real-world-examples.md](08-real-world-examples.md)

## Common Issues

### "Cannot find module '@modelcontextprotocol/sdk'"

```bash
npm install @modelcontextprotocol/sdk
```

### Server starts but client can't connect

Make sure you're using `StdioServerTransport` on the server and `StdioClientTransport` on the client.

### Tool calls timeout

Check that your tool implementation returns quickly. If it takes too long, the client might timeout.

---

**Next Step**: Continue with [04-configuration.md](04-configuration.md) to set up MCP with Claude
