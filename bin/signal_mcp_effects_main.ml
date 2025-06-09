(* Signal MCP Server with Effects - Main executable *)

open Ocaml_mcp_sdk.Signal_mcp_effects

let () =
  (* Initialize logging *)
  Printf.printf "Pensieve Signal MCP Server with Effects - Initializing...\n%!";
  
  (* Set up signal handlers for graceful shutdown *)
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ ->
    Printf.printf "\nReceived SIGINT, shutting down gracefully...\n%!";
    exit 0
  ));
  
  (* Run the Signal MCP server with effect system *)
  try
    run_signal_mcp_server_with_effects ()
  with
  | exn ->
    Printf.printf "Error running Signal MCP server with effects: %s\n%!" (Printexc.to_string exn);
    exit 1