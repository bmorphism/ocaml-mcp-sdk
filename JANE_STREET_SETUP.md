# Setting Up Jane Street OCaml for Mode Checking

The current codebase requires Jane Street's OCaml fork to enable mode extensions. Here's how to set it up:

## 1. Install Jane Street OCaml Switch

```bash
# Create a new opam switch with Jane Street's OCaml + flambda2
opam switch create 5.2.0+flambda2 \
  --repos with-extensions=git+https://github.com/janestreet/opam-repository.git#with-extensions,default

# Activate the switch
eval $(opam env)

# Verify mode extensions are available
ocamlopt -help | grep mode
```

## 2. Install Dependencies in New Switch

```bash
opam install dune yojson unix
```

## 3. Enable Modes in Dune

Uncomment the modes flag in `lib/dune`:
```dune
(library
 (name ocaml_mcp_sdk)
 (public_name ocaml-mcp-sdk)
 (libraries oxcaml_effect yojson unix)
 (modules modes mcp_effect stdio_transport protocol_handler mcp_client mcp_server)
 (flags :standard -extension mode))  # <- Uncomment this line
```

## 4. Test Mode Compilation

```bash
dune build

# Should show mode errors for:
# - Double-use of unique resources
# - Cross-domain sharing violations
# - Closure capture violations
```

## 5. Current Status

Without Jane Street's compiler:
- Mode annotations are parsed but ignored
- Code behaves like standard OCaml
- No compile-time mode checking

With `-extension mode` enabled:
- Full mode checking active
- Compile errors for mode violations
- Zero runtime overhead

## 6. Fallback for Standard OCaml

The codebase is designed to work with both:
- Standard OCaml 5.2+ (modes ignored)
- Jane Street OCaml 5.2+flambda2 (modes checked)

This allows gradual adoption and testing of mode annotations.