# Real-World MCP Examples

Production-ready MCP servers you can use as templates.

## Example 1: PostgreSQL Database Server

A complete MCP server for PostgreSQL databases.

**File**: `postgres-mcp-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { Pool } = require('pg');

// Initialize database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://localhost/dev',
});

const server = new Server({
  name: 'postgres-database',
  version: '1.0.0',
});

// Utilities
async function getSchema() {
  const result = await pool.query(`
    SELECT 
      t.table_name,
      array_agg(json_build_object(
        'name', c.column_name,
        'type', c.data_type,
        'nullable', c.is_nullable = 'YES'
      )) as columns
    FROM information_schema.tables t
    LEFT JOIN information_schema.columns c 
      ON t.table_name = c.table_name
    WHERE t.table_schema = 'public'
    GROUP BY t.table_name
  `);
  return result.rows;
}

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'query',
        description: 'Execute a SQL SELECT query',
        inputSchema: {
          type: 'object',
          properties: {
            sql: { type: 'string', description: 'SQL SELECT query' },
            params: {
              type: 'array',
              description: 'Query parameters (for prepared statements)',
            },
          },
          required: ['sql'],
        },
      },
      {
        name: 'execute',
        description: 'Execute an INSERT, UPDATE, or DELETE query',
        inputSchema: {
          type: 'object',
          properties: {
            sql: { type: 'string', description: 'SQL INSERT/UPDATE/DELETE query' },
            params: { type: 'array' },
          },
          required: ['sql'],
        },
      },
      {
        name: 'describe-table',
        description: 'Get schema information for a table',
        inputSchema: {
          type: 'object',
          properties: {
            table: { type: 'string' },
          },
          required: ['table'],
        },
      },
    ],
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === 'query') {
      const result = await pool.query(args.sql, args.params || []);
      return {
        content: [{ type: 'text', text: JSON.stringify(result.rows, null, 2) }],
      };
    } else if (name === 'execute') {
      const result = await pool.query(args.sql, args.params || []);
      return {
        content: [
          {
            type: 'text',
            text: `Executed successfully. Rows affected: ${result.rowCount}`,
          },
        ],
      };
    } else if (name === 'describe-table') {
      const schema = await getSchema();
      const table = schema.find((t) => t.table_name === args.table);
      if (!table) throw new Error(`Table ${args.table} not found`);
      return {
        content: [{ type: 'text', text: JSON.stringify(table, null, 2) }],
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
  const schema = await getSchema();
  return {
    resources: schema.map((table) => ({
      uri: `postgres://table/${table.table_name}`,
      name: `table-${table.table_name}`,
      description: `Schema for ${table.table_name} table`,
      mimeType: 'application/json',
    })),
  };
});

server.setRequestHandler('resources/read', async (request) => {
  const match = request.params.uri.match(/^postgres:\/\/table\/(.+)$/);
  if (!match) throw new Error('Invalid resource URI');

  const schema = await getSchema();
  const table = schema.find((t) => t.table_name === match[1]);
  if (!table) throw new Error(`Table ${match[1]} not found`);

  return {
    contents: [
      {
        uri: request.params.uri,
        mimeType: 'application/json',
        text: JSON.stringify(table, null, 2),
      },
    ],
  };
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);

// Graceful shutdown
process.on('SIGINT', async () => {
  await pool.end();
  process.exit(0);
});
```

**Configuration**:

```json
{
  "mcpServers": {
    "postgres": {
      "command": "node",
      "args": ["./postgres-mcp-server.js"],
      "env": {
        "DATABASE_URL": "${env:DATABASE_URL}"
      }
    }
  }
}
```

**Usage with Claude**:

> Find all users created in the last 30 days and their total orders

Claude will:
1. Read the schema resource
2. Query for users
3. Query for their orders
4. Combine results

## Example 2: Git Repository Server

Access git information through MCP.

**File**: `git-mcp-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const repoPath = process.env.GIT_REPO || '.';

const server = new Server({
  name: 'git-repository',
  version: '1.0.0',
});

function gitCommand(cmd) {
  return execSync(`cd ${repoPath} && git ${cmd}`, {
    encoding: 'utf-8',
  });
}

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'get-log',
        description: 'Get commit log',
        inputSchema: {
          type: 'object',
          properties: {
            count: { type: 'number', description: 'Number of commits (default: 10)' },
            format: { type: 'string', enum: ['short', 'full'] },
          },
        },
      },
      {
        name: 'get-status',
        description: 'Get repository status',
        inputSchema: { type: 'object', properties: {} },
      },
      {
        name: 'get-branch',
        description: 'Get current branch',
        inputSchema: { type: 'object', properties: {} },
      },
      {
        name: 'list-branches',
        description: 'List all branches',
        inputSchema: { type: 'object', properties: {} },
      },
      {
        name: 'show-file',
        description: 'Show file at specific commit',
        inputSchema: {
          type: 'object',
          properties: {
            file: { type: 'string' },
            ref: { type: 'string', description: 'Commit/branch (default: HEAD)' },
          },
          required: ['file'],
        },
      },
    ],
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === 'get-log') {
      const count = args.count || 10;
      let output = gitCommand(`log -${count} --oneline`);
      if (args.format === 'full') {
        output = gitCommand(`log -${count}`);
      }
      return { content: [{ type: 'text', text: output }] };
    } else if (name === 'get-status') {
      const status = gitCommand('status --short');
      return { content: [{ type: 'text', text: status || 'Clean working directory' }] };
    } else if (name === 'get-branch') {
      const branch = gitCommand('branch --show-current');
      return { content: [{ type: 'text', text: `Current branch: ${branch.trim()}` }] };
    } else if (name === 'list-branches') {
      const branches = gitCommand('branch -a');
      return { content: [{ type: 'text', text: branches }] };
    } else if (name === 'show-file') {
      const ref = args.ref || 'HEAD';
      const content = gitCommand(`show ${ref}:${args.file}`);
      return { content: [{ type: 'text', text: content }] };
    }
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Git error: ${error.message}` }],
    };
  }
});

server.setRequestHandler('resources/list', async () => {
  return {
    resources: [
      {
        uri: 'git://readme',
        name: 'readme',
        description: 'Project README',
        mimeType: 'text/markdown',
      },
      {
        uri: 'git://gitignore',
        name: 'gitignore',
        description: 'Git ignore file',
        mimeType: 'text/plain',
      },
    ],
  };
});

server.setRequestHandler('resources/read', async (request) => {
  try {
    if (request.params.uri === 'git://readme') {
      const readmePath = path.join(repoPath, 'README.md');
      const content = fs.readFileSync(readmePath, 'utf-8');
      return {
        contents: [
          {
            uri: 'git://readme',
            mimeType: 'text/markdown',
            text: content,
          },
        ],
      };
    } else if (request.params.uri === 'git://gitignore') {
      const gitignorePath = path.join(repoPath, '.gitignore');
      const content = fs.existsSync(gitignorePath)
        ? fs.readFileSync(gitignorePath, 'utf-8')
        : 'No .gitignore file found';
      return {
        contents: [
          {
            uri: 'git://gitignore',
            mimeType: 'text/plain',
            text: content,
          },
        ],
      };
    }
  } catch (error) {
    throw new Error(`Failed to read resource: ${error.message}`);
  }
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);
```

**Configuration**:

```json
{
  "mcpServers": {
    "git": {
      "command": "node",
      "args": ["./git-mcp-server.js"],
      "env": {
        "GIT_REPO": "/path/to/your/repo"
      }
    }
  }
}
```

**Usage with Claude**:

> Show me the last 5 commits and tell me what changed

## Example 3: Web API Integration Server

Fetch and process web data.

**File**: `web-api-mcp-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const https = require('https');

const server = new Server({
  name: 'web-api-integration',
  version: '1.0.0',
});

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Invalid JSON: ${e.message}`));
        }
      });
    }).on('error', reject);
  });
}

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'fetch-api',
        description: 'Fetch data from a public API',
        inputSchema: {
          type: 'object',
          properties: {
            url: { type: 'string', description: 'HTTPS URL to fetch' },
            method: { type: 'string', enum: ['GET'], default: 'GET' },
          },
          required: ['url'],
        },
      },
      {
        name: 'search-github',
        description: 'Search for GitHub repositories',
        inputSchema: {
          type: 'object',
          properties: {
            query: { type: 'string' },
            sort: { type: 'string', enum: ['stars', 'forks', 'updated'] },
          },
          required: ['query'],
        },
      },
    ],
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === 'fetch-api') {
      if (!args.url.startsWith('https://')) {
        throw new Error('Only HTTPS URLs are allowed');
      }
      const data = await fetchJson(args.url);
      return {
        content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
      };
    } else if (name === 'search-github') {
      const sort = args.sort || 'stars';
      const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(args.query)}&sort=${sort}&per_page=10`;
      const data = await fetchJson(url);
      const repos = data.items.map((r) => ({
        name: r.name,
        url: r.html_url,
        stars: r.stargazers_count,
        description: r.description,
      }));
      return {
        content: [{ type: 'text', text: JSON.stringify(repos, null, 2) }],
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

## Example 4: File System Server with Safety

Safe file operations with path validation.

**File**: `filesystem-safe-mcp-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const fs = require('fs');
const path = require('path');

const ALLOWED_DIRS = (process.env.ALLOWED_DIRS || '.').split(':');

function validatePath(filePath) {
  const absPath = path.resolve(filePath);
  const allowed = ALLOWED_DIRS.some((dir) => {
    const absDir = path.resolve(dir);
    return absPath.startsWith(absDir);
  });

  if (!allowed) {
    throw new Error(`Access denied: ${filePath} is outside allowed directories`);
  }

  return absPath;
}

const server = new Server({
  name: 'safe-filesystem',
  version: '1.0.0',
});

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'read-file',
        description: 'Read a file within allowed directories',
        inputSchema: {
          type: 'object',
          properties: {
            path: { type: 'string' },
          },
          required: ['path'],
        },
      },
      {
        name: 'list-directory',
        description: 'List files in a directory',
        inputSchema: {
          type: 'object',
          properties: {
            path: { type: 'string' },
            recursive: { type: 'boolean' },
          },
          required: ['path'],
        },
      },
    ],
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === 'read-file') {
      const safePath = validatePath(args.path);
      const content = fs.readFileSync(safePath, 'utf-8');
      return { content: [{ type: 'text', text: content }] };
    } else if (name === 'list-directory') {
      const safePath = validatePath(args.path);
      const files = fs.readdirSync(safePath);
      const details = files.map((file) => {
        const fullPath = path.join(safePath, file);
        const stat = fs.statSync(fullPath);
        return {
          name: file,
          type: stat.isDirectory() ? 'dir' : 'file',
          size: stat.size,
        };
      });
      return { content: [{ type: 'text', text: JSON.stringify(details, null, 2) }] };
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

**Configuration**:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["./filesystem-safe-mcp-server.js"],
      "env": {
        "ALLOWED_DIRS": "/home/user/projects:/home/user/documents"
      }
    }
  }
}
```

## Production Deployment

### Using PM2

Keep your MCP server running in production:

```bash
# Install PM2
npm install -g pm2

# Create ecosystem.config.js
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'postgres-mcp',
      script: './postgres-mcp-server.js',
      env: {
        DATABASE_URL: 'postgresql://user:pass@localhost/db',
      },
      restart_delay: 4000,
      max_memory_restart: '500M',
    },
    {
      name: 'git-mcp',
      script: './git-mcp-server.js',
      env: {
        GIT_REPO: '/path/to/repo',
      },
    },
  ],
};
EOF

# Start
pm2 start ecosystem.config.js

# Monitor
pm2 logs

# Stop
pm2 stop all
```

### Using Docker

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY postgres-mcp-server.js ./

ENV DATABASE_URL=postgresql://localhost/dev

CMD ["node", "postgres-mcp-server.js"]
```

**Build and run**:

```bash
docker build -t postgres-mcp .
docker run -e DATABASE_URL=... postgres-mcp
```

## Next Steps

- **Building your own**: [07-building-custom-tools.md](07-building-custom-tools.md)
- **Troubleshooting**: [09-troubleshooting.md](09-troubleshooting.md)
