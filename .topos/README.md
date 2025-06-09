This directory is a landing spot for *formal artefacts* that live adjacent to the codebase but are not compiled directly—e.g. JSON Schema documents, formal proofs, or metamodels.

Layout convention

```
.topos/
  schema/
    <date>/          # versioned schemas from the MCP spec repo
      schema.json
  proofs/
  model/
```

The sub-folder added in this patch mirrors the path used in the upstream *Model-Context-Protocol* specification repository so that it stays discoverable by tooling.

Generated / vendored content **must not** be edited manually; instead update via the helper script described below.

## Syncing the spec

Run

```sh
just update-schema
```

which will:  
1. Fetch the latest JSON from the canonical URL using `curl --fail --silent --location`.  
2. Overwrite `.topos/schema/<date>/schema.json`.  
3. Commit with message `chore: update MCP schema to <date>`.

If you are offline the script prints a helpful error and leaves the existing file untouched.

## Why under `.topos`?

The MCP SDK proper never reads the schema at runtime—the schema is used by *tooling* (generators, linters, test fixtures).  Keeping it outside `lib/` avoids accidental inclusion in the build artefacts while still version-controlling it.

