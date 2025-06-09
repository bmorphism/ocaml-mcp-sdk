(* MCP Protocol Effect Operations using oxcaml_effect *)

open Printf
open Mcp_types
open Mcp_requests

(* STEP 1 - Describe MCP operations using GADT *)
module Mcp_ops = struct
  type _ t =
    (* Core Protocol Operations *)
    | Initialize : initialize_params -> initialize_result t
    | Ping : unit -> unit t
    
    (* Tool Operations *)
    | ListTools : list_params -> list_tools_result t
    | CallTool : call_tool_params -> call_tool_result t
    
    (* Resource Operations *)
    | ListResources : list_params -> list_resources_result t
    | ListResourceTemplates : list_params -> list_resources_result t
    | ReadResource : read_resource_params -> read_resource_result t
    | Subscribe : subscribe_params -> unit t
    | Unsubscribe : subscribe_params -> unit t
    
    (* Prompt Operations *)
    | ListPrompts : list_params -> list_prompts_result t
    | GetPrompt : get_prompt_params -> get_prompt_result t
    
    (* Completion Operations *)
    | Complete : completion_params -> completion_result t
    
    (* Logging Operations *)
    | SetLevel : set_level_params -> unit t
    | LogMessage : logging_message_params -> unit t
    
    (* Sampling Operations (Server -> Client) *)
    | CreateMessage : create_message_params -> create_message_result t
    | ListRoots : unit -> list_roots_result t
    | Elicit : elicit_params -> elicit_result t
    
    (* Notification Operations *)
    | SendNotification : server_notification -> unit t
    | ReceiveNotification : unit -> client_notification option t
    
    (* Transport Operations *)
    | SendMessage : json_rpc_message -> unit t
    | ReceiveMessage : unit -> json_rpc_message option t
    
    (* Process Operations (for external tools) *)
    | ExecuteCommand : {
        command : string;
        args : string list;
        timeout : float option;
        cwd : string option;
      } -> (string * int) t (* output, exit_code *)
    
    (* File System Operations *)
    | ReadFile : string -> string t
    | WriteFile : string * string -> unit t
    | FileExists : string -> bool t
    | ListDirectory : string -> string list t
    
    (* JSON Operations *)
    | ParseJson : string -> (string * string) list t
    | SerializeJson : (string * string) list -> string t
    
    (* Error Handling *)
    | ThrowError : {
        code : int;
        message : string;
        data : string option;
      } -> 'a t
end

(* STEP 2 - Instantiate the functor with FULL oxcaml_effect *)
module Mcp = Oxcaml_effect.Make(Mcp_ops)

(* STEP 3 - Handler Types and Creation using oxcaml_effect *)
type mcp_handler = (unit, unit) Mcp.handler

(* MCP Server Handler Implementation using FULL oxcaml_effect *)
let create_mcp_server_handler ?(tools=[]) ?(resources=[]) ?(prompts=[]) () =
  let handler_result = { Mcp.Result.handle = fun (type a) (op : a Mcp_ops.t) k ->
    match op with
    | Mcp_ops.Initialize params ->
        printf "🚀 MCP Server initializing with protocol %s\n" params.protocol_version;
        let result = {
          base = { meta = None };
          protocol_version = "2024-11-05";
          capabilities = {
            tools = Some (Some true);
            resources = Some (Some true, Some true);
            prompts = Some (Some true);
            logging = Some true;
            completions = Some true;
            experimental = None;
          };
          server_info = { name = "OCaml MCP SDK"; version = "1.0.0" };
          instructions = Some "Advanced MCP server with effect-based architecture";
        } in
        k result
        
    | Mcp_ops.Ping () ->
        printf "🏓 Ping received - server alive\n";
        k ()
        
    | Mcp_ops.ListTools params ->
        printf "🔧 Listing %d available tools\n" (List.length tools);
        let result = {
          base = { meta = None };
          tools = tools;
          next_cursor = None;
        } in
        k result
        
    | Mcp_ops.CallTool params ->
        printf "⚡ Executing tool: %s\n" params.name;
        (* Find and execute the tool *)
        let tool_result = match List.find_opt (fun t -> t.name = params.name) tools with
          | Some tool ->
              printf "📋 Tool found: %s\n" tool.name;
              (* Simulate tool execution *)
              [Text { text = sprintf "Tool %s executed successfully" params.name; annotations = None }]
          | None ->
              printf "❌ Tool not found: %s\n" params.name;
              [Text { text = sprintf "Error: Tool '%s' not found" params.name; annotations = None }]
        in
        let result = {
          base = { meta = None };
          content = tool_result;
          is_error = None;
          structured_content = None;
        } in
        k result
        
    | Mcp_ops.ListResources params ->
        printf "📁 Listing %d available resources\n" (List.length resources);
        let result = {
          base = { meta = None };
          resources = resources;
          next_cursor = None;
        } in
        k result
        
    | Mcp_ops.ReadResource params ->
        printf "📖 Reading resource: %s\n" params.uri;
        (* Simulate resource reading *)
        let contents = [Text {
          uri = params.uri;
          text = sprintf "Content of resource %s" params.uri;
          mime_type = Some "text/plain";
        }] in
        let result = {
          base = { meta = None };
          contents = contents;
        } in
        k result
        
    | Mcp_ops.ListPrompts params ->
        printf "💭 Listing %d available prompts\n" (List.length prompts);
        let result = {
          base = { meta = None };
          prompts = prompts;
          next_cursor = None;
        } in
        k result
        
    | Mcp_ops.GetPrompt params ->
        printf "📝 Getting prompt: %s\n" params.name;
        let messages = [
          { role = User; content = Text { text = "Example prompt message"; annotations = None } }
        ] in
        let result = {
          base = { meta = None };
          description = Some (sprintf "Prompt: %s" params.name);
          messages = messages;
        } in
        k result
        
    | Mcp_ops.ExecuteCommand { command; args; timeout; cwd } ->
        printf "🔨 Executing command: %s %s\n" command (String.concat " " args);
        (* Simulate command execution *)
        let output = sprintf "Command output for: %s" command in
        k (output, 0)
        
    | Mcp_ops.LogMessage params ->
        printf "[%s] %s\n" (string_of_logging_level params.level) params.data;
        k ()
        
    | Mcp_ops.SendNotification notif ->
        printf "📢 Sending notification\n";
        k ()
        
    | Mcp_ops.ThrowError { code; message; data } ->
        printf "💥 Error %d: %s\n" code message;
        failwith message
        
    | _ ->
        printf "❓ Unhandled operation\n";
        failwith "Operation not implemented in server handler"
  } in
  Mcp.deep handler_result

(* MCP Client Handler Implementation using FULL oxcaml_effect *)
let create_mcp_client_handler ?(server_info={ name = "Test Server"; version = "1.0" }) () =
  let client_result = { Mcp.Result.handle = fun (type a) (op : a Mcp_ops.t) k ->
    match op with
    | Mcp_ops.CreateMessage params ->
        printf "🤖 Client sampling LLM with %d messages\n" (List.length params.messages);
        let result = {
          base = { meta = None };
          role = Assistant;
          content = Text { text = "Generated response from LLM"; annotations = None };
          model = "claude-3.5-sonnet";
          stop_reason = Some "end_turn";
        } in
        k result
        
    | Mcp_ops.ListRoots () ->
        printf "🌱 Client listing roots\n";
        let roots = [
          { uri = "file:///Users/test/project"; name = Some "Project Root" };
          { uri = "file:///Users/test/data"; name = Some "Data Directory" };
        ] in
        let result = {
          base = { meta = None };
          roots = roots;
        } in
        k result
        
    | Mcp_ops.Elicit params ->
        printf "❓ Client eliciting user input: %s\n" params.message;
        let result = {
          base = { meta = None };
          action = "accept";
          content = Some [("response", "User accepted the elicitation")];
        } in
        k result
        
    | Mcp_ops.ReceiveNotification () ->
        printf "🔔 Client checking for notifications\n";
        k None (* No notifications for now *)
        
    | _ ->
        printf "❓ Unhandled operation in client\n";
        failwith "Operation not implemented in client handler"
  } in
  Mcp.deep client_result

(* Helper functions for effect operations *)
let initialize handler params =
  Mcp.perform handler (Mcp_ops.Initialize params)

let ping handler =
  Mcp.perform handler (Mcp_ops.Ping ())

let list_tools handler params =
  Mcp.perform handler (Mcp_ops.ListTools params)

let call_tool handler params =
  Mcp.perform handler (Mcp_ops.CallTool params)

let list_resources handler params =
  Mcp.perform handler (Mcp_ops.ListResources params)

let read_resource handler params =
  Mcp.perform handler (Mcp_ops.ReadResource params)

let list_prompts handler params =
  Mcp.perform handler (Mcp_ops.ListPrompts params)

let get_prompt handler params =
  Mcp.perform handler (Mcp_ops.GetPrompt params)

let execute_command handler ~command ~args ?timeout ?cwd () =
  Mcp.perform handler (Mcp_ops.ExecuteCommand { command; args; timeout; cwd })

let log_message handler params =
  Mcp.perform handler (Mcp_ops.LogMessage params)

(* Effect-based MCP workflow composition *)
let run_mcp_server_workflow handler =
  printf "\n🎯 Running Complete MCP Server Workflow\n";
  String.make 60 '=' |> printf "%s\n";
  
  (* Initialize protocol *)
  let init_params = {
    protocol_version = "2024-11-05";
    capabilities = {
      roots = Some (Some true);
      sampling = Some true;
      elicitation = Some true;
      experimental = None;
    };
    client_info = { name = "OCaml MCP Client"; version = "1.0.0" };
  } in
  let init_result = initialize handler init_params in
  printf "✅ Initialized: %s v%s\n" 
    init_result.server_info.name init_result.server_info.version;
  
  (* Test ping *)
  ping handler;
  printf "✅ Ping successful\n";
  
  (* List tools *)
  let tools_result = list_tools handler { cursor = None } in
  printf "✅ Found %d tools\n" (List.length tools_result.tools);
  
  (* Call a tool if available *)
  (match tools_result.tools with
   | tool :: _ ->
       let call_result = call_tool handler { name = tool.name; arguments = None } in
       printf "✅ Called tool: %s\n" tool.name
   | [] ->
       printf "ℹ️  No tools to call\n");
  
  (* List and read resources *)
  let resources_result = list_resources handler { cursor = None } in
  printf "✅ Found %d resources\n" (List.length resources_result.resources);
  
  (* Execute external command *)
  let (output, exit_code) = execute_command handler 
    ~command:"echo" ~args:["Hello from MCP effects!"] () in
  printf "✅ Command executed: %s (exit %d)\n" output exit_code;
  
  printf "\n🎉 MCP Workflow Complete!\n";
  String.make 60 '=' |> printf "%s\n"