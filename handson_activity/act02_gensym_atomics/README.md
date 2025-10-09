# Safe GenSym in OxCaml

In this activity, we will implement a correct parallel version of GenSym
function in OxCaml using
[Atomics](https://github.com/oxcaml/oxcaml/blob/main/stdlib/atomic.mli). See
`gensym_atomics.ml`.

## Building and running the code

`dune build` builds all the code examples.  `dune exec ./gensym_atomics.exe`
builds and runs the code in `gensym_atomics.ml`.
