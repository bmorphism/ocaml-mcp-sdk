(* MCP Server using oxcaml_effect *)

open Mcp_effect

type server_config = {
  name: string;
  version: string;
  resources: (string * (unit -> json)) list;
  tools: (string * (json option -> json)) list;
  prompts: (string * (json option -> json)) list;
}

(* Resource handler *)
let handle_resources config =
  let open Resource in
  { Result.handle = fun op k ->
    match op with
    | Resource_ops.List_resources ->
        let resources = List.map (fun (uri, _) ->
          `Assoc [
            ("uri", `String uri);
            ("name", `String uri);
          ]
        ) config.resources in
        continue k resources []
        
    | Resource_ops.Read_resource uri ->
        (match List.assoc_opt uri config.resources with
         | Some getter ->
             let content = getter () in
             continue k content []
         | None ->
             continue k (`Assoc [
               ("error", `String "Resource not found")
             ]) [])
  }

(* Tool handler *)
let handle_tools config =
  let open Tool in
  { Result.handle = fun op k ->
    match op with
    | Tool_ops.List_tools ->
        let tools = List.map (fun (name, _) ->
          `Assoc [
            ("name", `String name);
            ("description", `String (name ^ " tool"));
            ("inputSchema", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc []);
            ]);
          ]
        ) config.tools in
        continue k tools []
        
    | Tool_ops.Call_tool { name; arguments } ->
        (match List.assoc_opt name config.tools with
         | Some handler ->
             let result = handler arguments in
             continue k result []
         | None ->
             continue k (`Assoc [
               ("error", `String "Tool not found")
             ]) [])
  }

(* Process a single request *)
let process_request protocol_handler resource_handler tool_handler = function
  | Request { id; method_; params } ->
      (match method_ with
       | "initialize" ->
           let response = `Assoc [
             ("protocolVersion", `String "2024-11-05");
             ("capabilities", `Assoc [
               ("resources", `Assoc [("list", `Bool true); ("read", `Bool true)]);
               ("tools", `Assoc [("list", `Bool true); ("call", `Bool true)]);
             ]);
             ("serverInfo", `Assoc [
               ("name", `String "OCaml MCP Server");
               ("version", `String "0.1.0");
             ]);
           ] in
           send_response protocol_handler ~id ~result:(Some response)
           
       | "resources/list" ->
           let resources = list_resources resource_handler in
           let response = `Assoc [("resources", `List resources)] in
           send_response protocol_handler ~id ~result:(Some response)
           
       | "resources/read" ->
           let uri = 
             match params with
             | Some (`Assoc params) ->
                 (match List.assoc_opt "uri" params with
                  | Some (`String uri) -> uri
                  | _ -> "")
             | _ -> ""
           in
           let content = read_resource resource_handler uri in
           let response = `Assoc [
             ("contents", `List [
               `Assoc [
                 ("uri", `String uri);
                 ("text", content);
               ]
             ])
           ] in
           send_response protocol_handler ~id ~result:(Some response)
           
       | "tools/list" ->
           let tools = list_tools tool_handler in
           let response = `Assoc [("tools", `List tools)] in
           send_response protocol_handler ~id ~result:(Some response)
           
       | "tools/call" ->
           let name, arguments =
             match params with
             | Some (`Assoc params) ->
                 let name = match List.assoc_opt "name" params with
                   | Some (`String n) -> n
                   | _ -> ""
                 in
                 let args = List.assoc_opt "arguments" params in
                 (name, args)
             | _ -> ("", None)
           in
           let result = call_tool tool_handler ~name ~arguments in
           send_response protocol_handler ~id ~result:(Some result)
           
       | _ ->
           send_error protocol_handler ~id ~code:(-32601) 
             ~message:"Method not found" ~data:None)
           
  | Notification { method_; params = _ } ->
      (* Handle notifications if needed *)
      Printf.eprintf "Received notification: %s\n" method_
      
  | Response _ ->
      (* Server doesn't typically receive responses *)
      ()

(* Main server loop *)
let serve_forever protocol_handler resource_handler tool_handler =
  let rec loop () =
    let msg = receive_message protocol_handler in
    process_request protocol_handler resource_handler tool_handler msg;
    loop ()
  in
  loop ()

(* Run a server with all effects composed *)
let run_server config =
  Stdio_transport.with_stdio_transport (fun transport_handler ->
    let protocol_state = Protocol_handler.create_protocol_state () in
    
    (* Create a fiber with all required handlers *)
    Transport.fiber_with [Handler.List.Length.X; Handler.List.Length.X; Handler.List.Length.X] 
      (fun handlers ->
        match handlers with
        | protocol_h :: resource_h :: tool_h :: _ ->
            serve_forever protocol_h resource_h tool_h
        | _ -> failwith "Invalid handler list"
      ) |> fun k ->
    
    (* Provide all handlers *)
    let handlers = [
      Protocol_handler.handle_protocol protocol_state transport_handler;
      handle_resources config;
      handle_tools config;
    ] in
    Transport.continue k () handlers
  )