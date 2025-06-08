(* Stdio transport handler using oxcaml_effect with mode annotations *)

open Mcp_effect
open Modes

(* Buffered line reader - owned uniquely by transport handler *)
type reader = {
  mutable buffer: string;
  mutable closed: bool;
} [@@unboxed]  (* value mode = unique *)

let create_reader () : reader @ unique = 
  { buffer = ""; closed = false }

let read_line (reader : reader @ unique) : string option =
  if reader.closed then None
  else
    try
      let line = input_line stdin in
      Some line
    with End_of_file ->
      reader.closed <- true;
      None

(* Transport handler - takes unique ownership of reader *)
let handle_transport (reader : reader @ unique) =
  let open Transport in
  { Result.handle = fun op k ->
    match op with
    | Transport_ops.Read ->
        (match read_line reader with
         | Some line -> continue k line []
         | None -> continue k "" [])
    | Transport_ops.Write data ->
        output_string stdout data;
        output_char stdout '\n';
        flush stdout;
        continue k () []
    | Transport_ops.Close ->
        reader.closed <- true;  (* Linear write to unique reader *)
        continue k () []
  }

(* Run with stdio transport - creates unique reader *)
let with_stdio_transport f =
  let reader = create_reader () in  (* reader : reader @ unique *)
  Transport.run (fun h -> f h) 
  |> Transport.Result.handle (handle_transport reader)
  (* handle_transport consumes reader uniquely *)