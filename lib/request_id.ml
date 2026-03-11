open! Core

type t =
  | String of string
  | Int of int
[@@deriving sexp, compare, equal]

let to_yojson = function
  | String s -> `String s
  | Int i -> `Int i
;;

let of_yojson = function
  | `String s -> String s
  | `Int i -> Int i
  | json ->
    raise_s
      [%message "Expected string or int for request_id" ~json:(Yojson.Safe.to_string json : string)]
;;

let to_string = function
  | String s -> s
  | Int i -> Int.to_string i
;;
