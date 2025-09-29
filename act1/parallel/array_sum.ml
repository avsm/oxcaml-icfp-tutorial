(* Parallel array sum example *)

[@@@warning "-unused-module"]
[@@@alert "-unsafe_multidomain"]
[@@@alert "-unsafe_parallelism"]

let add_many_seq (arr : int array) =
  Array.fold_left (fun acc x -> acc + x) 0 arr

let add_many_par (arr : int array) =
  let mid = Array.length arr / 2 in
  let d1 = Domain.spawn (fun _ ->
    let sum = ref 0 in
    for i = 0 to mid - 1 do
      sum := !sum + arr.(i)
    done;
    !sum)
  in
  let d2 = Domain.spawn (fun _ ->
    let sum = ref 0 in
    for i = mid to Array.length arr - 1 do
      sum := !sum + arr.(i)
    done;
    !sum)
  in
  Domain.join d1 + Domain.join d2

let add_many_par_atomic (arr : int array) =
  let mid = Array.length arr / 2 in
  let sum = Atomic.make 0 in
  let d1 = Domain.spawn (fun _ ->
    for i = 0 to mid - 1 do
      Atomic.fetch_and_add sum arr.(i) |> ignore
    done)
  in
  let d2 = Domain.spawn (fun _ ->
    for i = mid to Array.length arr - 1 do
      Atomic.fetch_and_add sum arr.(i) |> ignore
    done)
  in
  Domain.join d1;
  Domain.join d2;
  Atomic.get sum

let main () =
  Random.init 42;
  let sizes = [1000; 10000; 100000; 1000000] in

  List.iter (fun size ->
    (* Create immutable array for parallelism *)
    let arr = Array.init size (fun _ -> Random.int 100) in

    (* Sequential *)
    let start_time = Unix.gettimeofday () in
    let sum_seq = add_many_seq arr in
    let time_seq = Unix.gettimeofday () -. start_time in

    (* Parallel reduce *)
    let start_time = Unix.gettimeofday () in
    let sum_par = add_many_par arr in
    let time_par = Unix.gettimeofday () -. start_time in

    (* Parallel with atomics *)
    let start_time = Unix.gettimeofday () in
    let sum_atomic = add_many_par_atomic arr in
    let time_atomic = Unix.gettimeofday () -. start_time in

    let open Printf in
    printf "Array size %d:\n" size;
    printf "  Sequential:   sum=%d, time=%.6f s\n" sum_seq time_seq;
    printf "  Parallel:     sum=%d, time=%.6f s (speedup %.2fx)\n"
      sum_par time_par (time_seq /. time_par);
    printf "  Par+Atomic:   sum=%d, time=%.6f s (speedup %.2fx)\n"
      sum_atomic time_atomic (time_seq /. time_atomic);
    printf "\n"
  ) sizes

let () = main ()