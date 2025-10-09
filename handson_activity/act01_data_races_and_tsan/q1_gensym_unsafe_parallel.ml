let gensym =
  let count = ref 0 in
  fun () ->
    count := !count + 1 ;
    Printf.sprintf "gsym_%d" !count

let gen_many n =
  Parallel_array.init n (fun _ -> gensym ())

let () =
  let names = gen_many 10000 in
  Array.iter print_endline names