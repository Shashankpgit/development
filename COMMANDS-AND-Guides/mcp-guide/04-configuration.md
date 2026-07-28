# Configuring MCP with Claude

How to set up MCP servers to work with Claude.

## Where Claude Looks for MCP Configuration

Claude reads MCP configuration from:

**On your computer**:
- **macOS/Linux**: `~/.claude/claude.json` or `.claude/mcp.json`
- **Windows**: `%APPDATA%\Claude\claude.json`

**In your project**:
- `./.claude/claude.json` (project-level config, highest priority)

Claude checks both and merges them (project config overrides user config).

## The Configuration File

### Basic Structure

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["path/to/server.js"],
      "disabled": false
    }
  }
}
```

Breaking it down:
- `mcpServers` - Container for all MCP server definitions
- `server-name` - Unique identifier for this server (you choose it)
- `command` - What to run (executable name)
- `args` - Arguments to pass to the command
- `disabled` - Optional, set to true to disable without deleting

### Example: Adding a Simple Local Server

**Create file**: `~/.claude/claude.json`

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": ["/Users/yourname/projects/file-server.js"]
    }
  }
}
```

Now Claude can use your file server!

## Full Configuration Options

```json
{
  "mcpServers": {
    "my-database": {
      "command": "python3",
      "args": ["~/path/to/db_server.py"],
      "env": {
        "DB_URL": "postgresql://localhost/mydb",
        "DB_USER": "admin"
      },
      "disabled": false,
      "description": "PostgreSQL database interface"
    },
    "http-server": {
      "command": "node",
      "args": ["/app/http-server.js", "--port", "3000"],
      "env": {
        "NODE_ENV": "production",
        "API_KEY": "${env:MY_API_KEY}"
      }
    }
  }
}
```

**Options explained**:

| Option | Purpose | Example |
|--------|---------|---------|
| `command` | Executable to run | "node", "python3", "go run" |
| `args` | Arguments passed to command | ["server.js", "--port", "3000"] |
| `env` | Environment variables | {"DB_URL": "postgresql://..."} |
| `disabled` | Disable without deleting | false or true |
| `description` | Human-readable description | "PostgreSQL interface" |

## Using Environment Variables

You can reference environment variables in your config:

```json
{
  "mcpServers": {
    "secure-server": {
      "command": "node",
      "args": ["./server.js"],
      "env": {
        "API_KEY": "${env:MY_API_KEY}",
        "DB_PASSWORD": "${env:DB_PASSWORD}"
      }
    }
  }
}
```

This reads `MY_API_KEY` and `DB_PASSWORD` from your shell environment.

**Setting environment variables** (on macOS/Linux):

```bash
# Temporarily (for current terminal session)
export MY_API_KEY="your-secret-key"

# Permanently (add to ~/.bashrc or ~/.zshrc)
echo 'export MY_API_KEY="your-secret-key"' >> ~/.bashrc
source ~/.bashrc
```

## Real-World Example: Database MCP Server

Let's set up a complete PostgreSQL MCP server.

### Step 1: Create the Server

**File**: `~/projects/db-server.js`

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const server = new Server({
  name: 'postgres-server',
  version: '1.0.0',
});

// List tools
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'query',
        description: 'Execute a SQL query',
        inputSchema: {
          type: 'object',
          properties: {
            sql: { type: 'string' },
          },
          required: ['sql'],
        },
      },
    ],
  };
});

// Handle queries
server.setRequestHandler('tools/call', async (request) => {
  try {
    const result = await pool.query(request.params.arguments.sql);
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(result.rows, null, 2),
        },
      ],
    };
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Query error: ${error.message}` }],
    };
  }
});

const transport = new StdioServerTransport();
server.connect(transport).catch(console.error);
```

### Step 2: Configure in Claude

**File**: `~/.claude/claude.json`

```json
{
  "mcpServers": {
    "postgres": {
      "command": "node",
      "args": ["~/projects/db-server.js"],
      "env": {
        "DATABASE_URL": "${env:DATABASE_URL}",
        "NODE_ENV": "production"
      }
    }
  }
}
```

### Step 3: Set Environment Variable

```bash
# Add to ~/.bashrc or ~/.zshrc
export DATABASE_URL="postgresql://user:password@localhost:5432/mydb"

# Verify
echo $DATABASE_URL
```

### Step 4: Use with Claude

Restart Claude (or reload the configuration). Now you can tell Claude:

> Query the users table and show me all active users

Claude will:
1. Call the `query` tool
2. Pass a SQL query to your server
3. Get back the results
4. Show them to you

## Testing Your Configuration

Before relying on it with Claude, test locally:

### Create a Test Client

**File**: `test-client.js`

```javascript
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');

async function test() {
  const transport = new StdioClientTransport({
    command: 'node',
    args: ['~/projects/db-server.js'],
  });

  const client = new Client({
    name: 'test-client',
    version: '1.0.0',
  });

  await client.connect(transport);

  // Test 1: Initialize
  const init = await client.initialize();
  console.log('✓ Connected:', init.serverInfo.name);

  // Test 2: List tools
  const tools = await client.listTools();
  console.log('✓ Available tools:', tools.tools.length);

  // Test 3: Call a tool
  const result = await client.callTool({
    name: 'query',
    arguments: { sql: 'SELECT 1 as result' },
  });
  console.log('✓ Tool works:', result.content[0].text);

  console.log('\nAll tests passed!');
}

test().catch(console.error);
```

**Run it**:

```bash
node test-client.js
```

## Multiple MCP Servers

You can configure multiple servers and Claude will use them all:

```json
{
  "mcpServers": {
    "database": {
      "command": "node",
      "args": ["~/servers/db.js"],
      "env": { "DATABASE_URL": "${env:DATABASE_URL}" }
    },
    "filesystem": {
      "command": "node",
      "args": ["~/servers/fs.js"]
    },
    "web-api": {
      "command": "node",
      "args": ["~/servers/api.js"],
      "env": { "API_KEY": "${env:API_KEY}" }
    },
    "git": {
      "command": "node",
      "args": ["~/servers/git.js"]
    }
  }
}
```

Claude can now use all four servers simultaneously.

## Project-Level Configuration

For team projects, store MCP config in version control:

**File**: `.claude/claude.json` (in your project root)

```json
{
  "mcpServers": {
    "project-db": {
      "command": "node",
      "args": ["./scripts/mcp-db-server.js"],
      "env": {
        "DATABASE_URL": "${env:DATABASE_URL}"
      }
    },
    "project-api": {
      "command": "node",
      "args": ["./scripts/mcp-api-server.js"]
    }
  }
}
```

**Benefits**:
- Team members automatically get the same MCP setup
- No manual configuration per developer
- Servers can be versioned with the project

## Debugging Configuration Issues

### Issue: Claude Can't Find the Server

**Diagnosis**:

```bash
# Check if the server runs manually
node ~/projects/db-server.js
# Should print: "Server running on stdio"
```

**Fix**: Verify the path in your config is absolute:

```json
{
  "mcpServers": {
    "db": {
      "command": "node",
      "args": ["/absolute/path/to/db-server.js"]  // Use full path, not ~/
    }
  }
}
```

### Issue: "Unknown tool" Error

Claude is connecting but can't find your tools.

**Diagnosis**:

```bash
# Run test client (from "Testing Your Configuration" section)
node test-client.js
```

**Fix**: Make sure your server's `tools/list` handler returns the right structure:

```javascript
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'my-tool',
        description: 'Does something',
        inputSchema: { /* ... */ },
      },
    ],
  };
});
```

### Issue: Environment Variable Not Substituted

If `${env:MY_VAR}` isn't being replaced:

```bash
# Check if the variable is set
echo $MY_VAR

# If empty, set it
export MY_VAR="value"

# Add to ~/.bashrc to make it permanent
echo 'export MY_VAR="value"' >> ~/.bashrc
```

## Configuration Best Practices

✅ **Do**:
- Use absolute paths for server locations
- Store sensitive values in environment variables (not in config files)
- Test each server independently before adding to Claude config
- Document what each server does in the description

❌ **Don't**:
- Put API keys or passwords directly in config files
- Use relative paths like `./server.js` (they're relative to where Claude runs, not the config file)
- Start servers with `npm run` (use the executable directly)
- Forget to export environment variables

## Next Steps

- **Using MCP with Claude**: [05-using-with-claude.md](05-using-with-claude.md)
- **Real-world examples**: [08-real-world-examples.md](08-real-world-examples.md)
- **Troubleshooting**: [09-troubleshooting.md](09-troubleshooting.md)
