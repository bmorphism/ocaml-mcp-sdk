# Just settings for OCaml MCP SDK

# Use bash for shell commands
set shell := ["bash", "-uc"]

# Allow .env file loading (if present)
set dotenv-load := true

# Set working directory to project root
set working-directory := justfile_directory()

# Export just variables as environment variables
set export := true