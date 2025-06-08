(* Protocol handler using oxcaml_effect with mode annotations *)

open Mcp_effect
open Modes

(* Protocol state - shared within fiber, never cross-domain *)
type protocol_state = {
  mutable next_id: int;
  pending_requests: (int, json Lwt.u) Hashtbl.t @ local many;
  (* Hashtable can be aliased within the same fiber but stays local *)
}

let create_protocol_state () : protocol_state @ local = {
  next_id = 1;
  pending_requests = Hashtbl.create 16;
}

(* JSON encoding/decoding - returns portable values for cross-domain *)
let encode_request state ~method_ ~params : int * (Yojson.Safe.t @ contended @@ portable) =
  let id = state.next_id in
  state.next_id <- id + 1;
  let json = `Assoc (
    ("jsonrpc", `String "2.0") ::
    ("id", `Int id) ::
    ("method", `String method_) ::
    (match params with
     | Some p -> [("params", p)]
     | None -> [])
  ) in
  id, json

let encode_notification ~method_ ~params : Yojson.Safe.t @ contended @@ portable =
  `Assoc (
    ("jsonrpc", `String "2.0") ::
    ("method", `String method_) ::
    (match params with
     | Some p -> [("params", p)]
     | None -> [])
  )

let encode_response ~id ~result : Yojson.Safe.t @ contended @@ portable =
  `Assoc (
    ("jsonrpc", `String "2.0") ::
    (match id with
     | Some id -> [("id", id)]
     | None -> []) @
    (match result with
     | Some r -> [("result", r)]
     | None -> [("result", `Null)])
  )

let encode_error ~id ~code ~message ~data : Yojson.Safe.t @ contended @@ portable =
  `Assoc (
    ("jsonrpc", `String "2.0") ::
    (match id with
     | Some id -> [("id", id)]
     | None -> []) @
    [("error", `Assoc (
      ("code", `Int code) ::
      ("message", `String message) ::
      (match data with
       | Some d -> [("data", d)]
       | None -> [])
    ))]
  )

(* Message decoding - takes portable JSON from cross-domain *)
let decode_message (json : Yojson.Safe.t @ contended @@ portable) =
  let open Yojson.Safe.Util in
  match json |> member "method" |> to_string_option with
  | Some method_ ->
      let params = json |> member "params" |> fun p ->
        if p = `Null then None else Some p in
      let id = json |> member "id" |> fun i ->
        if i = `Null then None else Some i in
      if id = None then
        Notification { method_; params }
      else
        Request { id; method_; params }
  | None ->
      let id = json |> member "id" |> fun i ->
        if i = `Null then None else Some i in
      match json |> member "error" with
      | `Null ->
          let result = json |> member "result" |> fun r ->
            if r = `Null then None else Some r in
          Response { id; result; error = None }
      | error ->
          let code = error |> member "code" |> to_int in
          let message = error |> member "message" |> to_string in
          let data = error |> member "data" |> fun d ->
            if d = `Null then None else Some d in
          Response { id; result = None; error = Some (code, message, data) }

(* Protocol handler that uses transport *)
let handle_protocol (state : protocol_state @ local) transport_handler =
  let open Protocol in
  { Result.handle = fun op k ->
    match op with
    | Protocol_ops.Send_request { method_; params } ->
        let id, json = encode_request state ~method_ ~params in
        let data = Yojson.Safe.to_string json in
        write_transport transport_handler data;
        (* Store pending request in local hashtable *)
        (* For now, return the id as a simple response *)
        continue k (`Int id) []
        
    | Protocol_ops.Send_notification { method_; params } ->
        let json = encode_notification ~method_ ~params in
        let data = Yojson.Safe.to_string json in
        write_transport transport_handler data;
        continue k () []
        
    | Protocol_ops.Receive_message ->
        let rec read_valid_message () =
          let line = read_transport transport_handler in
          if String.length line = 0 then
            read_valid_message ()
          else
            try
              let json = Yojson.Safe.from_string line in
              decode_message json
            with _ -> read_valid_message ()
        in
        let msg = read_valid_message () in
        continue k msg []
        
    | Protocol_ops.Send_response { id; result } ->
        let json = encode_response ~id ~result in
        let data = Yojson.Safe.to_string json in
        write_transport transport_handler data;
        continue k () []
        
    | Protocol_ops.Send_error { id; code; message; data } ->
        let json = encode_error ~id ~code ~message ~data in
        let data_str = Yojson.Safe.to_string json in
        write_transport transport_handler data_str;
        continue k () []
  }