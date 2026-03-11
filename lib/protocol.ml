open! Core

type t = { id_gen : Jsonrpc.Id_generator.t }

let create () = { id_gen = Jsonrpc.Id_generator.create () }

let run t f =
  Effect.Deep.match_with
    f
    ()
    { retc = Fn.id
    ; exnc = raise
    ; effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Mcp_effect.Send_request { method_; params } ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                let id = Jsonrpc.Id_generator.next_id t.id_gen in
                let msg = Jsonrpc.Message.request ~id ~method_ ?params () in
                let data = Jsonrpc.Message.encode msg in
                Mcp_effect.write data;
                Effect.Deep.continue k id)
          | Mcp_effect.Send_notification { method_; params } ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                let msg = Jsonrpc.Message.notification ~method_ ?params () in
                let data = Jsonrpc.Message.encode msg in
                Mcp_effect.write data;
                Effect.Deep.continue k ())
          | Mcp_effect.Receive_message ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                let rec read_valid () =
                  let line = Mcp_effect.read () in
                  if String.is_empty line
                  then read_valid ()
                  else (
                    match Jsonrpc.Message.decode line with
                    | Ok msg -> msg
                    | Error _ -> read_valid ())
                in
                let msg = read_valid () in
                Effect.Deep.continue k msg)
          | Mcp_effect.Send_response { id; result } ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                let msg = Jsonrpc.Message.response ~id ~result in
                let data = Jsonrpc.Message.encode msg in
                Mcp_effect.write data;
                Effect.Deep.continue k ())
          | Mcp_effect.Send_error { id; error } ->
            Some
              (fun (k : (a, _) Effect.Deep.continuation) ->
                let msg = Jsonrpc.Message.error ?id error in
                let data = Jsonrpc.Message.encode msg in
                Mcp_effect.write data;
                Effect.Deep.continue k ())
          | _ -> None)
    }
;;
