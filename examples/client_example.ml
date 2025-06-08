(* Example MCP Client using oxcaml_effect *)

open Ocaml_mcp_sdk

let () =
  let client_info = {
    Mcp_client.name = "OCaml Example Client";
    version = "1.0.0";
  } in
  
  Mcp_client.run_client ~client_info (fun protocol_handler server_info ->
    Printf.printf "Connected to server: %s v%s\n" 
      server_info.name server_info.version;
    
    (* List resources *)
    Printf.printf "\nListing resources...\n";
    let resources = Mcp_client.list_resources_client protocol_handler in
    List.iter (fun resource ->
      let open Yojson.Safe.Util in
      let uri = resource |> member "uri" |> to_string in
      Printf.printf "- %s\n" uri
    ) resources;
    
    (* Read a resource if available *)
    (match resources with
     | resource :: _ ->
         let open Yojson.Safe.Util in
         let uri = resource |> member "uri" |> to_string in
         Printf.printf "\nReading resource: %s\n" uri;
         let content = Mcp_client.read_resource_client protocol_handler uri in
         Printf.printf "Content: %s\n" (Yojson.Safe.to_string content)
     | [] ->
         Printf.printf "No resources available\n");
    
    (* Call a tool *)
    Printf.printf "\nCalling example tool...\n";
    let result = Mcp_client.call_tool_client protocol_handler 
      ~name:"echo" 
      ~arguments:(Some (`Assoc [("message", `String "Hello from OCaml!")])) in
    Printf.printf "Tool result: %s\n" (Yojson.Safe.to_string result)
  )