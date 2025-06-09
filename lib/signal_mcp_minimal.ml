(* Minimal Signal MCP Server Implementation *)

open Printf

(* Core types for Signal operations *)
type extraction_result = {
  status: string;
  extracted_count: int;
  output_path: string;
  encryption_status: string;
}

type media_result = {
  status: string;
  cataloged_count: int;
  total_size_bytes: int;
  output_path: string;
}

type query_result = {
  status: string;
  rows: Yojson.Safe.t list;
  query_time_ms: float;
}

type schema_info = {
  status: string;
  tables: string list;
  total_tables: int;
  encryption_method: string;
}

(* External script execution utilities *)
let run_command ?(timeout=300.0) cmd =
  let ic = Unix.open_process_in cmd in
  let output = really_input_string ic (in_channel_length ic) in
  let exit_code = Unix.close_process_in ic in
  (output, exit_code)

(* Signal operation implementations *)
let extract_signal_messages ~storage_path ~keychain_password ~output_path ?date_range () =
  let date_args = match date_range with
    | Some (start_date, end_date) -> sprintf " --start-date %s --end-date %s" start_date end_date
    | None -> ""
  in
  let cmd = sprintf "node scripts/extract-signal-messages.js --storage-path %s --output-path %s --keychain-password %s%s" 
    (Filename.quote storage_path) 
    (Filename.quote output_path)
    (Filename.quote keychain_password)
    date_args
  in
  let (output, exit_code) = run_command cmd in
  match exit_code with
  | Unix.WEXITED 0 ->
    let json = Yojson.Safe.from_string output in
    let open Yojson.Safe.Util in
    {
      status = "success";
      extracted_count = json |> member "extracted_count" |> to_int;
      output_path = json |> member "output_path" |> to_string;
      encryption_status = json |> member "encryption_status" |> to_string;
    }
  | _ ->
    {
      status = sprintf "error: %s" output;
      extracted_count = 0;
      output_path = "";
      encryption_status = "failed";
    }

let extract_media_assets ~message_db ~output_path ~include_metadata ~verify_files =
  let metadata_flag = if include_metadata then " --include-metadata" else "" in
  let verify_flag = if verify_files then " --verify-files" else "" in
  let cmd = sprintf "node scripts/extract-signal-media.js --message-db %s --output-path %s%s%s"
    (Filename.quote message_db)
    (Filename.quote output_path)
    metadata_flag
    verify_flag
  in
  let (output, exit_code) = run_command cmd in
  match exit_code with
  | Unix.WEXITED 0 ->
    let json = Yojson.Safe.from_string output in
    let open Yojson.Safe.Util in
    {
      status = "success";
      cataloged_count = json |> member "cataloged_count" |> to_int;
      total_size_bytes = json |> member "total_size_bytes" |> to_int;
      output_path = json |> member "output_path" |> to_string;
    }
  | _ ->
    {
      status = sprintf "error: %s" output;
      cataloged_count = 0;
      total_size_bytes = 0;
      output_path = "";
    }

let query_signal_data ~db_path ~query ~limit =
  let cmd = sprintf "duckdb %s -c \"SELECT * FROM (%s) LIMIT %d\" -json"
    (Filename.quote db_path)
    (String.escaped query)
    limit
  in
  let start_time = Unix.gettimeofday () in
  let (output, exit_code) = run_command cmd in
  let end_time = Unix.gettimeofday () in
  let query_time_ms = (end_time -. start_time) *. 1000.0 in
  
  match exit_code with
  | Unix.WEXITED 0 ->
    let rows = match Yojson.Safe.from_string output with
      | `List rows -> rows
      | json -> [json]
    in
    {
      status = "success";
      rows = rows;
      query_time_ms = query_time_ms;
    }
  | _ ->
    {
      status = sprintf "error: %s" output;
      rows = [];
      query_time_ms = query_time_ms;
    }

let inspect_signal_schema ~storage_path ~keychain_password =
  let cmd = sprintf "node scripts/inspect-signal-schema.js --storage-path %s --keychain-password %s"
    (Filename.quote storage_path)
    (Filename.quote keychain_password)
  in
  let (output, exit_code) = run_command cmd in
  match exit_code with
  | Unix.WEXITED 0 ->
    let json = Yojson.Safe.from_string output in
    let open Yojson.Safe.Util in
    {
      status = "success";
      tables = json |> member "tables" |> to_list |> List.map to_string;
      total_tables = json |> member "total_tables" |> to_int;
      encryption_method = json |> member "encryption_method" |> to_string;
    }
  | _ ->
    {
      status = sprintf "error: %s" output;
      tables = [];
      total_tables = 0;
      encryption_method = "unknown";
    }

(* MCP JSON-RPC message handling *)
type mcp_request = {
  id: Yojson.Safe.t option;
  method_: string;
  params: Yojson.Safe.t option;
}

type mcp_response = {
  id: Yojson.Safe.t option;
  result: Yojson.Safe.t option;
  error: (int * string * Yojson.Safe.t option) option;
}

let parse_mcp_request json =
  let open Yojson.Safe.Util in
  {
    id = json |> member "id" |> to_option (fun x -> x);
    method_ = json |> member "method" |> to_string;
    params = json |> member "params" |> to_option (fun x -> x);
  }

let mcp_response_to_json response =
  let base = [
    ("jsonrpc", `String "2.0");
    ("id", match response.id with Some id -> id | None -> `Null);
  ] in
  match response.error with
  | Some (code, message, data) ->
    let error_obj = [
      ("code", `Int code);
      ("message", `String message);
    ] @ (match data with Some d -> [("data", d)] | None -> []) in
    `Assoc (base @ [("error", `Assoc error_obj)])
  | None ->
    `Assoc (base @ [("result", match response.result with Some r -> r | None -> `Null)])

(* Tool execution handlers *)
let handle_tool_call tool_name arguments =
  let open Yojson.Safe.Util in
  try
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
      let result = extract_signal_messages ~storage_path ~keychain_password ~output_path ?date_range () in
      let response = `Assoc [
        ("status", `String result.status);
        ("extracted_count", `Int result.extracted_count);
        ("output_path", `String result.output_path);
        ("encryption_status", `String result.encryption_status)
      ] in
      `List [`Assoc [("type", `String "text"); ("text", `String (Yojson.Safe.pretty_to_string response))]]

    | "extract_media_assets" ->
      let message_db = arguments |> member "message_db_path" |> to_string in
      let output_path = arguments |> member "output_path" |> to_string_option |> Option.value ~default:"exports/signal-media.duckdb" in
      let include_metadata = arguments |> member "include_metadata" |> to_bool_option |> Option.value ~default:true in
      let verify_files = arguments |> member "verify_files" |> to_bool_option |> Option.value ~default:true in
      let result = extract_media_assets ~message_db ~output_path ~include_metadata ~verify_files in
      let response = `Assoc [
        ("status", `String result.status);
        ("cataloged_count", `Int result.cataloged_count);
        ("total_size_bytes", `Int result.total_size_bytes);
        ("output_path", `String result.output_path)
      ] in
      `List [`Assoc [("type", `String "text"); ("text", `String (Yojson.Safe.pretty_to_string response))]]

    | "query_signal_data" ->
      let db_path = arguments |> member "database_path" |> to_string in
      let query = arguments |> member "query" |> to_string in
      let limit = arguments |> member "limit" |> to_int_option |> Option.value ~default:100 in
      let result = query_signal_data ~db_path ~query ~limit in
      let response = `Assoc [
        ("status", `String result.status);
        ("rows", `List result.rows);
        ("query_time_ms", `Float result.query_time_ms);
        ("row_count", `Int (List.length result.rows))
      ] in
      `List [`Assoc [("type", `String "text"); ("text", `String (Yojson.Safe.pretty_to_string response))]]

    | "inspect_signal_schema" ->
      let storage_path = arguments |> member "storage_path" |> to_string_option |> Option.value ~default:"~/Library/Application Support/Signal" in
      let keychain_password = arguments |> member "keychain_password" |> to_string in
      let result = inspect_signal_schema ~storage_path ~keychain_password in
      let response = `Assoc [
        ("status", `String result.status);
        ("tables", `List (List.map (fun s -> `String s) result.tables));
        ("total_tables", `Int result.total_tables);
        ("encryption_method", `String result.encryption_method)
      ] in
      `List [`Assoc [("type", `String "text"); ("text", `String (Yojson.Safe.pretty_to_string response))]]

    | _ -> 
      `List [`Assoc [("type", `String "text"); ("text", `String (sprintf "Unknown tool: %s" tool_name)); ("isError", `Bool true)]]
  with
  | exn ->
    `List [`Assoc [("type", `String "text"); ("text", `String (sprintf "Error executing tool %s: %s" tool_name (Printexc.to_string exn))); ("isError", `Bool true)]]

(* MCP message processing *)
let process_mcp_request request =
  let open Yojson.Safe.Util in
  match request.method_ with
  | "initialize" ->
    let response = `Assoc [
      ("protocolVersion", `String "2025-03-26");
      ("serverInfo", `Assoc [
        ("name", `String "pensieve-signal-mcp");
        ("version", `String "1.0.0")
      ]);
      ("capabilities", `Assoc [
        ("tools", `Assoc [("listChanged", `Bool true)]);
        ("resources", `Assoc [("listChanged", `Bool true); ("subscribe", `Bool true)]);
        ("prompts", `Assoc [("listChanged", `Bool true)]);
        ("logging", `Assoc [])
      ])
    ] in
    { id = request.id; result = Some response; error = None }

  | "tools/list" ->
    let tools = `List [
      `Assoc [
        ("name", `String "extract_signal_messages");
        ("description", `String "Extract Signal messages from encrypted database to DuckDB for analysis")
      ];
      `Assoc [
        ("name", `String "extract_media_assets");
        ("description", `String "Catalog Signal media attachments and create searchable database")
      ];
      `Assoc [
        ("name", `String "query_signal_data");
        ("description", `String "Execute SQL queries against Signal databases")
      ];
      `Assoc [
        ("name", `String "inspect_signal_schema");
        ("description", `String "Analyze Signal database structure and provide schema information")
      ]
    ] in
    { id = request.id; result = Some (`Assoc [("tools", tools)]); error = None }

  | "tools/call" ->
    (match request.params with
     | Some params ->
       let tool_name = params |> member "name" |> to_string in
       let arguments = params |> member "arguments" |> to_option (fun x -> x) |> Option.value ~default:(`Assoc []) in
       let content = handle_tool_call tool_name arguments in
       { id = request.id; result = Some (`Assoc [("content", content)]); error = None }
     | None ->
       { id = request.id; result = None; error = Some (-32602, "Invalid params", None) })

  | _ ->
    { id = request.id; result = None; error = Some (-32601, "Method not found", None) }

(* Main server loop *)
let run_signal_mcp_server () =
  printf "Pensieve Signal MCP Server v1.0.0 - Ready\n%!";
  
  try
    while true do
      let line = read_line () in
      if String.trim line <> "" then
        try
          let json = Yojson.Safe.from_string line in
          let request = parse_mcp_request json in
          let response = process_mcp_request request in
          let response_json = mcp_response_to_json response in
          printf "%s\n%!" (Yojson.Safe.to_string response_json)
        with
        | exn ->
          let error_response = {
            id = None;
            result = None;
            error = Some (-32700, "Parse error: " ^ (Printexc.to_string exn), None)
          } in
          let response_json = mcp_response_to_json error_response in
          printf "%s\n%!" (Yojson.Safe.to_string response_json)
    done
  with
  | End_of_file -> ()
  | exn ->
    printf "Server error: %s\n%!" (Printexc.to_string exn)