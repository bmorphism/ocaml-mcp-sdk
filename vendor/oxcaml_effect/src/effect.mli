@@ portable

open! Base

module Handler : sig
  (** ['e t] is an effect handler for the effect ['e] on the current stack. *)
  type 'e t

  module List : sig
    type 'e handler := 'e t

    type 'es t =
      | [] : unit t
      | ( :: ) : 'e handler * 'es t -> ('e * 'es) t
      (** ['es t] is a typed list of [Handler.t]s *)

    module Length : sig
      type x = X

      type 'es t =
        | [] : unit t
        | ( :: ) : x * 'es t -> ('e * 'es) t
        (** ['es t] represents the length of a typed list of [Handler.t]s. It has slightly
            unusual constructors so that lengths can be written as [[X; X; X]] rather than
            e.g. [(S (S (S Z)))]. *)
    end

    (** [length hs] is the length of [hs] *)
    val length : 'es t @ local -> 'es Length.t
  end
end

module Continuation : sig
  (** [('a, 'b, 'es) continuation] is a delimited continuation that expects an ['a] value
      and returns a ['b] value. It requires handlers for the effects ['es]. *)
  type (-'a, +'b, 'es) t : value mod contended many

  (** [get_callstack c n] returns a description of the top of the call stack on the
      continuation [c], with at most [n] entries. *)
  val get_callstack
    :  ('a, 'b, 'es) t @ unique
    -> int
    -> Backtrace.t Modes.Aliased.t * ('a, 'b, 'es) t @ unique
    @@ portable
end

(** [continue k v hs] resumes the continuation [k] with value [v]. [hs] are used to handle
    [k]'s additional effects. *)
val continue
  :  ('a, 'b, 'es) Continuation.t @ unique
  -> 'a @ unique
  -> 'es Handler.List.t @ local
  -> 'b @ unique

(** [discontinue k e hs] resumes the continuation [k] by raising the exception [e]. [hs]
    are used to handle [k]'s additional effects. *)
val discontinue
  :  ('a, 'b, 'es) Continuation.t @ unique
  -> exn
  -> 'es Handler.List.t @ local
  -> 'b @ unique

(** [discontinue_with_backtrace k e bt hs] resumes the continuation [k] by raising the
    exception [e] using the raw backtrace [bt] as the origin of the exception. [hs] are
    used to handle [k]'s additional effects. *)
val discontinue_with_backtrace
  :  ('a, 'b, 'es) Continuation.t @ unique
  -> exn
  -> Backtrace.t
  -> 'es Handler.List.t @ local
  -> 'b @ unique

(** The signature for effects with no type parameters *)
module type S = sig @@ portable
  (** [t] represents the effect. It only appears as the argument to [Handler.t]. *)
  type t

  (** [('a, 'e) ops] is the type of operations of the effect [t]. ['a] is the return type
      of the given operation. ['e] will be filled in with [t] to tie the knot on recursive
      operations. *)
  type ('a, 'e) ops

  module Result : sig @@ portable
    type eff := t

    type ('a, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'es) t
      | Operation :
          ('o, eff) ops @@ aliased global * ('o, ('a, 'es) t, 'es) Continuation.t
          -> ('a, 'es) t
      (** [('a, 'es) t] is the result of running a continuation until it either finishes
          and returns an ['a] value, raises an exception, or performs an operation. *)

    type ('a, 'es) handler =
      { handle : 'o. ('o, eff) ops -> ('o, ('a, 'es) t, 'es) Continuation.t @ unique -> 'a
      }
    [@@unboxed]

    (** [handle r f] uses [f] to handle the [Operation] case of [r]. The [Value] and
        [Exception] cases are handled by returning and raising respectively. *)
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
    ('a, ('b, unit) Result.t, unit) Continuation.t[@@ocaml.doc
                                                    " [fiber f] constructs a continuation that runs the computation [f]. [f] is passed a\n        [t Handler.t] so that it can perform operations from the effect [t]. "]
val fiber_with :
  local_ 'es Handler.List.Length.t ->
    once_ (local_ (t * 'es) Handler.List.t -> 'a -> 'b) -> unique_
      ('a, ('b, 'es) Result.t, 'es) Continuation.t[@@ocaml.doc
                                                    " [fiber_with l f] constructs a continuation that runs the computation [f] and\n        requires handlers for [l] additional effects. [f] is passed a typed list of\n        handlers so that it can perform operations from the effect [t] and the effects\n        ['es]. "]
val run : once_ (local_ t Handler.t -> 'a) -> unique_ ('a, unit) Result.t
[@@ocaml.doc
  " [run f] constructs a continuation that runs the computation [f] and immediately\n        resumes it. [f] is passed a [t Handler.t] so that it can perform operations from\n        the effect [t]. "]
val run_with :
  local_ 'es Handler.List.t ->
    once_ (local_ (t * 'es) Handler.List.t -> 'a) -> unique_
      ('a, 'es) Result.t[@@ocaml.doc
                          " [run_with hs f] constructs a continuation that runs the computation [f] and\n        immediately resumes it under the handlers [hs]. [f] is passed a typed list of\n        handlers so that it can perform operations from the effect [t] and the effects\n        ['es]. "]

  (** [perform h e] performs an effect [e] that will be handled by [h] *)
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
      ('a, ('b, unit) Result.t, unit) Continuation.t[@@ocaml.doc
                                                      " [fiber f] works as the non-contended version, but provides a [portable] handler\n          at the cost of requiring a [value mod portable] argument and returning a\n          [Contended.Result.t]. "]
val fiber_with :
  ('a : value mod portable) 'b 'es .
    local_ 'es Handler.List.Length.t ->
      once_
        (local_ (t * 'es) Handler.List.t @ portable -> 'a @ contended -> 'b)
        -> unique_ ('a, ('b, 'es) Result.t, 'es) Continuation.t[@@ocaml.doc
                                                                 " [fiber_with l f] works as the non-contended version, but provides [portable]\n          handlers at the cost of requiring a [value mod portable] argument and returning\n          a [Contended.Result.t]. "]
val run :
  once_ (local_ t Handler.t @ portable -> 'a) -> unique_ ('a, unit) Result.t
[@@ocaml.doc
  " [run f] works as the non-contended version, but provides a [portable] handler at\n          the cost of returning a [Contended.Result.t]. "]
val run_with :
  local_ 'es Handler.List.t @ portable ->
    once_ (local_ (t * 'es) Handler.List.t @ portable -> 'a) -> unique_
      ('a, 'es) Result.t[@@ocaml.doc
                          " [run_with hs f] works as the non-contended version, but provides [portable]\n          handlers at the cost of returning a [Contended.Result.t]. "]

    (** [perform h e] performs an effect [e] that will be handled by the contended [h] *)
    val perform
      :  t Handler.t @ contended local
      -> ('a, t) ops @ portable
      -> 'a @ contended unique
  end

  module Handler : sig
    type nonrec t = t Handler.t
  end

  module Continuation : sig
    (** [('a, 'b, 'es) t] is the type of continuations for [t] handlers that expect an
        ['a] and return a ['b]. It requires additional handlers for the effects ['es].

        This is not to be confused with the other [Continuation.t] type available in this
        file; external uses will be of the form [This_effect.Continuation.t] and
        [That_effect.Continuation.t], and thus more visually distinct. *)
    type ('a, 'b, 'es) t = ('a, ('b, 'es) Result.t, 'es) Continuation.t
  end
end

(** The signature for effects with one type parameter *)
module type S1 = sig @@ portable
  (** ['p t] represents the effect. It only appears as the argument to [Handler.t]. *)
  type 'p t

  (** [('a, 'p, 'e) ops] is the type of operations of effect ['p t]. ['a] is the return
      type of the given operation. ['e] will be filled in with ['p t] to tie the knot on
      recursive operations. *)
  type ('a, 'p, 'e) ops

  module Result : sig @@ portable
    type 'p eff := 'p t

    type ('a, 'p, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'p, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'p, 'es) t
      | Operation :
          ('o, 'p, 'p eff) ops @@ aliased global
          * ('o, ('a, 'p, 'es) t, 'es) Continuation.t
          -> ('a, 'p, 'es) t
      (** [('a, 'p, 'es) t] is the result of running a continuation until it either
          finishes and returns an ['a] value, raises an exception, or performs an
          operation. *)

    type ('a, 'p, 'es) handler =
      { handle :
          'o.
          ('o, 'p, 'p eff) ops -> ('o, ('a, 'p, 'es) t, 'es) Continuation.t @ unique -> 'a
      }
    [@@unboxed]

    (** [handle r f] uses [f] to handle the [Operation] case of [r]. The [Value] and
        [Exception] cases are handled by returning and raising respectively. *)
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
    ('a, ('b, 'p, unit) Result.t, unit) Continuation.t[@@ocaml.doc
                                                        " [fiber f] constructs a continuation that runs the computation [f]. [f] is passed a\n        [t Handler.t] so that it can perform operations from the effect [t]. "]
val fiber_with :
  local_ 'es Handler.List.Length.t ->
    once_ (local_ ('p t * 'es) Handler.List.t -> 'a -> 'b) -> unique_
      ('a, ('b, 'p, 'es) Result.t, 'es) Continuation.t[@@ocaml.doc
                                                        " [fiber_with l f] constructs a continuation that runs the computation [f] and\n        requires handlers for [l] additional effects. [f] is passed a typed list of\n        handlers so that it can perform operations from the effect [t] and the effects\n        ['es]. "]
val run :
  once_ (local_ 'p t Handler.t -> 'a) -> unique_ ('a, 'p, unit) Result.t
[@@ocaml.doc
  " [run f] constructs a continuation that runs the computation [f] and immediately\n        resumes it. "]
val run_with :
  local_ 'es Handler.List.t ->
    once_ (local_ ('p t * 'es) Handler.List.t -> 'a) -> unique_
      ('a, 'p, 'es) Result.t[@@ocaml.doc
                              " [run_with hs f] constructs a continuation that runs the computation [f] and\n        immediately resumes it under the handlers [hs]. [f] is passed a typed list of\n        handlers so that it can perform operations from the effect [t] and the effects\n        ['es]. "]

  (** [perform h e] performs an effect [e] that will be handled by [h] *)
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
      unique_ ('a, ('b, 'p, unit) Result.t, unit) Continuation.t[@@ocaml.doc
                                                                  " [fiber f] works as the non-contended version, but provides a [portable] handler\n          at the cost of requiring a [value mod portable] argument and returning a\n          [Contended.Result.t]. "]
val fiber_with :
  ('a : value mod portable) 'b 'p 'es .
    local_ 'es Handler.List.Length.t ->
      once_
        (local_ ('p t * 'es) Handler.List.t @ portable ->
           'a @ contended -> 'b)
        -> unique_ ('a, ('b, 'p, 'es) Result.t, 'es) Continuation.t[@@ocaml.doc
                                                                    " [fiber_with l f] works as the non-contended version, but provides [portable]\n          handlers at the cost of requiring a [value mod portable] argument and returning\n          a [Contended.Result.t]. "]
val run :
  once_ (local_ 'p t Handler.t @ portable -> 'a) -> unique_
    ('a, 'p, unit) Result.t[@@ocaml.doc
                             " [run f] works as the non-contended version, but provides a [portable] handler at\n          the cost of returning a [Contended.Result.t]. "]
val run_with :
  local_ 'es Handler.List.t @ portable ->
    once_ (local_ ('p t * 'es) Handler.List.t @ portable -> 'a) -> unique_
      ('a, 'p, 'es) Result.t[@@ocaml.doc
                              " [run_with hs f] works as the non-contended version, but provides [portable]\n          handlers at the cost of returning a [Contended.Result.t]. "]

    (** [perform h e] performs an effect [e] that will be handled by the contended [h] *)
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

(** The signature for effects with two type parameters *)
module type S2 = sig @@ portable
  (** [('p, 'q) t] represents the effect. It only appears as the argument to [Handler.t]. *)
  type ('p, 'q) t

  (** [('a, 'p, 'q, 'e) ops] is the type of operations of the effect [('p, 'q) t]. ['a] is
      the return type of the given operation. ['e] will be filled in with [('p, 'q) t] to
      tie the knot on recursive operations. *)
  type ('a, 'p, 'q, 'e) ops

  module Result : sig @@ portable
    type ('p, 'q) eff := ('p, 'q) t

    type ('a, 'p, 'q, 'es) t =
      | Value : 'a @@ aliased global -> ('a, 'p, 'q, 'es) t
      | Exception : exn @@ aliased global -> ('a, 'p, 'q, 'es) t
      | Operation :
          ('o, 'p, 'q, ('p, 'q) eff) ops @@ aliased global
          * ('o, ('a, 'p, 'q, 'es) t, 'es) Continuation.t
          -> ('a, 'p, 'q, 'es) t
      (** [('a, 'p, 'q, 'es) t] is the result of running a continuation until it either
          finishes and returns an ['a] value, raises an exception, or performs an
          operation. *)

    type ('a, 'p, 'q, 'es) handler =
      { handle :
          'o.
          ('o, 'p, 'q, ('p, 'q) eff) ops
          -> ('o, ('a, 'p, 'q, 'es) t, 'es) Continuation.t @ unique
          -> 'a
      }
    [@@unboxed]

    (** [handle r f] uses [f] to handle the [Operation] case of [r]. The [Value] and
        [Exception] cases are handled by returning and raising respectively. *)
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
    ('a, ('b, 'p, 'q, unit) Result.t, unit) Continuation.t[@@ocaml.doc
                                                            " [fiber f] constructs a continuation that runs the computation [f]. [f] is passed a\n        [t Handler.t] so that it can perform operations from the effect [t]. "]
val fiber_with :
  local_ 'es Handler.List.Length.t ->
    once_ (local_ (('p, 'q) t * 'es) Handler.List.t -> 'a -> 'b) -> unique_
      ('a, ('b, 'p, 'q, 'es) Result.t, 'es) Continuation.t[@@ocaml.doc
                                                            " [fiber_with l f] constructs a continuation that runs the computation [f] and\n        requires handlers for [l] additional effects. [f] is passed a typed list of\n        handlers so that it can perform operations from the effect [t] and the effects\n        ['es]. "]
val run :
  once_ (local_ ('p, 'q) t Handler.t -> 'a) -> unique_
    ('a, 'p, 'q, unit) Result.t[@@ocaml.doc
                                 " [run f] constructs a continuation that runs the computation [f] and immediately\n        resumes it. "]
val run_with :
  local_ 'es Handler.List.t ->
    once_ (local_ (('p, 'q) t * 'es) Handler.List.t -> 'a) -> unique_
      ('a, 'p, 'q, 'es) Result.t[@@ocaml.doc
                                  " [run_with hs f] constructs a continuation that runs the computation [f] and\n        immediately resumes it under the handlers [hs]. [f] is passed a typed list of\n        handlers so that it can perform operations from the effect [t] and the effects\n        ['es]. "]

  (** [perform h e] performs an effect [e] that will be handled by [h] *)
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
      unique_ ('a, ('b, 'p, 'q, unit) Result.t, unit) Continuation.t[@@ocaml.doc
                                                                    " [fiber f] works as the non-contended version, but provides a [portable] handler\n          at the cost of requiring a [value mod portable] argument and returning a\n          [Contended.Result.t]. "]
val fiber_with :
  ('a : value mod portable) 'b 'p 'q 'es .
    local_ 'es Handler.List.Length.t ->
      once_
        (local_ (('p, 'q) t * 'es) Handler.List.t @ portable ->
           'a @ contended -> 'b)
        -> unique_ ('a, ('b, 'p, 'q, 'es) Result.t, 'es) Continuation.t
[@@ocaml.doc
  " [fiber_with l f] works as the non-contended version, but provides [portable]\n          handlers at the cost of requiring a [value mod portable] argument and returning\n          a [Contended.Result.t]. "]
val run :
  once_ (local_ ('p, 'q) t Handler.t @ portable -> 'a) -> unique_
    ('a, 'p, 'q, unit) Result.t[@@ocaml.doc
                                 " [run f] works as the non-contended version, but provides a [portable] handler at\n          the cost of returning a [Contended.Result.t]. "]
val run_with :
  local_ 'es Handler.List.t @ portable ->
    once_ (local_ (('p, 'q) t * 'es) Handler.List.t @ portable -> 'a) ->
      unique_ ('a, 'p, 'q, 'es) Result.t[@@ocaml.doc
                                          " [run_with hs f] works as the non-contended version, but provides [portable]\n          handlers at the cost of returning a [Contended.Result.t]. "]


    (** [perform h e] performs an effect [e] that will be handled by the contended [h] *)
    val perform
      :  ('p, 'q) t Handler.t @ contended local
      -> ('a, 'p, 'q, ('p, 'q) t) ops @ portable
      -> 'a @ contended unique
  end

  module Handler : sig
    type nonrec ('p, 'q) t = ('p, 'q) t Handler.t
  end

  module Continuation : sig
    type ('a, 'b, 'p, 'q, 'es) t = ('a, ('b, 'p, 'q, 'es) Result.t, 'es) Continuation.t
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

module Make (Ops : Operations) : S with type ('a, 'e) ops := 'a Ops.t
module Make_rec (Ops : Operations_rec) : S with type ('a, 'e) ops := ('a, 'e) Ops.t
module Make1 (Ops : Operations1) : S1 with type ('a, 'p, 'e) ops := ('a, 'p) Ops.t

module Make1_rec (Ops : Operations1_rec) :
  S1 with type ('a, 'p, 'e) ops := ('a, 'p, 'e) Ops.t

module Make2 (Ops : Operations2) : S2 with type ('a, 'p, 'q, 'e) ops := ('a, 'p, 'q) Ops.t

module Make2_rec (Ops : Operations2_rec) :
  S2 with type ('a, 'p, 'q, 'e) ops := ('a, 'p, 'q, 'e) Ops.t

(** Exception raised when a continuation is continued or discontinued more than once.

    Only achievable with [Obj.magic_unique] or similar escape hatches. *)
exception Continuation_already_resumed
