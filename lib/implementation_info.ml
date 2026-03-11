open! Core

type t =
  { name : string
  ; version : string
  }
[@@deriving sexp, compare]

let to_yojson t =
  `Assoc [ "name", `String t.name; "version", `String t.version ]
;;

let of_yojson json =
  let open Yojson.Safe.Util in
  { name = json |> member "name" |> to_string
  ; version = json |> member "version" |> to_string
  }
;;
