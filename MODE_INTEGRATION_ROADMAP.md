# OCaml MCP SDK Mode Integration Roadmap

This roadmap maps the modal tags from our theoretical discussion onto the concrete MCP SDK codebase.

## 1. Modal Tag Mapping for Key Components

### Transport Module (`stdio_transport.ml`)
**Current State**: Single-threaded ownership of file descriptors  
**Modal Annotation**: `@unique @local` on reader record, `@once` on closures

```ocaml
(* Before *)
type reader = {
  mutable buffer: string;
  mutable closed: bool;
}

(* After *)
type reader = {
  mutable buffer: string;
  mutable closed: bool;
} [@@unboxed]  (* value mode = unique *)

let with_reader (r : reader @ unique) f =
  f r  (* f is @once because it captures r *)
```

### Protocol State (`protocol_handler.ml`)
**Current State**: Shared within protocol fiber, never cross-domain  
**Modal Annotation**: Leave `@local many` (default) for hashtable

```ocaml
type protocol_state = {
  mutable next_id: int;
  pending_requests: (int, json Lwt.u) Hashtbl.t;  (* @ local many *)
}
```

### JSON Resources (`mcp_server.ml`)
**Current State**: Pure immutable trees that can travel anywhere  
**Modal Annotation**: `Yojson.Safe.t @ contended @@ portable`

```ocaml
(* Return type annotations *)
let list_resources_client h : Yojson.Safe.t @ contended @@ portable =
  ...
```

### Handler Lists
**Current State**: Built once, shared read-only across fibers  
**Modal Annotation**: Record fields `@@ aliased`, whole handler `@contended`

```ocaml
(* Server config *)
type server_config = {
  name: string;
  version: string;
  resources: (string * (unit -> json @unique)) list @ local;
  tools: (string * (json option -> json @unique)) list @ local;
  prompts: (string * (json option -> json @unique)) list @ local;
}
```

### User Tool Closures
**Current State**: May capture local state  
**Modal Annotation**: Parameter `<fun> @once`, result `json @unique`

## 2. Minimal Patches for Mode Compilation

### Step 1: Enable modes in dune
```dune
(library
 (name ocaml_mcp_sdk)
 (public_name ocaml-mcp-sdk)
 (libraries oxcaml_effect yojson unix)
 (modules mcp_effect stdio_transport protocol_handler mcp_client mcp_server)
 (flags :standard -extension mode))
```

### Step 2: Add mode type synonyms
Create `lib/modes.ml`:
```ocaml
module M = Modes
type 'a unique = 'a M.unique
type 'a local_aliasable = 'a M.aliased local
```

### Step 3: Annotate transport state
Update `stdio_transport.ml`:
```ocaml
open Modes

type reader = {
  mutable buffer: string;
  mutable closed: bool;
} [@@unboxed]  (* value mode = unique *)

let handle_transport (reader : reader @ unique) =
  let open Transport in
  { Result.handle = fun op k ->
    match op with
    | Transport_ops.Read ->
        (* Reader is unique, can't be shared *)
        ...
    | Transport_ops.Close ->
        reader.closed <- true;  (* Linear write *)
        continue k () []
  }
```

### Step 4: Mark portable JSON returns
Update protocol functions:
```ocaml
let encode_response ~id ~result : Yojson.Safe.t @ contended @@ portable =
  `Assoc (...)
```

### Step 5: Remove runtime guards
The `Continuation_already_resumed` exception becomes unreachable:
```ocaml
(** Unreachable unless you violate modes with Obj.magic. *)
exception Continuation_already_resumed
```

## 3. Girard Lens Verification

### Linear Zone (A ⇒ @unique @once)
- Raw IO operations
- Continuation state
- File descriptor ownership

### Exponential Zone (!A ⇒ @aliased @many)
- JSON duplication
- Broadcasting
- Logging operations

### Promotion Rule (Γ ⊢ A ⇒ !Γ ⊢ □A)
- Cross-domain paths use `@portable`
- Contended resources properly promoted

## 4. Implementation Order

1. **Transport Module** (smallest, clearest ownership)
   - Add annotations to `stdio_transport.ml`
   - Compile with `-extension mode`
   - Fix any double-use bugs revealed

2. **Protocol Handler** (hashtable sharing semantics)
   - Annotate state management
   - Verify fiber-local sharing

3. **Server Resources** (JSON portability)
   - Mark all JSON returns as portable
   - Ensure handler lists are aliased

4. **Full Integration**
   - Enable modes across all modules
   - Run test suite with mode checking
   - Document any Obj.magic escapes needed

## 5. Expected Benefits

- **Compile-time guarantees**: No double-close, no double-resume
- **Cross-domain safety**: No FS descriptor leaks
- **Memory clarity**: Explicit sharing vs. uniqueness
- **Performance**: Compiler can optimize based on modes

## Next Concrete Step

Start with the transport module patch - it's the smallest change that demonstrates all four modal axes in action.