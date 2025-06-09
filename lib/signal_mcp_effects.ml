(* Signal MCP Server with Proper Effect System *)

open Printf
open Oxcaml_effect

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

(* STEP 1 - Describe Signal operations using GADT *)
module Signal_ops = struct
  type 'a t =
    | Extract_messages : { 
        storage_path: string; 
        keychain_password: string; 
        output_path: string;
        date_range: (string * string) option;
      } -> extraction_result t
    | Extract_media : { 
        message_db: string; 
        output_path: string;
        include_metadata: bool;
        verify_files: bool;
      } -> media_result t  
    | Query_database : { 
        db_path: string; 
        query: string; 
        limit: int;
      } -> query_result t
    | Inspect_schema : { 
        storage_path: string; 
        keychain_password: string;
      } -> schema_info t
end

(* STEP 2 - Instantiate the functor *)
module Signal = Make(Signal_ops)

(* External script execution utilities *)
let run_command ?(timeout=300.0) cmd =
  let ic = Unix.open_process_in cmd in
  let output = really_input_string ic (in_channel_length ic) in
  let exit_code = Unix.close_process_in ic in
  (output, exit_code)

let run_extraction_script storage_path keychain_password output_path date_range =
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

let run_media_extraction message_db output_path include_metadata verify_files =
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

let execute_duckdb_query db_path query limit =
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

let analyze_signal_schema storage_path keychain_password =
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

(* STEP 3 - Write a handler *)
let signal_handler =
  let open Signal in
  { Result.handle = fun op k ->
    match op with
    | Signal_ops.Extract_messages { storage_path; keychain_password; output_path; date_range } ->
        let result = run_extraction_script storage_path keychain_password output_path date_range in
        k result []
        
    | Signal_ops.Extract_media { message_db; output_path; include_metadata; verify_files } ->
        let result = run_media_extraction message_db output_path include_metadata verify_files in
        k result []
        
    | Signal_ops.Query_database { db_path; query; limit } ->
        let result = execute_duckdb_query db_path query limit in
        k result []
        
    | Signal_ops.Inspect_schema { storage_path; keychain_password } ->
        let result = analyze_signal_schema storage_path keychain_password in
        k result []
  }

(* Helper functions for Signal operations *)
let extract_signal_messages handler ~storage_path ~keychain_password ~output_path ?date_range () =
  Signal.perform handler (Signal_ops.Extract_messages { 
    storage_path; 
    keychain_password; 
    output_path;
    date_range;
  })

let extract_media_assets handler ~message_db ~output_path ~include_metadata ~verify_files =
  Signal.perform handler (Signal_ops.Extract_media { 
    message_db; 
    output_path;
    include_metadata;
    verify_files;
  })

let query_signal_data handler ~db_path ~query ~limit =
  Signal.perform handler (Signal_ops.Query_database { 
    db_path; 
    query; 
    limit;
  })

let inspect_signal_schema handler ~storage_path ~keychain_password =
  Signal.perform handler (Signal_ops.Inspect_schema { 
    storage_path; 
    keychain_password;
  })

(* MCP Tool execution with effects *)
let handle_tool_call_with_effects handler tool_name arguments =
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
      let result = extract_signal_messages handler ~storage_path ~keychain_password ~output_path ?date_range () in
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
      let result = extract_media_assets handler ~message_db ~output_path ~include_metadata ~verify_files in
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
      let result = query_signal_data handler ~db_path ~query ~limit in
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
      let result = inspect_signal_schema handler ~storage_path ~keychain_password in
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

(* Main server function using effects *)
let run_signal_mcp_server_with_effects () =
  printf "Pensieve Signal MCP Server v1.0.0 with Effects - Ready\n%!";
  
  (* Run the server with Signal handler in scope *)
  Signal.run (fun () ->
    printf "Effect system initialized with Signal handler\n%!";
    printf "Server ready to process MCP requests...\n%!"
  )