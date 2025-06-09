(* Standalone Signal Effect System - Complete Demo *)

open Printf

(* Core result types *)
type extraction_result = {
  status: string;
  extracted_count: int;
  output_path: string;
}

(* Effect operation definition using GADT *)
type _ operation =
  | Extract_messages : { 
      storage_path: string; 
      output_path: string;
    } -> extraction_result operation
  | Query_database : { 
      db_path: string; 
      query: string; 
    } -> string operation

(* Effect handler type *)
type 'a effect_handler = {
  handle : 'b. 'b operation -> 'b
}

(* Simple effect implementation without external dependencies *)
let create_signal_handler () = {
  handle = fun (type a) (op : a operation) : a ->
    match op with
    | Extract_messages { storage_path; output_path } ->
        printf "Extracting from %s to %s\n" storage_path output_path;
        { status = "success"; extracted_count = 42; output_path }
        
    | Query_database { db_path; query } ->
        printf "Querying %s: %s\n" db_path query;
        "query results here"
}

(* Helper functions *)
let extract_messages handler ~storage_path ~output_path =
  handler.handle (Extract_messages { storage_path; output_path })

let query_database handler ~db_path ~query =
  handler.handle (Query_database { db_path; query })

(* MCP server simulation *)
let process_mcp_request handler request_id method_name params =
  printf "Processing MCP request %s: %s\n" request_id method_name;
  match method_name with
  | "tools/list" ->
      printf "Returning tool list\n";
      `Assoc [
        ("tools", `List [
          `Assoc [
            ("name", `String "extract_signal_messages");
            ("description", `String "Extract messages from Signal database")
          ]
        ])
      ]
      
  | "tools/call" ->
      (match params with
       | Some (`Assoc params_list) ->
           let tool_name = List.assoc "name" params_list in
           (match tool_name with
            | `String "extract_signal_messages" ->
                let result = extract_messages handler 
                  ~storage_path:"/path/to/signal" 
                  ~output_path:"output.db" in
                printf "Extraction completed: %s (%d messages)\n" 
                  result.status result.extracted_count;
                `Assoc [
                  ("status", `String result.status);
                  ("count", `Int result.extracted_count);
                  ("output", `String result.output_path)
                ]
            | _ -> `Assoc [("error", `String "Unknown tool")]
           )
       | _ -> `Assoc [("error", `String "Invalid parameters")]
      )
      
  | _ -> `Assoc [("error", `String "Unknown method")]

(* Main demo function *)
let run_signal_mcp_demo () =
  printf "Signal MCP Server with Effects - Standalone Demo\n%!";
  
  (* Create effect handler *)
  let handler = create_signal_handler () in
  printf "Effect handler created successfully!\n%!";
  
  (* Demonstrate direct effect operations *)
  printf "\n=== Direct Effect Operations ===\n";
  let result = extract_messages handler ~storage_path:"/path/to/signal" ~output_path:"output.db" in
  printf "Extraction result: %s (%d messages)\n" result.status result.extracted_count;
  
  let query_result = query_database handler ~db_path:"output.db" ~query:"SELECT * FROM messages" in
  printf "Query result: %s\n" query_result;
  
  (* Demonstrate MCP protocol simulation *)
  printf "\n=== MCP Protocol Simulation ===\n";
  let _tools_response = process_mcp_request handler "req1" "tools/list" None in
  printf "Tools list response received\n";
  
  let call_params = `Assoc [("name", `String "extract_signal_messages")] in
  let _call_response = process_mcp_request handler "req2" "tools/call" (Some call_params) in
  printf "Tool call response received\n";
  
  printf "\nDemo completed successfully!\n%!"

(* Entry point - exposed for executable *)