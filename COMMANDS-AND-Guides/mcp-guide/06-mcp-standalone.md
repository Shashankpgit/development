# Using MCP Without Claude

MCP works perfectly fine without Claude. You can build applications that use MCP servers directly.

## Why Use MCP Without Claude?

| Reason | Benefit |
|--------|---------|
| **Reusability** | Build tools once, use in multiple applications |
| **Standardization** | One protocol for all integrations |
| **Team Tools** | Build internal tools that follow MCP standard |
| **Modular Architecture** | Compose functionality from independent servers |

## Building an MCP Client

### Simple Local Client

Let's build a client that talks to your MCP server (without Claude).

```javascript
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');

class DatabaseClient {
  constructor(serverPath) {
    this.serverPath = serverPath;
    this.client = null;
  }

  async connect() {
    const transport = new StdioClientTransport({
      command: 'node',
      args: [this.serverPath],
    });

    this.client = new Client({
      name: 'database-client',
      version: '1.0.0',
    });

    await this.client.connect(transport);
    await this.client.initialize();
    console.log('Connected to database server');
  }

  async query(sql) {
    const result = await this.client.callTool({
      name: 'query',
      arguments: { sql },
    });
    return JSON.parse(result.content[0].text);
  }

  async disconnect() {
    // Cleanup if needed
  }
}

// Usage
async function main() {
  const client = new DatabaseClient('./db-server.js');
  await client.connect();

  // Query the database
  const users = await client.query('SELECT * FROM users WHERE status = "active"');
  console.log('Active users:', users);

  await client.disconnect();
}

main().catch(console.error);
```

### HTTP-Based MCP Client

For remote servers, use HTTP:

```javascript
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const http = require('http');

class HttpMcpClient {
  constructor(serverUrl) {
    this.serverUrl = serverUrl;
    this.client = null;
  }

  async connect() {
    // Custom transport over HTTP
    const transport = new HttpTransport(this.serverUrl);
    this.client = new Client({
      name: 'http-client',
      version: '1.0.0',
    });

    await this.client.connect(transport);
    await this.client.initialize();
  }

  async callTool(name, args) {
    return await this.client.callTool({ name, arguments: args });
  }
}

// Custom HTTP transport implementation
class HttpTransport {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
  }

  async send(message) {
    return new Promise((resolve, reject) => {
      const options = {
        hostname: new URL(this.baseUrl).hostname,
        port: 3000,
        path: '/mcp',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      };

      const req = http.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          resolve(JSON.parse(data));
        });
      });

      req.on('error', reject);
      req.write(JSON.stringify(message));
      req.end();
    });
  }
}

// Usage
async function main() {
  const client = new HttpMcpClient('http://localhost:3000');
  await client.connect();

  const result = await client.callTool('query', {
    sql: 'SELECT * FROM users',
  });
  console.log(result);
}

main().catch(console.error);
```

## Real-World Example: CLI Tool Using MCP

Build a command-line tool that uses MCP servers:

```bash
# Tool: db-cli - interact with database via CLI

npm install commander pg @modelcontextprotocol/sdk
```

**File**: `db-cli.js`

```javascript
#!/usr/bin/env node

const { program } = require('commander');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');

class DbCli {
  async connect() {
    const transport = new StdioClientTransport({
      command: 'node',
      args: ['./db-server.js'],
    });

    this.client = new Client({
      name: 'db-cli',
      version: '1.0.0',
    });

    await this.client.connect(transport);
    await this.client.initialize();
  }

  async query(sql) {
    try {
      const result = await this.client.callTool({
        name: 'query',
        arguments: { sql },
      });
      const rows = JSON.parse(result.content[0].text);
      this.printTable(rows);
    } catch (error) {
      console.error('Error:', error.message);
    }
  }

  printTable(rows) {
    if (rows.length === 0) {
      console.log('No results');
      return;
    }

    const cols = Object.keys(rows[0]);
    const widths = cols.map((col) => col.length);

    // Calculate column widths
    rows.forEach((row) => {
      cols.forEach((col, i) => {
        widths[i] = Math.max(widths[i], String(row[col]).length);
      });
    });

    // Print header
    console.log(cols.map((c, i) => c.padEnd(widths[i])).join(' | '));
    console.log(widths.map((w) => '-'.repeat(w)).join('-+-'));

    // Print rows
    rows.forEach((row) => {
      console.log(
        cols
          .map((c, i) => String(row[c]).padEnd(widths[i]))
          .join(' | ')
      );
    });
  }
}

// Set up CLI
const cli = new DbCli();

program
  .command('query <sql>')
  .description('Execute a SQL query')
  .action(async (sql) => {
    await cli.connect();
    await cli.query(sql);
    process.exit(0);
  });

program
  .command('list-tables')
  .description('List all tables')
  .action(async () => {
    await cli.connect();
    await cli.query(`SELECT name FROM sqlite_master WHERE type='table'`);
    process.exit(0);
  });

program
  .command('schema [table]')
  .description('Show schema for a table')
  .action(async (table) => {
    await cli.connect();
    if (table) {
      await cli.query(`PRAGMA table_info(${table})`);
    } else {
      console.log('Please provide a table name');
    }
    process.exit(0);
  });

program.parse(process.argv);
```

**Usage**:

```bash
# Make it executable
chmod +x db-cli.js

# Use it
./db-cli.js query "SELECT * FROM users"
./db-cli.js list-tables
./db-cli.js schema users
```

## Web Application Using MCP

Build a web app that uses MCP servers:

**File**: `web-app.js`

```javascript
const express = require('express');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');

const app = express();
app.use(express.json());

// Initialize MCP client (reuse connection)
let mcpClient = null;

async function getMcpClient() {
  if (!mcpClient) {
    const transport = new StdioClientTransport({
      command: 'node',
      args: ['./db-server.js'],
    });

    mcpClient = new Client({
      name: 'web-app',
      version: '1.0.0',
    });

    await mcpClient.connect(transport);
    await mcpClient.initialize();
  }
  return mcpClient;
}

// API endpoint: GET /api/users
app.get('/api/users', async (req, res) => {
  try {
    const client = await getMcpClient();
    const result = await client.callTool({
      name: 'query',
      arguments: { sql: 'SELECT * FROM users' },
    });
    const users = JSON.parse(result.content[0].text);
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// API endpoint: GET /api/users/:id
app.get('/api/users/:id', async (req, res) => {
  try {
    const client = await getMcpClient();
    const result = await client.callTool({
      name: 'query',
      arguments: {
        sql: `SELECT * FROM users WHERE id = ${req.params.id}`,
      },
    });
    const users = JSON.parse(result.content[0].text);
    res.json(users[0] || null);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// API endpoint: POST /api/query (for dynamic queries)
app.post('/api/query', async (req, res) => {
  try {
    const { sql } = req.body;

    // Basic validation (prevent SQL injection)
    if (!sql.toLowerCase().startsWith('select')) {
      throw new Error('Only SELECT queries allowed');
    }

    const client = await getMcpClient();
    const result = await client.callTool({
      name: 'query',
      arguments: { sql },
    });
    const rows = JSON.parse(result.content[0].text);
    res.json(rows);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Web app listening on port ${PORT}`);
  console.log(`Try: curl http://localhost:${PORT}/api/users`);
});
```

**Run it**:

```bash
npm install express
node web-app.js

# In another terminal:
curl http://localhost:3000/api/users
```

## Testing MCP Integrations

Always test your MCP integrations:

```javascript
// test-integration.js
const assert = require('assert');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');

async function testMcpIntegration() {
  console.log('Testing MCP integration...\n');

  const transport = new StdioClientTransport({
    command: 'node',
    args: ['./db-server.js'],
  });

  const client = new Client({
    name: 'test-client',
    version: '1.0.0',
  });

  try {
    // Test 1: Connect and initialize
    console.log('Test 1: Initialization...');
    await client.connect(transport);
    const init = await client.initialize();
    assert.strictEqual(init.serverInfo.name, 'sqlite-database');
    console.log('✓ Passed\n');

    // Test 2: List tools
    console.log('Test 2: Tool discovery...');
    const tools = await client.listTools();
    assert(tools.tools.length > 0);
    assert(tools.tools.some((t) => t.name === 'query'));
    console.log('✓ Passed\n');

    // Test 3: Call tool
    console.log('Test 3: Tool execution...');
    const result = await client.callTool({
      name: 'query',
      arguments: { sql: 'SELECT COUNT(*) as count FROM users' },
    });
    const data = JSON.parse(result.content[0].text);
    assert(data[0].count >= 0);
    console.log('✓ Passed\n');

    // Test 4: Error handling
    console.log('Test 4: Error handling...');
    const errorResult = await client.callTool({
      name: 'query',
      arguments: { sql: 'INVALID SQL' },
    });
    assert(errorResult.isError);
    console.log('✓ Passed\n');

    console.log('All tests passed! ✓');
  } catch (error) {
    console.error('Test failed:', error);
    process.exit(1);
  }
}

testMcpIntegration();
```

**Run it**:

```bash
node test-integration.js
```

## Performance Considerations

### Caching Results

If you're calling tools frequently, cache results:

```javascript
class CachingMcpClient {
  constructor(serverPath) {
    this.serverPath = serverPath;
    this.cache = new Map();
  }

  getCacheKey(toolName, args) {
    return `${toolName}:${JSON.stringify(args)}`;
  }

  async callTool(name, args, cacheTime = 60000) {
    const key = this.getCacheKey(name, args);

    // Check cache
    if (this.cache.has(key)) {
      const { value, timestamp } = this.cache.get(key);
      if (Date.now() - timestamp < cacheTime) {
        return value; // Return cached value
      }
    }

    // Call tool and cache result
    const result = await this.client.callTool({ name, arguments: args });
    this.cache.set(key, {
      value: result,
      timestamp: Date.now(),
    });

    return result;
  }
}
```

### Connection Pooling

Reuse connections instead of creating new ones:

```javascript
class McpClientPool {
  constructor(serverPath, poolSize = 5) {
    this.serverPath = serverPath;
    this.poolSize = poolSize;
    this.clients = [];
    this.availableClients = [];
  }

  async initialize() {
    for (let i = 0; i < this.poolSize; i++) {
      const client = new DatabaseClient(this.serverPath);
      await client.connect();
      this.clients.push(client);
      this.availableClients.push(client);
    }
  }

  async withClient(callback) {
    // Wait for a client to be available
    while (this.availableClients.length === 0) {
      await new Promise((resolve) => setTimeout(resolve, 10));
    }

    const client = this.availableClients.pop();
    try {
      return await callback(client);
    } finally {
      this.availableClients.push(client);
    }
  }

  async query(sql) {
    return this.withClient((client) => client.query(sql));
  }
}
```

## Next Steps

- **Building custom tools**: [07-building-custom-tools.md](07-building-custom-tools.md)
- **Real-world examples**: [08-real-world-examples.md](08-real-world-examples.md)
- **Troubleshooting**: [09-troubleshooting.md](09-troubleshooting.md)
