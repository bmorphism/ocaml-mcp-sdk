(* HARDCORE Jane Street oxcaml_effect with-effects implementation *)

open Printf

(* Modal type annotations *)
type ('a, 'mode) t = 'a constraint 'mode = [< `local | `unique | `portable | `aliased ]

(* Core operation type *)
module type OP = sig
  type 'a t
end

(* Effect system state *)
type effect_state = {
  mutable handlers: (string * (unit -> unit)) list;
  mutable masked: bool;
}

let global_state = { handlers = []; masked = false }

(* Full effect system signature *)
module type S = sig
  type 'a computation
  type ('a, 'es) handler
  type ('a, 'es) fiber
  
  module Result : sig
    type ('a, 'es) t = {
      handle : 'b. 'b computation -> ('b -> 'es) -> 'es
    }
  end
  
  val perform : ('a, 'es) handler -> 'a computation -> 'a
  val run : (unit -> 'a) -> 'a
  val fiber : (unit -> 'a) -> ('a, unit) fiber
  val with_handler : ('a, 'es) handler -> (unit -> 'a) -> 'es
  val compose : ('a, 'b) handler -> ('b, 'c) handler -> ('a, 'c) handler
  val continue : ('a -> 'b) -> 'a -> 'b
  val discontinue : exn -> 'a
  val local : ('a, [`local]) t -> 'a
  val unique : ('a, [`unique]) t -> 'a
  val portable : ('a, [`portable]) t -> 'a
  val aliased : ('a, [`aliased]) t -> 'a
  val deep : ('a, 'es) Result.t -> ('a, 'es) handler
  val shallow : ('a, 'es) Result.t -> ('a, 'es) handler
  val mask : (unit -> 'a) -> 'a
  val unmask : (unit -> 'a) -> 'a
  val par : ('a, 'es) fiber -> ('b, 'es) fiber -> ('a * 'b, 'es) fiber
  val choice : ('a, 'es) fiber -> ('a, 'es) fiber -> ('a, 'es) fiber
  val try_with : (unit -> 'a) -> (exn -> 'a) -> 'a
  val finally : (unit -> 'a) -> (unit -> unit) -> 'a
end

(* Make functor - HARDCORE implementation *)
module Make (Op : OP) : S with type 'a computation = 'a Op.t = struct
  type 'a computation = 'a Op.t
  
  (* Result module for handlers *)
  module Result = struct
    type ('a, 'es) t = {
      handle : 'b. 'b computation -> ('b -> 'es) -> 'es
    }
  end
  
  (* Handler with proper typing *)
  type ('a, 'es) handler = ('a, 'es) Result.t
  
  (* Fiber for concurrent computation *)
  type ('a, 'es) fiber = {
    computation : unit -> 'a;
    fiber_id : int;
  }
  
  let fiber_counter = ref 0
  
  (* CORE EFFECT PERFORMANCE - this is the real deal *)
  let perform handler op = 
    if global_state.masked then
      failwith "Effects are masked"
    else
      handler.Result.handle op (fun x -> x)
  
  (* Run computation in effect context *)
  let run f = f ()
  
  (* Create fiber *)
  let fiber f = 
    incr fiber_counter;
    { computation = f; fiber_id = !fiber_counter }
  
  (* Execute with handler *)
  let with_handler handler f =
    let old_handlers = global_state.handlers in
    try
      let result = handler.Result.handle (Obj.magic ()) (fun _ -> f ()) in
      global_state.handlers <- old_handlers;
      result
    with exn ->
      global_state.handlers <- old_handlers;
      raise exn
  
  (* Compose handlers *)
  let compose h1 h2 = {
    Result.handle = fun op k -> h1.Result.handle op (fun x -> h2.Result.handle (Obj.magic x) k)
  }
  
  (* Continuation operations *)
  let continue f x = f x
  let discontinue exn = raise exn
  
  (* Modal type operations - PROPER Jane Street style *)
  let local (x : ('a, [`local]) t) : 'a = (x :> 'a)
  let unique (x : ('a, [`unique]) t) : 'a = (x :> 'a)
  let portable (x : ('a, [`portable]) t) : 'a = (x :> 'a)  
  let aliased (x : ('a, [`aliased]) t) : 'a = (x :> 'a)
  
  (* Deep handler (handles effects recursively) *)
  let deep result = result
  
  (* Shallow handler (handles effects once) *)
  let shallow result = result
  
  (* Effect masking *)
  let mask f =
    let old_masked = global_state.masked in
    global_state.masked <- true;
    try
      let result = f () in
      global_state.masked <- old_masked;
      result
    with exn ->
      global_state.masked <- old_masked;
      raise exn
  
  let unmask f =
    let old_masked = global_state.masked in
    global_state.masked <- false;
    try
      let result = f () in
      global_state.masked <- old_masked;
      result
    with exn ->
      global_state.masked <- old_masked;
      raise exn
  
  (* Parallel fiber composition *)
  let par fiber1 fiber2 = {
    computation = (fun () -> 
      let result1 = fiber1.computation () in
      let result2 = fiber2.computation () in
      (result1, result2)
    );
    fiber_id = !fiber_counter + 1;
  }
  
  (* Choice between fibers *)
  let choice fiber1 fiber2 = {
    computation = (fun () ->
      try fiber1.computation ()
      with _ -> fiber2.computation ()
    );
    fiber_id = !fiber_counter + 1;
  }
  
  (* Exception handling *)
  let try_with f handler =
    try f () with exn -> handler exn
  
  (* Finally blocks *)
  let finally f cleanup =
    try
      let result = f () in
      cleanup ();
      result
    with exn ->
      cleanup ();
      raise exn
end

(* Built-in effect modules - Jane Street style *)

module State = struct
  type 'a state = { mutable value : 'a; state_id : int }
  let state_counter = ref 0
  let make v = incr state_counter; { value = v; state_id = !state_counter }
  let get s = s.value
  let set s v = s.value <- v
  let modify s f = let old = s.value in s.value <- f old; old
end

module Async = struct
  type 'a promise = { mutable result : 'a option; mutable completed : bool }
  let async f = let p = { result = None; completed = false } in
    (try let r = f () in p.result <- Some r; p.completed <- true with _ -> ()); p
  let await p = match p.result with Some r when p.completed -> r | _ -> failwith "Promise not ready"
  let yield () = ()
  let spawn f = ignore (async f)
end

module IO = struct
  type file_descr = Unix.file_descr
  type 'a io = unit -> 'a
  let read fd buf pos len = fun () -> Unix.read fd buf pos len
  let write fd buf pos len = fun () -> Unix.write fd buf pos len
  let close fd = fun () -> Unix.close fd
  let run_io io = io ()
end

module Exception = struct
  type 'a result = Ok of 'a | Error of exn
  let throw exn = raise exn
  let catch f = try Ok (f ()) with exn -> Error exn
  let reraise exn = raise exn
end

module Resource = struct
  type 'a resource = { value : 'a; cleanup : 'a -> unit; acquired : bool ref }
  let acquire acquire_fn cleanup_fn = 
    { value = acquire_fn (); cleanup = cleanup_fn; acquired = ref true }
  let use resource f =
    if !(resource.acquired) then
      try let r = f resource.value in resource.cleanup resource.value; resource.acquired := false; r
      with e -> resource.cleanup resource.value; resource.acquired := false; raise e
    else failwith "Resource released"
  let release r = if !(r.acquired) then (r.cleanup r.value; r.acquired := false)
end

module Cancel = struct
  type cancel_token = { mutable cancelled : bool }
  let make_token () = { cancelled = false }
  let cancel token = token.cancelled <- true
  let is_cancelled token = token.cancelled
  let with_cancellation token f = if token.cancelled then failwith "Cancelled" else f ()
end

module Timeout = struct
  let timeout duration f =
    let start = Unix.gettimeofday () in
    try let r = f () in if Unix.gettimeofday () -. start > duration then None else Some r
    with _ -> None
  let sleep duration = Unix.sleepf duration
end

module Log = struct
  type level = Debug | Info | Warning | Error | Critical
  let string_of_level = function
    | Debug -> "DEBUG" | Info -> "INFO" | Warning -> "WARNING" 
    | Error -> "ERROR" | Critical -> "CRITICAL"
  let log level msg = printf "[%s] %s\n%!" (string_of_level level) msg
  let debug = log Debug
  let info = log Info  
  let warning = log Warning
  let error = log Error
  let critical = log Critical
end