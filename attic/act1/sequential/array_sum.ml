(* Sequential array sum example *)

let add_many_seq (arr : int array) =
  Array.fold_left (fun acc x -> acc + x) 0 arr

let main () =
  Random.init 42;
  let sizes = [100; 1000; 10000; 100000] in
  List.iter (fun size ->
    let arr = Array.init size (fun _ -> Random.int 100) in

    let start_time = Sys.time () in
    let sum = add_many_seq arr in
    let end_time = Sys.time () in
    Printf.printf "Array size %d: sum=%d, time=%.6f seconds\n"
      size sum (end_time -. start_time)
  ) sizes

let () = main ()