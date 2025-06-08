# OCaml MCP SDK API Reference

## Core Module: `Mcp`

### Types

#### `protocol_version`
```ocaml
type protocol_version = string
```
The MCP protocol version string.

#### `client_info` / `server_info`
```ocaml
type client_info = {
  name: string;
  version: string;
}

type server_info = {
  name: string;
  version: string;
}
```
Information about the client or server implementation.

### Module: `JsonRpc`

Types and functions for JSON-RPC 2.0 protocol.

```ocaml
type id = 
  | String of string
  | Number of int
  | Null

type error = {
  code: int;
  message: string;
  data: Yojson.Safe.t option;
}
```

### Module: `Transport`

Effect for handling transport operations.

```ocaml
type ('a, 'e) ops =
  | Send : Yojson.Safe.t -> (unit, 'e) ops
  | Receive : (Yojson.Safe.t, 'e) ops
  | Close : (unit, 'e) ops

val perform : t Handler.t -> ('a, t) ops -> 'a
```

#### `StdioTransport`
```ocaml
val run : (Transport.t Handler.t -> 'a) -> 'a
```
Run with stdio transport (reads from stdin, writes to stdout).

#### `HttpTransport`
```ocaml
type config = {
  base_url: string;
  headers: (string * string) list;
}

val run : config -> (Transport.t Handler.t -> 'a) -> 'a
val run_sse : config -> (Transport.t Handler.t -> 'a) -> 'a
```

### Module: `Protocol`

Effect for MCP protocol operations.

```ocaml
type ('a, 'e) ops =
  | Initialize : client_info -> (server_info, 'e) ops
  | ListResources : ((string * string) list, 'e) ops
  | ReadResource : string -> (Yojson.Safe.t, 'e) ops
  | ListTools : ((string * string) list, 'e) ops
  | CallTool : (string * Yojson.Safe.t) -> (Yojson.Safe.t, 'e) ops
  | ListPrompts : ((string * string) list, 'e) ops
  | GetPrompt : string -> (string, 'e) ops
  | Shutdown : (unit, 'e) ops

val perform : t Handler.t -> ('a, t) ops -> 'a
```

### Module: `Resource`

Effect for resource management.

```ocaml
type t = {
  uri: string;
  name: string;
  description: string option;
  mime_type: string option;
}

type contents = 
  | Text of string
  | Binary of bytes

type ('a, 'e) ops =
  | List : (t list, 'e) ops
  | Read : string -> (contents, 'e) ops
```

### Module: `Tool`

Effect for tool management.

```ocaml
type parameter = {
  name: string;
  description: string;
  required: bool;
  schema: Yojson.Safe.t;
}

type t = {
  name: string;
  description: string;
  parameters: parameter list;
}

type ('a, 'e) ops =
  | List : (t list, 'e) ops
  | Call : (string * Yojson.Safe.t) -> (Yojson.Safe.t, 'e) ops
```

### Module: `Prompt`

Effect for prompt management.

```ocaml
type argument = {
  name: string;
  description: string;
  required: bool;
}

type t = {
  name: string;
  description: string;
  arguments: argument list;
}

type message = {
  role: string;
  content: string;
}

type ('a, 'e) ops =
  | List : (t list, 'e) ops
  | Get : (string * Yojson.Safe.t) -> (message list, 'e) ops
```

### Module: `Client`

Client implementation utilities.

```ocaml
type capabilities = {
  resources: bool;
  tools: bool;
  prompts: bool;
}

type config = {
  client_info: client_info;
  capabilities: capabilities;
}

val run : 
  config ->
  (Transport.t * Protocol.t) Handler.List.t ->
  'a ->
  'a

val with_stdio : config -> (Protocol.t Handler.t -> 'a) -> 'a
val with_http : config -> HttpTransport.config -> (Protocol.t Handler.t -> 'a) -> 'a
```

### Module: `Server`

Server implementation utilities.

```ocaml
type capabilities = {
  resources: bool;
  tools: bool;
  prompts: bool;
}

type config = {
  server_info: server_info;
  capabilities: capabilities;
}

val run :
  config ->
  (Transport.t * Resource.t * Tool.t * Prompt.t) Handler.List.t ->
  unit ->
  unit

val create :
  config ->
  resources:(Resource.t Handler.t -> Resource.t list * (string -> Resource.contents)) ->
  tools:(Tool.t Handler.t -> Tool.t list * (string * Yojson.Safe.t -> Yojson.Safe.t)) ->
  prompts:(Prompt.t Handler.t -> Prompt.t list * (string * Yojson.Safe.t -> Prompt.message list)) ->
  (Transport.t Handler.t -> unit) ->
  unit

val stdio :
  config ->
  resources:(Resource.t Handler.t -> Resource.t list * (string -> Resource.contents)) ->
  tools:(Tool.t Handler.t -> Tool.t list * (string * Yojson.Safe.t -> Yojson.Safe.t)) ->
  prompts:(Prompt.t Handler.t -> Prompt.t list * (string * Yojson.Safe.t -> Prompt.message list)) ->
  unit
```

### Exceptions

```ocaml
exception Protocol_error of string
exception Transport_error of string
exception Invalid_request of string
exception Method_not_found of string
exception Invalid_params of string
```

## Effect Handlers

All effects follow the same pattern:

```ocaml
(* Run an effect *)
Module.run : (Module.t Handler.t -> 'a) -> 'a

(* Perform an operation *)
Module.perform : Module.t Handler.t -> ('a, Module.t) Module.ops -> 'a

(* Handle results *)
Module.Result.handle : ('a, 'es) Module.Result.t -> ('a, 'es) Module.Result.handler -> 'a
```

## Usage Examples

### Basic Client

```ocaml
open Mcp

let () =
  Client.with_stdio config (fun protocol ->
    let server_info = Protocol.perform protocol (Initialize client_info) in
    (* ... *)
    Protocol.perform protocol Shutdown
  )
```

### Basic Server

```ocaml
open Mcp

let () =
  Server.stdio config
    ~resources:(fun _ -> (resource_list, resource_reader))
    ~tools:(fun _ -> (tool_list, tool_handler))
    ~prompts:(fun _ -> (prompt_list, prompt_handler))
```

### Custom Effect Handler

```ocaml
let custom_handler = { Module.Result.handle = fun op k ->
  match op with
  | SpecificOp data ->
      (* Handle operation *)
      continue k result []
  | _ ->
      (* Delegate to default handler *)
      Module.Result.handle (Module.perform default_handler op) default_handler
}