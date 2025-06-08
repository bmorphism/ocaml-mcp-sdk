#!/bin/bash

echo "OCaml MCP SDK with oxcaml_effect - Structure Overview"
echo "===================================================="
echo

echo "Vendored dependencies:"
echo "- oxcaml_effect: Jane Street's effect library"
echo "  - src/effect.mli: Interface with S, S1, S2 signatures"
echo "  - src/effect.ml: Implementation with handler indices"
echo "- base_stub: Minimal Base library stub"
echo "- basement_stub: Minimal Basement library stub"
echo

echo "Library modules:"
echo "- mcp_effect.ml: Core effect definitions (Transport, Protocol, Resource, Tool, Prompt)"
echo "- stdio_transport.ml: Stdio transport handler"
echo "- protocol_handler.ml: JSON-RPC protocol handler"
echo "- mcp_client.ml: MCP client implementation"
echo "- mcp_server.ml: MCP server implementation"
echo

echo "Examples:"
echo "- client_example.ml: Example MCP client"
echo "- server_example.ml: Example MCP server"
echo

echo "Key features:"
echo "✓ Uses oxcaml_effect for O(1) effect dispatch"
echo "✓ Typed handler lists with GADTs"
echo "✓ Mode annotations for safety (@@ portable, @ local, @ unique)"
echo "✓ Composable effects using fiber_with"
echo "✓ Complete MCP protocol implementation"
echo

echo "To build (requires OCaml 5.0+ and dune):"
echo "  dune build"
echo

echo "File tree:"
find . -type f -name "*.ml" -o -name "*.mli" -o -name "dune" | grep -v ".git" | sort