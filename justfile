# OCaml MCP SDK justfile

# Default recipe - show available commands
default:
    @just --list

# Build the project
build:
    dune build

# Clean build artifacts
clean:
    dune clean

# Run tests
test:
    dune runtest

# Build documentation
doc:
    dune build @doc

# Install the library
install:
    dune install

# Uninstall the library
uninstall:
    dune uninstall

# Format code
format:
    dune build @fmt --auto-promote

# Development watch mode
watch:
    dune build -w

# Run the weather server example
weather-server: build
    dune exec examples/weather_server.exe

# Run the weather client example
weather-client: build
    dune exec examples/weather_client.exe

# Run both examples (server in background, then client)
examples: build
    #!/usr/bin/env bash
    dune exec examples/weather_server.exe &
    SERVER_PID=$!
    sleep 2
    dune exec examples/weather_client.exe
    kill $SERVER_PID

# Check code without building
check:
    dune build @check

# Run tests with coverage
test-coverage:
    dune runtest --instrument-with bisect_ppx
    bisect-ppx-report html

# Create a release build
release:
    dune build --profile release

# Run all quality checks (format, build, test)
ci: format build test

# Open documentation in browser
doc-open: doc
    open _build/default/_doc/_html/index.html

# Run specific test file
test-file FILE:
    dune exec test/{{FILE}}.exe

# Clean and rebuild everything
rebuild: clean build

# Show project structure
structure:
    tree -I '_build|*.install|*.merlin|.git'

# Initialize opam environment
init:
    opam install . --deps-only --with-test --with-doc

# Update dependencies
update:
    opam update
    opam upgrade
    opam install . --deps-only --with-test --with-doc

# Create a new example
new-example NAME:
    #!/usr/bin/env bash
    echo "Creating new example: {{NAME}}"
    echo '(** Example {{NAME}} using OCaml MCP SDK with effects *)' > examples/{{NAME}}.ml
    echo '' >> examples/{{NAME}}.ml
    echo 'open Mcp' >> examples/{{NAME}}.ml
    echo '' >> examples/{{NAME}}.ml
    echo 'let () =' >> examples/{{NAME}}.ml
    echo '  Printf.printf "{{NAME}} example\n"' >> examples/{{NAME}}.ml
    echo "(executable" >> examples/dune
    echo " (public_name {{NAME}})" >> examples/dune
    echo " (name {{NAME}})" >> examples/dune
    echo " (libraries mcp))" >> examples/dune
    echo "" >> examples/dune
    echo "Created examples/{{NAME}}.ml"

# Run server with custom port (for HTTP transport)
server-http PORT="8080":
    @echo "Starting HTTP server on port {{PORT}}"
    @echo "Not yet implemented - add HTTP server runner"

# Benchmark the effect system
bench:
    dune exec test/bench_effects.exe

# Package for distribution
package:
    dune build @install
    dune-release distrib

# Lint the code
lint:
    dune build @lint

# Watch tests
watch-test:
    dune runtest -w

# Profile memory usage
profile-memory:
    dune exec --profile release --instrument-with landmarks examples/weather_server.exe

# Generate effect visualization
visualize-effects:
    @echo "Generating effect hierarchy visualization..."
    @echo "Not yet implemented - add graphviz generation"

# Run with debug logging
debug TARGET:
    OCAMLRUNPARAM=b dune exec {{TARGET}}