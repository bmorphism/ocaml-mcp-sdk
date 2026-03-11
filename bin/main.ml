open! Core

let signal_server_config =
  Mcp.Server.Config.create
    ~name:"pensieve-signal-mcp"
    ~version:"1.0.0"
    ~capabilities:
      { tools = Some { list_changed = true }
      ; resources = Some { list_changed = true; subscribe = true }
      ; prompts = Some { list_changed = true }
      ; logging = true
      ; completions = false
      ; experimental = [ "ocaml_effects", true ]
      }
    ()
;;

let run_demo () =
  printf "MCP SDK Demo - Jane Street OCaml Style\n";
  printf "%s\n\n" (String.make 60 '=');
  printf "Protocol version: %s\n" Mcp.Jsonrpc.protocol_version;
  printf "Server: %s v%s\n\n"
    signal_server_config.name
    signal_server_config.version;
  printf "Available tools:\n";
  List.iter Mcp.Signal.Mcp_handler.tools ~f:(fun (tool : Mcp.Tool.t) ->
    printf "  - %s: %s\n"
      tool.name
      (Option.value tool.description ~default:"(no description)"));
  printf "\nAvailable resources:\n";
  List.iter Mcp.Signal.Mcp_handler.resources ~f:(fun (resource : Mcp.Resource.t) ->
    printf "  - %s [%s]: %s\n"
      resource.name
      resource.uri
      (Option.value resource.description ~default:"(no description)"));
  printf "\nAvailable prompts:\n";
  List.iter Mcp.Signal.Mcp_handler.prompts ~f:(fun (prompt : Mcp.Prompt.t) ->
    printf "  - %s: %s (%d args)\n"
      prompt.name
      (Option.value prompt.description ~default:"(no description)")
      (List.length prompt.arguments));
  printf "\nCapabilities:\n";
  printf "  %s\n"
    (Yojson.Safe.pretty_to_string
       (Mcp.Capabilities.Server.to_yojson signal_server_config.capabilities));
  printf "\n%s\n" (String.make 60 '=');
  printf "Run with 'serve' argument to start MCP stdio server.\n"
;;

let () =
  let mode =
    match Sys.get_argv () |> Array.to_list |> List.tl with
    | Some ("serve" :: _) -> `Serve
    | _ -> `Demo
  in
  match mode with
  | `Serve ->
    Mcp.Signal.Handler.run (fun () ->
      Mcp.Server.run (module Mcp.Signal.Mcp_handler) ~config:signal_server_config)
  | `Demo -> run_demo ()
;;
