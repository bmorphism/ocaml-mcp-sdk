(* MCP Effects using oxcaml_effect *)

open Oxcaml_effect

(* Transport effect operations *)
module Transport_ops = struct
  type 'a t =
    | Read : string t
    | Write : string -> unit t
    | Close : unit t
end

(* JSON-RPC message types *)
type json = Yojson.Safe.t

type request = {
  id: json option;
  method_: string;
  params: json option;
}

type response = {
  id: json option;
  result: json option;
  error: (int * string * json option) option;
}

type message = 
  | Request of request
  | Response of response
  | Notification of { method_: string; params: json option }

(* Protocol effect operations *)
module Protocol_ops = struct
  type 'a t =
    | Send_request : { method_: string; params: json option } -> json t
    | Send_notification : { method_: string; params: json option } -> unit t
    | Receive_message : message t
    | Send_response : { id: json option; result: json option } -> unit t
    | Send_error : { id: json option; code: int; message: string; data: json option } -> unit t
end

(* Resource effect operations *)
module Resource_ops = struct
  type 'a t =
    | List_resources : json list t
    | Read_resource : string -> json t
end

(* Tool effect operations *)
module Tool_ops = struct
  type 'a t =
    | List_tools : json list t
    | Call_tool : { name: string; arguments: json option } -> json t
end

(* Prompt effect operations *)
module Prompt_ops = struct
  type 'a t =
    | List_prompts : json list t
    | Get_prompt : { name: string; arguments: json option } -> json t
end

(* Create effect modules using oxcaml_effect *)
module Transport = Make(Transport_ops)
module Protocol = Make(Protocol_ops)
module Resource = Make(Resource_ops)
module Tool = Make(Tool_ops)
module Prompt = Make(Prompt_ops)

(* Helper functions for performing effects *)
let read_transport h = Transport.perform h Transport_ops.Read
let write_transport h data = Transport.perform h (Transport_ops.Write data)
let close_transport h = Transport.perform h Transport_ops.Close

let send_request h ~method_ ~params = 
  Protocol.perform h (Protocol_ops.Send_request { method_; params })
  
let send_notification h ~method_ ~params =
  Protocol.perform h (Protocol_ops.Send_notification { method_; params })
  
let receive_message h = Protocol.perform h Protocol_ops.Receive_message

let send_response h ~id ~result =
  Protocol.perform h (Protocol_ops.Send_response { id; result })
  
let send_error h ~id ~code ~message ~data =
  Protocol.perform h (Protocol_ops.Send_error { id; code; message; data })

let list_resources h = Resource.perform h Resource_ops.List_resources
let read_resource h uri = Resource.perform h (Resource_ops.Read_resource uri)

let list_tools h = Tool.perform h Tool_ops.List_tools
let call_tool h ~name ~arguments = Tool.perform h (Tool_ops.Call_tool { name; arguments })

let list_prompts h = Prompt.perform h Prompt_ops.List_prompts
let get_prompt h ~name ~arguments = Prompt.perform h (Prompt_ops.Get_prompt { name; arguments })