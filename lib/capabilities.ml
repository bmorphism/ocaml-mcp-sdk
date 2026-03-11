open! Core

module Client = struct
  type t =
    { roots_list_changed : bool
    ; sampling : bool
    ; elicitation : bool
    ; experimental : (string * bool) list
    }
  [@@deriving sexp, compare]

  let default =
    { roots_list_changed = false
    ; sampling = false
    ; elicitation = false
    ; experimental = []
    }
  ;;

  let to_yojson t =
    `Assoc
      (List.filter_opt
         [ (if t.roots_list_changed
            then Some ("roots", `Assoc [ "listChanged", `Bool true ])
            else None)
         ; (if t.sampling then Some ("sampling", `Assoc []) else None)
         ; (if t.elicitation then Some ("elicitation", `Assoc []) else None)
         ; (match t.experimental with
            | [] -> None
            | pairs ->
              Some
                ( "experimental"
                , `Assoc (List.map pairs ~f:(fun (k, v) -> k, `Bool v)) ))
         ])
  ;;
end

module Server = struct
  module Tools = struct
    type t = { list_changed : bool } [@@deriving sexp, compare]

    let to_yojson t =
      `Assoc [ "listChanged", `Bool t.list_changed ]
    ;;
  end

  module Resources = struct
    type t =
      { list_changed : bool
      ; subscribe : bool
      }
    [@@deriving sexp, compare]

    let to_yojson t =
      `Assoc
        [ "listChanged", `Bool t.list_changed
        ; "subscribe", `Bool t.subscribe
        ]
    ;;
  end

  module Prompts = struct
    type t = { list_changed : bool } [@@deriving sexp, compare]

    let to_yojson t =
      `Assoc [ "listChanged", `Bool t.list_changed ]
    ;;
  end

  type t =
    { tools : Tools.t option
    ; resources : Resources.t option
    ; prompts : Prompts.t option
    ; logging : bool
    ; completions : bool
    ; experimental : (string * bool) list
    }
  [@@deriving sexp, compare]

  let default =
    { tools = None
    ; resources = None
    ; prompts = None
    ; logging = false
    ; completions = false
    ; experimental = []
    }
  ;;

  let to_yojson t =
    `Assoc
      (List.filter_opt
         [ Option.map t.tools ~f:(fun v -> "tools", Tools.to_yojson v)
         ; Option.map t.resources ~f:(fun v -> "resources", Resources.to_yojson v)
         ; Option.map t.prompts ~f:(fun v -> "prompts", Prompts.to_yojson v)
         ; (if t.logging then Some ("logging", `Assoc []) else None)
         ; (if t.completions then Some ("completions", `Assoc []) else None)
         ; (match t.experimental with
            | [] -> None
            | pairs ->
              Some
                ( "experimental"
                , `Assoc (List.map pairs ~f:(fun (k, v) -> k, `Bool v)) ))
         ])
  ;;
end
