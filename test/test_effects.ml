open! Core
open Mcp

let%expect_test "transport effect handler - stdio roundtrip" =
  let input_data = ref [ "hello"; "world" ] in
  let output_data = Queue.create () in
  Effect.Deep.match_with
    (fun () ->
      let line1 = Mcp_effect.read () in
      Mcp_effect.write [%string "got: %{line1}"];
      let line2 = Mcp_effect.read () in
      Mcp_effect.write [%string "got: %{line2}"];
      Mcp_effect.close ())
    ()
    { retc = Fn.id
    ; exnc = raise
    ; effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Mcp_effect.Transport_read ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                match !input_data with
                | line :: rest ->
                  input_data := rest;
                  Effect.Deep.continue k line
                | [] -> Effect.Deep.continue k "")
          | Mcp_effect.Transport_write data ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                Queue.enqueue output_data data;
                Effect.Deep.continue k ())
          | Mcp_effect.Transport_close ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                Effect.Deep.continue k ())
          | _ -> None)
    };
  Queue.iter output_data ~f:print_endline;
  [%expect {|
    got: hello
    got: world |}]
;;

let%expect_test "protocol effect handler - send request" =
  let written = Queue.create () in
  let proto = Protocol.create () in
  Effect.Deep.match_with
    (fun () ->
      Protocol.run proto (fun () ->
        let id1 = Mcp_effect.send_request ~method_:"test/method" () in
        printf "id1=%s\n" (Yojson.Safe.to_string id1);
        let id2 =
          Mcp_effect.send_request
            ~method_:"test/with_params"
            ~params:(`Assoc [ "key", `String "value" ])
            ()
        in
        printf "id2=%s\n" (Yojson.Safe.to_string id2);
        Mcp_effect.send_notification ~method_:"test/notify" ()))
    ()
    { retc = Fn.id
    ; exnc = raise
    ; effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Mcp_effect.Transport_write data ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                Queue.enqueue written data;
                Effect.Deep.continue k ())
          | _ -> None)
    };
  printf "Messages sent: %d\n" (Queue.length written);
  Queue.iter written ~f:(fun data ->
    let json = Yojson.Safe.from_string data in
    let method_ =
      match Yojson.Safe.Util.member "method" json with
      | `String m -> m
      | _ -> "(response)"
    in
    printf "  method=%s\n" method_);
  [%expect {|
    id1=1
    id2=2
    Messages sent: 3
      method=test/method
      method=test/with_params
      method=test/notify |}]
;;

let%expect_test "signal effects - mock handler" =
  Effect.Deep.match_with
    (fun () ->
      let result =
        Signal.extract_messages
          ~storage_path:"/test/path"
          ~keychain_password:"secret"
          ~output_path:"/test/output"
          ()
      in
      printf "status=%s count=%d\n" result.status result.extracted_count;
      let query_result =
        Signal.query_database
          ~db_path:"/test/db"
          ~query:"SELECT * FROM messages"
          ()
      in
      printf "query_status=%s rows=%d\n" query_result.status (List.length query_result.rows))
    ()
    { retc = Fn.id
    ; exnc = raise
    ; effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Signal.Extract_messages { storage_path; output_path; _ } ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                let result : Signal.Extraction_result.t =
                  { status = "mock_success"
                  ; extracted_count = 42
                  ; output_path
                  ; encryption_status = [%string "decrypted from %{storage_path}"]
                  }
                in
                Effect.Deep.continue k result)
          | Signal.Query_database { query; _ } ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                let result : Signal.Query_result.t =
                  { status = "mock_success"
                  ; rows =
                      [ `Assoc [ "id", `Int 1; "text", `String "hello" ]
                      ; `Assoc [ "id", `Int 2; "text", `String "world" ]
                      ]
                  ; query_time_ms = 1.5
                  }
                in
                ignore (query : string);
                Effect.Deep.continue k result)
          | _ -> None)
    };
  [%expect {|
    status=mock_success count=42
    query_status=mock_success rows=2 |}]
;;

let%expect_test "composed effect handlers - transport + protocol" =
  let input_lines =
    ref
      [ {|{"jsonrpc":"2.0","id":1,"result":{"tools":[]}}|}
      ]
  in
  let output_lines = Queue.create () in
  let proto = Protocol.create () in
  Effect.Deep.match_with
    (fun () ->
      Effect.Deep.match_with
        (fun () ->
          Protocol.run proto (fun () ->
            let id = Mcp_effect.send_request ~method_:"tools/list" () in
            printf "sent request, id=%s\n" (Yojson.Safe.to_string id);
            let msg = Mcp_effect.receive_message () in
            print_s [%sexp (msg : Jsonrpc.Message.t)]))
        ()
        { retc = Fn.id
        ; exnc = raise
        ; effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Mcp_effect.Transport_read ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    match !input_lines with
                    | line :: rest ->
                      input_lines := rest;
                      Effect.Deep.continue k line
                    | [] -> Effect.Deep.continue k "")
              | Mcp_effect.Transport_write data ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    Queue.enqueue output_lines data;
                    Effect.Deep.continue k ())
              | _ -> None)
        })
    ()
    { retc = Fn.id
    ; exnc = raise
    ; effc = (fun (type a) (_eff : a Effect.t) -> None)
    };
  printf "output count: %d\n" (Queue.length output_lines);
  [%expect {|
    sent request, id=1
    (Response (id 1) (result "{\"tools\":[]}"))
    output count: 1
    |}]
;;

let%expect_test "server config to_yojson" =
  let config =
    Server.Config.create
      ~name:"test-server"
      ~version:"0.1.0"
      ~capabilities:
        { tools = Some { list_changed = true }
        ; resources = None
        ; prompts = None
        ; logging = false
        ; completions = false
        ; experimental = []
        }
      ()
  in
  printf "name=%s version=%s\n" config.name config.version;
  [%expect {| name=test-server version=0.1.0 |}]
;;
