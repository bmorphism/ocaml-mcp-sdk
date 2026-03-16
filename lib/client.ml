open! Core

module Server_info = struct
  type t =
    { name : string
    ; version : string
    ; capabilities : Json_sexp.json option [@sexp.option]
    }
  [@@deriving sexp_of]
end

let wait_for_response ~id =
  let rec loop () =
    match Mcp_effect.receive_message () with
    | Response { id = resp_id; result } when Yojson.Safe.equal resp_id id ->
      Ok result
    | Error { error; _ } -> Or_error.error_s [%message "RPC error" (error : Jsonrpc.Error_info.t)]
    | _ -> loop ()
  in
  loop ()
;;

let initialize ~client_info =
  let params =
    `Assoc
      [ "protocolVersion", `String "2025-03-26"
      ; "capabilities", `Assoc []
      ; "clientInfo", Implementation_info.to_yojson client_info
      ]
  in
  let id = Mcp_effect.send_request ~method_:"initialize" ~params () in
  match wait_for_response ~id with
  | Ok result ->
    let open Yojson.Safe.Util in
    let server_info_json = result |> member "serverInfo" in
    let info : Server_info.t =
      { name = server_info_json |> member "name" |> to_string
      ; version = server_info_json |> member "version" |> to_string
      ; capabilities = Some (result |> member "capabilities")
      }
    in
    Mcp_effect.send_notification ~method_:"notifications/initialized" ();
    Ok info
  | Error _ as err -> err
;;

let list_tools () =
  let id = Mcp_effect.send_request ~method_:"tools/list" () in
  match wait_for_response ~id with
  | Ok result ->
    let open Yojson.Safe.Util in
    Ok (result |> member "tools" |> to_list)
  | Error _ as err -> err
;;

let call_tool ~name ?arguments () =
  let params =
    `Assoc
      (List.filter_opt
         [ Some ("name", `String name)
         ; Option.map arguments ~f:(fun a -> "arguments", a)
         ])
  in
  let id = Mcp_effect.send_request ~method_:"tools/call" ~params () in
  wait_for_response ~id
;;

let list_resources () =
  let id = Mcp_effect.send_request ~method_:"resources/list" () in
  match wait_for_response ~id with
  | Ok result ->
    let open Yojson.Safe.Util in
    Ok (result |> member "resources" |> to_list)
  | Error _ as err -> err
;;

let read_resource ~uri =
  let params = `Assoc [ "uri", `String uri ] in
  let id = Mcp_effect.send_request ~method_:"resources/read" ~params () in
  match wait_for_response ~id with
  | Ok result ->
    let open Yojson.Safe.Util in
    Ok (result |> member "contents" |> to_list)
  | Error _ as err -> err
;;

let list_prompts () =
  let id = Mcp_effect.send_request ~method_:"prompts/list" () in
  match wait_for_response ~id with
  | Ok result ->
    let open Yojson.Safe.Util in
    Ok (result |> member "prompts" |> to_list)
  | Error _ as err -> err
;;

let get_prompt ~name ?arguments () =
  let params =
    `Assoc
      (List.filter_opt
         [ Some ("name", `String name)
         ; Option.map arguments ~f:(fun a -> "arguments", a)
         ])
  in
  let id = Mcp_effect.send_request ~method_:"prompts/get" ~params () in
  wait_for_response ~id
;;

let run ~client_info f =
  let proto = Protocol.create () in
  Transport.Stdio.run (fun () ->
    Protocol.run proto (fun () ->
      match initialize ~client_info with
      | Ok server_info -> f server_info
      | Error err ->
        raise_s [%message "Failed to initialize MCP client" (err : Error.t)]))
;;
