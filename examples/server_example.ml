(* Example MCP Server using oxcaml_effect *)

open Ocaml_mcp_sdk

let () =
  let config = {
    Mcp_server.name = "OCaml Example Server";
    version = "1.0.0";
    resources = [
      ("file:///example.txt", fun () -> 
        `String "This is example content from the OCaml MCP server!");
      ("file:///data.json", fun () ->
        `Assoc [
          ("message", `String "Hello from OCaml");
          ("timestamp", `String (string_of_float (Unix.time ())));
          ("effects", `Bool true);
        ]);
    ];
    tools = [
      ("echo", fun args ->
        match args with
        | Some (`Assoc params) ->
            (match List.assoc_opt "message" params with
             | Some msg -> `Assoc [("echoed", msg)]
             | None -> `Assoc [("error", `String "No message provided")])
        | _ -> `Assoc [("error", `String "Invalid arguments")]);
      
      ("calculate", fun args ->
        match args with
        | Some (`Assoc params) ->
            (match List.assoc_opt "operation" params,
                   List.assoc_opt "a" params,
                   List.assoc_opt "b" params with
             | Some (`String "add"), Some (`Int a), Some (`Int b) ->
                 `Assoc [("result", `Int (a + b))]
             | Some (`String "multiply"), Some (`Int a), Some (`Int b) ->
                 `Assoc [("result", `Int (a * b))]
             | _ -> `Assoc [("error", `String "Invalid operation or arguments")])
        | _ -> `Assoc [("error", `String "Invalid arguments")]);
    ];
    prompts = [];
  } in
  
  Printf.eprintf "Starting OCaml MCP Server...\n";
  Mcp_server.run_server config