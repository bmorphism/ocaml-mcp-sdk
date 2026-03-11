open! Core

type t =
  | User
  | Assistant
[@@deriving sexp, compare, equal, enumerate]

let to_string = function
  | User -> "user"
  | Assistant -> "assistant"
;;

let of_string = function
  | "user" -> User
  | "assistant" -> Assistant
  | s -> raise_s [%message "Unknown role" (s : string)]
;;

let to_yojson t = `String (to_string t)

let of_yojson = function
  | `String s -> of_string s
  | _ -> raise_s [%message "Expected string for role"]
;;
