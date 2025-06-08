# Getting Started with OCaml MCP SDK

## Prerequisites

- OCaml 5.0 or higher (for algebraic effects support)
- opam package manager
- dune build system
- just command runner

## Installation

### From Source

```bash
git clone https://github.com/yourusername/ocaml-mcp-sdk.git
cd ocaml-mcp-sdk
just init    # Install dependencies
just build   # Build the project
```

### Via opam

```bash
opam install ocaml-mcp-sdk
```

## Quick Start

### Creating a Simple Server

```ocaml
open Mcp

(* Define a simple tool *)
let echo_tool = Tool.{
  name = "echo";
  description = "Echoes back the input";
  parameters = [{
    name = "message";
    description = "Message to echo";
    required = true;
    schema = `Assoc [("type", `String "string")];
  }];
}

(* Handle tool calls *)
let handle_tool_call (name, params) =
  match name with
  | "echo" ->
      begin match params with
      | `Assoc fields ->
          let message = 
            match List.assoc_opt "message" fields with
            | Some (`String msg) -> msg
            | _ -> "No message provided"
          in
          `Assoc [("content", `List [
            `Assoc [
              ("type", `String "text");
              ("text", `String message);
            ]
          ])]
      | _ -> raise (Invalid_params "Invalid parameters")
      end
  | _ -> raise (Method_not_found name)

(* Create and run the server *)
let () =
  let config = Server.{
    server_info = {
      name = "Echo Server";
      version = "1.0.0";
    };
    capabilities = {
      resources = false;
      tools = true;
      prompts = false;
    };
  } in
  
  Server.stdio config
    ~resources:(fun _ -> ([], fun _ -> raise Not_found))
    ~tools:(fun _ -> ([echo_tool], handle_tool_call))
    ~prompts:(fun _ -> ([], fun _ -> raise Not_found))
```

### Creating a Simple Client

```ocaml
open Mcp

let () =
  let config = Client.{
    client_info = {
      name = "Echo Client";
      version = "1.0.0";
    };
    capabilities = {
      resources = false;
      tools = true;
      prompts = false;
    };
  } in
  
  Client.with_stdio config (fun protocol ->
    (* Initialize connection *)
    let server_info = Protocol.perform protocol (Initialize config.client_info) in
    Printf.printf "Connected to: %s v%s\n" server_info.name server_info.version;
    
    (* Call the echo tool *)
    let result = Protocol.perform protocol (CallTool ("echo", `Assoc [
      ("message", `String "Hello, MCP!")
    ])) in
    
    (* Print result *)
    Printf.printf "Result: %s\n" (Yojson.Safe.to_string result);
    
    (* Shutdown *)
    Protocol.perform protocol Shutdown
  )
```

## Understanding Effects

The OCaml MCP SDK uses algebraic effects to handle operations. Here's how they work:

### Transport Effect

```ocaml
(* Define custom transport behavior *)
let logging_transport base_handler = 
  { Transport.Result.handle = fun op k ->
      match op with
      | Send json ->
          Printf.printf "Sending: %s\n" (Yojson.Safe.to_string json);
          Transport.Result.handle (Transport.Value ()) base_handler
      | Receive ->
          let result = Transport.perform base_handler Receive in
          Printf.printf "Received: %s\n" (Yojson.Safe.to_string result);
          continue k result []
      | Close ->
          Printf.printf "Closing connection\n";
          Transport.Result.handle (Transport.Value ()) base_handler
  }
```

### Composing Effects

```ocaml
(* Stack multiple effects *)
Transport.run (fun transport ->
  Resource.run (fun resource ->
    Tool.run (fun tool ->
      (* All three effects available here *)
      let _ = Transport.perform transport (Send (`String "test")) in
      let resources = Resource.perform resource List in
      let tools = Tool.perform tool List in
      ()
    )
  )
)
```

## Next Steps

- Read the [API documentation](API.md)
- See more [examples](../examples/)
- Learn about [advanced patterns](ADVANCED.md)