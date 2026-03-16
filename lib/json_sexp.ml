open! Core

let sexp_of_yojson json = Sexp.Atom (Yojson.Safe.to_string json)
let yojson_of_sexp sexp = Yojson.Safe.from_string (Sexp.to_string sexp)

type json = Yojson.Safe.t

let sexp_of_json = sexp_of_yojson
let json_of_sexp = yojson_of_sexp
