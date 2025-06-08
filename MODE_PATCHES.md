# Mode Annotation Patches for OCaml MCP SDK

## 1. Transport Module Patch

This patch demonstrates all four modal axes in the transport layer:

```diff
--- a/lib/stdio_transport.ml
+++ b/lib/stdio_transport_annotated.ml
@@ -1,11 +1,13 @@
-(* Stdio transport handler using oxcaml_effect *)
+(* Stdio transport handler using oxcaml_effect with mode annotations *)
 
 open Mcp_effect
+open Modes
 
-(* Buffered line reader *)
+(* Buffered line reader - owned uniquely by transport handler *)
 type reader = {
   mutable buffer: string;
   mutable closed: bool;
-}
+} [@@unboxed]  (* value mode = unique *)
 
-let create_reader () = { buffer = ""; closed = false }
+let create_reader () : reader @ unique = 
+  { buffer = ""; closed = false }
 
-let read_line reader =
+let read_line (reader : reader @ unique) : string option =
   if reader.closed then None
   else
     try
@@ -21,8 +23,8 @@
       reader.closed <- true;
       None
 
-(* Transport handler *)
-let handle_transport reader =
+(* Transport handler - takes unique ownership of reader *)
+let handle_transport (reader : reader @ unique) =
   let open Transport in
   { Result.handle = fun op k ->
     match op with
@@ -36,11 +38,13 @@
         flush stdout;
         continue k () []
     | Transport_ops.Close ->
-        reader.closed <- true;
+        reader.closed <- true;  (* Linear write to unique reader *)
         continue k () []
   }
 
-(* Run with stdio transport *)
+(* Run with stdio transport - creates unique reader *)
 let with_stdio_transport f =
-  let reader = create_reader () in
-  Transport.run (fun h -> f h) |> Transport.Result.handle (handle_transport reader)
+  let reader = create_reader () in  (* reader : reader @ unique *)
+  Transport.run (fun h -> f h) 
+  |> Transport.Result.handle (handle_transport reader)
+  (* handle_transport consumes reader uniquely *)
```

## 2. Protocol Handler Annotations

For the protocol handler, we focus on the sharing semantics:

```ocaml
(* protocol_handler.ml with annotations *)
open Modes

type protocol_state = {
  mutable next_id: int;
  pending_requests: (int, json Lwt.u) Hashtbl.t @ local many;
  (* Hashtable is local to this fiber, can be aliased within it *)
}

(* JSON encoding returns portable values *)
let encode_response ~id ~result : Yojson.Safe.t @ contended @@ portable =
  `Assoc (
    ("jsonrpc", `String "2.0") ::
    (match id with
     | Some id -> [("id", id)]
     | None -> []) @
    (match result with
     | Some r -> [("result", r)]
     | None -> [("result", `Null)])
  )
```

## 3. Server Resource Annotations

For the server, we annotate the handler lists and JSON returns:

```ocaml
(* mcp_server.ml with annotations *)
open Modes

type server_config = {
  name: string;
  version: string;
  resources: (string * (unit -> json @ unique)) list @ local @@ aliased;
  tools: (string * (json option -> json @ unique)) list @ local @@ aliased;
  prompts: (string * (json option -> json @ unique)) list @ local @@ aliased;
}

(* Resource handler returns portable JSON *)
let list_resources config : Yojson.Safe.t list @ contended @@ portable =
  List.map (fun (uri, _) ->
    `Assoc [
      ("uri", `String uri);
      ("name", `String uri);
    ]
  ) config.resources
```

## 4. Key Benefits of These Annotations

1. **Unique Reader**: Prevents double-close bugs at compile time
2. **Local Hashtables**: Clear fiber-local sharing semantics
3. **Portable JSON**: Safe cross-domain message passing
4. **Aliased Lists**: Read-only sharing of handler configurations

## 5. Testing the Patches

To test these patches:

```bash
# 1. Apply the dune changes
# 2. Create modes.ml
# 3. Replace stdio_transport.ml with the annotated version
# 4. Compile with modes enabled
dune build

# If compilation succeeds, the mode system has verified:
# - No double-use of unique resources
# - Proper isolation of local state
# - Safe cross-domain communication
```

## 6. Gradual Migration Strategy

1. Start with `stdio_transport.ml` (smallest, clearest ownership)
2. Add annotations incrementally, module by module
3. Use `Obj.magic` escape hatches temporarily if needed
4. Document any mode violations that require runtime checks