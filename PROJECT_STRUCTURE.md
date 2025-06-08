# OCaml MCP SDK Project Structure

```
ocaml-mcp-sdk/
├── LICENSE                          # MIT License
├── README.md                        # Main documentation
├── CHANGELOG.md                     # Version history
├── justfile                         # Build commands (using just)
├── dune-project                     # Dune project configuration
├── ocaml-mcp-sdk.opam              # OPAM package definition
├── .gitignore                       # Git ignore patterns
│
├── lib/                            # Library source code
│   ├── dune                        # Library build configuration
│   ├── mcp.mli                     # Public interface
│   └── mcp.ml                      # Implementation
│
├── examples/                       # Example applications
│   ├── dune                        # Examples build configuration
│   ├── weather_server.ml           # Example MCP server
│   └── weather_client.ml           # Example MCP client
│
├── test/                           # Test suite
│   ├── dune                        # Test build configuration
│   └── test_effects.ml             # Effect system tests
│
├── docs/                           # Documentation
│   ├── API.md                      # API reference
│   ├── GETTING_STARTED.md          # Quick start guide
│   └── ADVANCED.md                 # Advanced patterns
│
└── analysis/                       # Architecture analysis
    ├── SDK_COMPARISON.md           # Comparison with other SDKs
    └── ARCHITECTURE_ANALYSIS.md    # Detailed architecture analysis
```

## Key Files

### Core Implementation (`lib/`)

- **mcp.mli**: The public interface defining all modules, types, and effects
- **mcp.ml**: The implementation using OCaml's algebraic effects system

### Examples (`examples/`)

- **weather_server.ml**: Demonstrates server implementation with tools and resources
- **weather_client.ml**: Shows client usage patterns

### Tests (`test/`)

- **test_effects.ml**: Unit tests for the effect system and handler composition

### Documentation (`docs/`)

- **API.md**: Complete API reference
- **GETTING_STARTED.md**: Beginner-friendly introduction
- **ADVANCED.md**: Advanced patterns and techniques

## Building the Project

```bash
# Show available commands
just

# Build everything
just build

# Run tests
just test

# Build documentation
just doc

# Run examples
just weather-server  # In one terminal
just weather-client  # In another terminal

# Run both examples automatically
just examples
```

## Development Workflow

1. **Edit** source files in `lib/`
2. **Build** with `just watch` (watch mode)
3. **Test** with `just test`
4. **Format** with `just format`
5. **Document** changes in CHANGELOG.md

Additional just commands:
- `just ci` - Run all quality checks
- `just clean` - Clean build artifacts
- `just rebuild` - Clean and rebuild
- `just test-coverage` - Run tests with coverage
- `just new-example NAME` - Create a new example

## Dependencies

- OCaml >= 5.0.0 (for algebraic effects)
- effect (effect system library)
- yojson (JSON parsing)
- lwt (asynchronous programming)
- cohttp-lwt-unix (HTTP client/server)
- uri (URI parsing)