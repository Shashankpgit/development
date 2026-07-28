# Building Custom MCP Tools

Complete guide to creating production-ready MCP servers.

## Planning Your Tool

Before coding, ask yourself:

1. **What problem does it solve?**
   - What functionality do clients need?
   
2. **What are the tools?** (actions/verbs)
   - What functions should clients be able to call?
   
3. **What are the resources?** (information/nouns)
   - What context/documentation should be available?

4. **What are the constraints?**
   - Timeouts? Size limits? Authentication?

## Example: Building a PDF Processing Tool

Let's build an MCP server that extracts text from PDFs.

### Step 1: Setup

```bash
mkdir pdf-processor
cd pdf-processor
npm init -y
npm install @modelcontextprotocol/sdk pdf-parse
```

### Step 2: Define the Server

**File**: `pdf-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const fs = require('fs');
const path = require('path');
const pdfParse = require('pdf-parse');

const server = new Server({
  name: 'pdf-processor',
  version: '1.0.0',
});

// List available tools
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'extract-text',
        description: 'Extract all text from a PDF file',
        inputSchema: {
          type: 'object',
          properties: {
            filepath: {
              type: 'string',
              description: 'Path to the PDF file',
            },
          },
          required: ['filepath'],
        },
      },
      {
        name: 'count-pages',
        description: 'Count the number of pages in a PDF',
        inputSchema: {
          type: 'object',
          properties: {
            filepath: {
              type: 'string',
              description: 'Path to the PDF file',
            },
          },
          required: ['filepath'],
        },
      },
      {
        name: 'extract-metadata',
        description: 'Extract metadata from a PDF',
        inputSchema: {
          type: 'object',
          properties: {
            filepath: {
              type: 'string',
              description: 'Path to the PDF file',
            },
          },
          required: ['filepath'],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    // Validate file exists and is readable
    if (!fs.existsSync(args.filepath)) {
      throw new Error(`File not found: ${args.filepath}`);
    }

    if (!args.filepath.toLowerCase().endsWith('.pdf')) {
      throw new Error('File must be a PDF');
    }

    // Read PDF file
    const fileBuffer = fs.readFileSync(args.filepath);
    const data = await pdfParse(fileBuffer);

    // Handle different tools
    let result;
    if (name === 'extract-text') {
      result = `Extracted ${data.numpages} pages of text:\n\n${data.text}`;
    } else if (name === 'count-pages') {
      result = `Total pages: ${data.numpages}`;
    } else if (name === 'extract-metadata') {
      result = JSON.stringify(data.metadata, null, 2);
    } else {
      throw new Error(`Unknown tool: ${name}`);
    }

    return {
      content: [{ type: 'text', text: result }],
    };
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Error: ${error.message}` }],
    };
  }
});

// List resources (documentation)
server.setRequestHandler('resources/list', async () => {
  return {
    resources: [
      {
        uri: 'help://usage',
        name: 'usage-guide',
        description: 'How to use the PDF processor',
        mimeType: 'text/markdown',
      },
      {
        uri: 'help://limitations',
        name: 'limitations',
        description: 'Known limitations and constraints',
        mimeType: 'text/markdown',
      },
    ],
  };
});

// Read resources
server.setRequestHandler('resources/read', async (request) => {
  if (request.params.uri === 'help://usage') {
    return {
      contents: [
        {
          uri: 'help://usage',
          mimeType: 'text/markdown',
          text: `# PDF Processor Usage Guide

## Available Tools

### extract-text
Extracts all text content from a PDF file.

Example:
\`\`\`
extract-text with filepath: "/path/to/document.pdf"
\`\`\`

### count-pages
Returns the total number of pages in a PDF.

### extract-metadata
Returns document metadata (title, author, creation date, etc.)`,
        },
      ],
    };
  } else if (request.params.uri === 'help://limitations') {
    return {
      contents: [
        {
          uri: 'help://limitations',
          mimeType: 'text/markdown',
          text: `# Limitations

- Maximum file size: 100MB
- Password-protected PDFs not supported
- Text extraction works best with standard fonts
- Scanned PDFs (images) will not extract text`,
        },
      ],
    };
  }
  throw new Error(`Unknown resource: ${request.params.uri}`);
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);
```

### Step 3: Test It Locally

**File**: `test-pdf-server.js`

```javascript
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const fs = require('fs');

async function test() {
  // Create a sample PDF for testing
  // (In real use, you'd have an actual PDF)

  const transport = new StdioClientTransport({
    command: 'node',
    args: ['./pdf-server.js'],
  });

  const client = new Client({
    name: 'test-client',
    version: '1.0.0',
  });

  try {
    await client.connect(transport);
    console.log('✓ Connected to PDF server');

    // Initialize
    const init = await client.initialize();
    console.log(`✓ Server: ${init.serverInfo.name}`);

    // List tools
    const tools = await client.listTools();
    console.log(`✓ Available tools: ${tools.tools.map((t) => t.name).join(', ')}`);

    // List resources
    const resources = await client.listResources();
    console.log(`✓ Resources: ${resources.resources.map((r) => r.name).join(', ')}`);

    // Read a resource
    const usage = await client.readResource({ uri: 'help://usage' });
    console.log(`\n✓ Retrieved usage guide (${usage.contents[0].text.length} chars)`);

    console.log('\nAll tests passed!');
  } catch (error) {
    console.error('Error:', error);
  }
}

test();
```

**Run it**:

```bash
node test-pdf-server.js
```

## Best Practices

### 1. Input Validation

Always validate inputs:

```javascript
server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    // Validate required fields
    if (!args.filepath) {
      throw new Error('filepath is required');
    }

    // Validate types
    if (typeof args.filepath !== 'string') {
      throw new Error('filepath must be a string');
    }

    // Validate constraints
    if (args.timeout && args.timeout > 300) {
      throw new Error('timeout cannot exceed 300 seconds');
    }

    // ... do work
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Validation error: ${error.message}` }],
    };
  }
});
```

### 2. Error Messages

Provide helpful, specific error messages:

```javascript
// ❌ Not helpful
throw new Error('Failed');

// ✅ Helpful
throw new Error(`Failed to process PDF: File is password-protected. Try removing password first.`);
```

### 3. Rate Limiting

Prevent abuse:

```javascript
const callCounts = new Map();

function checkRateLimit(clientId, maxCalls = 100, windowSeconds = 60) {
  const now = Date.now();
  const key = `${clientId}:${Math.floor(now / (windowSeconds * 1000))}`;

  const count = (callCounts.get(key) || 0) + 1;
  callCounts.set(key, count);

  if (count > maxCalls) {
    throw new Error(`Rate limit exceeded: ${maxCalls} calls per ${windowSeconds} seconds`);
  }

  // Cleanup old entries
  const allKeys = Array.from(callCounts.keys());
  allKeys.forEach((k) => {
    if (!k.startsWith(clientId)) return;
    const [, window] = k.split(':');
    if (Math.floor(now / (windowSeconds * 1000)) - window > 5) {
      callCounts.delete(k);
    }
  });
}
```

### 4. Logging

Log for debugging:

```javascript
const fs = require('fs');

function log(level, message, data = {}) {
  const timestamp = new Date().toISOString();
  const entry = JSON.stringify({ timestamp, level, message, ...data });
  fs.appendFileSync('./server.log', entry + '\n');

  if (level === 'error') {
    console.error(`[${level}] ${message}`, data);
  }
}

server.setRequestHandler('tools/call', async (request) => {
  log('info', 'Tool called', {
    tool: request.params.name,
    args: request.params.arguments,
  });

  try {
    // ... do work
  } catch (error) {
    log('error', 'Tool failed', { tool: request.params.name, error: error.message });
    return { isError: true, content: [{ type: 'text', text: error.message }] };
  }
});
```

### 5. Documentation

Provide excellent documentation:

```javascript
server.setRequestHandler('resources/list', async () => {
  return {
    resources: [
      {
        uri: 'docs://full',
        name: 'complete-documentation',
        description: 'Complete guide including examples, limitations, and troubleshooting',
        mimeType: 'text/markdown',
      },
      {
        uri: 'docs://api',
        name: 'api-reference',
        description: 'Full API reference for all tools',
        mimeType: 'text/markdown',
      },
      {
        uri: 'docs://examples',
        name: 'usage-examples',
        description: 'Real-world examples of how to use this server',
        mimeType: 'text/markdown',
      },
    ],
  };
});
```

### 6. Performance

Make tools fast and responsive:

```javascript
// ❌ Slow: waits for all to complete
const allResults = await Promise.all([
  expensiveOperation1(),
  expensiveOperation2(),
  expensiveOperation3(),
]);

// ✅ Better: return quickly with progress
return {
  content: [
    {
      type: 'text',
      text: 'Processing started. This may take a minute. I will return partial results as they become available.',
    },
  ],
};
// Then process in background
```

### 7. Security

Never expose sensitive information:

```javascript
// ❌ Dangerous
return {
  content: [{ type: 'text', text: `Connected as: ${process.env.DB_PASSWORD}` }],
};

// ✅ Safe
return {
  content: [{ type: 'text', text: 'Connected to database' }],
};
```

## Complete Example: Task Management Server

Here's a production-ready MCP server:

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');

// In-memory task storage (replace with database in production)
const tasks = [
  { id: 1, title: 'Buy groceries', status: 'pending', priority: 'high' },
  { id: 2, title: 'Finish report', status: 'in-progress', priority: 'high' },
  { id: 3, title: 'Review code', status: 'pending', priority: 'medium' },
];

const server = new Server({
  name: 'task-manager',
  version: '1.0.0',
});

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'list-tasks',
        description: 'List all tasks with optional filtering',
        inputSchema: {
          type: 'object',
          properties: {
            status: { type: 'string', enum: ['pending', 'in-progress', 'done'] },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
          },
        },
      },
      {
        name: 'create-task',
        description: 'Create a new task',
        inputSchema: {
          type: 'object',
          properties: {
            title: { type: 'string' },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
          },
          required: ['title'],
        },
      },
      {
        name: 'update-task',
        description: 'Update a task',
        inputSchema: {
          type: 'object',
          properties: {
            id: { type: 'number' },
            status: { type: 'string', enum: ['pending', 'in-progress', 'done'] },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
          },
          required: ['id'],
        },
      },
    ],
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === 'list-tasks') {
      let filtered = tasks;
      if (args.status) {
        filtered = filtered.filter((t) => t.status === args.status);
      }
      if (args.priority) {
        filtered = filtered.filter((t) => t.priority === args.priority);
      }
      return {
        content: [{ type: 'text', text: JSON.stringify(filtered, null, 2) }],
      };
    } else if (name === 'create-task') {
      const newTask = {
        id: Math.max(...tasks.map((t) => t.id), 0) + 1,
        title: args.title,
        status: 'pending',
        priority: args.priority || 'medium',
      };
      tasks.push(newTask);
      return {
        content: [{ type: 'text', text: `Created task: ${JSON.stringify(newTask)}` }],
      };
    } else if (name === 'update-task') {
      const task = tasks.find((t) => t.id === args.id);
      if (!task) throw new Error(`Task ${args.id} not found`);

      if (args.status) task.status = args.status;
      if (args.priority) task.priority = args.priority;

      return {
        content: [{ type: 'text', text: `Updated task: ${JSON.stringify(task)}` }],
      };
    }
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Error: ${error.message}` }],
    };
  }
});

server.setRequestHandler('resources/list', async () => {
  return {
    resources: [
      {
        uri: 'help://overview',
        name: 'overview',
        description: 'Task management system overview',
        mimeType: 'text/markdown',
      },
    ],
  };
});

server.setRequestHandler('resources/read', async (request) => {
  if (request.params.uri === 'help://overview') {
    return {
      contents: [
        {
          uri: 'help://overview',
          mimeType: 'text/markdown',
          text: `# Task Manager

A simple task management system.

## Task Status
- pending: Not yet started
- in-progress: Currently being worked on
- done: Completed

## Task Priority
- low: Nice to have
- medium: Normal priority
- high: Urgent`,
        },
      ],
    };
  }
  throw new Error('Unknown resource');
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);
```

## Next Steps

- **Real-world examples**: [08-real-world-examples.md](08-real-world-examples.md)
- **Troubleshooting**: [09-troubleshooting.md](09-troubleshooting.md)
- **Configuration**: [04-configuration.md](04-configuration.md)
