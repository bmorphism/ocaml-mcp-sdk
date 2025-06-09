# Signal Data Extraction as MCP Server

## Overview

Transform the Pensieve Signal extraction toolkit into a Model Context Protocol (MCP) server that provides AI assistants with secure, structured access to Signal message data through tools, resources, and prompts.

## MCP Server Architecture

### Core Capabilities

**Server Name**: `pensieve-signal-mcp`  
**Protocol Version**: `2025-03-26`  
**Transport**: stdio (local execution)

### Security Model

- **Keychain Integration**: Secure access to Signal encryption keys
- **Local-Only**: No network access, operates on local Signal databases
- **Permission-Based**: User consent required for each extraction operation
- **Audit Trail**: All operations logged for transparency

## 1. Tools (Function Calls)

### `extract_signal_messages`
```json
{
  "name": "extract_signal_messages",
  "description": "Extract Signal messages from encrypted database to DuckDB for analysis",
  "inputSchema": {
    "type": "object",
    "properties": {
      "storage_path": {
        "type": "string",
        "description": "Path to Signal data directory",
        "default": "~/Library/Application Support/Signal"
      },
      "output_path": {
        "type": "string", 
        "description": "Output DuckDB file path",
        "default": "exports/signal-messages.duckdb"
      },
      "keychain_password": {
        "type": "string",
        "description": "Signal database encryption password"
      },
      "date_range": {
        "type": "object",
        "properties": {
          "start": {"type": "string", "format": "date"},
          "end": {"type": "string", "format": "date"}
        }
      }
    },
    "required": ["keychain_password"]
  }
}
```

### `extract_media_assets`
```json
{
  "name": "extract_media_assets", 
  "description": "Catalog Signal media attachments and create searchable database",
  "inputSchema": {
    "type": "object",
    "properties": {
      "message_db_path": {
        "type": "string",
        "description": "Path to extracted messages DuckDB"
      },
      "output_path": {
        "type": "string",
        "description": "Output path for media catalog DuckDB"
      },
      "include_metadata": {
        "type": "boolean", 
        "description": "Extract file metadata (size, type, etc.)",
        "default": true
      },
      "verify_files": {
        "type": "boolean",
        "description": "Verify attachment files exist on disk",
        "default": true
      }
    },
    "required": ["message_db_path"]
  }
}
```

### `query_signal_data`
```json
{
  "name": "query_signal_data",
  "description": "Execute SQL queries against Signal databases",
  "inputSchema": {
    "type": "object", 
    "properties": {
      "database_path": {
        "type": "string",
        "description": "Path to DuckDB database file"
      },
      "query": {
        "type": "string",
        "description": "SQL query to execute"
      },
      "limit": {
        "type": "integer",
        "description": "Maximum number of rows to return",
        "default": 100
      }
    },
    "required": ["database_path", "query"]
  }
}
```

### `inspect_signal_schema`
```json
{
  "name": "inspect_signal_schema",
  "description": "Analyze Signal database structure and provide schema information",
  "inputSchema": {
    "type": "object",
    "properties": {
      "storage_path": {
        "type": "string",
        "description": "Path to Signal data directory"
      },
      "keychain_password": {
        "type": "string", 
        "description": "Signal database encryption password"
      }
    },
    "required": ["keychain_password"]
  }
}
```

## 2. Resources (Data Access)

### Signal Database Schemas
- **URI**: `schema://signal/messages`
- **Type**: `application/json`
- **Description**: Complete schema definition for Signal messages table

### Extraction Statistics  
- **URI**: `stats://signal/extraction/{session_id}`
- **Type**: `application/json`
- **Description**: Real-time extraction progress and statistics

### Media Catalog Summary
- **URI**: `catalog://signal/media/summary`
- **Type**: `application/json` 
- **Description**: Aggregated media statistics (file types, sizes, counts)

### Query Results Cache
- **URI**: `cache://signal/query/{query_hash}`
- **Type**: `application/json`
- **Description**: Cached results from previous queries

## 3. Prompts (AI Workflows)

### `analyze_conversation_patterns`
```json
{
  "name": "analyze_conversation_patterns",
  "description": "Analyze communication patterns in Signal messages",
  "arguments": [
    {
      "name": "contact_name",
      "description": "Name or identifier of contact to analyze",
      "required": false
    },
    {
      "name": "time_period", 
      "description": "Time period for analysis (e.g., 'last 6 months')",
      "required": false
    }
  ]
}
```

### `find_media_memories`
```json
{
  "name": "find_media_memories",
  "description": "Discover significant photos/videos shared in conversations",
  "arguments": [
    {
      "name": "media_type",
      "description": "Type of media to search (photo, video, all)",
      "required": false
    },
    {
      "name": "date_context",
      "description": "Date or event context for search",
      "required": false  
    }
  ]
}
```

### `export_conversation_archive`
```json
{
  "name": "export_conversation_archive", 
  "description": "Create portable archive of specific conversations",
  "arguments": [
    {
      "name": "contacts",
      "description": "List of contacts to include in archive",
      "required": true
    },
    {
      "name": "format",
      "description": "Export format (html, json, pdf)",
      "required": false
    }
  ]
}
```

## 4. Implementation Using OCaml MCP SDK

### Effect Operations

```ocaml
(* Signal-specific effect operations *)
module Signal_ops = struct
  type 'a t =
    | Extract_messages : { storage_path: string; keychain_password: string; output_path: string } -> extraction_result t
    | Extract_media : { message_db: string; output_path: string } -> media_result t  
    | Query_database : { db_path: string; query: string; limit: int } -> query_result t
    | Inspect_schema : { storage_path: string; keychain_password: string } -> schema_info t
end

module Signal = Make(Signal_ops)
```

### Handler Implementation

```ocaml
let handle_signal_operations =
  let open Signal in
  { Result.handle = fun op k ->
    match op with
    | Signal_ops.Extract_messages { storage_path; keychain_password; output_path } ->
        (* Execute extraction script *)
        let result = run_extraction_script storage_path keychain_password output_path in
        continue k result []
        
    | Signal_ops.Extract_media { message_db; output_path } ->
        (* Execute media cataloging script *)
        let result = run_media_extraction message_db output_path in
        continue k result []
        
    | Signal_ops.Query_database { db_path; query; limit } ->
        (* Execute DuckDB query *)
        let result = execute_duckdb_query db_path query limit in
        continue k result []
        
    | Signal_ops.Inspect_schema { storage_path; keychain_password } ->
        (* Analyze Signal database schema *)
        let result = analyze_signal_schema storage_path keychain_password in
        continue k result []
  }
```

## 5. Security and Privacy Considerations

### Data Protection
- **Encryption at Rest**: All extracted databases encrypted by default
- **Memory Safety**: Modal types prevent data leaks (`@unique` for sensitive data)
- **Audit Logging**: All operations logged with timestamps and user consent

### Access Control
- **User Consent**: Each operation requires explicit user approval
- **Keychain Integration**: Secure password storage and retrieval
- **Local Processing**: No network transmission of sensitive data

### Privacy Features
- **Selective Extraction**: Extract only specific date ranges or contacts
- **Anonymization**: Option to hash or remove identifying information
- **Automatic Cleanup**: Temporary files securely deleted after processing

## 6. Client Integration Examples

### Claude Desktop Integration
```json
{
  "mcpServers": {
    "pensieve-signal": {
      "command": "./pensieve-signal-mcp-server",
      "args": [],
      "cwd": "~/infinity-topos/pensieve"
    }
  }
}
```

### Typical Workflow
1. **Extract**: AI calls `extract_signal_messages` tool
2. **Analyze**: AI queries data using `query_signal_data` 
3. **Discover**: AI uses prompts to find patterns and insights
4. **Present**: AI formats results using accessible visualizations

## 7. Benefits of MCP Architecture

### For AI Assistants
- **Structured Access**: Type-safe tools and consistent data formats
- **Contextual Prompts**: Pre-built workflows for common analysis tasks
- **Real-time Resources**: Access to live extraction status and cached results

### For Users
- **Consent-Based**: Explicit control over each data access operation
- **Audit Trail**: Complete log of all AI interactions with personal data
- **Local Processing**: Data never leaves the local machine

### For Developers
- **Extensible**: Easy to add new analysis tools and workflows
- **Testable**: Effect system enables comprehensive testing without Signal data
- **Safe**: Modal types prevent common security vulnerabilities

This MCP architecture transforms the Signal extraction toolkit from a manual process into an AI-accessible service while maintaining strong security and privacy guarantees.