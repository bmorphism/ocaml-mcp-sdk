(* Jane Street oxcaml_effect with-effects branch - FULL IMPLEMENTATION *)

(* Modal type annotations for resource tracking *)
type ('a, 'mode) t constraint 'mode = [< `local | `unique | `portable | `aliased ]

(* Core operation type signature *)
module type OP = sig
  type 'a t
end

(* Full effect system signature with modal types *)
module type S = sig
  type 'a computation
  type ('a, 'es) handler
  type ('a, 'es) fiber
  
  (* Result module with proper handler typing *)
  module Result : sig
    type ('a, 'es) t = {
      handle : 'b. 'b computation -> ('b -> 'es) -> 'es
    }
  end
  
  (* Core effect operations *)
  val perform : ('a, 'es) handler -> 'a computation -> 'a
  val run : (unit -> 'a) -> 'a
  val fiber : (unit -> 'a) -> ('a, unit) fiber
  
  (* Handler combinators *)
  val with_handler : ('a, 'es) handler -> (unit -> 'a) -> 'es
  val compose : ('a, 'b) handler -> ('b, 'c) handler -> ('a, 'c) handler
  
  (* Continuation management *)
  val continue : ('a -> 'b) -> 'a -> 'b
  val discontinue : exn -> 'a
  
  (* Resource management with modal types *)
  val local : ('a, [`local]) t -> 'a
  val unique : ('a, [`unique]) t -> 'a
  val portable : ('a, [`portable]) t -> 'a
  val aliased : ('a, [`aliased]) t -> 'a
  
  (* Deep and shallow handlers *)
  val deep : ('a, 'es) Result.t -> ('a, 'es) handler
  val shallow : ('a, 'es) Result.t -> ('a, 'es) handler
  
  (* Effect masking and unmasking *)
  val mask : (unit -> 'a) -> 'a
  val unmask : (unit -> 'a) -> 'a
  
  (* Parallel composition *)
  val par : ('a, 'es) fiber -> ('b, 'es) fiber -> ('a * 'b, 'es) fiber
  val choice : ('a, 'es) fiber -> ('a, 'es) fiber -> ('a, 'es) fiber
  
  (* Error handling *)
  val try_with : (unit -> 'a) -> (exn -> 'a) -> 'a
  val finally : (unit -> 'a) -> (unit -> unit) -> 'a
end

(* Make functor for creating effect modules *)
module Make (Op : OP) : S with type 'a computation = 'a Op.t

(* Built-in effect operations *)
module State : sig
  type 'a state
  val make : 'a -> 'a state
  val get : 'a state -> 'a
  val set : 'a state -> 'a -> unit
  val modify : 'a state -> ('a -> 'a) -> 'a
end

module Async : sig
  type 'a promise
  val async : (unit -> 'a) -> 'a promise
  val await : 'a promise -> 'a
  val yield : unit -> unit
  val spawn : (unit -> unit) -> unit
end

module IO : sig
  type file_descr
  type 'a io
  val read : file_descr -> bytes -> int -> int -> int io
  val write : file_descr -> bytes -> int -> int -> int io
  val close : file_descr -> unit io
  val run_io : 'a io -> 'a
end

(* Exception effects *)
module Exception : sig
  type 'a result = Ok of 'a | Error of exn
  val throw : exn -> 'a
  val catch : (unit -> 'a) -> 'a result
  val reraise : exn -> 'a
end

(* Resource management *)
module Resource : sig
  type 'a resource
  val acquire : (unit -> 'a) -> ('a -> unit) -> 'a resource
  val use : 'a resource -> ('a -> 'b) -> 'b
  val release : 'a resource -> unit
end

(* Cancellation *)
module Cancel : sig
  type cancel_token
  val make_token : unit -> cancel_token
  val cancel : cancel_token -> unit
  val is_cancelled : cancel_token -> bool
  val with_cancellation : cancel_token -> (unit -> 'a) -> 'a
end

(* Timeout *)
module Timeout : sig
  val timeout : float -> (unit -> 'a) -> 'a option
  val sleep : float -> unit
end

(* Logging effects *)
module Log : sig
  type level = Debug | Info | Warning | Error | Critical
  val log : level -> string -> unit
  val debug : string -> unit
  val info : string -> unit
  val warning : string -> unit
  val error : string -> unit
  val critical : string -> unit
end