(* Complete MCP Schema Implementation Demo *)

open Printf
open Mcp_types
open Mcp_requests
open Mcp_effects

(* Create comprehensive sample data *)
let sample_tools = [
  {
    name = "extract_signal_data";
    description = Some "Extract messages from Signal database";
    input_schema = {
      schema_type = "object";
      properties = Some [
        ("storage_path", String { title = Some "Storage Path"; description = Some "Path to Signal storage"; min_length = None; max_length = None; format = None });
        ("output_path", String { title = Some "Output Path"; description = Some "Where to save extracted data"; min_length = None; max_length = None; format = None });
      ];
      required = Some ["storage_path"; "output_path"];
    };
    output_schema = None;
    annotations = Some {
      title = Some "Signal Data Extractor";
      read_only_hint = Some false;
      destructive_hint = Some false;
      idempotent_hint = Some true;
      open_world_hint = Some false;
    };
  };
  {
    name = "query_database";
    description = Some "Query extracted database with SQL";
    input_schema = {
      schema_type = "object";
      properties = Some [
        ("db_path", String { title = Some "Database Path"; description = Some "Path to database file"; min_length = None; max_length = None; format = None });
        ("query", String { title = Some "SQL Query"; description = Some "SQL query to execute"; min_length = Some 1; max_length = None; format = None });
      ];
      required = Some ["db_path"; "query"];
    };
    output_schema = None;
    annotations = Some {
      title = Some "Database Query Tool";
      read_only_hint = Some true;
      destructive_hint = Some false;
      idempotent_hint = Some true;
      open_world_hint = Some false;
    };
  };
  {
    name = "web_search";
    description = Some "Search the web for information";
    input_schema = {
      schema_type = "object";
      properties = Some [
        ("query", String { title = Some "Search Query"; description = Some "What to search for"; min_length = Some 1; max_length = Some 500; format = None });
        ("max_results", Number { title = Some "Max Results"; description = Some "Maximum number of results"; minimum = Some 1; maximum = Some 20 });
      ];
      required = Some ["query"];
    };
    output_schema = None;
    annotations = Some {
      title = Some "Web Search";
      read_only_hint = Some true;
      destructive_hint = Some false;
      idempotent_hint = Some false;
      open_world_hint = Some true;
    };
  };
]

let sample_resources = [
  {
    uri = "file:///signal/database.db";
    name = "Signal Database";
    description = Some "Encrypted Signal message database";
    mime_type = Some "application/x-sqlite3";
    size = Some 1048576;
    annotations = Some {
      audience = Some [User];
      priority = Some 0.9;
    };
  };
  {
    uri = "file:///signal/attachments/";
    name = "Signal Attachments";
    description = Some "Directory containing Signal attachments";
    mime_type = None;
    size = None;
    annotations = Some {
      audience = Some [User; Assistant];
      priority = Some 0.7;
    };
  };
  {
    uri = "https://api.signal.org/docs";
    name = "Signal API Documentation";
    description = Some "Official Signal API documentation";
    mime_type = Some "text/html";
    size = None;
    annotations = Some {
      audience = Some [Assistant];
      priority = Some 0.3;
    };
  };
]

let sample_prompts = [
  {
    name = "analyze_conversations";
    description = Some "Analyze Signal conversations for patterns";
    arguments = Some [
      { name = "time_range"; description = Some "Time range to analyze (e.g., '30 days')"; required = Some false };
      { name = "participants"; description = Some "Specific participants to focus on"; required = Some false };
    ];
  };
  {
    name = "privacy_report";
    description = Some "Generate privacy analysis report";
    arguments = Some [
      { name = "detail_level"; description = Some "Level of detail (summary, detailed, comprehensive)"; required = Some true };
    ];
  };
  {
    name = "export_summary";
    description = Some "Create export summary for data transfer";
    arguments = None;
  };
]

(* Comprehensive MCP demonstration *)
let run_full_mcp_demo () =
  printf "🎯 Complete MCP Schema Implementation Demo\n";
  printf "Based on official MCP JSON Schema specification\n";
  String.make 80 '=' |> printf "%s\n\n";
  
  (* Create handlers with sample data *)
  let server_handler = create_mcp_server_handler 
    ~tools:sample_tools 
    ~resources:sample_resources 
    ~prompts:sample_prompts () in
  
  let client_handler = create_mcp_client_handler () in
  
  (* Run comprehensive MCP workflow *)
  Mcp.run (fun () ->
    printf "⚡ MCP Effect System Initialized\n\n";
    
    (* 1. Protocol Initialization *)
    printf "🔸 Protocol Initialization\n";
    let init_params = {
      protocol_version = "2024-11-05";
      capabilities = {
        roots = Some (Some true);
        sampling = Some true;
        elicitation = Some true;
        experimental = Some [("ocaml_effects", true)];
      };
      client_info = { name = "OCaml MCP Client"; version = "1.0.0" };
    } in
    let init_result = initialize server_handler init_params in
    printf "  ✅ Server: %s v%s\n" init_result.server_info.name init_result.server_info.version;
    printf "  ✅ Protocol: %s\n" init_result.protocol_version;
    printf "  ✅ Instructions: %s\n" (Option.value init_result.instructions ~default:"None");
    
    (* 2. Tool Operations *)
    printf "\n🔸 Tool Operations\n";
    let tools_result = list_tools server_handler { cursor = None } in
    printf "  ✅ Found %d tools:\n" (List.length tools_result.tools);
    List.iteri (fun i tool ->
      printf "    %d. %s - %s\n" (i+1) tool.name 
        (Option.value tool.description ~default:"No description")
    ) tools_result.tools;
    
    (* Call each tool *)
    List.iter (fun tool ->
      let call_result = call_tool server_handler { 
        name = tool.name; 
        arguments = Some [("test_param", "test_value")] 
      } in
      printf "  ⚡ Executed: %s\n" tool.name
    ) tools_result.tools;
    
    (* 3. Resource Operations *)
    printf "\n🔸 Resource Operations\n";
    let resources_result = list_resources server_handler { cursor = None } in
    printf "  ✅ Found %d resources:\n" (List.length resources_result.resources);
    List.iteri (fun i resource ->
      printf "    %d. %s (%s) - %s\n" (i+1) resource.name resource.uri
        (Option.value resource.description ~default:"No description")
    ) resources_result.resources;
    
    (* Read each resource *)
    List.iter (fun resource ->
      let read_result = read_resource server_handler { uri = resource.uri } in
      printf "  📖 Read: %s (%d content items)\n" resource.name (List.length read_result.contents)
    ) resources_result.resources;
    
    (* 4. Prompt Operations *)
    printf "\n🔸 Prompt Operations\n";
    let prompts_result = list_prompts server_handler { cursor = None } in
    printf "  ✅ Found %d prompts:\n" (List.length prompts_result.prompts);
    List.iteri (fun i prompt ->
      printf "    %d. %s - %s\n" (i+1) prompt.name
        (Option.value prompt.description ~default:"No description")
    ) prompts_result.prompts;
    
    (* Get each prompt *)
    List.iter (fun prompt ->
      let prompt_result = get_prompt server_handler { 
        name = prompt.name; 
        arguments = Some [("example_arg", "example_value")] 
      } in
      printf "  📝 Retrieved: %s (%d messages)\n" prompt.name (List.length prompt_result.messages)
    ) prompts_result.prompts;
    
    (* 5. External Command Execution *)
    printf "\n🔸 External Command Operations\n";
    let commands = [
      ("echo", ["Hello from MCP!"]);
      ("date", []);
      ("whoami", []);
    ] in
    List.iter (fun (cmd, args) ->
      let (output, exit_code) = execute_command server_handler ~command:cmd ~args () in
      printf "  🔨 %s: %s (exit %d)\n" cmd (String.trim output) exit_code
    ) commands;
    
    (* 6. Logging Operations *)
    printf "\n🔸 Logging Operations\n";
    let log_levels = [Debug; Info; Warning; Error] in
    List.iter (fun level ->
      log_message server_handler {
        level = level;
        logger = Some "mcp_demo";
        data = sprintf "Test %s message" (string_of_logging_level level);
      }
    ) log_levels;
    
    (* 7. Client Operations (Sampling) *)
    printf "\n🔸 Client Operations (LLM Sampling)\n";
    let sampling_params = {
      messages = [
        { role = User; content = Text { text = "Analyze this Signal data"; annotations = None } };
      ];
      max_tokens = 1000;
      system_prompt = Some "You are a privacy-focused data analyst";
      include_context = Some "thisServer";
      temperature = Some 0.7;
      stop_sequences = None;
      metadata = Some [("purpose", "signal_analysis")];
      model_preferences = Some {
        hints = Some [{ name = Some "claude-3.5-sonnet" }];
        cost_priority = Some 0.3;
        speed_priority = Some 0.5;
        intelligence_priority = Some 0.9;
      };
    } in
    let message_result = Mcp.perform client_handler (Mcp_ops.CreateMessage sampling_params) in
    printf "  🤖 LLM Response: %s (model: %s)\n" 
      (match message_result.content with Text t -> t.text | _ -> "Non-text content")
      message_result.model;
    
    (* 8. Roots and Elicitation *)
    printf "\n🔸 Roots and Elicitation\n";
    let roots_result = Mcp.perform client_handler (Mcp_ops.ListRoots ()) in
    printf "  🌱 Found %d roots\n" (List.length roots_result.roots);
    
    let elicit_params = {
      message = "Please provide your Signal database password";
      requested_schema = {
        schema_type = "object";
        properties = [
          ("password", String { title = Some "Password"; description = Some "Database password"; min_length = Some 1; max_length = None; format = None });
        ];
        required = Some ["password"];
      };
    } in
    let elicit_result = Mcp.perform client_handler (Mcp_ops.Elicit elicit_params) in
    printf "  ❓ Elicitation result: %s\n" elicit_result.action;
    
    (* 9. Workflow Summary *)
    printf "\n🎉 MCP Full Schema Demo Complete!\n";
    printf "Key Features Demonstrated:\n";
    printf "  ✓ Complete JSON Schema type definitions\n";
    printf "  ✓ First-class effect handlers with oxcaml_effect\n";
    printf "  ✓ Tools, Resources, Prompts, and Sampling\n";
    printf "  ✓ External command execution\n";
    printf "  ✓ Comprehensive logging system\n";
    printf "  ✓ Client-server bidirectional communication\n";
    printf "  ✓ Type-safe operation composition\n";
    String.make 80 '=' |> printf "%s\n"
  )