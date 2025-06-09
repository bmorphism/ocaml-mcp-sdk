(* Signal MCP Server Executable *)

open Ocaml_mcp_sdk.Test_simple

let () =
  (* Initialize logging *)
  Printf.printf "Pensieve Signal MCP Server - Initializing...\n%!";
  
  (* Set up signal handlers for graceful shutdown *)
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ ->
    Printf.printf "\nReceived SIGINT, shutting down gracefully...\n%!";
    exit 0
  ));
  
  (* Run the Signal MCP server *)
  try
    run_signal_mcp_server ()
  with
  | exn ->
    Printf.printf "Error running Signal MCP server: %s\n%!" (Printexc.to_string exn);
    exit 1