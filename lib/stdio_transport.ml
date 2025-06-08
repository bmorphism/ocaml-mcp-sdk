(* Stdio transport handler using oxcaml_effect *)

open Mcp_effect

(* Buffered line reader *)
type reader = {
  mutable buffer: string;
  mutable closed: bool;
}

let create_reader () = { buffer = ""; closed = false }

let read_line reader =
  if reader.closed then None
  else
    try
      let line = input_line stdin in
      Some line
    with End_of_file ->
      reader.closed <- true;
      None

(* Transport handler *)
let handle_transport reader =
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
        reader.closed <- true;
        continue k () []
  }

(* Run with stdio transport *)
let with_stdio_transport f =
  let reader = create_reader () in
  Transport.run (fun h -> f h) |> Transport.Result.handle (handle_transport reader)