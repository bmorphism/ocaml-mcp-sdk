open! Core

module Extraction_result = struct
  type t =
    { status : string
    ; extracted_count : int
    ; output_path : string
    ; encryption_status : string
    }
  [@@deriving sexp_of]

  let to_yojson t =
    `Assoc
      [ "status", `String t.status
      ; "extracted_count", `Int t.extracted_count
      ; "output_path", `String t.output_path
      ; "encryption_status", `String t.encryption_status
      ]
  ;;
end

module Media_result = struct
  type t =
    { status : string
    ; cataloged_count : int
    ; total_size_bytes : int
    ; output_path : string
    }
  [@@deriving sexp_of]

  let to_yojson t =
    `Assoc
      [ "status", `String t.status
      ; "cataloged_count", `Int t.cataloged_count
      ; "total_size_bytes", `Int t.total_size_bytes
      ; "output_path", `String t.output_path
      ]
  ;;
end

module Query_result = struct
  type t =
    { status : string
    ; rows : Yojson.Safe.t list
    ; query_time_ms : float
    }
  [@@deriving sexp_of]

  let to_yojson t =
    `Assoc
      [ "status", `String t.status
      ; "rows", `List t.rows
      ; "query_time_ms", `Float t.query_time_ms
      ; "row_count", `Int (List.length t.rows)
      ]
  ;;
end

module Schema_info = struct
  type t =
    { status : string
    ; tables : string list
    ; total_tables : int
    ; encryption_method : string
    }
  [@@deriving sexp_of]

  let to_yojson t =
    `Assoc
      [ "status", `String t.status
      ; "tables", `List (List.map t.tables ~f:(fun s -> `String s))
      ; "total_tables", `Int t.total_tables
      ; "encryption_method", `String t.encryption_method
      ]
  ;;
end

type _ Effect.t +=
  | Extract_messages :
      { storage_path : string
      ; keychain_password : string
      ; output_path : string
      ; date_range : (string * string) option
      }
      -> Extraction_result.t Effect.t
  | Extract_media :
      { message_db : string
      ; output_path : string
      ; include_metadata : bool
      ; verify_files : bool
      }
      -> Media_result.t Effect.t
  | Query_database :
      { db_path : string
      ; query : string
      ; limit : int
      }
      -> Query_result.t Effect.t
  | Inspect_schema :
      { storage_path : string
      ; keychain_password : string
      }
      -> Schema_info.t Effect.t

let extract_messages ~storage_path ~keychain_password ~output_path ?date_range () =
  Effect.perform
    (Extract_messages { storage_path; keychain_password; output_path; date_range })
;;

let extract_media ~message_db ~output_path ?(include_metadata = true) ?(verify_files = true) () =
  Effect.perform
    (Extract_media { message_db; output_path; include_metadata; verify_files })
;;

let query_database ~db_path ~query ?(limit = 100) () =
  Effect.perform (Query_database { db_path; query; limit })
;;

let inspect_schema ~storage_path ~keychain_password () =
  Effect.perform (Inspect_schema { storage_path; keychain_password })
;;

module Handler = struct
  let run_command cmd =
    let ic = Core_unix.open_process_in cmd in
    let output = In_channel.input_all ic in
    let exit_status = Core_unix.close_process_in ic in
    output, exit_status
  ;;

  let run_extraction_script ~storage_path ~keychain_password ~output_path ~date_range =
    let date_args =
      match date_range with
      | Some (start_date, end_date) ->
        [%string " --start-date %{start_date} --end-date %{end_date}"]
      | None -> ""
    in
    let cmd =
      [%string
        "node scripts/extract-signal-messages.js --storage-path \
         %{Filename.quote storage_path} --output-path %{Filename.quote output_path} \
         --keychain-password %{Filename.quote keychain_password}%{date_args}"]
    in
    let output, exit_status = run_command cmd in
    match exit_status with
    | Ok () ->
      let json = Yojson.Safe.from_string output in
      let open Yojson.Safe.Util in
      { Extraction_result.status = "success"
      ; extracted_count = json |> member "extracted_count" |> to_int
      ; output_path = json |> member "output_path" |> to_string
      ; encryption_status = json |> member "encryption_status" |> to_string
      }
    | Error _ ->
      { status = [%string "error: %{output}"]
      ; extracted_count = 0
      ; output_path = ""
      ; encryption_status = "failed"
      }
  ;;

  let run_media_extraction ~message_db ~output_path ~include_metadata ~verify_files =
    let metadata_flag = if include_metadata then " --include-metadata" else "" in
    let verify_flag = if verify_files then " --verify-files" else "" in
    let cmd =
      [%string
        "node scripts/extract-signal-media.js --message-db \
         %{Filename.quote message_db} --output-path \
         %{Filename.quote output_path}%{metadata_flag}%{verify_flag}"]
    in
    let output, exit_status = run_command cmd in
    match exit_status with
    | Ok () ->
      let json = Yojson.Safe.from_string output in
      let open Yojson.Safe.Util in
      { Media_result.status = "success"
      ; cataloged_count = json |> member "cataloged_count" |> to_int
      ; total_size_bytes = json |> member "total_size_bytes" |> to_int
      ; output_path = json |> member "output_path" |> to_string
      }
    | Error _ ->
      { status = [%string "error: %{output}"]
      ; cataloged_count = 0
      ; total_size_bytes = 0
      ; output_path = ""
      }
  ;;

  let execute_duckdb_query ~db_path ~query ~limit =
    let cmd =
      [%string
        "duckdb %{Filename.quote db_path} -c \"SELECT * FROM (%{String.escaped query}) \
         LIMIT %{limit#Int}\" -json"]
    in
    let start_time = Core_unix.gettimeofday () in
    let output, exit_status = run_command cmd in
    let query_time_ms = (Core_unix.gettimeofday () -. start_time) *. 1000.0 in
    match exit_status with
    | Ok () ->
      let rows =
        match Yojson.Safe.from_string output with
        | `List rows -> rows
        | json -> [ json ]
      in
      { Query_result.status = "success"; rows; query_time_ms }
    | Error _ ->
      { status = [%string "error: %{output}"]; rows = []; query_time_ms }
  ;;

  let analyze_schema ~storage_path ~keychain_password =
    let cmd =
      [%string
        "node scripts/inspect-signal-schema.js --storage-path \
         %{Filename.quote storage_path} --keychain-password \
         %{Filename.quote keychain_password}"]
    in
    let output, exit_status = run_command cmd in
    match exit_status with
    | Ok () ->
      let json = Yojson.Safe.from_string output in
      let open Yojson.Safe.Util in
      { Schema_info.status = "success"
      ; tables = json |> member "tables" |> to_list |> List.map ~f:to_string
      ; total_tables = json |> member "total_tables" |> to_int
      ; encryption_method = json |> member "encryption_method" |> to_string
      }
    | Error _ ->
      { status = [%string "error: %{output}"]
      ; tables = []
      ; total_tables = 0
      ; encryption_method = "unknown"
      }
  ;;

  let run f =
    Effect.Deep.match_with
      f
      ()
      { retc = Fn.id
      ; exnc = raise
      ; effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Extract_messages { storage_path; keychain_password; output_path; date_range }
              ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  let result =
                    run_extraction_script
                      ~storage_path
                      ~keychain_password
                      ~output_path
                      ~date_range
                  in
                  Effect.Deep.continue k result)
            | Extract_media { message_db; output_path; include_metadata; verify_files } ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  let result =
                    run_media_extraction
                      ~message_db
                      ~output_path
                      ~include_metadata
                      ~verify_files
                  in
                  Effect.Deep.continue k result)
            | Query_database { db_path; query; limit } ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  let result = execute_duckdb_query ~db_path ~query ~limit in
                  Effect.Deep.continue k result)
            | Inspect_schema { storage_path; keychain_password } ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  let result = analyze_schema ~storage_path ~keychain_password in
                  Effect.Deep.continue k result)
            | _ -> None)
      }
  ;;
end

module Mcp_handler : Server.Handler = struct
  let tools =
    [ Tool.create
        ~name:"extract_signal_messages"
        ~description:"Extract Signal messages from encrypted database to DuckDB"
        ~input_schema:
          { properties =
              [ ( "storage_path"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Path to Signal data directory"
                       ()) )
              ; ( "output_path"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Output DuckDB file path"
                       ()) )
              ; ( "keychain_password"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Signal database encryption password"
                       ()) )
              ]
          ; required = [ "keychain_password" ]
          }
        ()
    ; Tool.create
        ~name:"extract_media_assets"
        ~description:"Catalog Signal media attachments"
        ~input_schema:
          { properties =
              [ ( "message_db_path"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Path to extracted messages DuckDB"
                       ()) )
              ; ( "output_path"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Output path for media catalog"
                       ()) )
              ; ( "include_metadata"
                , Schema.Primitive.Boolean
                    (Schema.Boolean_schema.create
                       ~description:"Extract file metadata"
                       ~default:true
                       ()) )
              ; ( "verify_files"
                , Schema.Primitive.Boolean
                    (Schema.Boolean_schema.create
                       ~description:"Verify attachment files exist"
                       ~default:true
                       ()) )
              ]
          ; required = [ "message_db_path" ]
          }
        ()
    ; Tool.create
        ~name:"query_signal_data"
        ~description:"Execute SQL queries against Signal databases"
        ~input_schema:
          { properties =
              [ ( "database_path"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Path to DuckDB database"
                       ()) )
              ; ( "query"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"SQL query to execute"
                       ()) )
              ; ( "limit"
                , Schema.Primitive.Number
                    (Schema.Number_schema.create
                       ~description:"Max rows to return"
                       ~minimum:1
                       ~maximum:10000
                       ()) )
              ]
          ; required = [ "database_path"; "query" ]
          }
        ()
    ; Tool.create
        ~name:"inspect_signal_schema"
        ~description:"Analyze Signal database structure"
        ~input_schema:
          { properties =
              [ ( "storage_path"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Path to Signal data directory"
                       ()) )
              ; ( "keychain_password"
                , Schema.Primitive.String
                    (Schema.String_schema.create
                       ~description:"Signal database encryption password"
                       ()) )
              ]
          ; required = [ "keychain_password" ]
          }
        ()
    ]
  ;;

  let resources =
    [ Resource.create
        ~uri:"schema://signal/messages"
        ~name:"Signal Messages Schema"
        ~description:"Complete schema definition for Signal messages table"
        ~mime_type:"application/json"
        ()
    ; Resource.create
        ~uri:"catalog://signal/media/summary"
        ~name:"Media Catalog Summary"
        ~description:"Aggregated media statistics"
        ~mime_type:"application/json"
        ()
    ]
  ;;

  let prompts =
    [ { Prompt.name = "analyze_conversation_patterns"
      ; description = Some "Analyze communication patterns in Signal messages"
      ; arguments =
          [ { Prompt.Argument.name = "contact_name"
            ; description = Some "Name or identifier of contact"
            ; required = false
            }
          ; { name = "time_period"
            ; description = Some "Time period for analysis"
            ; required = false
            }
          ]
      }
    ; { name = "find_media_memories"
      ; description = Some "Discover significant photos/videos shared in conversations"
      ; arguments =
          [ { name = "media_type"
            ; description = Some "Type of media (photo, video, all)"
            ; required = false
            }
          ; { name = "date_context"
            ; description = Some "Date or event context for search"
            ; required = false
            }
          ]
      }
    ; { name = "export_conversation_archive"
      ; description = Some "Create portable archive of specific conversations"
      ; arguments =
          [ { name = "contacts"
            ; description = Some "Contacts to include"
            ; required = true
            }
          ; { name = "format"
            ; description = Some "Export format (html, json, pdf)"
            ; required = false
            }
          ]
      }
    ]
  ;;

  let handle_tool_call ~name ~arguments =
    let open Yojson.Safe.Util in
    match name with
    | "extract_signal_messages" ->
      let storage_path =
        arguments
        |> member "storage_path"
        |> to_string_option
        |> Option.value ~default:"~/Library/Application Support/Signal"
      in
      let output_path =
        arguments
        |> member "output_path"
        |> to_string_option
        |> Option.value ~default:"exports/signal-messages.duckdb"
      in
      let keychain_password = arguments |> member "keychain_password" |> to_string in
      let date_range =
        match arguments |> member "date_range" with
        | `Null -> None
        | range_obj ->
          (try
             let start_date = range_obj |> member "start" |> to_string in
             let end_date = range_obj |> member "end" |> to_string in
             Some (start_date, end_date)
           with
           | _ -> None)
      in
      let result =
        extract_messages ~storage_path ~keychain_password ~output_path ?date_range ()
      in
      Server.Tool_result.ok
        [ Content.text (Yojson.Safe.pretty_to_string (Extraction_result.to_yojson result))
        ]
    | "extract_media_assets" ->
      let message_db = arguments |> member "message_db_path" |> to_string in
      let output_path =
        arguments
        |> member "output_path"
        |> to_string_option
        |> Option.value ~default:"exports/signal-media.duckdb"
      in
      let include_metadata =
        arguments |> member "include_metadata" |> to_bool_option |> Option.value ~default:true
      in
      let verify_files =
        arguments |> member "verify_files" |> to_bool_option |> Option.value ~default:true
      in
      let result = extract_media ~message_db ~output_path ~include_metadata ~verify_files () in
      Server.Tool_result.ok
        [ Content.text (Yojson.Safe.pretty_to_string (Media_result.to_yojson result)) ]
    | "query_signal_data" ->
      let db_path = arguments |> member "database_path" |> to_string in
      let query = arguments |> member "query" |> to_string in
      let limit =
        arguments |> member "limit" |> to_int_option |> Option.value ~default:100
      in
      let result = query_database ~db_path ~query ~limit () in
      Server.Tool_result.ok
        [ Content.text (Yojson.Safe.pretty_to_string (Query_result.to_yojson result)) ]
    | "inspect_signal_schema" ->
      let storage_path =
        arguments
        |> member "storage_path"
        |> to_string_option
        |> Option.value ~default:"~/Library/Application Support/Signal"
      in
      let keychain_password = arguments |> member "keychain_password" |> to_string in
      let result = inspect_schema ~storage_path ~keychain_password () in
      Server.Tool_result.ok
        [ Content.text (Yojson.Safe.pretty_to_string (Schema_info.to_yojson result)) ]
    | _ -> Server.Tool_result.error [%string "Unknown tool: %{name}"]
  ;;

  let handle_read_resource ~uri =
    [ Content.Resource_contents.Text
        { uri; text = [%string "Content of %{uri}"]; mime_type = Some "application/json" }
    ]
  ;;

  let handle_get_prompt ~name ~arguments:_ =
    [ { Prompt.Message.role = Role.User
      ; content = Content.text [%string "Execute prompt: %{name}"]
      }
    ]
  ;;
end
