# MCP Troubleshooting Guide

Solutions to common MCP problems.

## General Diagnostics

Always start with these checks:

### 1. Verify Server Runs Manually

```bash
# Test if your server starts without errors
node your-server.js

# You should see something like:
# "Your MCP Server running on stdio"
```

If the server doesn't start, check:
- Is Node.js installed? `node --version`
- Are all dependencies installed? `npm ls`
- Is there a syntax error? Check the error message carefully

### 2. Test Server with Client

Use the test client from [03-getting-started.md](03-getting-started.md):

```bash
# This will tell you if the server communicates correctly
node test-client.js
```

If this fails, the problem is the server-client communication.

### 3. Check Claude Configuration

```bash
# Verify the config file exists
cat ~/.claude/claude.json

# Or check project config
cat .claude/claude.json
```

Look for:
- Correct command path (should be absolute)
- Server name is correct
- Environment variables are set

## Common Issues and Solutions

### Issue: "Cannot find module '@modelcontextprotocol/sdk'"

**Diagnosis**:
```bash
npm ls @modelcontextprotocol/sdk
```

**Solutions**:

Option 1: Install locally
```bash
npm install @modelcontextprotocol/sdk
```

Option 2: Install globally
```bash
npm install -g @modelcontextprotocol/sdk
```

Option 3: Use absolute path to node_modules
```json
{
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["/full/path/to/server.js"]
    }
  }
}
```

### Issue: Claude Can't Connect to Server

**Symptoms**:
- Claude says "tool not available"
- Error about MCP server not responding

**Diagnosis**:
```bash
# 1. Verify server runs
node your-server.js
# Should start without errors

# 2. Test connectivity
node test-client.js
# Should print "Connected" and list tools
```

**Solutions**:

1. **Use absolute paths**:
   ```json
   {
     "mcpServers": {
      "db": {
        "command": "node",
        "args": ["/Users/yourname/projects/server.js"]  // ✅ Absolute path
      }
    }
   }
   ```

2. **Restart Claude** after updating config
   - Close Claude completely
   - Reopen Claude

3. **Check environment variables**:
   ```bash
   # Verify environment variable exists
   echo $MY_VAR

   # If empty, set it
   export MY_VAR="value"

   # Make it permanent (add to ~/.bashrc or ~/.zshrc)
   echo 'export MY_VAR="value"' >> ~/.bashrc
   ```

### Issue: "Tool is not defined" or "Unknown tool"

**Symptoms**:
- Claude says the tool exists but then can't use it
- "tools/list shows the tool but tools/call fails"

**Diagnosis**:
```bash
# Check what tools your server lists
node test-client.js
# Look at the output - what tools does it show?
```

**Solutions**:

1. **Verify tools/list handler exists**:
   ```javascript
   server.setRequestHandler('tools/list', async () => {
     return {
       tools: [
         {
           name: 'my-tool',
           description: 'Does something',
           inputSchema: { /* ... */ }
         }
       ]
     };
   });
   ```

2. **Verify tools/call handler exists and matches**:
   ```javascript
   server.setRequestHandler('tools/call', async (request) => {
     const { name } = request.params;
     if (name === 'my-tool') {
       // Handle the tool
       return { content: [{ type: 'text', text: 'Result' }] };
     }
   });
   ```

3. **Check tool name spelling exactly matches**

### Issue: Tool Call Timeout

**Symptoms**:
- Claude says "Tool timed out"
- Tool takes a long time to respond

**Diagnosis**:
```bash
# Test how long your tool takes
time node -e "
  const yourServer = require('./your-server.js');
  // Time your operation
"
```

**Solutions**:

1. **Optimize tool performance**:
   - Cache database queries
   - Use indexes
   - Reduce data processing
   - Profile to find bottlenecks

2. **Return quickly with partial results**:
   ```javascript
   return {
     content: [{
       type: 'text',
       text: 'Processing... This will take ~30 seconds. Results so far: ...'
     }]
   };
   // Continue processing in background if needed
   ```

3. **Break large operations into smaller tools**:
   ```javascript
   // ❌ Bad: One large tool
   {
     name: 'process-all-users',
     description: 'Process all 1 million users'
   }

   // ✅ Better: Multiple smaller tools
   [
     { name: 'process-users-batch', ... },
     { name: 'get-processing-status', ... }
   ]
   ```

### Issue: Environment Variables Not Working

**Symptoms**:
- Tool fails with "DATABASE_URL is undefined"
- Environment variable substitution not working

**Diagnosis**:
```bash
# Check if variable is set
echo $MY_VAR

# Check Claude config
cat ~/.claude/claude.json | grep -A 5 "env"
```

**Solutions**:

1. **Make sure variable is exported**:
   ```bash
   # Temporary (current terminal only)
   export MY_VAR="value"

   # Permanent (add to ~/.bashrc or ~/.zshrc)
   echo 'export MY_VAR="value"' >> ~/.bashrc
   source ~/.bashrc

   # Verify
   echo $MY_VAR
   ```

2. **Use correct syntax in config**:
   ```json
   {
     "mcpServers": {
       "db": {
         "env": {
           "DATABASE_URL": "${env:DATABASE_URL}"  // ✅ Correct
         }
       }
     }
   }
   ```

3. **Check that variable is set before starting Claude**:
   ```bash
   # Set variable
   export DATABASE_URL="postgresql://..."

   # Start Claude
   claude  # or open the Claude app
   ```

### Issue: "Connection Refused" or "ECONNREFUSED"

**Symptoms**:
- Error mentions "ECONNREFUSED" or "Connection refused"
- Usually for HTTP-based servers

**Diagnosis**:
```bash
# Check if server is running
lsof -i :3000  # For port 3000, adjust as needed

# Try to connect manually
curl http://localhost:3000
```

**Solutions**:

1. **Start the server first**:
   ```bash
   # Terminal 1: Start server
   node http-server.js

   # Terminal 2: Use with Claude
   claude
   ```

2. **Check port availability**:
   ```bash
   # Find what's using the port
   lsof -i :3000

   # Kill the process if needed
   kill -9 <PID>

   # Start your server again
   node http-server.js
   ```

3. **Use stdio instead of HTTP** (simpler, no ports):
   ```json
   {
     "command": "node",
     "args": ["./server.js"]
   }
   ```

### Issue: JSON Parse Error

**Symptoms**:
- Error: "Unexpected token < in JSON at position 0"
- "Invalid JSON" error

**Diagnosis**:
```bash
# Check if server returns JSON
node -e "
  const server = require('./your-server.js');
  // Check what it outputs
" 2>&1 | head -20
```

**Solutions**:

1. **Make sure tool returns proper format**:
   ```javascript
   // ❌ Wrong
   return {
     content: [{ type: 'text', text: '<html>...' }]
   };

   // ✅ Correct
   return {
     content: [{ type: 'text', text: 'Plain text or JSON string' }]
   };
   ```

2. **When returning JSON string, stringify it**:
   ```javascript
   const data = { id: 1, name: 'Alice' };
   return {
     content: [{
       type: 'text',
       text: JSON.stringify(data, null, 2)
     }]
   };
   ```

3. **Remove debug output from server**:
   ```javascript
   // ❌ This breaks JSON output
   console.log('Debug:', something);

   // ✅ Instead, log to file or stderr
   require('fs').appendFileSync('./debug.log', 'Debug: ' + something + '\n');
   ```

### Issue: "Permission Denied" When Running Server

**Symptoms**:
- Error: EACCES or Permission denied
- Can't execute the server

**Solutions**:

1. **Make script executable**:
   ```bash
   chmod +x your-server.js
   ```

2. **Use node explicitly**:
   ```json
   {
     "command": "node",
     "args": ["./your-server.js"]
   }
   ```

3. **Check directory permissions**:
   ```bash
   # Verify directory is readable/writable
   ls -la your-server.js
   # Should show: -rw-r--r-- or similar
   ```

### Issue: Memory Leak or High CPU Usage

**Symptoms**:
- Server uses increasing memory over time
- CPU stays at 100%
- System slows down

**Diagnosis**:
```bash
# Monitor memory usage
watch -n 1 'ps aux | grep your-server.js'

# Or use Node profiling
node --inspect your-server.js
# Then open chrome://inspect
```

**Solutions**:

1. **Close database connections**:
   ```javascript
   server.on('shutdown', async () => {
     await pool.end();  // Close connection pool
   });
   ```

2. **Clear caches periodically**:
   ```javascript
   const cache = new Map();
   const MAX_CACHE_SIZE = 1000;

   function cacheSet(key, value) {
     if (cache.size > MAX_CACHE_SIZE) {
       // Remove oldest entry
       const firstKey = cache.keys().next().value;
       cache.delete(firstKey);
     }
     cache.set(key, value);
   }
   ```

3. **Profile to find leaks**:
   ```bash
   node --prof your-server.js
   # Wait a bit for memory to grow, then Ctrl+C
   node --prof-process *.log > processed.txt
   cat processed.txt | head -50
   ```

## Debugging Techniques

### 1. Add Logging

```javascript
const fs = require('fs');

function log(message, data = {}) {
  const entry = JSON.stringify({
    timestamp: new Date().toISOString(),
    message,
    ...data,
  });
  fs.appendFileSync('./server.log', entry + '\n');
}

server.setRequestHandler('tools/call', async (request) => {
  log('Tool called', { tool: request.params.name });
  try {
    // ... do work
    log('Tool succeeded', { tool: request.params.name });
  } catch (error) {
    log('Tool failed', { tool: request.params.name, error: error.message });
  }
});
```

**View logs**:
```bash
tail -f ./server.log
```

### 2. Add Type Checking

```javascript
// Validate request structure
server.setRequestHandler('tools/call', async (request) => {
  if (!request.params || !request.params.name) {
    throw new Error('Invalid request: missing tool name');
  }

  if (typeof request.params.arguments !== 'object') {
    throw new Error('Invalid request: arguments must be an object');
  }

  // ... proceed
});
```

### 3. Test Each Tool Independently

```javascript
// test-tools.js
const tools = require('./your-server.js');

async function testTool(toolName, args) {
  console.log(`Testing: ${toolName}`);
  try {
    const result = await tools.callTool(toolName, args);
    console.log('✓ Success:', result);
  } catch (error) {
    console.error('✗ Failed:', error.message);
  }
}

async function runTests() {
  await testTool('tool1', { arg1: 'value1' });
  await testTool('tool2', { arg2: 'value2' });
}

runTests();
```

## Getting Help

If you're still stuck:

1. **Check the error message carefully** - it usually tells you what's wrong
2. **Review the server logs** - add logging and check what's happening
3. **Test the server in isolation** - make sure it works without Claude
4. **Simplify your code** - remove complexity one step at a time
5. **Review examples** - see how others solved similar problems

## Common Patterns That Work

### Pattern: Simple Database Tool
See [08-real-world-examples.md](08-real-world-examples.md) - PostgreSQL example

### Pattern: File Operations
See [08-real-world-examples.md](08-real-world-examples.md) - Safe filesystem example

### Pattern: API Integration
See [08-real-world-examples.md](08-real-world-examples.md) - Web API example

---

**Still need help?** Go back and re-read the relevant section from the guide:
- [03-getting-started.md](03-getting-started.md) - Basics
- [04-configuration.md](04-configuration.md) - Claude setup
- [07-building-custom-tools.md](07-building-custom-tools.md) - Building servers
