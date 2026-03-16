open! Core
open Mcp

let%expect_test "Signal.Mcp_handler.tools are well-formed" =
  List.iter Signal.Mcp_handler.tools ~f:(fun (tool : Tool.t) ->
    printf "tool: %s\n" tool.name;
    let json = Tool.to_yojson tool in
    let name =
      Yojson.Safe.Util.member "name" json
      |> Yojson.Safe.Util.to_string
    in
    printf "  json name matches: %b\n" (String.equal name tool.name));
  [%expect {|
    tool: extract_signal_messages
      json name matches: true
    tool: extract_media_assets
      json name matches: true
    tool: query_signal_data
      json name matches: true
    tool: inspect_signal_schema
      json name matches: true |}]
;;

let%expect_test "Signal.Mcp_handler.resources are well-formed" =
  List.iter Signal.Mcp_handler.resources ~f:(fun (resource : Resource.t) ->
    printf "resource: %s [%s]\n" resource.name resource.uri);
  [%expect {|
    resource: Signal Messages Schema [schema://signal/messages]
    resource: Media Catalog Summary [catalog://signal/media/summary] |}]
;;

let%expect_test "Signal.Mcp_handler.prompts are well-formed" =
  List.iter Signal.Mcp_handler.prompts ~f:(fun (prompt : Prompt.t) ->
    printf "prompt: %s (%d args)\n" prompt.name (List.length prompt.arguments));
  [%expect {|
    prompt: analyze_conversation_patterns (2 args)
    prompt: find_media_memories (2 args)
    prompt: export_conversation_archive (2 args) |}]
;;

let%expect_test "Signal effect results serialize to json" =
  let extraction : Signal.Extraction_result.t =
    { status = "success"
    ; extracted_count = 100
    ; output_path = "/tmp/output.duckdb"
    ; encryption_status = "decrypted"
    }
  in
  print_endline (Yojson.Safe.pretty_to_string (Signal.Extraction_result.to_yojson extraction));
  [%expect {|
    {
      "status": "success",
      "extracted_count": 100,
      "output_path": "/tmp/output.duckdb",
      "encryption_status": "decrypted"
    } |}]
;;

let%expect_test "Signal query result serialization" =
  let result : Signal.Query_result.t =
    { status = "success"
    ; rows = [ `Assoc [ "id", `Int 1 ]; `Assoc [ "id", `Int 2 ] ]
    ; query_time_ms = 3.14
    }
  in
  let json = Signal.Query_result.to_yojson result in
  let row_count =
    Yojson.Safe.Util.member "row_count" json
    |> Yojson.Safe.Util.to_int
  in
  printf "row_count=%d\n" row_count;
  [%expect {| row_count=2 |}]
;;

let%expect_test "Signal.Mcp_handler.handle_tool_call with mock effects" =
  Effect.Deep.match_with
    (fun () ->
      let result =
        Signal.Mcp_handler.handle_tool_call
          ~name:"query_signal_data"
          ~arguments:
            (`Assoc
               [ "database_path", `String "/test/db.duckdb"
               ; "query", `String "SELECT 1"
               ])
      in
      printf "is_error=%b\n" result.is_error)
    ()
    { retc = Fn.id
    ; exnc = raise
    ; effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Signal.Query_database _ ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                Effect.Deep.continue k
                  { Signal.Query_result.status = "success"
                  ; rows = [ `Assoc [ "result", `Int 1 ] ]
                  ; query_time_ms = 0.5
                  })
          | _ -> None)
    };
  [%expect {| is_error=false |}]
;;

let%expect_test "Signal.Mcp_handler.handle_tool_call unknown tool" =
  let result =
    Signal.Mcp_handler.handle_tool_call
      ~name:"nonexistent_tool"
      ~arguments:(`Assoc [])
  in
  printf "is_error=%b\n" result.is_error;
  [%expect {| is_error=true |}]
;;
