(* Signal Effects Demo - Proper First-Class Handlers *)

open Printf

(* Core result types *)
type extraction_result = {
  status: string;
  extracted_count: int;
  output_path: string;
}

(* STEP 1 - Describe operations with GADT *)
type _ signal_operation =
  | Extract_messages : { 
      storage_path: string; 
      output_path: string;
    } -> extraction_result signal_operation
  | Query_database : { 
      db_path: string; 
      query: string; 
    } -> string signal_operation
  | Get_conversations : unit -> string list signal_operation

(* STEP 2 - First-class handler type *)
type signal_handler = {
  handle : 'a. 'a signal_operation -> 'a
}

(* STEP 3 - Create concrete handler implementation *)
let create_signal_handler () = {
  handle = fun (type a) (op : a signal_operation) : a ->
    match op with
    | Extract_messages { storage_path; output_path } ->
        printf "🔓 Extracting Signal data from: %s\n" storage_path;
        printf "📁 Saving to: %s\n" output_path;
        printf "⚡ Processing database with oxcaml_effect patterns...\n";
        { status = "completed"; extracted_count = 2048; output_path }
        
    | Query_database { db_path; query } ->
        printf "🔍 Querying: %s\n" db_path;
        printf "📝 SQL: %s\n" query;
        printf "💾 Using first-class handler for database operations\n";
        "user_id,message_count,last_active\n1,156,2024-01-15\n2,89,2024-01-14"
        
    | Get_conversations () ->
        printf "👥 Fetching conversation list with effect handlers\n";
        printf "🎯 Demonstrating statically-checked effect operations\n";
        ["Alice Cooper"; "Bob Dylan"; "Charlie Parker"; "Diana Ross"]
}

(* Effect operations using first-class handlers *)
let extract_messages handler ~storage_path ~output_path =
  handler.handle (Extract_messages { storage_path; output_path })

let query_database handler ~db_path ~query =
  handler.handle (Query_database { db_path; query })

let get_conversations handler =
  handler.handle (Get_conversations ())

(* MCP protocol implementation with effects *)
let mcp_tools_list _handler =
  printf "🛠️  Listing MCP tools (handler-based):\n";
  [
    ("extract_signal_data", "Extract messages using typed effects");
    ("query_signal_db", "Query database with first-class handlers");
    ("list_conversations", "Get conversations via effect operations");
  ]

let mcp_call_tool handler tool_name params =
  printf "🚀 Executing MCP tool: %s\n" tool_name;
  match tool_name with
  | "extract_signal_data" ->
      let storage = List.assoc "storage_path" params in
      let output = List.assoc "output_path" params in
      let result = extract_messages handler ~storage_path:storage ~output_path:output in
      printf "✅ Extraction: %s (%d messages)\n" result.status result.extracted_count;
      [("status", result.status); ("count", string_of_int result.extracted_count)]
      
  | "query_signal_db" ->
      let db_path = List.assoc "db_path" params in
      let query = List.assoc "query" params in
      let result = query_database handler ~db_path ~query in
      printf "📊 Query returned %d bytes\n" (String.length result);
      [("result_size", string_of_int (String.length result))]
      
  | "list_conversations" ->
      let conversations = get_conversations handler in
      printf "👥 Found %d conversations\n" (List.length conversations);
      [("count", string_of_int (List.length conversations))]
      
  | _ ->
      printf "❌ Unknown tool: %s\n" tool_name;
      [("error", "Tool not found")]

(* Workflow composition with first-class handlers *)
let run_analysis_workflow handler =
  printf "\n🔥 Signal Analysis Workflow (oxcaml_effect style)\n";
  String.make 60 '=' |> printf "%s\n";
  
  (* Chain effect operations *)
  printf "Step 1: Extract Signal data\n";
  let extraction = extract_messages handler 
    ~storage_path:"/Users/signal/data" 
    ~output_path:"analysis.db" in
  
  printf "Step 2: Get conversation metadata\n";
  let conversations = get_conversations handler in
  
  printf "Step 3: Query extracted data\n";
  let stats_query = "SELECT sender, COUNT(*) as msg_count FROM messages GROUP BY sender" in
  let query_result = query_database handler 
    ~db_path:extraction.output_path 
    ~query:stats_query in
  
  printf "\n📈 Workflow Results:\n";
  printf "  • Messages extracted: %d\n" extraction.extracted_count;
  printf "  • Conversations found: %d\n" (List.length conversations);
  printf "  • Query data size: %d bytes\n" (String.length query_result);
  printf "  • All operations type-safe! ✅\n";
  
  (extraction, conversations, query_result)

(* Main demo showcasing proper oxcaml_effect patterns *)
let run_effects_demo () =
  printf "🎯 Signal MCP with First-Class Effect Handlers\n";
  printf "Based on Jane Street's oxcaml_effect patterns\n";
  String.make 70 '=' |> printf "%s\n\n";
  
  (* Create the first-class handler *)
  let signal_handler = create_signal_handler () in
  printf "⚡ Created first-class Signal handler\n\n";
  
  (* Demonstrate individual effect operations *)
  printf "🔸 Testing Individual Operations:\n";
  let result = extract_messages signal_handler 
    ~storage_path:"/path/to/Signal.app/storage" 
    ~output_path:"extracted.db" in
  
  let _conversations = get_conversations signal_handler in
  let _query_result = query_database signal_handler 
    ~db_path:result.output_path 
    ~query:"SELECT * FROM messages LIMIT 10" in
  
  (* Demonstrate MCP protocol integration *)
  printf "\n🔸 Testing MCP Integration:\n";
  let _tools = mcp_tools_list signal_handler in
  
  let params = [
    ("storage_path", "/Signal/database");
    ("output_path", "mcp_output.db")
  ] in
  let _tool_result = mcp_call_tool signal_handler "extract_signal_data" params in
  
  (* Run comprehensive workflow *)
  printf "\n🔸 Running Complete Workflow:\n";
  let (_extraction, _conversations, _data) = run_analysis_workflow signal_handler in
  
  printf "\n🎉 Demo Complete!\n";
  printf "Key oxcaml_effect benefits demonstrated:\n";
  printf "  ✓ First-class handlers (pass around, store in data structures)\n";
  printf "  ✓ Statically-checked 'who handles what'\n";
  printf "  ✓ Uniform API for all effects (no special syntax)\n";
  printf "  ✓ Easy abstraction boundaries and composition\n";
  String.make 70 '=' |> printf "%s\n"