open! Core

module Config = struct
  type t =
    { name : string
    ; version : string
    ; capabilities : Capabilities.Server.t
    }
  [@@deriving sexp_of]

  let create ~name ~version ?(capabilities = Capabilities.Server.default) () =
    { name; version; capabilities }
  ;;
end

module Init_result = struct
  type t =
    { protocol_version : string
    ; capabilities : Capabilities.Server.t
    ; server_info : Implementation_info.t
    ; instructions : string option
    }
  [@@deriving sexp_of]

  let to_yojson t =
    `Assoc
      (List.filter_opt
         [ Some ("protocolVersion", `String t.protocol_version)
         ; Some ("capabilities", Capabilities.Server.to_yojson t.capabilities)
         ; Some ("serverInfo", Implementation_info.to_yojson t.server_info)
         ; Option.map t.instructions ~f:(fun i -> "instructions", `String i)
         ])
  ;;
end

module Tool_result = struct
  type t =
    { content : Content.t list
    ; is_error : bool
    }
  [@@deriving sexp_of]

  let ok contents = { content = contents; is_error = false }
  let error msg = { content = [ Content.text msg ]; is_error = true }

  let to_yojson t =
    `Assoc
      [ "content", `List (List.map t.content ~f:Content.to_yojson)
      ; "isError", `Bool t.is_error
      ]
  ;;
end

module type Handler = sig
  val tools : Tool.t list
  val resources : Resource.t list
  val prompts : Prompt.t list
  val handle_tool_call : name:string -> arguments:Yojson.Safe.t -> Tool_result.t
  val handle_read_resource : uri:string -> Content.Resource_contents.t list
  val handle_get_prompt : name:string -> arguments:(string * string) list -> Prompt.Message.t list
end

let process_request (module H : Handler) config ~id ~method_ ~params =
  let open Yojson.Safe.Util in
  let params = Option.value params ~default:`Null in
  match method_ with
  | "initialize" ->
    let result =
      Init_result.to_yojson
        { protocol_version = "2025-03-26"
        ; capabilities = config.Config.capabilities
        ; server_info =
            { name = config.name; version = config.version }
        ; instructions = None
        }
    in
    Mcp_effect.send_response ~id ~result
  | "ping" -> Mcp_effect.send_response ~id ~result:(`Assoc [])
  | "tools/list" ->
    let result =
      `Assoc
        [ "tools", `List (List.map H.tools ~f:Tool.to_yojson) ]
    in
    Mcp_effect.send_response ~id ~result
  | "tools/call" ->
    let name = params |> member "name" |> to_string in
    let arguments =
      match params |> member "arguments" with
      | `Null -> `Assoc []
      | args -> args
    in
    let tool_result = H.handle_tool_call ~name ~arguments in
    Mcp_effect.send_response ~id ~result:(Tool_result.to_yojson tool_result)
  | "resources/list" ->
    let result =
      `Assoc
        [ "resources", `List (List.map H.resources ~f:Resource.to_yojson) ]
    in
    Mcp_effect.send_response ~id ~result
  | "resources/read" ->
    let uri = params |> member "uri" |> to_string in
    let contents = H.handle_read_resource ~uri in
    let result =
      `Assoc
        [ ( "contents"
          , `List (List.map contents ~f:Content.Resource_contents.to_yojson) )
        ]
    in
    Mcp_effect.send_response ~id ~result
  | "resources/templates/list" ->
    Mcp_effect.send_response ~id ~result:(`Assoc [ "resourceTemplates", `List [] ])
  | "prompts/list" ->
    let result =
      `Assoc
        [ "prompts", `List (List.map H.prompts ~f:Prompt.to_yojson) ]
    in
    Mcp_effect.send_response ~id ~result
  | "prompts/get" ->
    let name = params |> member "name" |> to_string in
    let arguments =
      match params |> member "arguments" with
      | `Assoc pairs ->
        List.map pairs ~f:(fun (k, v) ->
          k, Yojson.Safe.Util.to_string v)
      | _ -> []
    in
    let messages = H.handle_get_prompt ~name ~arguments in
    let result =
      `Assoc
        [ ( "messages"
          , `List
              (List.map messages ~f:(fun (m : Prompt.Message.t) ->
                 `Assoc
                   [ "role", Role.to_yojson m.role
                   ; "content", Content.to_yojson m.content
                   ])) )
        ]
    in
    Mcp_effect.send_response ~id ~result
  | _ ->
    Mcp_effect.send_error
      ~id
      (Jsonrpc.Error_info.method_not_found method_)
;;

let process_message handler config msg =
  match (msg : Jsonrpc.Message.t) with
  | Request { id; method_; params } ->
    process_request handler config ~id ~method_ ~params
  | Notification { method_; params = _ } ->
    Mcp_effect.log Log_level.Debug [%string "Notification: %{method_}"]
  | Response _ | Error _ -> ()
;;

let serve_forever handler config =
  let rec loop () =
    let msg = Mcp_effect.receive_message () in
    process_message handler config msg;
    loop ()
  in
  loop ()
;;

let run handler ~config =
  let proto = Protocol.create () in
  Transport.Stdio.run (fun () ->
    Protocol.run proto (fun () ->
      Effect.Deep.match_with
        (fun () -> serve_forever handler config)
        ()
        { retc = Fn.id
        ; exnc = raise
        ; effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Mcp_effect.Log (_level, _msg) ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    Effect.Deep.continue k ())
              | _ -> None)
        }))
;;
