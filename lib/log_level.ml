open! Core

type t =
  | Emergency
  | Alert
  | Critical
  | Error
  | Warning
  | Notice
  | Info
  | Debug
[@@deriving sexp, compare, equal, enumerate]

let to_string = function
  | Emergency -> "emergency"
  | Alert -> "alert"
  | Critical -> "critical"
  | Error -> "error"
  | Warning -> "warning"
  | Notice -> "notice"
  | Info -> "info"
  | Debug -> "debug"
;;

let of_string = function
  | "emergency" -> Emergency
  | "alert" -> Alert
  | "critical" -> Critical
  | "error" -> Error
  | "warning" -> Warning
  | "notice" -> Notice
  | "info" -> Info
  | "debug" -> Debug
  | s -> raise_s [%message "Unknown logging level" (s : string)]
;;

let to_yojson t = `String (to_string t)

let of_yojson = function
  | `String s -> of_string s
  | _ -> raise_s [%message "Expected string for logging level"]
;;
