(* Signal data extraction operations for MCP server *)

type extraction_result = {
  status: string;
  extracted_count: int;
  output_path: string;
  encryption_status: string;
}

type media_result = {
  status: string;
  cataloged_count: int;
  total_size_bytes: int;
  output_path: string;
}

type query_result = {
  status: string;
  rows: Yojson.Safe.t list;
  query_time_ms: float;
}

type schema_info = {
  status: string;
  tables: string list;
  total_tables: int;
  encryption_method: string;
}

(* Signal-specific effect operations *)
module Signal_ops = struct
  type 'a t =
    | Extract_messages : { 
        storage_path: string; 
        keychain_password: string; 
        output_path: string;
        date_range: (string * string) option;
      } -> extraction_result t
    | Extract_media : { 
        message_db: string; 
        output_path: string;
        include_metadata: bool;
        verify_files: bool;
      } -> media_result t  
    | Query_database : { 
        db_path: string; 
        query: string; 
        limit: int;
      } -> query_result t
    | Inspect_schema : { 
        storage_path: string; 
        keychain_password: string;
      } -> schema_info t
end

(* Generate Signal effect module using the Make functor *)
module Signal = Mcp_effect.Make(Signal_ops)

(* Helper functions for Signal operations *)
let extract_signal_messages h ~storage_path ~keychain_password ~output_path ?date_range () =
  Signal.perform h (Signal_ops.Extract_messages { 
    storage_path; 
    keychain_password; 
    output_path;
    date_range;
  })

let extract_media_assets h ~message_db ~output_path ~include_metadata ~verify_files =
  Signal.perform h (Signal_ops.Extract_media { 
    message_db; 
    output_path;
    include_metadata;
    verify_files;
  })

let query_signal_data h ~db_path ~query ~limit =
  Signal.perform h (Signal_ops.Query_database { 
    db_path; 
    query; 
    limit;
  })

let inspect_signal_schema h ~storage_path ~keychain_password =
  Signal.perform h (Signal_ops.Inspect_schema { 
    storage_path; 
    keychain_password;
  })