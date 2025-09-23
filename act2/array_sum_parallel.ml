(* Parallel array sum using Parallel.Sequence *)

open Base
open Stdio
module Atomic = Portable.Atomic

(* Sequential version *)
let add_many_seq (arr : int iarray) =
  Iarray.fold arr ~init:0 ~f:(fun acc x -> acc + x)

(* Parallel version using Parallel.Sequence *)
let add_many_par par arr =
  let seq = Parallel.Sequence.of_iarray arr in
  Parallel.Sequence.reduce par seq ~f:(fun a b -> a + b)
  |> Option.value ~default:0

(* Version with atomics to track running total *)
let add_many_par_atomic par arr =
  let total = Atomic.make 0 in
  let seq = Parallel.Sequence.of_iarray arr in
  Parallel.Sequence.iter par seq ~f:(fun x ->
    Atomic.update total ~pure_f:(fun t -> t + x)
  );
  Atomic.get total

(* Run parallel computation *)
let run_parallel ~f =
  let module Scheduler = Parallel_scheduler_work_stealing in
  let scheduler = Scheduler.create () in
  let monitor = Parallel.Monitor.create_root () in
  let result = Scheduler.schedule scheduler ~monitor ~f in
  Scheduler.stop scheduler;
  result

let main () =
  Random.init 42;
  let sizes = [1000; 10000; 100000; 1000000] in

  List.iter ~f:(fun size ->
    (* Create immutable array for parallelism *)
    let arr = Iarray.init size ~f:(fun _ -> Random.int 100) in

    (* Sequential *)
    let start_time = Unix.gettimeofday () in
    let sum_seq = add_many_seq arr in
    let time_seq = Unix.gettimeofday () -. start_time in

    (* Parallel reduce *)
    let start_time = Unix.gettimeofday () in
    let sum_par = run_parallel ~f:(fun par -> add_many_par par arr) in
    let time_par = Unix.gettimeofday () -. start_time in

    (* Parallel with atomics *)
    let start_time = Unix.gettimeofday () in
    let sum_atomic = run_parallel ~f:(fun par -> add_many_par_atomic par arr) in
    let time_atomic = Unix.gettimeofday () -. start_time in

    printf "Array size %d:\n" size;
    printf "  Sequential:   sum=%d, time=%.6f s\n" sum_seq time_seq;
    printf "  Parallel:     sum=%d, time=%.6f s (speedup %.2fx)\n"
      sum_par time_par (time_seq /. time_par);
    printf "  Par+Atomic:   sum=%d, time=%.6f s (speedup %.2fx)\n"
      sum_atomic time_atomic (time_seq /. time_atomic);
    printf "\n"
  ) sizes

let () = main ()
