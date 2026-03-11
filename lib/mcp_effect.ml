open! Core

type _ Effect.t +=
  | Transport_read : string Effect.t
  | Transport_write : string -> unit Effect.t
  | Transport_close : unit Effect.t
  | Send_request :
      { method_ : string
      ; params : Yojson.Safe.t option
      }
      -> Yojson.Safe.t Effect.t
  | Send_notification :
      { method_ : string
      ; params : Yojson.Safe.t option
      }
      -> unit Effect.t
  | Receive_message : Jsonrpc.Message.t Effect.t
  | Send_response :
      { id : Yojson.Safe.t
      ; result : Yojson.Safe.t
      }
      -> unit Effect.t
  | Send_error :
      { id : Yojson.Safe.t option
      ; error : Jsonrpc.Error_info.t
      }
      -> unit Effect.t
  | Log : Log_level.t * string -> unit Effect.t

let read () = Effect.perform Transport_read
let write data = Effect.perform (Transport_write data)
let close () = Effect.perform Transport_close

let send_request ~method_ ?params () =
  Effect.perform (Send_request { method_; params })
;;

let send_notification ~method_ ?params () =
  Effect.perform (Send_notification { method_; params })
;;

let receive_message () = Effect.perform Receive_message

let send_response ~id ~result =
  Effect.perform (Send_response { id; result })
;;

let send_error ?id error =
  Effect.perform (Send_error { id; error })
;;

let log level msg = Effect.perform (Log (level, msg))
