open! Core

module String_schema = struct
  type t =
    { title : string option
    ; description : string option
    ; min_length : int option
    ; max_length : int option
    ; format : string option
    }
  [@@deriving sexp, compare]

  let create ?title ?description ?min_length ?max_length ?format () =
    { title; description; min_length; max_length; format }
  ;;
end

module Number_schema = struct
  type t =
    { title : string option
    ; description : string option
    ; minimum : int option
    ; maximum : int option
    }
  [@@deriving sexp, compare]

  let create ?title ?description ?minimum ?maximum () =
    { title; description; minimum; maximum }
  ;;
end

module Boolean_schema = struct
  type t =
    { title : string option
    ; description : string option
    ; default : bool option
    }
  [@@deriving sexp, compare]

  let create ?title ?description ?default () = { title; description; default }
end

module Enum_schema = struct
  type t =
    { title : string option
    ; description : string option
    ; values : string list
    ; names : string list option
    }
  [@@deriving sexp, compare]
end

module Primitive = struct
  type t =
    | String of String_schema.t
    | Number of Number_schema.t
    | Boolean of Boolean_schema.t
    | Enum of Enum_schema.t
  [@@deriving sexp, compare]

  let to_yojson = function
    | String s ->
      `Assoc
        (List.filter_opt
           [ Some ("type", `String "string")
           ; Option.map s.title ~f:(fun t -> "title", `String t)
           ; Option.map s.description ~f:(fun d -> "description", `String d)
           ; Option.map s.min_length ~f:(fun n -> "minLength", `Int n)
           ; Option.map s.max_length ~f:(fun n -> "maxLength", `Int n)
           ; Option.map s.format ~f:(fun f -> "format", `String f)
           ])
    | Number n ->
      `Assoc
        (List.filter_opt
           [ Some ("type", `String "number")
           ; Option.map n.title ~f:(fun t -> "title", `String t)
           ; Option.map n.description ~f:(fun d -> "description", `String d)
           ; Option.map n.minimum ~f:(fun v -> "minimum", `Int v)
           ; Option.map n.maximum ~f:(fun v -> "maximum", `Int v)
           ])
    | Boolean b ->
      `Assoc
        (List.filter_opt
           [ Some ("type", `String "boolean")
           ; Option.map b.title ~f:(fun t -> "title", `String t)
           ; Option.map b.description ~f:(fun d -> "description", `String d)
           ; Option.map b.default ~f:(fun v -> "default", `Bool v)
           ])
    | Enum e ->
      `Assoc
        (List.filter_opt
           [ Some ("type", `String "string")
           ; Option.map e.title ~f:(fun t -> "title", `String t)
           ; Option.map e.description ~f:(fun d -> "description", `String d)
           ; Some ("enum", `List (List.map e.values ~f:(fun v -> `String v)))
           ])
  ;;
end

module Input = struct
  type t =
    { properties : (string * Primitive.t) list
    ; required : string list
    }
  [@@deriving sexp, compare]

  let to_yojson t =
    `Assoc
      [ "type", `String "object"
      ; ( "properties"
        , `Assoc (List.map t.properties ~f:(fun (k, v) -> k, Primitive.to_yojson v)) )
      ; "required", `List (List.map t.required ~f:(fun s -> `String s))
      ]
  ;;
end
