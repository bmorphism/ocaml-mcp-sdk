(* Simple Signal Effect System without JSON dependencies *)

open Printf
module Oxcaml_effect = struct
  include Oxcaml_effect.Effect
end

(* Core result types *)
type extraction_result = {
  status: string;
  extracted_count: int;
  output_path: string;
}

(* STEP 1 - Signal operations *)
module Signal_ops = struct
  type 'a t =
    | Extract_messages : { 
        storage_path: string; 
        output_path: string;
      } -> extraction_result t
    | Query_database : { 
        db_path: string; 
        query: string; 
      } -> string t
end

(* STEP 2 - Instantiate the functor *)
module Signal = Oxcaml_effect.Make(Signal_ops)

(* STEP 3 - Write handlers *)
let signal_handler =
  let open Signal in
  { Result.handle = fun op k ->
    match op with
    | Signal_ops.Extract_messages { storage_path; output_path } ->
        printf "Extracting from %s to %s\n" storage_path output_path;
        let result = { status = "success"; extracted_count = 42; output_path } in
        k result
        
    | Signal_ops.Query_database { db_path; query } ->
        printf "Querying %s: %s\n" db_path query;
        k "query results here"
  }

(* Helper functions *)
let extract_messages handler ~storage_path ~output_path =
  Signal.perform handler (Signal_ops.Extract_messages { storage_path; output_path })

let query_database handler ~db_path ~query =
  Signal.perform handler (Signal_ops.Query_database { db_path; query })

(* Main server function *)
let run_signal_effects_demo () =
  printf "Signal MCP Server with Effects - Demo\n%!";
  
  Signal.run (fun () ->
    printf "Effect system initialized successfully!\n%!";
    
    (* Demonstrate effect operations *)
    let result = extract_messages () ~storage_path:"/path/to/signal" ~output_path:"output.db" in
    printf "Extraction result: %s (%d messages)\n" result.status result.extracted_count;
    
    let query_result = query_database () ~db_path:"output.db" ~query:"SELECT * FROM messages" in
    printf "Query result: %s\n" query_result;
    
    printf "Demo completed successfully!\n%!"
  )