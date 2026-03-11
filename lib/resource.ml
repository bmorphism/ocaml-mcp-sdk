open! Core

type t =
  { uri : string
  ; name : string
  ; description : string option
  ; mime_type : string option
  ; size : int option
  ; annotations : Content.Annotations.t option
  }
[@@deriving sexp, compare]

let create ?description ?mime_type ?size ?annotations ~uri ~name () =
  { uri; name; description; mime_type; size; annotations }
;;

let to_yojson t =
  `Assoc
    (List.filter_opt
       [ Some ("uri", `String t.uri)
       ; Some ("name", `String t.name)
       ; Option.map t.description ~f:(fun d -> "description", `String d)
       ; Option.map t.mime_type ~f:(fun m -> "mimeType", `String m)
       ; Option.map t.size ~f:(fun s -> "size", `Int s)
       ; Option.map t.annotations ~f:(fun a -> "annotations", Content.Annotations.to_yojson a)
       ])
;;

module Template = struct
  type t =
    { uri_template : string
    ; name : string
    ; description : string option
    ; mime_type : string option
    ; annotations : Content.Annotations.t option
    }
  [@@deriving sexp, compare]

  let to_yojson t =
    `Assoc
      (List.filter_opt
         [ Some ("uriTemplate", `String t.uri_template)
         ; Some ("name", `String t.name)
         ; Option.map t.description ~f:(fun d -> "description", `String d)
         ; Option.map t.mime_type ~f:(fun m -> "mimeType", `String m)
         ; Option.map t.annotations ~f:(fun a ->
             "annotations", Content.Annotations.to_yojson a)
         ])
  ;;
end
