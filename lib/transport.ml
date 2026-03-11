open! Core

module type S = sig
  val run : (unit -> 'a) -> 'a
end

module Stdio : S = struct
  type reader =
    { mutable closed : bool
    ; in_channel : In_channel.t
    ; out_channel : Out_channel.t
    }

  let create () =
    { closed = false; in_channel = In_channel.stdin; out_channel = Out_channel.stdout }
  ;;

  let read_line reader =
    if reader.closed
    then None
    else (
      try Some (In_channel.input_line_exn reader.in_channel) with
      | End_of_file ->
        reader.closed <- true;
        None)
  ;;

  let write_line reader data =
    Out_channel.output_string reader.out_channel data;
    Out_channel.newline reader.out_channel;
    Out_channel.flush reader.out_channel
  ;;

  let run f =
    let reader = create () in
    Effect.Deep.match_with
      f
      ()
      { retc = Fn.id
      ; exnc = raise
      ; effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Mcp_effect.Transport_read ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  let line =
                    match read_line reader with
                    | Some line -> line
                    | None -> ""
                  in
                  Effect.Deep.continue k line)
            | Mcp_effect.Transport_write data ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  write_line reader data;
                  Effect.Deep.continue k ())
            | Mcp_effect.Transport_close ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  reader.closed <- true;
                  Effect.Deep.continue k ())
            | _ -> None)
      }
  ;;
end
