(* Signal operation handlers implementation *)

open Signal_ops
open Printf

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
    (* Parse output JSON to extract results *)
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

(* Main Signal operation handler *)
let handle_signal_operations =
  let open Signal in
  { Result.handle = fun op k ->
    match op with
    | Signal_ops.Extract_messages { storage_path; keychain_password; output_path; date_range } ->
        let result = run_extraction_script storage_path keychain_password output_path date_range in
        continue k result []
        
    | Signal_ops.Extract_media { message_db; output_path; include_metadata; verify_files } ->
        let result = run_media_extraction message_db output_path include_metadata verify_files in
        continue k result []
        
    | Signal_ops.Query_database { db_path; query; limit } ->
        let result = execute_duckdb_query db_path query limit in
        continue k result []
        
    | Signal_ops.Inspect_schema { storage_path; keychain_password } ->
        let result = analyze_signal_schema storage_path keychain_password in
        continue k result []
  }