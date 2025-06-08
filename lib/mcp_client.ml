(* MCP Client using oxcaml_effect *)

open Mcp_effect

type client_info = {
  name: string;
  version: string;
}

type server_info = {
  name: string;
  version: string;
  capabilities: json option;
}

(* Initialize connection *)
let initialize protocol_handler ~client_info =
  let params = `Assoc [
    ("protocolVersion", `String "2024-11-05");
    ("capabilities", `Assoc []);
    ("clientInfo", `Assoc [
      ("name", `String client_info.name);
      ("version", `String client_info.version);
    ]);
  ] in
  
  let response = send_request protocol_handler ~method_:"initialize" ~params:(Some params) in
  
  (* Wait for response *)
  let rec wait_for_response id =
    match receive_message protocol_handler with
    | Response { id = Some resp_id; result = Some result; _ } when resp_id = id ->
        result
    | _ -> wait_for_response id
  in
  
  match response with
  | `Int id -> 
      let result = wait_for_response (`Int id) in
      let open Yojson.Safe.Util in
      let server_info = result |> member "serverInfo" in
      {
        name = server_info |> member "name" |> to_string;
        version = server_info |> member "version" |> to_string;
        capabilities = Some (result |> member "capabilities");
      }
  | _ -> failwith "Invalid response from initialize"

(* List available resources *)
let list_resources_client protocol_handler =
  let response = send_request protocol_handler ~method_:"resources/list" ~params:None in
  
  let rec wait_for_response id =
    match receive_message protocol_handler with
    | Response { id = Some resp_id; result = Some result; _ } when resp_id = id ->
        result
    | _ -> wait_for_response id
  in
  
  match response with
  | `Int id ->
      let result = wait_for_response (`Int id) in
      let open Yojson.Safe.Util in
      result |> member "resources" |> to_list
  | _ -> []

(* Read a resource *)
let read_resource_client protocol_handler uri =
  let params = `Assoc [("uri", `String uri)] in
  let response = send_request protocol_handler ~method_:"resources/read" ~params:(Some params) in
  
  let rec wait_for_response id =
    match receive_message protocol_handler with
    | Response { id = Some resp_id; result = Some result; _ } when resp_id = id ->
        result
    | _ -> wait_for_response id
  in
  
  match response with
  | `Int id ->
      let result = wait_for_response (`Int id) in
      let open Yojson.Safe.Util in
      result |> member "contents" |> to_list |> List.hd
  | _ -> `Null

(* Call a tool *)
let call_tool_client protocol_handler ~name ~arguments =
  let params = `Assoc (
    ("name", `String name) ::
    (match arguments with
     | Some args -> [("arguments", args)]
     | None -> [])
  ) in
  let response = send_request protocol_handler ~method_:"tools/call" ~params:(Some params) in
  
  let rec wait_for_response id =
    match receive_message protocol_handler with
    | Response { id = Some resp_id; result = Some result; _ } when resp_id = id ->
        result
    | _ -> wait_for_response id
  in
  
  match response with
  | `Int id -> wait_for_response (`Int id)
  | _ -> `Null

(* Run a client with all effects composed *)
let run_client ~client_info f =
  Stdio_transport.with_stdio_transport (fun transport_handler ->
    let protocol_state = Protocol_handler.create_protocol_state () in
    
    (* Run protocol handler within transport context *)
    Transport.fiber_with [Handler.List.Length.X] (fun handlers ->
      let protocol_handler = List.hd handlers in
      
      (* Initialize connection *)
      let server_info = initialize protocol_handler ~client_info in
      
      (* Run user function with protocol handler *)
      f protocol_handler server_info
    ) |> fun k ->
    
    (* Handle protocol operations *)
    let handlers = [Protocol_handler.handle_protocol protocol_state transport_handler] in
    Transport.continue k () handlers
  )