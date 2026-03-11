open! Core

let protocol_version = "2.0"

module Error_code = struct
  let parse_error = -32700
  let invalid_request = -32600
  let method_not_found = -32601
  let invalid_params = -32602
  let internal_error = -32603
end

module Error_info = struct
  type t =
    { code : int
    ; message : string
    ; data : Yojson.Safe.t option
    }
  [@@deriving sexp_of]

  let to_yojson t =
    `Assoc
      (List.filter_opt
         [ Some ("code", `Int t.code)
         ; Some ("message", `String t.message)
         ; Option.map t.data ~f:(fun d -> "data", d)
         ])
  ;;

  let of_yojson json =
    let open Yojson.Safe.Util in
    { code = json |> member "code" |> to_int
    ; message = json |> member "message" |> to_string
    ; data =
        (match json |> member "data" with
         | `Null -> None
         | d -> Some d)
    }
  ;;

  let method_not_found method_name =
    { code = Error_code.method_not_found
    ; message = [%string "Method not found: %{method_name}"]
    ; data = None
    }
  ;;

  let invalid_params message =
    { code = Error_code.invalid_params; message; data = None }
  ;;

  let internal message =
    { code = Error_code.internal_error; message; data = None }
  ;;
end

module Message = struct
  type t =
    | Request of
        { id : Yojson.Safe.t
        ; method_ : string
        ; params : Yojson.Safe.t option
        }
    | Notification of
        { method_ : string
        ; params : Yojson.Safe.t option
        }
    | Response of
        { id : Yojson.Safe.t
        ; result : Yojson.Safe.t
        }
    | Error of
        { id : Yojson.Safe.t option
        ; error : Error_info.t
        }
  [@@deriving sexp_of]

  let request ~id ~method_ ?params () =
    Request { id; method_; params }
  ;;

  let notification ~method_ ?params () =
    Notification { method_; params }
  ;;

  let response ~id ~result = Response { id; result }

  let error ?id error_info = Error { id; error = error_info }

  let to_yojson = function
    | Request { id; method_; params } ->
      `Assoc
        (List.filter_opt
           [ Some ("jsonrpc", `String protocol_version)
           ; Some ("id", id)
           ; Some ("method", `String method_)
           ; Option.map params ~f:(fun p -> "params", p)
           ])
    | Notification { method_; params } ->
      `Assoc
        (List.filter_opt
           [ Some ("jsonrpc", `String protocol_version)
           ; Some ("method", `String method_)
           ; Option.map params ~f:(fun p -> "params", p)
           ])
    | Response { id; result } ->
      `Assoc
        [ "jsonrpc", `String protocol_version
        ; "id", id
        ; "result", result
        ]
    | Error { id; error } ->
      `Assoc
        (List.filter_opt
           [ Some ("jsonrpc", `String protocol_version)
           ; Option.map id ~f:(fun i -> "id", i)
           ; Some ("error", Error_info.to_yojson error)
           ])
  ;;

  let of_yojson json =
    let open Yojson.Safe.Util in
    let method_opt =
      match json |> member "method" with
      | `Null -> None
      | `String m -> Some m
      | _ -> None
    in
    let id_opt =
      match json |> member "id" with
      | `Null -> None
      | id -> Some id
    in
    match method_opt, id_opt with
    | Some method_, Some id ->
      let params =
        match json |> member "params" with
        | `Null -> None
        | p -> Some p
      in
      Request { id; method_; params }
    | Some method_, None ->
      let params =
        match json |> member "params" with
        | `Null -> None
        | p -> Some p
      in
      Notification { method_; params }
    | None, _ ->
      (match json |> member "error" with
       | `Null ->
         let id = Option.value_exn id_opt ~message:"Response must have id" in
         let result =
           match json |> member "result" with
           | `Null -> `Null
           | r -> r
         in
         Response { id; result }
       | err ->
         Error { id = id_opt; error = Error_info.of_yojson err })
  ;;

  let encode t = Yojson.Safe.to_string (to_yojson t)

  let decode_exn line =
    let json = Yojson.Safe.from_string line in
    of_yojson json
  ;;

  let decode line =
    Or_error.try_with (fun () -> decode_exn line)
  ;;
end

module Id_generator = struct
  type t = { mutable next : int }

  let create () = { next = 1 }

  let next_id t =
    let id = t.next in
    t.next <- id + 1;
    `Int id
  ;;
end
