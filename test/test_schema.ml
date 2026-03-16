open! Core
open Mcp

let%expect_test "String_schema to_yojson" =
  let schema =
    Schema.Primitive.String
      (Schema.String_schema.create
         ~title:"Name"
         ~description:"A person's name"
         ~min_length:1
         ~max_length:100
         ())
  in
  print_endline (Yojson.Safe.pretty_to_string (Schema.Primitive.to_yojson schema));
  [%expect
    {|
    {
      "type": "string",
      "title": "Name",
      "description": "A person's name",
      "minLength": 1,
      "maxLength": 100
    } |}]
;;

let%expect_test "Number_schema to_yojson" =
  let schema =
    Schema.Primitive.Number
      (Schema.Number_schema.create
         ~title:"Count"
         ~minimum:0
         ~maximum:1000
         ())
  in
  print_endline (Yojson.Safe.pretty_to_string (Schema.Primitive.to_yojson schema));
  [%expect
    {| { "type": "number", "title": "Count", "minimum": 0, "maximum": 1000 } |}]
;;

let%expect_test "Boolean_schema to_yojson" =
  let schema =
    Schema.Primitive.Boolean
      (Schema.Boolean_schema.create ~title:"Enabled" ~default:true ())
  in
  print_endline (Yojson.Safe.pretty_to_string (Schema.Primitive.to_yojson schema));
  [%expect
    {| { "type": "boolean", "title": "Enabled", "default": true } |}]
;;

let%expect_test "Enum_schema to_yojson" =
  let schema =
    Schema.Primitive.Enum
      { title = Some "Format"
      ; description = Some "Output format"
      ; values = [ "json"; "csv"; "html" ]
      ; names = None
      }
  in
  print_endline (Yojson.Safe.pretty_to_string (Schema.Primitive.to_yojson schema));
  [%expect
    {|
    {
      "type": "string",
      "title": "Format",
      "description": "Output format",
      "enum": [ "json", "csv", "html" ]
    } |}]
;;

let%expect_test "Input_schema to_yojson" =
  let schema : Schema.Input.t =
    { properties =
        [ "name", String (Schema.String_schema.create ~description:"The name" ())
        ; "count", Number (Schema.Number_schema.create ~minimum:1 ())
        ; "verbose", Boolean (Schema.Boolean_schema.create ~default:false ())
        ]
    ; required = [ "name"; "count" ]
    }
  in
  print_endline (Yojson.Safe.pretty_to_string (Schema.Input.to_yojson schema));
  [%expect
    {|
    {
      "type": "object",
      "properties": {
        "name": { "type": "string", "description": "The name" },
        "count": { "type": "number", "minimum": 1 },
        "verbose": { "type": "boolean", "default": false }
      },
      "required": [ "name", "count" ]
    } |}]
;;
