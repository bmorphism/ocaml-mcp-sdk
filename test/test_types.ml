open! Core
open Mcp

let%expect_test "Role sexp roundtrip" =
  let roles = [ Role.User; Role.Assistant ] in
  List.iter roles ~f:(fun role ->
    print_s [%sexp (role : Role.t)]);
  [%expect {|
    User
    Assistant |}]
;;

let%expect_test "Role to/from yojson" =
  let role = Role.User in
  let json = Role.to_yojson role in
  let role' = Role.of_yojson json in
  printf "%b\n" (Role.equal role role');
  [%expect {| true |}]
;;

let%expect_test "Role of_string" =
  let role = Role.of_string "assistant" in
  printf "%s\n" (Role.to_string role);
  [%expect {| assistant |}]
;;

let%expect_test "Log_level ordering" =
  let levels =
    [ Log_level.Debug; Log_level.Info; Log_level.Warning
    ; Log_level.Error; Log_level.Critical; Log_level.Alert
    ; Log_level.Emergency
    ]
  in
  List.iter levels ~f:(fun level ->
    printf "%s\n" (Log_level.to_string level));
  [%expect {|
    debug
    info
    warning
    error
    critical
    alert
    emergency |}]
;;

let%expect_test "Content.text" =
  let content = Content.text "hello world" in
  let json = Content.to_yojson content in
  print_endline (Yojson.Safe.to_string json);
  [%expect {| {"type":"text","text":"hello world"} |}]
;;

let%expect_test "Content.image" =
  let content = Content.image ~data:"base64data" ~mime_type:"image/png" () in
  let json = Content.to_yojson content in
  print_endline (Yojson.Safe.to_string json);
  [%expect {| {"type":"image","data":"base64data","mimeType":"image/png"} |}]
;;

let%expect_test "Request_id" =
  let id_int = Request_id.Int 42 in
  let id_str = Request_id.String "abc-123" in
  printf "%s %s\n" (Request_id.to_string id_int) (Request_id.to_string id_str);
  print_s [%sexp (id_int : Request_id.t)];
  [%expect {|
    42 abc-123
    (Int 42) |}]
;;

let%expect_test "Implementation_info to_yojson" =
  let info = { Implementation_info.name = "test-server"; version = "2.0.0" } in
  print_endline (Yojson.Safe.to_string (Implementation_info.to_yojson info));
  [%expect {| {"name":"test-server","version":"2.0.0"} |}]
;;

let%expect_test "Tool to_yojson" =
  let tool =
    Tool.create
      ~name:"my_tool"
      ~description:"A test tool"
      ~input_schema:
        { Schema.Input.properties =
            [ "query"
            , Schema.Primitive.String
                (Schema.String_schema.create ~description:"The query" ())
            ]
        ; required = [ "query" ]
        }
      ()
  in
  let json = Tool.to_yojson tool in
  print_endline (Yojson.Safe.pretty_to_string json);
  [%expect {|
    {
      "name": "my_tool",
      "description": "A test tool",
      "inputSchema": {
        "type": "object",
        "properties": {
          "query": { "type": "string", "description": "The query" }
        },
        "required": [ "query" ]
      }
    }
    |}]
;;

let%expect_test "Resource to_yojson" =
  let resource =
    Resource.create
      ~uri:"file:///data/test.db"
      ~name:"Test DB"
      ~description:"A test database"
      ~mime_type:"application/x-sqlite3"
      ()
  in
  let json = Resource.to_yojson resource in
  print_endline (Yojson.Safe.pretty_to_string json);
  [%expect {|
    {
      "uri": "file:///data/test.db",
      "name": "Test DB",
      "description": "A test database",
      "mimeType": "application/x-sqlite3"
    } |}]
;;

let%expect_test "Prompt to_yojson" =
  let prompt =
    Prompt.create
      ~description:"Analyze data"
      ~arguments:
        [ { Prompt.Argument.name = "format"
          ; description = Some "Output format"
          ; required = true
          }
        ]
      "analyze"
  in
  let json = Prompt.to_yojson prompt in
  print_endline (Yojson.Safe.pretty_to_string json);
  [%expect {|
    {
      "name": "analyze",
      "description": "Analyze data",
      "arguments": [
        { "name": "format", "description": "Output format", "required": true }
      ]
    } |}]
;;

let%expect_test "Server capabilities to_yojson" =
  let caps : Capabilities.Server.t =
    { tools = Some { list_changed = true }
    ; resources = Some { list_changed = false; subscribe = true }
    ; prompts = Some { list_changed = true }
    ; logging = true
    ; completions = false
    ; experimental = [ "effects", true ]
    }
  in
  let json = Capabilities.Server.to_yojson caps in
  print_endline (Yojson.Safe.pretty_to_string json);
  [%expect {|
    {
      "tools": { "listChanged": true },
      "resources": { "listChanged": false, "subscribe": true },
      "prompts": { "listChanged": true },
      "logging": {},
      "experimental": { "effects": true }
    } |}]
;;
