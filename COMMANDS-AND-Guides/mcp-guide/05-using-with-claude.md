# Using MCP with Claude - Practical Examples

Real-world scenarios and how to work with MCP-connected Claude.

## Before You Start

Make sure you've:
1. Created an MCP server (see [03-getting-started.md](03-getting-started.md))
2. Configured it in Claude (see [04-configuration.md](04-configuration.md))
3. Tested it works (see troubleshooting in 04-configuration.md)

## Example 1: Database Query Tool

User wants Claude to analyze their database.

### The MCP Server

**File**: `db-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const sqlite3 = require('sqlite3');

const db = new sqlite3.Database(':memory:');

// Initialize sample data
db.run(`
  CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT,
    created_at TEXT,
    status TEXT
  )
`);
db.run(`INSERT INTO users VALUES (1, 'Alice', 'alice@example.com', '2024-01-01', 'active')`);
db.run(`INSERT INTO users VALUES (2, 'Bob', 'bob@example.com', '2024-01-15', 'inactive')`);
db.run(`INSERT INTO users VALUES (3, 'Charlie', 'charlie@example.com', '2024-02-01', 'active')`);

const server = new Server({
  name: 'sqlite-database',
  version: '1.0.0',
});

// List tools
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'query',
        description: 'Execute a SQL SELECT query on the database',
        inputSchema: {
          type: 'object',
          properties: {
            sql: {
              type: 'string',
              description: 'SQL SELECT query to execute',
            },
          },
          required: ['sql'],
        },
      },
      {
        name: 'schema',
        description: 'Get the database schema',
        inputSchema: {
          type: 'object',
          properties: {},
          required: [],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler('tools/call', async (request) => {
  return new Promise((resolve) => {
    const { name, arguments: args } = request.params;

    if (name === 'query') {
      db.all(args.sql, (err, rows) => {
        if (err) {
          resolve({
            isError: true,
            content: [{ type: 'text', text: `Error: ${err.message}` }],
          });
        } else {
          resolve({
            content: [
              {
                type: 'text',
                text: JSON.stringify(rows, null, 2),
              },
            ],
          });
        }
      });
    } else if (name === 'schema') {
      resolve({
        content: [
          {
            type: 'text',
            text: `Database Schema:\n\nTable: users\n- id (INTEGER PRIMARY KEY)\n- name (TEXT)\n- email (TEXT)\n- created_at (TEXT)\n- status (TEXT)`,
          },
        ],
      });
    }
  });
});

// Add resources for schema documentation
server.setRequestHandler('resources/list', async () => {
  return {
    resources: [
      {
        uri: 'db://schema',
        name: 'database-schema',
        description: 'Complete database schema',
        mimeType: 'text/plain',
      },
    ],
  };
});

server.setRequestHandler('resources/read', async (request) => {
  if (request.params.uri === 'db://schema') {
    return {
      contents: [
        {
          uri: 'db://schema',
          mimeType: 'text/plain',
          text: `Database Schema

Table: users
├── id (INTEGER PRIMARY KEY)
├── name (TEXT)
├── email (TEXT)
├── created_at (TEXT)
└── status (TEXT: "active" or "inactive")`,
        },
      ],
    };
  }
  throw new Error(`Unknown resource: ${request.params.uri}`);
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);
```

### Configure in Claude

**File**: `~/.claude/claude.json`

```json
{
  "mcpServers": {
    "my-database": {
      "command": "node",
      "args": ["/path/to/db-server.js"]
    }
  }
}
```

### What Claude Can Do Now

**You tell Claude**:
> Analyze the users in the database. How many are active? Which one joined most recently?

**Claude thinks**:
1. "I need database information. Let me read the schema resource."
2. Reads `db://schema` resource
3. "Now I'll query for active users"
4. Calls `query` tool: `SELECT * FROM users WHERE status = 'active'`
5. Gets back: Alice and Charlie
6. "Now let me find the most recent"
7. Calls `query` tool: `SELECT * FROM users ORDER BY created_at DESC LIMIT 1`
8. Gets back: Charlie (2024-02-01)

**Claude responds**:
> There are 2 active users: Alice and Charlie. Charlie joined most recently on 2024-02-01.

**All without you writing any code!**

## Example 2: File System Access

Claude needs to read and understand your project structure.

### The MCP Server

**File**: `fs-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const fs = require('fs');
const path = require('path');

const server = new Server({
  name: 'filesystem-server',
  version: '1.0.0',
});

// List tools
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'list-files',
        description: 'List files in a directory',
        inputSchema: {
          type: 'object',
          properties: {
            directory: {
              type: 'string',
              description: 'Path to directory to list',
            },
          },
          required: ['directory'],
        },
      },
      {
        name: 'read-file',
        description: 'Read contents of a file',
        inputSchema: {
          type: 'object',
          properties: {
            filepath: {
              type: 'string',
              description: 'Path to file to read',
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
    if (name === 'list-files') {
      const files = fs.readdirSync(args.directory);
      const details = files.map((file) => {
        const fullPath = path.join(args.directory, file);
        const stat = fs.statSync(fullPath);
        return {
          name: file,
          type: stat.isDirectory() ? 'directory' : 'file',
          size: stat.size,
        };
      });
      return {
        content: [{ type: 'text', text: JSON.stringify(details, null, 2) }],
      };
    } else if (name === 'read-file') {
      const content = fs.readFileSync(args.filepath, 'utf-8');
      return {
        content: [{ type: 'text', text: content }],
      };
    }
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Error: ${error.message}` }],
    };
  }
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);
```

### What Claude Can Do

**You tell Claude**:
> What's in my project? Summarize the main files.

**Claude**:
1. Calls `list-files` on your project root
2. Sees package.json, README.md, src/, tests/
3. Calls `read-file` on README.md and package.json
4. Summarizes your project

## Example 3: API Integration

Claude calls an external API through MCP.

### The MCP Server

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const https = require('https');

const server = new Server({
  name: 'weather-api-server',
  version: '1.0.0',
});

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'get-weather',
        description: 'Get weather for a city',
        inputSchema: {
          type: 'object',
          properties: {
            city: {
              type: 'string',
              description: 'City name',
            },
          },
          required: ['city'],
        },
      },
    ],
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'get-weather') {
    // In production, use a real weather API like OpenWeatherMap
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            city: args.city,
            temperature: 72,
            condition: 'Sunny',
            humidity: 65,
          }),
        },
      ],
    };
  }
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);
```

**You tell Claude**:
> What's the weather in San Francisco and New York? Which is warmer?

**Claude**:
1. Calls `get-weather` with "San Francisco"
2. Calls `get-weather` with "New York"
3. Compares temperatures
4. Answers the question

## Working Patterns with Claude + MCP

### Pattern 1: Context + Action

**Setup**:
- MCP server provides resources (schema, documentation)
- MCP server provides tools (actions)

**Flow**:
1. Claude reads resources to understand the system
2. Claude uses tools to take action
3. Claude interprets results

**Example**:
```
User: "Update all inactive users to active"
Claude: Reads schema → Queries for inactive users → Updates each user
```

### Pattern 2: Multi-step Workflows

Claude chains multiple tool calls:

```
User: "List all files, read the largest one, and summarize it"

Claude:
1. list-files → gets file list
2. Finds largest file
3. read-file (on largest) → gets content
4. Summarizes content
```

### Pattern 3: Decision Making

Claude uses resources to make smart decisions:

```
User: "Should I archive this user?"

Claude:
1. Reads user-deletion-policy resource
2. Queries user information
3. Applies policy to decide
4. Recommends action
```

## Tips for Better Claude + MCP Integration

### 1. Write Good Descriptions

```javascript
// ❌ Bad
{
  name: 'query',
  description: 'Query tool',
  inputSchema: {
    properties: {
      q: { type: 'string' }
    }
  }
}

// ✅ Good
{
  name: 'query',
  description: 'Execute a SQL SELECT query on the PostgreSQL database. Returns results as JSON.',
  inputSchema: {
    properties: {
      sql: {
        type: 'string',
        description: 'A valid SQL SELECT statement'
      }
    }
  }
}
```

Claude uses descriptions to know when and how to use your tools.

### 2. Provide Resources for Context

Don't just expose tools—provide resources explaining how to use them:

```javascript
server.setRequestHandler('resources/list', async () => {
  return {
    resources: [
      {
        uri: 'help://database-guide',
        name: 'database-guide',
        description: 'Guide to querying the database',
        mimeType: 'text/markdown',
      },
    ],
  };
});
```

### 3. Return Structured Data

Return JSON or structured text, not raw dumps:

```javascript
// ❌ Less helpful
return {
  content: [{
    type: 'text',
    text: 'Alice,alice@example.com,active\nBob,bob@example.com,inactive'
  }]
};

// ✅ Better
return {
  content: [{
    type: 'text',
    text: JSON.stringify([
      { name: 'Alice', email: 'alice@example.com', status: 'active' },
      { name: 'Bob', email: 'bob@example.com', status: 'inactive' }
    ], null, 2)
  }]
};
```

### 4. Handle Errors Gracefully

```javascript
server.setRequestHandler('tools/call', async (request) => {
  try {
    // ... do work
  } catch (error) {
    return {
      isError: true,
      content: [{
        type: 'text',
        text: `Operation failed: ${error.message}\n\nTry: ${suggestFix(error)}`
      }]
    };
  }
});
```

## Common Workflows with Claude

### Workflow 1: Database Analysis

```
User: "Analyze user growth over the last 3 months"

Claude (using MCP):
1. Reads database schema
2. Queries users by date ranges
3. Calculates growth rates
4. Presents analysis with charts
```

### Workflow 2: Code Review

```
User: "Review the new API endpoints in my project"

Claude (using MCP):
1. Lists files in project
2. Reads the API file
3. Reads tests for API
4. Provides review comments
```

### Workflow 3: Data Migration

```
User: "Migrate all users to the new schema"

Claude (using MCP):
1. Reads old schema
2. Reads new schema
3. Queries all users in old schema
4. Transforms data to new schema
5. Inserts into new schema
6. Verifies migration
```

## Next Steps

- **Building custom tools**: [07-building-custom-tools.md](07-building-custom-tools.md)
- **Real-world examples**: [08-real-world-examples.md](08-real-world-examples.md)
- **Troubleshooting**: [09-troubleshooting.md](09-troubleshooting.md)
