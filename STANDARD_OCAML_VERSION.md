# Standard OCaml Compatibility Version

The vendor code contains Jane Street mode syntax that requires their compiler fork. For standard OCaml compatibility, we need to either:

## Option 1: Strip Mode Annotations

Create clean versions of the vendor files without mode syntax:

```bash
# Remove all @@ portable, @unique, @once annotations
sed 's/@@ portable//g' vendor/oxcaml_effect/src/effect.mli > effect_clean.mli
sed 's/@unique//g; s/@once//g; s/@@ portable//g' vendor/oxcaml_effect/src/effect.ml > effect_clean.ml
```

## Option 2: Use Jane Street Switch

Install the proper compiler:
```bash
opam switch create js-ocaml ocaml-variants.5.2.0+flambda2
eval $(opam env)
```

## Option 3: Mock Mode Syntax

Create compatibility shims in a prelude:
```ocaml
(* modes_compat.ml *)
type 'a unique = 'a
type 'a once = 'a  
type 'a portable = 'a
```

## Current Status

The codebase demonstrates the mode integration pattern but requires Jane Street's compiler to actually compile and verify the mode annotations.

## Recommendation

For the roadmap demonstration:
1. Keep the annotated examples as documentation
2. Strip vendor code for standard OCaml builds  
3. Switch to Jane Street compiler for full mode checking

The value is in showing WHERE the annotations go and WHAT guarantees they provide, not necessarily having a compilable implementation right now.