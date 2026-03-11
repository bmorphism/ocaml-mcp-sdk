open! Core

module Annotations = struct
  type t =
    { title : string option
    ; read_only_hint : bool option
    ; destructive_hint : bool option
    ; idempotent_hint : bool option
    ; open_world_hint : bool option
    }
  [@@deriving sexp, compare]

  let to_yojson t =
    `Assoc
      (List.filter_opt
         [ Option.map t.title ~f:(fun v -> "title", `String v)
         ; Option.map t.read_only_hint ~f:(fun v -> "readOnlyHint", `Bool v)
         ; Option.map t.destructive_hint ~f:(fun v -> "destructiveHint", `Bool v)
         ; Option.map t.idempotent_hint ~f:(fun v -> "idempotentHint", `Bool v)
         ; Option.map t.open_world_hint ~f:(fun v -> "openWorldHint", `Bool v)
         ])
  ;;
end

type t =
  { name : string
  ; description : string option
  ; input_schema : Schema.Input.t
  ; output_schema : Schema.Input.t option
  ; annotations : Annotations.t option
  }
[@@deriving sexp, compare]

let create ?description ?output_schema ?annotations ~name ~input_schema () =
  { name; description; input_schema; output_schema; annotations }
;;

let to_yojson t =
  `Assoc
    (List.filter_opt
       [ Some ("name", `String t.name)
       ; Option.map t.description ~f:(fun d -> "description", `String d)
       ; Some ("inputSchema", Schema.Input.to_yojson t.input_schema)
       ; Option.map t.output_schema ~f:(fun s -> "outputSchema", Schema.Input.to_yojson s)
       ; Option.map t.annotations ~f:(fun a -> "annotations", Annotations.to_yojson a)
       ])
;;
