open! Core
open Mcp

let%expect_test "encode request" =
  let msg =
    Jsonrpc.Message.request
      ~id:(`Int 1)
      ~method_:"tools/list"
      ~params:(`Assoc [ "cursor", `Null ])
      ()
  in
  print_endline (Jsonrpc.Message.encode msg);
  [%expect
    {| {"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"cursor":null}} |}]
;;

let%expect_test "encode notification" =
  let msg = Jsonrpc.Message.notification ~method_:"notifications/initialized" () in
  print_endline (Jsonrpc.Message.encode msg);
  [%expect {| {"jsonrpc":"2.0","method":"notifications/initialized"} |}]
;;

let%expect_test "encode response" =
  let msg =
    Jsonrpc.Message.response
      ~id:(`Int 1)
      ~result:(`Assoc [ "tools", `List [] ])
  in
  print_endline (Jsonrpc.Message.encode msg);
  [%expect {| {"jsonrpc":"2.0","id":1,"result":{"tools":[]}} |}]
;;

let%expect_test "encode error" =
  let msg =
    Jsonrpc.Message.error
      ~id:(`Int 1)
      (Jsonrpc.Error_info.method_not_found "foo/bar")
  in
  print_endline (Jsonrpc.Message.encode msg);
  [%expect
    {| {"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found: foo/bar"}} |}]
;;

let%expect_test "decode request" =
  let line =
    {|{"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":"test"}}|}
  in
  let msg = Jsonrpc.Message.decode_exn line in
  print_s [%sexp (msg : Jsonrpc.Message.t)];
  [%expect {| (Request (id 42) (method_ tools/call) (params "{\"name\":\"test\"}")) |}]
;;

let%expect_test "decode notification" =
  let line = {|{"jsonrpc":"2.0","method":"notifications/initialized"}|} in
  let msg = Jsonrpc.Message.decode_exn line in
  print_s [%sexp (msg : Jsonrpc.Message.t)];
  [%expect {| (Notification (method_ notifications/initialized)) |}]
;;

let%expect_test "decode response" =
  let line = {|{"jsonrpc":"2.0","id":1,"result":{"status":"ok"}}|} in
  let msg = Jsonrpc.Message.decode_exn line in
  print_s [%sexp (msg : Jsonrpc.Message.t)];
  [%expect {| (Response (id 1) (result "{\"status\":\"ok\"}")) |}]
;;

let%expect_test "decode error response" =
  let line =
    {|{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}|}
  in
  let msg = Jsonrpc.Message.decode_exn line in
  print_s [%sexp (msg : Jsonrpc.Message.t)];
  [%expect
    {| (Error (id 1) (error ((code -32601) (message "Method not found")))) |}]
;;

let%expect_test "decode returns Or_error for bad input" =
  let result = Jsonrpc.Message.decode "not json at all" in
  printf "%b\n" (Result.is_error result);
  [%expect {| true |}]
;;

let%expect_test "id generator produces sequential ids" =
  let gen = Jsonrpc.Id_generator.create () in
  let id1 = Jsonrpc.Id_generator.next_id gen in
  let id2 = Jsonrpc.Id_generator.next_id gen in
  let id3 = Jsonrpc.Id_generator.next_id gen in
  printf "%s %s %s\n"
    (Yojson.Safe.to_string id1)
    (Yojson.Safe.to_string id2)
    (Yojson.Safe.to_string id3);
  [%expect {| 1 2 3 |}]
;;

let%expect_test "roundtrip request" =
  let original =
    Jsonrpc.Message.request
      ~id:(`Int 7)
      ~method_:"resources/read"
      ~params:(`Assoc [ "uri", `String "file:///test" ])
      ()
  in
  let encoded = Jsonrpc.Message.encode original in
  let decoded = Jsonrpc.Message.decode_exn encoded in
  let re_encoded = Jsonrpc.Message.encode decoded in
  printf "%b\n" (String.equal encoded re_encoded);
  [%expect {| true |}]
;;
