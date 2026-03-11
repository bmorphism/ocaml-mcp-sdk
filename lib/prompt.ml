open! Core

module Argument = struct
  type t =
    { name : string
    ; description : string option
    ; required : bool
    }
  [@@deriving sexp, compare]

  let to_yojson t =
    `Assoc
      (List.filter_opt
         [ Some ("name", `String t.name)
         ; Option.map t.description ~f:(fun d -> "description", `String d)
         ; Some ("required", `Bool t.required)
         ])
  ;;
end

type t =
  { name : string
  ; description : string option
  ; arguments : Argument.t list
  }
[@@deriving sexp, compare]

let create ?description ?(arguments = []) name = { name; description; arguments }

let to_yojson t =
  `Assoc
    (List.filter_opt
       [ Some ("name", `String t.name)
       ; Option.map t.description ~f:(fun d -> "description", `String d)
       ; (match t.arguments with
          | [] -> None
          | args -> Some ("arguments", `List (List.map args ~f:Argument.to_yojson)))
       ])
;;

module Message = struct
  type t =
    { role : Role.t
    ; content : Content.t
    }
  [@@deriving sexp, compare]
end
