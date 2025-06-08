(* MCP Server using oxcaml_effect with mode annotations *)

open Mcp_effect
open Modes

(* Server configuration - built once, shared read-only across fibers *)
type server_config = {
  name: string;
  version: string;
  resources: (string * (unit -> json @ unique)) list @ local @@ aliased;
  tools: (string * (json option -> json @ unique)) list @ local @@ aliased;
  prompts: (string * (json option -> json @ unique)) list @ local @@ aliased;
  (* Handler lists can be aliased within local domain but stay local *)
}

(* Resource handler - returns portable JSON for cross-domain *)
let handle_resources (config : server_config @ local @@ aliased) =
  let open Resource in
  { Result.handle = fun op k ->
    match op with
    | Resource_ops.List_resources ->
        let resources : Yojson.Safe.t list @ contended @@ portable = 
          List.map (fun (uri, _) ->
            `Assoc [
              ("uri", `String uri);
              ("name", `String uri);
            ]
          ) config.resources in
        continue k resources []
        
    | Resource_ops.Read_resource uri ->
        (match List.assoc_opt uri config.resources with
         | Some getter ->
             let content : json @ unique = getter () in
             (* Convert unique content to portable for return *)
             let portable_content : json @ contended @@ portable = content in
             continue k portable_content []
         | None ->
             let error_response : json @ contended @@ portable = 
               `Assoc [("error", `String "Resource not found")] in
             continue k error_response [])
  }

(* Tool handler - processes tool calls and returns portable results *)
let handle_tools (config : server_config @ local @@ aliased) =
  let open Tool in
  { Result.handle = fun op k ->
    match op with
    | Tool_ops.List_tools ->
        let tools : Yojson.Safe.t list @ contended @@ portable = 
          List.map (fun (name, _) ->
            `Assoc [
              ("name", `String name);
              ("description", `String (name ^ " tool"));
              ("inputSchema", `Assoc [
                ("type", `String "object");
                ("properties", `Assoc []);
                ("additionalProperties", `Bool true);
              ]);
            ]
          ) config.tools in
        continue k tools []
        
    | Tool_ops.Call_tool { name; arguments } ->
        (match List.assoc_opt name config.tools with
         | Some tool_fn ->
             (* Tool function captures local state, so it's @once *)
             let result : json @ unique = tool_fn arguments in
             (* Convert to portable for cross-domain return *)
             let portable_result : json @ contended @@ portable = result in
             continue k portable_result []
         | None ->
             let error_response : json @ contended @@ portable = 
               `Assoc [("error", `String "Tool not found")] in
             continue k error_response [])
  }

(* Prompt handler - similar pattern to tools *)
let handle_prompts (config : server_config @ local @@ aliased) =
  let open Prompt in
  { Result.handle = fun op k ->
    match op with
    | Prompt_ops.List_prompts ->
        let prompts : Yojson.Safe.t list @ contended @@ portable = 
          List.map (fun (name, _) ->
            `Assoc [
              ("name", `String name);
              ("description", `String (name ^ " prompt"));
            ]
          ) config.prompts in
        continue k prompts []
        
    | Prompt_ops.Get_prompt { name; arguments } ->
        (match List.assoc_opt name config.prompts with
         | Some prompt_fn ->
             let result : json @ unique = prompt_fn arguments in
             let portable_result : json @ contended @@ portable = result in
             continue k portable_result []
         | None ->
             let error_response : json @ contended @@ portable = 
               `Assoc [("error", `String "Prompt not found")] in
             continue k error_response [])
  }

(* Server capabilities - returns portable configuration *)
let get_server_capabilities (config : server_config @ local @@ aliased) 
  : Yojson.Safe.t @ contended @@ portable =
  `Assoc [
    ("capabilities", `Assoc [
      ("resources", `Assoc [
        ("subscribe", `Bool true);
        ("listChanged", `Bool true);
      ]);
      ("tools", `Assoc [
        ("listChanged", `Bool true);
      ]);
      ("prompts", `Assoc [
        ("listChanged", `Bool true);
      ]);
    ]);
    ("serverInfo", `Assoc [
      ("name", `String config.name);
      ("version", `String config.version);
    ]);
  ]

(* Create server with aliased config that can be shared read-only *)
let create_server 
  ~name 
  ~version 
  ~resources 
  ~tools 
  ~prompts : server_config @ local @@ aliased =
  { name; version; resources; tools; prompts }

(* Run server - combines all handlers with aliased config *)
let run_server (config : server_config @ local @@ aliased) protocol_handler =
  let resource_handler = handle_resources config in
  let tool_handler = handle_tools config in
  let prompt_handler = handle_prompts config in
  
  (* Server event loop would go here *)
  (* Each handler can read from the aliased config safely *)
  (resource_handler, tool_handler, prompt_handler)