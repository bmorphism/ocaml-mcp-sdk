

module Obj = struct
  include Stdlib.Obj
  include Basement.Stdlib_shim.Obj
end

module Modes = Base.Modes

module Handler_index : sig @@ portable
  (** [(es1, es2) t] represents an index into the effect list [es2]. [es1] is the tail
      sublist containing the index and all following effects. For instance,
      [('b * ('c * unit), 'a * ('b * ('c * unit)) t] represents effect 1, ['b].

      It is used for building [Raw_handler.t]s, which represent one of the effects handled
      by a particular handler. *)
  type ('es1, 'es2) t : immediate

  (** [zero] is the index of the first element of an effect list. *)
  val zero : ('es, 'es) t

  (** [zero] is the index of the second element of an effect list. *)
  val one : ('es, 'e * 'es) t

  (** [succ t] is the index of the next element of an effect list after [t]. *)
  val succ : ('e * 'es1, 'es2) t -> ('es1, 'es2) t

  (** [is_zero t] tests if [t] is the index of the first element of an effect list. If it
      is then we learn that the remaining list is equal to the full list. *)
  val is_zero : ('es1, 'es2) t -> ('es1, 'es2) Type.eq option

  (** [weaken t] is an index for [es], where [t] is an index for [e * es]. If [t] is
      [zero] then [weaken t] is an invalid index and does not correspond to an element in
      [es]. *)
  val weaken : ('es1, 'e * 'es2) t -> ('es1, 'es2) t

  (** [to_int t] is the integer representation of [t]. *)
  val to_int : ('es1, 'es2) t -> int
end = struct
  type ('es1, 'es2) t = int

  let zero = 0
  let one = 1
  let succ t = t + 1

  let is_zero (type es1 es2) (t : (es1, es2) t) =
    if Int.equal t 0
    then (Obj.magic (Some Type.Equal) : (es1, es2) Type.eq option)
    else None
  ;;

  let weaken t = t - 1
  let to_int t = t
end

module Raw_handler : sig @@ portable
  (** [(e, es) t] is a handler for the effect [e], which must be an element of the effect
      list [es].

      It is used to represent one of the effects handled by a particular handler. *)
  type ('e, 'es) t : immediate

  (** [of_index i] is the handler corresponding to index [t]. *)
  val of_index : ('e * _, 'es) Handler_index.t -> ('e, 'es) t

  (** [zero] is [of_index (Handler_index.zero)]. *)
  val zero : ('e, 'e * _) t

  (** [is_zero t] tests if this handler is [zero]. If it is we learn that the handled
      effect is the first effect in the list. *)
  val is_zero : ('e1, 'e2 * _) t -> ('e1, 'e2) Type.eq option

  (** [weaken t] is a handler from the list [es], where [t] is a handler from the list
      [e * es]. If [t] is [zero] then [weaken t] is an invalid handler (i.e. not actually
      in the list). *)
  val weaken : ('e1, 'e2 * 'es2) t -> ('e1, 'es2) t

  (** [to_int t] is the integer representation of [t]. *)
  val to_int : ('e, 'es) t -> int
end = struct
  type ('e, 'es) t = Raw_handler : ('e * _, 'es) Handler_index.t -> ('e, 'es) t
  [@@unboxed]

  let of_index i = Raw_handler i
  let zero = Raw_handler Handler_index.zero

  let is_zero (type e1 e2 es) (Raw_handler i : (e1, e2 * es) t) : (e1, e2) Type.eq option =
    match Handler_index.is_zero i with
    | Some Equal as eq -> eq
    | None as eq -> eq
  ;;

  let weaken (Raw_handler i) = Raw_handler (Handler_index.weaken i)
  let to_int (Raw_handler i) = Handler_index.to_int i
end

module Handler : sig @@ portable
  (** [e t] is a handler for the effect [e]. *)
  type 'e t' = private ..


  (** Heap-allocated handler. *)
  type 'e t = { h : 'e t' @@ aliased global } [@@unboxed]

  type _ t' += Dummy : 'a t'

  module List : sig
    type 'e handler := 'e t

    type 'es t =
      | [] : unit t
      | ( :: ) : 'e handler * 'es t -> ('e * 'es) t
      (** [es t] is a list of handlers for effects [es]. *)

    module Length : sig
      type x = X (** [x] is the type of [X]s *)

      type 'es t =
        | [] : unit t
        | ( :: ) : x * 'es t -> ('e * 'es) t
        (** [es t] is the length of effect list [es]. It has slightly unusual constructors
            so that lengths can be written as [[X;X;X]] rather than e.g. [(S (S (S Z)))].
            This looks nicer on calls to [fiber_with]:

            {[
              fiber_with [X; X; X] (fun [a; b; c] -> ...)
            ]} *)
    end

    (** [length t] is the length of [t]. *)
    val length : 'es t @ local -> 'es Length.t
  end

  module type Create = sig
    type e
    type es
    type 'e t' += C : ('e, e * es) Raw_handler.t -> 'e t'

    (** [initial ~length] is a list of handlers for effects [es], where [length] is the
        length of [es]. *)
    val initial : length:es List.Length.t @ local -> es List.t

    (** [initial_from hs] is a list of handlers for effect [es], where [hs] is another
        list of handlers for effects [es]. These handlers are selected from the effect
        list [e * es] for some effect [e]. Note that [hs] is being used only for its
        length -- the actual handlers in it do not affect the output. *)
    val initial_from : es List.t @ local -> es List.t
  end

  val create : unit -> (module Create with type e = 'e and type es = 'es)
end = struct
  type 'e t' = ..
  type 'e t = { h : 'e t' @@ aliased global } [@@unboxed]
  type _ t' += Dummy : 'a t'

  module List = struct
    type 'e handler = 'e t

    type 'es t =
      | [] : unit t
      | ( :: ) : 'e handler * 'es t -> ('e * 'es) t

    module Length = struct
      type x = X

      type 'es t =
        | [] : unit t
        | ( :: ) : x * 'es t -> ('e * 'es) t
    end

    let length t =
      let rec loop : type es. es t @ local -> es Length.t = function
        | [] -> []
        | _ :: rest -> X :: loop rest
      in
      loop t [@nontail]
    ;;
  end

  module type Create = sig
    type e
    type es
    type 'e t' += C : ('e, e * es) Raw_handler.t -> 'e t'

    val initial : length:es List.Length.t @ local -> es List.t
    val initial_from : es List.t @ local -> es List.t
  end

  let[@inline] create (type e es) () : (module Create with type e = e and type es = es) =
    let module Create = struct
      type nonrec e = e
      type nonrec es = es
      type 'e t' += C : ('e, e * es) Raw_handler.t -> 'e t'

      let initial ~(length : es List.Length.t) : es List.t =
        let rec loop
          : type esr.
            (esr, e * es) Handler_index.t -> esr List.Length.t @ local -> esr List.t
          =
          fun i l ->
          match l with
          | [] -> []
          | X :: l' ->
            let h = Raw_handler.of_index i in
            { h = C h } :: loop (Handler_index.succ i) l'
        in
        loop Handler_index.one length [@nontail]
      ;;

      let initial_from (t : es List.t @@ local) : es List.t =
        let rec loop
          : type esr. (esr, e * es) Handler_index.t -> esr List.t @ local -> esr List.t
          =
          fun i l ->
          match l with
          | [] -> []
          | _ :: rest ->
            let h = Raw_handler.of_index i in
            { h = C h } :: loop (Handler_index.succ i) rest
        in
        loop Handler_index.one t [@nontail]
      ;;
    end
    in
    (module Create)
  ;;
end

module Mapping : sig @@ portable
  (** [es t] represents a mutable mapping from an effect in [es] to its handler. *)
  type 'es t

  (** [lookup h t] looks up the effect handled by [h] in mapping [t] and returns its
      handler. *)
  val lookup : ('e, 'es) Raw_handler.t @ local -> 'es t -> 'e Handler.t

  (** [empty] is the mapping for the empty effect list. *)
  val empty : unit -> unit t

  (** [create hs] creates a new mapping from [es], where [hs] is a list of handlers for
      the effects [es]. Its initial value is to map each effect in [es] to the
      corresponding handler in [hs]. *)
  val create : 'es Handler.List.t @ local -> 'es t

  (** [set hs t] updates the mapping [t] to map each effect handled by [hs] to its
      corresponding handler in [hs]. *)
  val set : 'es Handler.List.t @ local -> 'es t -> unit

  (** [create len] creates a new uninitialized mapping from [es], where [len] is the
      length of [es]. The mapping must be initialized with [set] before it is used. *)
  val create_unset : 'es Handler.List.Length.t @ local -> 'es t
end = struct
  type element : immediate

  let uninitialized () : element = Obj.magic (-1)

  type 'es1 t = element array

  let lookup (type e es) (h : (e, es) Raw_handler.t) (t : es t) =
    let elt = Array.unsafe_get t (Raw_handler.to_int h) in
    (Obj.magic elt : e Handler.t)
  ;;

  let empty () = [||]

  let make (type es) (idx : (unit, es) Handler_index.t) : es t =
    Array.make (Handler_index.to_int idx) (uninitialized ())
  ;;

  let set_element
    (type e esr es)
    (t : es t)
    (idx : (e * esr, es) Handler_index.t)
    (h : e Handler.t @@ local)
    =
    let elt : element = Obj.magic h.h in
    Array.unsafe_set t (Handler_index.to_int idx) elt
  ;;

  let create (type es) (l : es Handler.List.t @@ local) =
    let rec loop
      : type esr. (esr, es) Handler_index.t -> esr Handler.List.t @ local -> es t
      =
      fun idx l ->
      match l with
      | [] -> make idx
      | h :: rest ->
        let t = loop (Handler_index.succ idx) rest in
        set_element t idx h;
        t
    in
    loop Handler_index.zero l [@nontail]
  ;;

  let set (type es) (hs : es Handler.List.t @@ local) (t : es t) =
    let rec loop
      : type esr. (esr, es) Handler_index.t -> esr Handler.List.t @ local -> es t -> unit
      =
      fun idx hs t ->
      match hs with
      | [] -> ()
      | h :: rest ->
        set_element t idx h;
        loop (Handler_index.succ idx) rest t
    in
    loop Handler_index.zero hs t [@nontail]
  ;;

  let create_unset (type es) (l : es Handler.List.Length.t @@ local) =
    let rec loop
      : type esr. (esr, es) Handler_index.t -> esr Handler.List.Length.t @ local -> es t
      =
      fun idx l ->
      match l with
      | [] -> make idx
      | X :: l' -> loop (Handler_index.succ idx) l'
    in
    loop Handler_index.zero l [@nontail]
  ;;
end

type ('a, 'e) op
type ('a, 'e) perform = ('a, 'e) op * 'e Handler.t'

(* [perform_] is able to return a unique value because [continue] is required
   to provide a unique value. *)
external perform_ : ('a, 'e) perform -> 'a @ unique @@ portable = "%perform"

(* A last_fiber is a tagged pointer, so does not keep the fiber alive.
   It must never be the sole reference to the fiber, and is only used to cache
   the final fiber in the linked list formed by [cont.fiber->parent]. *)
type last_fiber : immediate
type (-'a, +'b) cont

let borrow (f : ('a, 'b) cont @ local -> 'c @ unique) (k : ('a, 'b) cont @@ unique)
  : 'c * ('a, 'b) cont
  =
  f k, Obj.magic_unique k
;;

external get_cont_callstack
  :  ('a, 'b) cont @ local
  -> int
  -> Printexc.raw_backtrace
  @@ portable
  = "caml_get_continuation_callstack"

external cont_last_fiber : ('a, 'b) cont @ local -> last_fiber @@ portable = "%field1"

external cont_set_last_fiber
  :  ('a, 'b) cont @ local
  -> last_fiber
  -> unit
  @@ portable
  = "%setfield1"

type 'b effc =
  { effc : 'o 'e. ('o, 'e) perform -> ('o, 'b) cont @ unique -> last_fiber -> 'b @ unique
  }
[@@unboxed]

module Must_not_enter_gc = struct
  (* Stacks are represented as tagged pointers, so do not keep the fiber alive.
     We must not enter the GC between the creation and use of a [stack]. *)
  type (-'a, +'b) stack : immediate

  external alloc_stack
    :  ('a -> 'b)
    -> (exn -> 'b)
    -> 'b effc
    -> ('a, 'b) stack
    @@ portable
    = "caml_alloc_stack"

  external runstack
    :  ('a, 'b) stack
    -> ('c -> 'a) @ once
    -> 'c
    -> 'b @ unique
    @@ portable
    = "%runstack"

  external take_cont_noexc
    :  ('a, 'b) cont
    -> ('a, 'b) stack
    @@ portable
    = "caml_continuation_use_noexc"
  [@@noalloc]

  external resume
    :  ('a, 'b) stack
    -> ('c -> 'a) @ once
    -> 'c
    -> last_fiber
    -> 'b @ unique
    @@ portable
    = "%resume"

  let is_runtime5 () = Basement.Stdlib_shim.runtime5 ()

  (* Allocate a stack and immediately run [f x] using that stack.
     We must not enter the GC between [alloc_stack] and [runstack].
     [with_stack] is marked as [@inline never] to avoid reordering. *)
  let[@inline never] with_stack valuec exnc effc f x =
    if not (is_runtime5 ()) then failwith "Effects require the OCaml 5 runtime.";
    runstack (alloc_stack valuec exnc effc) f x
  ;;

  (* Retrieve the stack from a [cont]inuation and run [f x] using it.
     We must not enter the GC between [take_cont_noexc] and [resume].
     [with_cont] is marked as [@inline never] to avoid reordering. *)
  let[@inline never] with_cont cont f x =
    if not (is_runtime5 ()) then failwith "Effects require the OCaml 5 runtime.";
    let fiber, cont = borrow (fun k -> cont_last_fiber k) cont in
    resume (take_cont_noexc cont) f x fiber
  ;;
end

type (+'a, 'es) r =
  | Val : 'a @@ aliased global -> ('a, 'es) r
  | Exn : exn @@ aliased global -> ('a, 'es) r
  | Op :
      ('o, 'e) op @@ aliased global
      * ('e, 'es) Raw_handler.t
      * ('o, ('a, 'es) r) cont
      * last_fiber
      -> ('a, 'es) r

let valuec v = Val v
let exnc e = Exn e

external reperform
  :  ('a, 'e) perform
  -> ('a, 'b) cont @ unique
  -> last_fiber
  -> 'b @ unique
  @@ portable
  = "%reperform"

let alloc_cont
  (type a b h e es)
  (module H : Handler.Create with type e = e and type es = es)
  (f : h @ local -> a -> b @@ once)
  (h : h)
  : (a, (b, e * es) r) cont
  =
  let exception Ready__ of (a, (b, e * es) r) cont in
  let effc
    (type o eh)
    ((op, h) as perf : (o, eh) perform)
    (k : (o, (b, e * es) r) cont)
    last_fiber
    =
    match h with
    | H.C h -> Op (op, h, k, last_fiber)
    | Handler.Dummy ->
      let k = (Obj.magic k : (a, (b, e * es) r) cont) in
      cont_set_last_fiber k last_fiber;
      (* Note that [k] is still actually unique here. *)
      Basement.Stdlib_shim.raise_notrace (Ready__ k)
    | _ -> reperform perf k last_fiber
  in
  let dummy_op : (a, e) op = Obj.magic () in
  let p = dummy_op, Handler.Dummy in
  match
    Must_not_enter_gc.with_stack valuec exnc { effc } (fun () -> f h (perform_ p)) ()
  with
  | _ -> assert false
  (* [Ready__ k] is only ever raised once with an unique [k]. However,
     raised exceptions must have the legacy mode, so we can't get rid
     of [magic_unique] here. *)
  | exception Ready__ k -> Obj.magic_unique k
;;

let run_stack
  (type a h e es)
  (module H : Handler.Create with type e = e and type es = es)
  (f : h @ local -> a @@ once)
  (h : h)
  : (a, e * es) r
  =
  let effc ((op, h) as perf) k last_fiber =
    match h with
    | H.C h -> Op (op, h, k, last_fiber)
    | _ -> reperform perf k last_fiber
  in
  Must_not_enter_gc.with_stack valuec exnc { effc } f h
;;

type (-'a, +'b, 'e, 'es) continuation =
  | Cont :
      { cont : ('a, ('b, 'e * 'es) r) cont
      ; mapping : 'es Mapping.t @@ aliased global
      }
      -> ('a, 'b, 'e, 'es) continuation

type ('a, 'e, 'es) res =
  | Value : 'a @@ aliased global -> ('a, 'e, 'es) res
  | Exception : exn @@ aliased global -> ('a, 'e, 'es) res
  | Operation :
      ('o, 'e) op @@ aliased global * ('o, 'a, 'e, 'es) continuation
      -> ('a, 'e, 'es) res

let get_callstack (Cont { cont; mapping }) i =
  let bt, cont =
    borrow (fun cont -> { Modes.Aliased.aliased = get_cont_callstack cont i }) cont
  in
  bt, Cont { cont; mapping }
;;

let rec handle
  : type a e es. es Mapping.t -> (a, e * es) r @ unique -> (a, e, es) res @ unique
  =
  fun mapping -> function
  | Val x -> Value x
  | Exn e -> Exception e
  | Op (op, handler, k, last_fiber) ->
    (match Raw_handler.is_zero handler with
     | Some Equal ->
       let (), k = borrow (fun k -> cont_set_last_fiber k last_fiber) k in
       Operation (op, Cont { cont = k; mapping })
     | None ->
       let handler = Raw_handler.weaken handler in
       let fwd = Mapping.lookup handler mapping in
       (* the bytecode compiler requires [reperform] to be in tail position *)
       let result = (fun () -> reperform (op, fwd.h) k last_fiber) () in
       handle mapping result)
;;

let resume (Cont { cont; mapping }) f x handlers =
  Mapping.set handlers mapping;
  handle mapping (Must_not_enter_gc.with_cont cont f x)
;;

let continue k v hs = resume k (fun x -> x) v hs
let discontinue k e hs = resume k (fun e -> raise e) e hs

let discontinue_with_backtrace k e bt hs =
  resume k (fun e -> Printexc.raise_with_backtrace e bt) e hs
;;

let fiber (type a b e) (f : e Handler.t @ local -> a -> b @@ once) =
  let module H =
    (val Handler.create () : Handler.Create with type e = e and type es = unit)
  in
  let handler : (e, e * unit) Raw_handler.t = Raw_handler.zero in
  let handler : e Handler.t = { h = H.C handler } in
  let mapping = Mapping.empty () in
  let cont = alloc_cont (module H) f handler in
  Cont { cont; mapping }
;;

let fiber_with
  (type a b e es)
  (l : es Handler.List.Length.t @@ local)
  (f : (e * es) Handler.List.t @ local -> a -> b @@ once)
  =
  let module H = (val Handler.create () : Handler.Create with type e = e and type es = es)
  in
  let handler : (e, e * es) Raw_handler.t = Raw_handler.zero in
  let handlers : (e * es) Handler.List.t = { h = H.C handler } :: H.initial ~length:l in
  let mapping = Mapping.create_unset l in
  let cont = alloc_cont (module H) f handlers in
  Cont { cont; mapping }
;;

let run (type a e) (f : e Handler.t @ local -> a @@ once) =
  let module H =
    (val Handler.create () : Handler.Create with type e = e and type es = unit)
  in
  let handler : (e, e * unit) Raw_handler.t = Raw_handler.zero in
  let handler : e Handler.t = { h = H.C handler } in
  let res = run_stack (module H) f handler in
  handle (Mapping.empty ()) res
;;

let run_with
  (type a e es)
  (hs : es Handler.List.t @@ local)
  (f : (e * es) Handler.List.t @ local -> a @@ once)
  =
  let module H = (val Handler.create () : Handler.Create with type e = e and type es = es)
  in
  let handler : (e, e * es) Raw_handler.t = Raw_handler.zero in
  let handlers : (e * es) Handler.List.t = { h = H.C handler } :: H.initial_from hs in
  let mapping = Mapping.create hs in
  let res = run_stack (module H) f handlers in
  handle mapping res
;;

(* Data-race-free wrappers around [fiber]/[run] functions.

   Uses [Obj.magic_portable] to avoid duplicating implementations
   of [alloc_cont]/[run_stack] in absence of mode polymorphism.

   Wrappers provide the handler at [portable], but require [portable]
   arguments and operations, which are marked as [contended]. *)
module DRF : sig @@ portable
  

val fiber :
  ('a : value mod portable) 'b 'e .
    once_ (local_ 'e Handler.t @ portable -> 'a @ contended -> 'b) -> unique_
      ('a, 'b, 'e, unit) continuation
val fiber_with :
  ('a : value mod portable) 'b 'e 'es .
    local_ 'es Handler.List.Length.t ->
      once_
        (local_ ('e * 'es) Handler.List.t @ portable -> 'a @ contended -> 'b)
        -> unique_ ('a, 'b, 'e, 'es) continuation
val run :
  once_ (local_ 'e Handler.t @ portable -> 'a) -> unique_ ('a, 'e, unit) res
val run_with :
  local_ 'es Handler.List.t @ portable ->
    once_ (local_ ('e * 'es) Handler.List.t @ portable -> 'a) -> unique_
      ('a, 'e, 'es) res

end = struct
  let[@inline] fiber f =
    let f h a = f (Obj.magic_portable h) (Obj.magic_portable a) [@nontail] in
    let k : ('a, 'b, 'e, unit) continuation = Obj.magic_at_unique (fiber f) in
    k
  ;;

  let[@inline] fiber_with hs f =
    let f hs a = f (Obj.magic_portable hs) (Obj.magic_portable a) [@nontail] in
    let k : ('a, 'b, 'e, 'es) continuation = Obj.magic_at_unique (fiber_with hs f) in
    k
  ;;

  let[@inline] run f =
    let f h = f (Obj.magic_portable h) [@nontail] in
    run f
  ;;

  let[@inline] run_with hs f =
    let f hs = f (Obj.magic_portable hs) [@nontail] in
    run_with hs f
  ;;
end

module Continuation = struct
  type (-'a, +'b, 'es) t : value mod contended many =
    | Continuation : ('a, 'c, 'e, 'es) continuation -> ('a, 'b, 'es) t
  [@@unsafe_allow_any_mode_crossing "Only accesses mutable data uniquely. "] [@@unboxed]
  (* This type has an unexpressible constraint that ['b] is a type that
     can safely be [Obj.magic]ed from [(c, e, es) res] *)

  let get_callstack (Continuation cont) i =
    let bt, cont = get_callstack cont i in
    bt, Continuation cont
  ;;
end

let continue (type a b es) (k : (a, b, es) Continuation.t) v hs =
  let (Continuation (type e c) (cont : (a, c, e, es) continuation)) = k in
  let res : (c, e, es) res = continue cont v hs in
  (* Sound per the constraint on [Continuation.t]. *)
  (Obj.magic_at_unique res : b)
;;

let discontinue (type a b es) (k : (a, b, es) Continuation.t) e hs =
  let (Continuation (type e c) (cont : (a, c, e, es) continuation)) = k in
  let res : (c, e, es) res = discontinue cont e hs in
  (* Sound per the constraint on [Continuation.t]. *)
  (Obj.magic_at_unique res : b)
;;

let discontinue_with_backtrace (type a b es) (k : (a, b, es) Continuation.t) e bt hs =
  let (Continuation (type e c) (cont : (a, c, e, es) continuation)) = k in
  let res : (c, e, es) res = discontinue_with_backtrace cont e bt hs in
  (* Sound per the constraint on [Continuation.t]. *)
  (Obj.magic_at_unique res : b)
;;

module type S = sig @@ portable
  type ('o, 'e) ops
  type t

  module Result : sig
    type eff := t

    type ('a, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'es) t
      | Operation :
          ('o, eff) ops @@ aliased global * ('o, ('a, 'es) t, 'es) Continuation.t
          -> ('a, 'es) t

    type ('a, 'es) handler =
      { handle : 'o. ('o, eff) ops -> ('o, ('a, 'es) t, 'es) Continuation.t @ unique -> 'a
      }
    [@@unboxed]

    val handle : ('a, 'es) t @ unique -> ('a, 'es) handler -> 'a
  end

  type ('a, 'es) result = ('a, 'es) Result.t =
    | Value : 'a @@ aliased global -> ('a, 'es) result
    | Exception : exn @@ aliased global -> ('a, 'es) result
    | Operation :
        ('o, t) ops @@ aliased global * ('o, ('a, 'es) result, 'es) Continuation.t
        -> ('a, 'es) result

  

val fiber :
  once_ (local_ t Handler.t -> 'a -> 'b) -> unique_
    ('a, ('b, unit) Result.t, unit) Continuation.t
val fiber_with :
  local_ 'es Handler.List.Length.t ->
    once_ (local_ (t * 'es) Handler.List.t -> 'a -> 'b) -> unique_
      ('a, ('b, 'es) Result.t, 'es) Continuation.t
val run : once_ (local_ t Handler.t -> 'a) -> unique_ ('a, unit) Result.t
val run_with :
  local_ 'es Handler.List.t ->
    once_ (local_ (t * 'es) Handler.List.t -> 'a) -> unique_
      ('a, 'es) Result.t

  val perform : t Handler.t @ local -> ('a, t) ops -> 'a @ unique

  module Contended : sig
    module Result : sig
      type eff := t

      type ('a, 'es) t =
        | Value : 'a @@ aliased global -> ('a, 'es) t
        | Exception : exn @@ aliased global -> ('a, 'es) t
        | Operation :
            ('o, eff) ops @@ aliased contended global
            * ('o Modes.Portable.t, ('a, 'es) t, 'es) Continuation.t
            -> ('a, 'es) t
    end

    

val fiber :
  ('a : value mod portable) 'b .
    once_ (local_ t Handler.t @ portable -> 'a @ contended -> 'b) -> unique_
      ('a, ('b, unit) Result.t, unit) Continuation.t
val fiber_with :
  ('a : value mod portable) 'b 'es .
    local_ 'es Handler.List.Length.t ->
      once_
        (local_ (t * 'es) Handler.List.t @ portable -> 'a @ contended -> 'b)
        -> unique_ ('a, ('b, 'es) Result.t, 'es) Continuation.t
val run :
  once_ (local_ t Handler.t @ portable -> 'a) -> unique_ ('a, unit) Result.t
val run_with :
  local_ 'es Handler.List.t @ portable ->
    once_ (local_ (t * 'es) Handler.List.t @ portable -> 'a) -> unique_
      ('a, 'es) Result.t

    val perform
      :  t Handler.t @ contended local
      -> ('a, t) ops @ portable
      -> 'a @ contended unique
  end

  module Handler : sig
    type nonrec t = t Handler.t
  end

  module Continuation : sig
    type ('a, 'b, 'es) t = ('a, ('b, 'es) Result.t, 'es) Continuation.t
  end
end

module type S1 = sig @@ portable
  type ('o, 'p, 'e) ops
  type 'p t

  module Result : sig
    type 'p eff := 'p t

    type ('a, 'p, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'p, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'p, 'es) t
      | Operation :
          ('o, 'p, 'p eff) ops @@ aliased global
          * ('o, ('a, 'p, 'es) t, 'es) Continuation.t
          -> ('a, 'p, 'es) t

    type ('a, 'p, 'es) handler =
      { handle :
          'o.
          ('o, 'p, 'p eff) ops -> ('o, ('a, 'p, 'es) t, 'es) Continuation.t @ unique -> 'a
      }
    [@@unboxed]

    val handle : ('a, 'p, 'es) t @ unique -> ('a, 'p, 'es) handler -> 'a
  end

  type ('a, 'p, 'es) result = ('a, 'p, 'es) Result.t =
    | Value : 'a @@ aliased global -> ('a, 'p, 'es) result
    | Exception : exn @@ aliased global -> ('a, 'p, 'es) result
    | Operation :
        ('o, 'p, 'p t) ops @@ aliased global
        * ('o, ('a, 'p, 'es) result, 'es) Continuation.t
        -> ('a, 'p, 'es) result

  

val fiber :
  once_ (local_ 'p t Handler.t -> 'a -> 'b) -> unique_
    ('a, ('b, 'p, unit) Result.t, unit) Continuation.t
val fiber_with :
  local_ 'es Handler.List.Length.t ->
    once_ (local_ ('p t * 'es) Handler.List.t -> 'a -> 'b) -> unique_
      ('a, ('b, 'p, 'es) Result.t, 'es) Continuation.t
val run :
  once_ (local_ 'p t Handler.t -> 'a) -> unique_ ('a, 'p, unit) Result.t
val run_with :
  local_ 'es Handler.List.t ->
    once_ (local_ ('p t * 'es) Handler.List.t -> 'a) -> unique_
      ('a, 'p, 'es) Result.t

  val perform : 'p t Handler.t @ local -> ('a, 'p, 'p t) ops -> 'a @ unique

  module Contended : sig
    module Result : sig
      type 'p eff := 'p t

      type ('a, 'p, 'es) t =
        | Value : 'a @@ aliased global -> ('a, 'p, 'es) t
        | Exception : exn @@ aliased global -> ('a, 'p, 'es) t
        | Operation :
            ('o, 'p, 'p eff) ops @@ aliased contended global
            * ('o Modes.Portable.t, ('a, 'p, 'es) t, 'es) Continuation.t
            -> ('a, 'p, 'es) t
    end

    

val fiber :
  ('a : value mod portable) 'b 'p .
    once_ (local_ 'p t Handler.t @ portable -> 'a @ contended -> 'b) ->
      unique_ ('a, ('b, 'p, unit) Result.t, unit) Continuation.t
val fiber_with :
  ('a : value mod portable) 'b 'p 'es .
    local_ 'es Handler.List.Length.t ->
      once_
        (local_ ('p t * 'es) Handler.List.t @ portable ->
           'a @ contended -> 'b)
        -> unique_ ('a, ('b, 'p, 'es) Result.t, 'es) Continuation.t
val run :
  once_ (local_ 'p t Handler.t @ portable -> 'a) -> unique_
    ('a, 'p, unit) Result.t
val run_with :
  local_ 'es Handler.List.t @ portable ->
    once_ (local_ ('p t * 'es) Handler.List.t @ portable -> 'a) -> unique_
      ('a, 'p, 'es) Result.t

    val perform
      :  'p t Handler.t @ contended local
      -> ('a, 'p, 'p t) ops @ portable
      -> 'a @ contended unique
  end

  module Handler : sig
    type nonrec 'p t = 'p t Handler.t
  end

  module Continuation : sig
    type ('a, 'b, 'p, 'es) t = ('a, ('b, 'p, 'es) Result.t, 'es) Continuation.t
  end
end

module type S2 = sig @@ portable
  type ('o, 'p, 'q, 'e) ops
  type ('p, 'q) t

  module Result : sig
    type ('p, 'q) eff := ('p, 'q) t

    type ('a, 'p, 'q, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'p, 'q, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'p, 'q, 'es) t
      | Operation :
          ('o, 'p, 'q, ('p, 'q) eff) ops @@ aliased global
          * ('o, ('a, 'p, 'q, 'es) t, 'es) Continuation.t
          -> ('a, 'p, 'q, 'es) t

    type ('a, 'p, 'q, 'es) handler =
      { handle :
          'o.
          ('o, 'p, 'q, ('p, 'q) eff) ops
          -> ('o, ('a, 'p, 'q, 'es) t, 'es) Continuation.t @ unique
          -> 'a
      }
    [@@unboxed]

    val handle : ('a, 'p, 'q, 'es) t @ unique -> ('a, 'p, 'q, 'es) handler -> 'a
  end

  type ('a, 'p, 'q, 'es) result = ('a, 'p, 'q, 'es) Result.t =
    | Value : 'a @@ aliased global -> ('a, 'p, 'q, 'es) result
    | Exception : exn @@ aliased global -> ('a, 'p, 'q, 'es) result
    | Operation :
        ('o, 'p, 'q, ('p, 'q) t) ops @@ aliased global
        * ('o, ('a, 'p, 'q, 'es) result, 'es) Continuation.t
        -> ('a, 'p, 'q, 'es) result

  

val fiber :
  once_ (local_ ('p, 'q) t Handler.t -> 'a -> 'b) -> unique_
    ('a, ('b, 'p, 'q, unit) result, unit) Continuation.t
val fiber_with :
  local_ 'es Handler.List.Length.t ->
    once_ (local_ (('p, 'q) t * 'es) Handler.List.t -> 'a -> 'b) -> unique_
      ('a, ('b, 'p, 'q, 'es) result, 'es) Continuation.t
val run :
  once_ (local_ ('p, 'q) t Handler.t -> 'a) -> unique_
    ('a, 'p, 'q, unit) result
val run_with :
  local_ 'es Handler.List.t ->
    once_ (local_ (('p, 'q) t * 'es) Handler.List.t -> 'a) -> unique_
      ('a, 'p, 'q, 'es) result

  val perform
    :  ('p, 'q) t Handler.t @ local
    -> ('a, 'p, 'q, ('p, 'q) t) ops
    -> 'a @ unique

  module Contended : sig
    module Result : sig
      type ('p, 'q) eff := ('p, 'q) t

      type ('a, 'p, 'q, 'es) t =
        | Value : 'a @@ aliased global -> ('a, 'p, 'q, 'es) t
        | Exception : exn @@ aliased global -> ('a, 'p, 'q, 'es) t
        | Operation :
            ('o, 'p, 'q, ('p, 'q) eff) ops @@ aliased contended global
            * ('o Modes.Portable.t, ('a, 'p, 'q, 'es) t, 'es) Continuation.t
            -> ('a, 'p, 'q, 'es) t
    end

    

val fiber :
  ('a : value mod portable) 'b 'p 'q .
    once_ (local_ ('p, 'q) t Handler.t @ portable -> 'a @ contended -> 'b) ->
      unique_ ('a, ('b, 'p, 'q, unit) Result.t, unit) Continuation.t
val fiber_with :
  ('a : value mod portable) 'b 'p 'q 'es .
    local_ 'es Handler.List.Length.t ->
      once_
        (local_ (('p, 'q) t * 'es) Handler.List.t @ portable ->
           'a @ contended -> 'b)
        -> unique_ ('a, ('b, 'p, 'q, 'es) Result.t, 'es) Continuation.t
val run :
  once_ (local_ ('p, 'q) t Handler.t @ portable -> 'a) -> unique_
    ('a, 'p, 'q, unit) Result.t
val run_with :
  local_ 'es Handler.List.t @ portable ->
    once_ (local_ (('p, 'q) t * 'es) Handler.List.t @ portable -> 'a) ->
      unique_ ('a, 'p, 'q, 'es) Result.t


    val perform
      :  ('p, 'q) t Handler.t @ contended local
      -> ('a, 'p, 'q, ('p, 'q) t) ops @ portable
      -> 'a @ contended unique
  end

  module Handler : sig
    type nonrec ('p, 'q) t = ('p, 'q) t Handler.t
  end

  module Continuation : sig
    type ('a, 'b, 'p, 'q, 'es) t = ('a, ('b, 'p, 'q, 'es) result, 'es) Continuation.t
  end
end

module type Operations = sig
  type 'a t
end

module type Operations_rec = sig
  type ('a, 'e) t
end

module type Operations1 = sig
  type ('a, 'p) t
end

module type Operations1_rec = sig
  type ('a, 'p, 'e) t
end

module type Operations2 = sig
  type ('a, 'p, 'q) t
end

module type Operations2_rec = sig
  type ('a, 'p, 'q, 'e) t
end

module Make_rec (Ops : Operations_rec) : S with type ('a, 'e) ops := ('a, 'e) Ops.t =
struct
  type t

  module Result = struct
    type eff = t

    type ('e, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'es) t
      | Operation :
          ('o, eff) Ops.t @@ aliased global * ('o, ('a, 'es) t, 'es) Continuation.t
          -> ('a, 'es) t

    type ('a, 'es) handler =
      { handle :
          'o. ('o, eff) Ops.t -> ('o, ('a, 'es) t, 'es) Continuation.t @ unique -> 'a
      }
    [@@unboxed]

    let handle r { handle } =
      match r with
      | Value x -> x
      | Exception e -> raise e
      | Operation (op, k) -> handle op k
    ;;
  end

  type ('a, 'es) result = ('a, 'es) Result.t =
    | Value : 'a @@ aliased global -> ('a, 'es) result
    | Exception : exn @@ aliased global -> ('a, 'es) result
    | Operation :
        ('o, t) Ops.t @@ aliased global * ('o, ('a, 'es) result, 'es) Continuation.t
        -> ('a, 'es) result

  let fiber f = Continuation.Continuation (fiber f)
  let fiber_with hs f = Continuation.Continuation (fiber_with hs f)

  let run (type a) f =
    let res : (a, t, unit) res = run f in
    (Obj.magic_at_unique res : (a, unit) Result.t)
  ;;

  let run_with (type a es) hs f =
    let res : (a, t, es) res = run_with hs f in
    (Obj.magic_at_unique res : (a, es) Result.t)
  ;;

  let perform (type a) (h : _ Handler.t @@ local) (op : (a, t) Ops.t) =
    let op : (a, t) op = Obj.magic op in
    perform_ (op, h.h)
  ;;

  module Contended = struct
    module Result = struct
      type eff = t

      type ('a, 'es) t =
        | Value : 'a @@ aliased global -> ('a, 'es) t
        | Exception : exn @@ aliased global -> ('a, 'es) t
        | Operation :
            ('o, eff) Ops.t @@ aliased contended global
            * ('o Modes.Portable.t, ('a, 'es) t, 'es) Continuation.t
            -> ('a, 'es) t
    end

    let fiber f = Continuation.Continuation (DRF.fiber f)
    let fiber_with l f = Continuation.Continuation (DRF.fiber_with l f)

    let run (type a) f =
      let res : (a, t, unit) res = DRF.run f in
      (Obj.magic_at_unique res : (a, unit) Result.t)
    ;;

    let run_with (type a es) hs f =
      let res : (a, t, es) res = DRF.run_with hs f in
      (Obj.magic_at_unique res : (a, es) Result.t)
    ;;

    let perform (type a) (h : t Handler.t) op : a =
      let op : (a, t) op = Obj.magic op in
      (* Here and below, [magic_uncontended] is safe since the handler
         is either portable or is executed in its original capsule. *)
      perform_ (op, Obj.magic_uncontended h.h)
    ;;
  end

  module Handler = struct
    type nonrec t = t Handler.t
  end

  module Continuation = struct
    type ('a, 'b, 'es) t = ('a, ('b, 'es) Result.t, 'es) Continuation.t
  end
end

module Make (Ops : Operations) : S with type ('a, 'e) ops := 'a Ops.t = Make_rec (struct
    type ('a, 'e) t = 'a Ops.t
  end)

module Make1_rec (Ops : Operations1_rec) :
  S1 with type ('a, 'p, 'e) ops := ('a, 'p, 'e) Ops.t = struct
  type 'p t

  module Result = struct
    type 'p eff = 'p t

    type ('a, 'p, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'p, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'p, 'es) t
      | Operation :
          ('o, 'p, 'p eff) Ops.t @@ aliased global
          * ('o, ('a, 'p, 'es) t, 'es) Continuation.t
          -> ('a, 'p, 'es) t

    type ('a, 'p, 'es) handler =
      { handle :
          'o.
          ('o, 'p, 'p eff) Ops.t
          -> ('o, ('a, 'p, 'es) t, 'es) Continuation.t @ unique
          -> 'a
      }
    [@@unboxed]

    let handle r { handle } =
      match r with
      | Value x -> x
      | Exception e -> raise e
      | Operation (op, k) -> handle op k
    ;;
  end

  type ('a, 'p, 'es) result = ('a, 'p, 'es) Result.t =
    | Value : 'a @@ aliased global -> ('a, 'p, 'es) result
    | Exception : exn @@ aliased global -> ('a, 'p, 'es) result
    | Operation :
        ('o, 'p, 'p t) Ops.t @@ aliased global
        * ('o, ('a, 'p, 'es) result, 'es) Continuation.t
        -> ('a, 'p, 'es) result

  let fiber f = Continuation.Continuation (fiber f)
  let fiber_with hs f = Continuation.Continuation (fiber_with hs f)

  let run (type a p) f =
    let res : (a, p t, unit) res = run f in
    (Obj.magic_at_unique res : (a, p, unit) Result.t)
  ;;

  let run_with (type a p es) hs f =
    let res : (a, p t, es) res = run_with hs f in
    (Obj.magic_at_unique res : (a, p, es) Result.t)
  ;;

  let perform (type a p) (h : _ Handler.t @@ local) (op : (a, p, p t) Ops.t) =
    let op : (a, p t) op = Obj.magic op in
    perform_ (op, h.h)
  ;;

  module Contended = struct
    module Result = struct
      type 'p eff = 'p t

      type ('a, 'p, 'es) t =
        | Value : 'a @@ aliased global -> ('a, 'p, 'es) t
        | Exception : exn @@ aliased global -> ('a, 'p, 'es) t
        | Operation :
            ('o, 'p, 'p eff) Ops.t @@ aliased contended global
            * ('o Modes.Portable.t, ('a, 'p, 'es) t, 'es) Continuation.t
            -> ('a, 'p, 'es) t
    end

    let fiber f = Continuation.Continuation (DRF.fiber f)
    let fiber_with l f = Continuation.Continuation (DRF.fiber_with l f)

    let run (type a p) f =
      let res : (a, p t, unit) res = DRF.run f in
      (Obj.magic_at_unique res : (a, p, unit) Result.t)
    ;;

    let run_with (type a p es) hs f =
      let res : (a, p t, es) res = DRF.run_with hs f in
      (Obj.magic_at_unique res : (a, p, es) Result.t)
    ;;

    let perform (type a p) (h : p t Handler.t) op : a =
      let op : (a, p t) op = Obj.magic op in
      perform_ (op, Obj.magic_uncontended h.h)
    ;;
  end

  module Handler = struct
    type nonrec 'p t = 'p t Handler.t
  end

  module Continuation = struct
    type ('a, 'b, 'p, 'es) t = ('a, ('b, 'p, 'es) Result.t, 'es) Continuation.t
  end
end

module Make1 (Ops : Operations1) : S1 with type ('a, 'p, 'e) ops := ('a, 'p) Ops.t =
Make1_rec (struct
    type ('a, 'p, 'e) t = ('a, 'p) Ops.t
  end)

module Make2_rec (Ops : Operations2_rec) :
  S2 with type ('a, 'p, 'q, 'e) ops := ('a, 'p, 'q, 'e) Ops.t = struct
  type ('p, 'q) t

  module Result = struct
    type ('p, 'q) eff = ('p, 'q) t

    type ('a, 'p, 'q, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'p, 'q, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'p, 'q, 'es) t
      | Operation :
          ('o, 'p, 'q, ('p, 'q) eff) Ops.t @@ aliased global
          * ('o, ('a, 'p, 'q, 'es) t, 'es) Continuation.t
          -> ('a, 'p, 'q, 'es) t

    type ('a, 'p, 'q, 'es) handler =
      { handle :
          'o.
          ('o, 'p, 'q, ('p, 'q) eff) Ops.t
          -> ('o, ('a, 'p, 'q, 'es) t, 'es) Continuation.t @ unique
          -> 'a
      }
    [@@unboxed]

    let handle r { handle } =
      match r with
      | Value x -> x
      | Exception e -> raise e
      | Operation (op, k) -> handle op k
    ;;
  end

  type ('a, 'p, 'q, 'es) result = ('a, 'p, 'q, 'es) Result.t =
    | Value : 'a @@ aliased global -> ('a, 'p, 'q, 'es) result
    | Exception : exn @@ aliased global -> ('a, 'p, 'q, 'es) result
    | Operation :
        ('o, 'p, 'q, ('p, 'q) t) Ops.t @@ aliased global
        * ('o, ('a, 'p, 'q, 'es) result, 'es) Continuation.t
        -> ('a, 'p, 'q, 'es) result

  let fiber f = Continuation.Continuation (fiber f)
  let fiber_with hs f = Continuation.Continuation (fiber_with hs f)

  let run (type a p q) f =
    let res : (a, (p, q) t, unit) res = run f in
    (Obj.magic_at_unique res : (a, p, q, unit) result)
  ;;

  let run_with (type a p q es) hs f =
    let res : (a, (p, q) t, es) res = run_with hs f in
    (Obj.magic_at_unique res : (a, p, q, es) result)
  ;;

  let perform (type a p q) (h : _ Handler.t @@ local) (op : (a, p, q, (p, q) t) Ops.t) =
    let op : (a, (p, q) t) op = Obj.magic op in
    perform_ (op, h.h)
  ;;

  module Contended = struct
    module Result = struct
      type ('p, 'q) eff = ('p, 'q) t

      type ('a, 'p, 'q, 'es) t =
        | Value : 'a @@ aliased global -> ('a, 'p, 'q, 'es) t
        | Exception : exn @@ aliased global -> ('a, 'p, 'q, 'es) t
        | Operation :
            ('o, 'p, 'q, ('p, 'q) eff) Ops.t @@ aliased contended global
            * ('o Modes.Portable.t, ('a, 'p, 'q, 'es) t, 'es) Continuation.t
            -> ('a, 'p, 'q, 'es) t
    end

    let fiber f = Continuation.Continuation (DRF.fiber f)
    let fiber_with l f = Continuation.Continuation (DRF.fiber_with l f)

    let run (type a p q) f =
      let res : (a, (p, q) t, unit) res = DRF.run f in
      (Obj.magic_at_unique res : (a, p, q, unit) Result.t)
    ;;

    let run_with (type a p q es) hs f =
      let res : (a, (p, q) t, es) res = DRF.run_with hs f in
      (Obj.magic_at_unique res : (a, p, q, es) Result.t)
    ;;

    let perform (type a p q) (h : (p, q) t Handler.t) op : a =
      let op : (a, (p, q) t) op = Obj.magic op in
      perform_ (op, Obj.magic_uncontended h.h)
    ;;
  end

  module Handler = struct
    type nonrec ('p, 'q) t = ('p, 'q) t Handler.t
  end

  module Continuation = struct
    type ('a, 'b, 'p, 'q, 'es) t = ('a, ('b, 'p, 'q, 'es) result, 'es) Continuation.t
  end
end

module Make2 (Ops : Operations2) :
  S2 with type ('a, 'p, 'q, 'e) ops := ('a, 'p, 'q) Ops.t = Make2_rec (struct
    type ('a, 'p, 'q, 'e) t = ('a, 'p, 'q) Ops.t
  end)

exception Continuation_already_resumed

type exn += Unhandled : 'e Handler.t -> exn

(* Register the exceptions so that the runtime can access it *)
let _ =
  Callback.Safe.register_exception "Effect.Unhandled" (Unhandled { h = Handler.Dummy })
;;

let _ =
  Callback.Safe.register_exception
    "Effect.Continuation_already_resumed"
    Continuation_already_resumed
;;
