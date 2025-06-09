(* Signal MCP with Proper oxcaml_effect Implementation *)

open Printf

(* Core result types *)
type extraction_result = {
  status: string;
  extracted_count: int;
  output_path: string;
}

(* STEP 1 - Describe your operations using GADT *)
module Signal_ops = struct
  type _ t =
    | Extract_messages : { 
        storage_path: string; 
        output_path: string;
      } -> extraction_result t
    | Query_database : { 
        db_path: string; 
        query: string; 
      } -> string t
    | Get_conversation_list : unit -> string list t
    | Export_to_format : {
        db_path: string;
        format: [`JSON | `CSV | `SQL];
        output_file: string;
      } -> bool t
end

(* STEP 2 - Instantiate the functor *)
module Signal = Oxcaml_effect.Effect.Make(Signal_ops)

(* STEP 3 - Write handlers *)
let create_signal_handler () =
  let open Signal in
  { handle = fun (type a) (op : a Signal_ops.t) k ->
    match op with
    | Signal_ops.Extract_messages { storage_path; output_path } ->
        printf "🔓 Extracting Signal messages from %s\n" storage_path;
        printf "📁 Output destination: %s\n" output_path;
        (* Simulate extraction process *)
        let result = { 
          status = "success"; 
          extracted_count = 1337; 
          output_path 
        } in
        printf "✅ Extracted %d messages successfully\n" result.extracted_count;
        k result
        
    | Signal_ops.Query_database { db_path; query } ->
        printf "🔍 Querying database: %s\n" db_path;
        printf "📝 SQL: %s\n" query;
        let mock_result = "conversation_id,timestamp,sender,message_text\n1,2024-01-01,Alice,Hello world" in
        printf "📊 Query returned %d rows\n" (String.split_on_char '\n' mock_result |> List.length);
        k mock_result
        
    | Signal_ops.Get_conversation_list () ->
        printf "👥 Retrieving conversation list\n";
        let conversations = ["Alice Johnson"; "Bob Smith"; "Family Group"; "Work Team"] in
        printf "📋 Found %d conversations\n" (List.length conversations);
        k conversations
        
    | Signal_ops.Export_to_format { db_path; format; output_file } ->
        let format_str = match format with
          | `JSON -> "JSON"
          | `CSV -> "CSV" 
          | `SQL -> "SQL" in
        printf "📤 Exporting %s to %s format\n" db_path format_str;
        printf "💾 Output file: %s\n" output_file;
        printf "✅ Export completed successfully\n";
        k true
  }

(* Helper functions using proper effect perform *)
let extract_messages handler ~storage_path ~output_path =
  Signal.perform handler (Signal_ops.Extract_messages { storage_path; output_path })

let query_database handler ~db_path ~query =
  Signal.perform handler (Signal_ops.Query_database { db_path; query })

let get_conversation_list handler =
  Signal.perform handler (Signal_ops.Get_conversation_list ())

let export_to_format handler ~db_path ~format ~output_file =
  Signal.perform handler (Signal_ops.Export_to_format { db_path; format; output_file })

(* MCP Protocol Handler with Effects *)
let handle_mcp_request handler request_id method_name params =
  printf "\n🌐 MCP Request %s: %s\n" request_id method_name;
  match method_name with
  | "tools/list" ->
      printf "📋 Listing available Signal tools\n";
      [
        ("extract_signal_messages", "Extract messages from Signal database");
        ("query_signal_database", "Query Signal database with SQL");
        ("list_conversations", "Get list of Signal conversations");
        ("export_signal_data", "Export Signal data to various formats");
      ]
      
  | "tools/call" ->
      (match params with
       | Some ("extract_signal_messages", args) ->
           printf "🔧 Executing: extract_signal_messages\n";
           let result = extract_messages handler 
             ~storage_path:(List.assoc "storage_path" args)
             ~output_path:(List.assoc "output_path" args) in
           printf "📈 Tool result: %s (%d messages)\n" result.status result.extracted_count;
           [("status", result.status); ("count", string_of_int result.extracted_count)]
           
       | Some ("query_signal_database", args) ->
           printf "🔧 Executing: query_signal_database\n";
           let result = query_database handler
             ~db_path:(List.assoc "db_path" args)
             ~query:(List.assoc "query" args) in
           printf "📊 Query completed\n";
           [("result", result)]
           
       | Some ("list_conversations", _) ->
           printf "🔧 Executing: list_conversations\n";
           let conversations = get_conversation_list handler in
           printf "👥 Found conversations: %s\n" (String.concat ", " conversations);
           [("conversations", String.concat "," conversations)]
           
       | Some ("export_signal_data", args) ->
           printf "🔧 Executing: export_signal_data\n";
           let format = match List.assoc "format" args with
             | "json" -> `JSON | "csv" -> `CSV | "sql" -> `SQL
             | _ -> `JSON in
           let success = export_to_format handler
             ~db_path:(List.assoc "db_path" args)
             ~format
             ~output_file:(List.assoc "output_file" args) in
           [("success", string_of_bool success)]
           
       | _ -> [("error", "Unknown tool or invalid parameters")]
      )
      
  | _ -> [("error", "Unknown MCP method")]

(* Advanced effect composition *)
let run_signal_analysis_workflow handler =
  printf "\n🚀 Running Signal Analysis Workflow\n";
  printf "=" |> String.make 50 |> printf "%s\n";
  
  (* Step 1: Extract messages *)
  let extraction_result = extract_messages handler 
    ~storage_path:"/Users/alice/Library/Application Support/Signal"
    ~output_path:"signal_analysis.db" in
  
  (* Step 2: Get conversation list *)
  let conversations = get_conversation_list handler in
  
  (* Step 3: Query for recent messages *)
  let recent_query = "SELECT * FROM messages WHERE timestamp > date('now', '-30 days')" in
  let recent_data = query_database handler 
    ~db_path:extraction_result.output_path 
    ~query:recent_query in
  
  (* Step 4: Export to multiple formats *)
  let json_export = export_to_format handler
    ~db_path:extraction_result.output_path
    ~format:`JSON
    ~output_file:"signal_export.json" in
    
  let csv_export = export_to_format handler
    ~db_path:extraction_result.output_path
    ~format:`CSV
    ~output_file:"signal_export.csv" in
  
  printf "\n📊 Workflow Summary:\n";
  printf "  • Extracted: %d messages\n" extraction_result.extracted_count;
  printf "  • Conversations: %d found\n" (List.length conversations);
  printf "  • Recent data: %d bytes\n" (String.length recent_data);
  printf "  • JSON export: %s\n" (if json_export then "✅" else "❌");
  printf "  • CSV export: %s\n" (if csv_export then "✅" else "❌");
  
  (extraction_result, conversations, recent_data, json_export && csv_export)

(* Main demo function using proper effect system *)
let run_proper_effects_demo () =
  printf "🎯 Signal MCP Server with Proper oxcaml_effect Implementation\n";
  printf "=" |> String.make 70 |> printf "%s\n";
  
  (* Create handler using oxcaml_effect pattern *)
  let handler = create_signal_handler () in
  
  (* Run within effect context using Signal.run *)
  Signal.run (fun () ->
    printf "⚡ Effect system initialized with first-class handlers!\n\n";
    
    (* Demonstrate individual operations *)
    printf "🔸 Individual Effect Operations:\n";
    let result = extract_messages handler 
      ~storage_path:"/path/to/signal/database" 
      ~output_path:"extracted_messages.db" in
    
    let query_result = query_database handler 
      ~db_path:result.output_path 
      ~query:"SELECT sender, COUNT(*) FROM messages GROUP BY sender" in
    
    let conversations = get_conversation_list handler in
    
    (* Demonstrate MCP protocol with effects *)
    printf "\n🔸 MCP Protocol with Effects:\n";
    let _tools = handle_mcp_request handler "req1" "tools/list" None in
    
    let call_params = [
      ("storage_path", "/path/to/signal");
      ("output_path", "mcp_extraction.db")
    ] in
    let _call_result = handle_mcp_request handler "req2" "tools/call" 
      (Some ("extract_signal_messages", call_params)) in
    
    (* Demonstrate workflow composition *)
    printf "\n🔸 Workflow Composition:\n";
    let (_extraction, _conversations, _data, workflow_success) = 
      run_signal_analysis_workflow handler in
    
    printf "\n🎉 Demo completed! Workflow success: %s\n" 
      (if workflow_success then "✅" else "❌");
    printf "=" |> String.make 70 |> printf "%s\n"
  )