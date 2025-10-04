# Walk through

## Q1

Consider the following program:

```ocaml
let gensym =
  let count = ref 0 in
  fun () ->
    count := !count + 1 ;
    Printf.sprintf "gsym_%d" !count

let gen_many n =
  Array.init n (fun _ -> gensym ())

let () =
  let names = gen_many 10000 in
  Array.iter print_endline names
```

> What does the program do?

See `q1_gensym.ml`. We generate Let's compile and run the program:

```bash
$ opam switch 5.3.0
$ eval $(opam env)
$ dune exec ./q1_gensym.exe
<snip>
gsym_9993
gsym_9994
gsym_9995
gsym_9996
gsym_9997
gsym_9998
gsym_9999
gsym_10000
```

> What goes wrong when `gensym` is called in parallel from two different
threads?

See `q1_gensym_unsafe_parallel.ml`.

```ocaml
let gensym =
  let count = ref 0 in
  fun () ->
    count := !count + 1 ;
    Printf.sprintf "gsym_%d" !count

let gen_many n =
  (* Do the array initialisation in parallel *)
  Parallel_array.init n (fun _ -> gensym ())

let () =
  let names = gen_many 10000 in
  Array.iter print_endline names
```

Let's compile and run the program:

```bash
$ dune exec ./q1_gensym_unsafe_parallel.exe
<snip>
gsym_9930
gsym_9931
gsym_9932
gsym_9933
gsym_9934
gsym_9935
```

We don't get to `gsym_10000` since duplicate symbols are generated. There is a
race condition in the code. Let's smoke it out using ThreadSanitizer (TSAN):

```bash
$ opam switch 5.3.0+tsan
$ eval $(opam env)
$ dune exec ./q1_gensym_unsafe_parallel.exe
==================
WARNING: ThreadSanitizer: data race (pid=34434)
  Write of size 8 at 0xffff9b5ffa10 by thread T4 (mutexes: write M0):
    #0 camlDune__exe__Q1_gensym_unsafe_parallel.fun_370 act1/q1_gensym_unsafe_parallel.ml:4 (q1_gensym_unsafe_parallel.exe+0x62be0) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #1 camlDune__exe__Parallel_array.fun_411 act1/Parallel_array.ml:11 (q1_gensym_unsafe_parallel.exe+0x632c8) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #2 camlStdlib__Domain.body_741 /home/vscode/.opam/5.3.0+tsan/.opam-switch/build/ocaml-compiler.5.3.0/stdlib/domain.ml:266 (q1_gensym_unsafe_parallel.exe+0xaa1a8) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #3 caml_start_program <null> (q1_gensym_unsafe_parallel.exe+0x112528) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #4 caml_callback_exn runtime/callback.c:206 (q1_gensym_unsafe_parallel.exe+0xd3124) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #5 caml_callback_res runtime/callback.c:321 (q1_gensym_unsafe_parallel.exe+0xd3b88) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #6 domain_thread_func runtime/domain.c:1245 (q1_gensym_unsafe_parallel.exe+0xd7240) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)

  Previous write of size 8 at 0xffff9b5ffa10 by thread T1 (mutexes: write M1):
    #0 camlDune__exe__Q1_gensym_unsafe_parallel.fun_370 act1/q1_gensym_unsafe_parallel.ml:4 (q1_gensym_unsafe_parallel.exe+0x62be0) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #1 camlDune__exe__Parallel_array.fun_406 act1/Parallel_array.ml:6 (q1_gensym_unsafe_parallel.exe+0x63140) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #2 camlStdlib__Domain.body_741 /home/vscode/.opam/5.3.0+tsan/.opam-switch/build/ocaml-compiler.5.3.0/stdlib/domain.ml:266 (q1_gensym_unsafe_parallel.exe+0xaa1a8) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #3 caml_start_program <null> (q1_gensym_unsafe_parallel.exe+0x112528) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #4 caml_callback_exn runtime/callback.c:206 (q1_gensym_unsafe_parallel.exe+0xd3124) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #5 caml_callback_res runtime/callback.c:321 (q1_gensym_unsafe_parallel.exe+0xd3b88) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
    #6 domain_thread_func runtime/domain.c:1245 (q1_gensym_unsafe_parallel.exe+0xd7240) (BuildId: c201d91391c5440a33fd665c3bac9d6411705307)
<snip>
```

The output shows two backtraces, with the first one being a write to a location
that was previously written to without _synchronization_. You can see from the
first function in the backtraces both refer to the same location
`q1_gensym_unsafe_parallel.ml:4`, which is the assignment to `count` reference
cell.

TSAN is a dynamic data race detector. Only detects races that are encountered at runtime.

> Can we statically detect this race condition?