open! Core

module Annotations = struct
  type t =
    { audience : Role.t list option
    ; priority : float option
    }
  [@@deriving sexp, compare]

  let empty = { audience = None; priority = None }

  let to_yojson t =
    let fields =
      List.filter_opt
        [ Option.map t.audience ~f:(fun roles ->
            "audience", `List (List.map roles ~f:Role.to_yojson))
        ; Option.map t.priority ~f:(fun p -> "priority", `Float p)
        ]
    in
    `Assoc fields
  ;;
end

module Text = struct
  type t =
    { text : string
    ; annotations : Annotations.t option
    }
  [@@deriving sexp, compare]

  let create ?annotations text = { text; annotations }
end

module Image = struct
  type t =
    { data : string
    ; mime_type : string
    ; annotations : Annotations.t option
    }
  [@@deriving sexp, compare]
end

module Audio = struct
  type t =
    { data : string
    ; mime_type : string
    ; annotations : Annotations.t option
    }
  [@@deriving sexp, compare]
end

module Resource_contents = struct
  module Text = struct
    type t =
      { uri : string
      ; text : string
      ; mime_type : string option
      }
    [@@deriving sexp, compare]
  end

  module Blob = struct
    type t =
      { uri : string
      ; blob : string
      ; mime_type : string option
      }
    [@@deriving sexp, compare]
  end

  type t =
    | Text of Text.t
    | Blob of Blob.t
  [@@deriving sexp, compare]

  let to_yojson = function
    | Text { uri; text; mime_type } ->
      `Assoc
        (List.filter_opt
           [ Some ("uri", `String uri)
           ; Some ("text", `String text)
           ; Option.map mime_type ~f:(fun m -> "mimeType", `String m)
           ])
    | Blob { uri; blob; mime_type } ->
      `Assoc
        (List.filter_opt
           [ Some ("uri", `String uri)
           ; Some ("blob", `String blob)
           ; Option.map mime_type ~f:(fun m -> "mimeType", `String m)
           ])
  ;;
end

module Embedded_resource = struct
  type t =
    { resource : Resource_contents.t
    ; annotations : Annotations.t option
    }
  [@@deriving sexp, compare]
end

type t =
  | Text of Text.t
  | Image of Image.t
  | Audio of Audio.t
  | Resource of Embedded_resource.t
[@@deriving sexp, compare]

let text ?annotations s = Text (Text.create ?annotations s)

let to_yojson = function
  | Text { text; annotations } ->
    `Assoc
      (List.filter_opt
         [ Some ("type", `String "text")
         ; Some ("text", `String text)
         ; Option.map annotations ~f:(fun a -> "annotations", Annotations.to_yojson a)
         ])
  | Image { data; mime_type; annotations } ->
    `Assoc
      (List.filter_opt
         [ Some ("type", `String "image")
         ; Some ("data", `String data)
         ; Some ("mimeType", `String mime_type)
         ; Option.map annotations ~f:(fun a -> "annotations", Annotations.to_yojson a)
         ])
  | Audio { data; mime_type; annotations } ->
    `Assoc
      (List.filter_opt
         [ Some ("type", `String "audio")
         ; Some ("data", `String data)
         ; Some ("mimeType", `String mime_type)
         ; Option.map annotations ~f:(fun a -> "annotations", Annotations.to_yojson a)
         ])
  | Resource { resource; annotations } ->
    `Assoc
      (List.filter_opt
         [ Some ("type", `String "resource")
         ; Some ("resource", Resource_contents.to_yojson resource)
         ; Option.map annotations ~f:(fun a -> "annotations", Annotations.to_yojson a)
         ])
;;
