(lang dune 3.16)

(name mcp)

(generate_opam_files true)

(source
 (github barton/ocaml-mcp-sdk))

(authors "Barton")

(maintainers "Barton")

(license MIT)

(package
 (name mcp)
 (synopsis "OCaml SDK for Model Context Protocol with algebraic effects")
 (description
  "A Jane Street-style OCaml implementation of the Model Context Protocol (MCP) using algebraic effects for typed, composable I/O")
 (depends
  (ocaml (>= 5.2))
  (dune (>= 3.16))
  (core (>= 0.17))
  (core_unix (>= 0.17))
  (ppx_jane (>= 0.17))
  yojson))
