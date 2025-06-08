# OCaml MCP SDK with oxcaml_effect

An OCaml implementation of the Model Context Protocol (MCP) using Jane Street's `oxcaml_effect` library for algebraic effects.

## Overview

This SDK provides a complete implementation of MCP using OCaml 5's effect system through Jane Street's `oxcaml_effect` library, which provides:

- **O(1) effect dispatch** using handler indices
- **Typed handler lists** using GADTs  
- **Mode annotations** for safe concurrent programming (`@@ portable`, `@ local`, `@ unique`, `@ contended`)
- **Efficient continuations** with proper memory management

## Architecture

The SDK is organized into several effect modules:

### Transport Effect
Handles low-level I/O operations:
```ocaml
type 'a t =
  | Read : string t
  | Write : string -> unit t
  | Close : unit t
```

### Protocol Effect
Manages JSON-RPC protocol:
```ocaml
type 'a t =
  | Send_request : { method_: string; params: json option } -> json t
  | Send_notification : { method_: string; params: json option } -> unit t
  | Receive_message : message t
  | Send_response : { id: json option; result: json option } -> unit t
  | Send_error : { id: json option; code: int; message: string; data: json option } -> unit t
```

### Resource, Tool, and Prompt Effects
Implement MCP capabilities:
```ocaml
(* Resource operations *)
type 'a t =
  | List_resources : json list t
  | Read_resource : string -> json t

(* Tool operations *)  
type 'a t =
  | List_tools : json list t
  | Call_tool : { name: string; arguments: json option } -> json t
```

## Usage

### Creating a Client

```ocaml
open Ocaml_mcp_sdk

let () =
  let client_info = {
    Mcp_client.name = "My Client";
    version = "1.0.0";
  } in
  
  Mcp_client.run_client ~client_info (fun protocol_handler server_info ->
    (* List and read resources *)
    let resources = Mcp_client.list_resources_client protocol_handler in
    
    (* Call tools *)
    let result = Mcp_client.call_tool_client protocol_handler 
      ~name:"my_tool" 
      ~arguments:(Some (`Assoc [("param", `String "value")])) in
    
    Printf.printf "Result: %s\n" (Yojson.Safe.to_string result)
  )
```

### Creating a Server

```ocaml
open Ocaml_mcp_sdk

let () =
  let config = {
    Mcp_server.name = "My Server";
    version = "1.0.0";
    resources = [
      ("file:///data.json", fun () ->
        `Assoc [("data", `String "Hello from OCaml")]
      );
    ];
    tools = [
      ("echo", fun args ->
        match args with
        | Some (`Assoc params) ->
            `Assoc [("echoed", List.assoc "message" params)]
        | _ -> `Assoc [("error", `String "Invalid arguments")]
      );
    ];
    prompts = [];
  } in
  
  Mcp_server.run_server config
```

## Building

The project uses dune and requires OCaml 5.0 or later:

```bash
# Build the project
dune build

# Run examples
dune exec mcp_server_example
dune exec mcp_client_example
```

## Implementation Details

### Effect Composition

The SDK uses `oxcaml_effect`'s typed handler lists to compose multiple effects:

```ocaml
Transport.fiber_with [Handler.List.Length.X; Handler.List.Length.X] 
  (fun handlers ->
    match handlers with
    | protocol_h :: resource_h :: _ ->
        (* Use handlers here *)
    | _ -> failwith "Invalid handler list"
  )
```

### Mode Safety

The implementation leverages OCaml 5's mode system through `oxcaml_effect`:
- `@ local` - Stack-allocated values
- `@ unique` - Linear/affine types
- `@@ portable` - Thread-safe values
- `@ contended` - Values that may be accessed concurrently

### Handler Indices

Effect dispatch is O(1) using handler indices, making the system efficient even with many active effects.

## Dependencies

- OCaml >= 5.0
- dune >= 3.16
- yojson (for JSON handling)
- unix (for stdio)
- oxcaml_effect (vendored from Jane Street's with-extensions branch)

## License

MIT