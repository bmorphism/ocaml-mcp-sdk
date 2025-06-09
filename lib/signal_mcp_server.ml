(* Signal MCP Server Implementation *)

open Mcp_effect
open Signal_ops
open Signal_handlers
open Printf

(* MCP Tool definitions matching the design specification *)
let tool_extract_signal_messages = {
  name = "extract_signal_messages";
  description = "Extract Signal messages from encrypted database to DuckDB for analysis";
  inputSchema = `Assoc [
    ("type", `String "object");
    ("properties", `Assoc [
      ("storage_path", `Assoc [
        ("type", `String "string");
        ("description", `String "Path to Signal data directory");
        ("default", `String "~/Library/Application Support/Signal")
      ]);
      ("output_path", `Assoc [
        ("type", `String "string");
        ("description", `String "Output DuckDB file path");
        ("default", `String "exports/signal-messages.duckdb")
      ]);
      ("keychain_password", `Assoc [
        ("type", `String "string");
        ("description", `String "Signal database encryption password")
      ]);
      ("date_range", `Assoc [
        ("type", `String "object");
        ("properties", `Assoc [
          ("start", `Assoc [("type", `String "string"); ("format", `String "date")]);
          ("end", `Assoc [("type", `String "string"); ("format", `String "date")])
        ])
      ])
    ]);
    ("required", `List [`String "keychain_password"])
  ]
}

let tool_extract_media_assets = {
  name = "extract_media_assets";
  description = "Catalog Signal media attachments and create searchable database";
  inputSchema = `Assoc [
    ("type", `String "object");
    ("properties", `Assoc [
      ("message_db_path", `Assoc [
        ("type", `String "string");
        ("description", `String "Path to extracted messages DuckDB")
      ]);
      ("output_path", `Assoc [
        ("type", `String "string");
        ("description", `String "Output path for media catalog DuckDB")
      ]);
      ("include_metadata", `Assoc [
        ("type", `String "boolean");
        ("description", `String "Extract file metadata (size, type, etc.)");
        ("default", `Bool true)
      ]);
      ("verify_files", `Assoc [
        ("type", `String "boolean");
        ("description", `String "Verify attachment files exist on disk");
        ("default", `Bool true)
      ])
    ]);
    ("required", `List [`String "message_db_path"])
  ]
}

let tool_query_signal_data = {
  name = "query_signal_data";
  description = "Execute SQL queries against Signal databases";
  inputSchema = `Assoc [
    ("type", `String "object");
    ("properties", `Assoc [
      ("database_path", `Assoc [
        ("type", `String "string");
        ("description", `String "Path to DuckDB database file")
      ]);
      ("query", `Assoc [
        ("type", `String "string");
        ("description", `String "SQL query to execute")
      ]);
      ("limit", `Assoc [
        ("type", `String "integer");
        ("description", `String "Maximum number of rows to return");
        ("default", `Int 100)
      ])
    ]);
    ("required", `List [`String "database_path"; `String "query"])
  ]
}

let tool_inspect_signal_schema = {
  name = "inspect_signal_schema";
  description = "Analyze Signal database structure and provide schema information";
  inputSchema = `Assoc [
    ("type", `String "object");
    ("properties", `Assoc [
      ("storage_path", `Assoc [
        ("type", `String "string");
        ("description", `String "Path to Signal data directory")
      ]);
      ("keychain_password", `Assoc [
        ("type", `String "string");
        ("description", `String "Signal database encryption password")
      ])
    ]);
    ("required", `List [`String "keychain_password"])
  ]
}

(* MCP Resource definitions *)
let resource_signal_message_schema = {
  uri = "schema://signal/messages";
  name = "Signal Messages Schema";
  description = "Complete schema definition for Signal messages table";
  mimeType = Some "application/json";
}

let resource_extraction_stats pattern = {
  uri = sprintf "stats://signal/extraction/%s" pattern;
  name = "Extraction Statistics";
  description = "Real-time extraction progress and statistics";
  mimeType = Some "application/json";
}

let resource_media_catalog_summary = {
  uri = "catalog://signal/media/summary";
  name = "Media Catalog Summary";
  description = "Aggregated media statistics (file types, sizes, counts)";
  mimeType = Some "application/json";
}

let resource_query_cache pattern = {
  uri = sprintf "cache://signal/query/%s" pattern;
  name = "Query Results Cache";
  description = "Cached results from previous queries";
  mimeType = Some "application/json";
}

(* MCP Prompt definitions *)
let prompt_analyze_conversation_patterns = {
  name = "analyze_conversation_patterns";
  description = "Analyze communication patterns in Signal messages";
  arguments = [
    { name = "contact_name"; description = "Name or identifier of contact to analyze"; required = false };
    { name = "time_period"; description = "Time period for analysis (e.g., 'last 6 months')"; required = false }
  ]
}

let prompt_find_media_memories = {
  name = "find_media_memories"; 
  description = "Discover significant photos/videos shared in conversations";
  arguments = [
    { name = "media_type"; description = "Type of media to search (photo, video, all)"; required = false };
    { name = "date_context"; description = "Date or event context for search"; required = false }
  ]
}

let prompt_export_conversation_archive = {
  name = "export_conversation_archive";
  description = "Create portable archive of specific conversations";
  arguments = [
    { name = "contacts"; description = "List of contacts to include in archive"; required = true };
    { name = "format"; description = "Export format (html, json, pdf)"; required = false }
  ]
}

(* Tool execution handlers *)
let handle_tool_call h tool_name arguments =
  let open Yojson.Safe.Util in
  match tool_name with
  | "extract_signal_messages" ->
    let storage_path = arguments |> member "storage_path" |> to_string_option |> Option.value ~default:"~/Library/Application Support/Signal" in
    let output_path = arguments |> member "output_path" |> to_string_option |> Option.value ~default:"exports/signal-messages.duckdb" in
    let keychain_password = arguments |> member "keychain_password" |> to_string in
    let date_range = 
      try
        let range_obj = arguments |> member "date_range" in
        let start_date = range_obj |> member "start" |> to_string in
        let end_date = range_obj |> member "end" |> to_string in
        Some (start_date, end_date)
      with _ -> None
    in
    let result = extract_signal_messages h ~storage_path ~keychain_password ~output_path ?date_range () in
    let response = `Assoc [
      ("status", `String result.status);
      ("extracted_count", `Int result.extracted_count);
      ("output_path", `String result.output_path);
      ("encryption_status", `String result.encryption_status)
    ] in
    [{ type_ = "text"; text = Yojson.Safe.pretty_to_string response }]

  | "extract_media_assets" ->
    let message_db = arguments |> member "message_db_path" |> to_string in
    let output_path = arguments |> member "output_path" |> to_string_option |> Option.value ~default:"exports/signal-media.duckdb" in
    let include_metadata = arguments |> member "include_metadata" |> to_bool_option |> Option.value ~default:true in
    let verify_files = arguments |> member "verify_files" |> to_bool_option |> Option.value ~default:true in
    let result = extract_media_assets h ~message_db ~output_path ~include_metadata ~verify_files in
    let response = `Assoc [
      ("status", `String result.status);
      ("cataloged_count", `Int result.cataloged_count);
      ("total_size_bytes", `Int result.total_size_bytes);
      ("output_path", `String result.output_path)
    ] in
    [{ type_ = "text"; text = Yojson.Safe.pretty_to_string response }]

  | "query_signal_data" ->
    let db_path = arguments |> member "database_path" |> to_string in
    let query = arguments |> member "query" |> to_string in
    let limit = arguments |> member "limit" |> to_int_option |> Option.value ~default:100 in
    let result = query_signal_data h ~db_path ~query ~limit in
    let response = `Assoc [
      ("status", `String result.status);
      ("rows", `List result.rows);
      ("query_time_ms", `Float result.query_time_ms);
      ("row_count", `Int (List.length result.rows))
    ] in
    [{ type_ = "text"; text = Yojson.Safe.pretty_to_string response }]

  | "inspect_signal_schema" ->
    let storage_path = arguments |> member "storage_path" |> to_string_option |> Option.value ~default:"~/Library/Application Support/Signal" in
    let keychain_password = arguments |> member "keychain_password" |> to_string in
    let result = inspect_signal_schema h ~storage_path ~keychain_password in
    let response = `Assoc [
      ("status", `String result.status);
      ("tables", `List (List.map (fun s -> `String s) result.tables));
      ("total_tables", `Int result.total_tables);
      ("encryption_method", `String result.encryption_method)
    ] in
    [{ type_ = "text"; text = Yojson.Safe.pretty_to_string response }]

  | _ -> 
    [{ type_ = "text"; text = sprintf "Unknown tool: %s" tool_name; isError = Some true }]

(* Server capabilities *)
let server_capabilities = {
  tools = Some { listChanged = Some true };
  resources = Some { listChanged = Some true; subscribe = Some true };
  prompts = Some { listChanged = Some true };
  logging = Some {};
}

(* Main server implementation *)
let create_signal_mcp_server () =
  let tools = [
    tool_extract_signal_messages;
    tool_extract_media_assets; 
    tool_query_signal_data;
    tool_inspect_signal_schema
  ] in
  let resources = [
    resource_signal_message_schema;
    resource_media_catalog_summary
  ] in
  let prompts = [
    prompt_analyze_conversation_patterns;
    prompt_find_media_memories;
    prompt_export_conversation_archive
  ] in
  
  {
    name = "pensieve-signal-mcp";
    version = "1.0.0";
    capabilities = server_capabilities;
    tools = tools;
    resources = resources;  
    prompts = prompts;
    tool_handler = handle_tool_call;
  }

(* Server initialization with Signal handlers *)
let run_signal_mcp_server () =
  let server = create_signal_mcp_server () in
  let handler_list = [handle_signal_operations] in
  
  printf "Starting Pensieve Signal MCP Server v%s\n" server.version;
  printf "Capabilities: Tools=%d, Resources=%d, Prompts=%d\n" 
    (List.length server.tools)
    (List.length server.resources) 
    (List.length server.prompts);
  
  (* Run server with Signal operation handlers *)
  Signal.run (fun () ->
    Mcp_server.start_stdio_server server handler_list
  )