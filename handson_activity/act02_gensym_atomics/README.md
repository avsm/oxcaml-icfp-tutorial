# Safe GenSym in OxCaml

In this activity, we will implement a correct parallel version of GenSym
function in OxCaml using
[Atomics](https://github.com/oxcaml/oxcaml/blob/main/stdlib/atomic.mli). See
`gensym_atomics.ml`.

## Building and running the code

Make sure you are on the correct switch:

```bash
$ opam switch 5.2.0+ox
$ eval $(opam env)
$ opam switch
#  switch      compiler                                          description
→  5.2.0+ox    ocaml-variants.5.2.0+ox                           5.2.0+ox
   5.3.0       ocaml-base-compiler.5.3.0                         5.3.0
   5.3.0+tsan  ocaml-option-tsan.1,ocaml-variants.5.3.0+options  5.3.0+tsan
```

Then, from the `handson_activity/act02_gensym_atomics` directory, run:

```bash

`dune build` builds all the code examples.  `dune exec ./gensym_atomics.exe`
builds and runs the code in `gensym_atomics.ml`.
