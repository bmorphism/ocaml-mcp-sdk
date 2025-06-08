(lang dune 3.16)

(name ocaml-mcp-sdk)

(generate_opam_files true)

(source
 (github barton/ocaml-mcp-sdk))

(authors "Barton")

(maintainers "Barton")

(license MIT)

(package
 (name ocaml-mcp-sdk)
 (synopsis "OCaml SDK for Model Context Protocol using oxcaml_effect")
 (description "An OCaml implementation of the Model Context Protocol (MCP) using Jane Street's oxcaml_effect library")
 (depends 
  (ocaml (>= 5.0))
  dune
  yojson
  unix))