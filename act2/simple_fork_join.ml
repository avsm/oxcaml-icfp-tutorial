(* Simple fork/join example following the tutorial *)

open Base
open Stdio

(* First, the trivial add4 example from the tutorial *)
let add4 (par : Parallel.t) a b c d =
  let a_plus_b, c_plus_d =
    Parallel.fork_join2 par
      (fun _par -> a + b)
      (fun _par -> c + d)
  in
  a_plus_b + c_plus_d

(* Tree type exactly as in tutorial *)
module Tree = struct
  type 'a t =
    | Leaf of 'a
    | Node of 'a t * 'a t
end

(* Sequential average over floats *)
let average_floats (tree : float Tree.t) =
  let rec total tree =
    match tree with
    | Tree.Leaf x -> ~total:x, ~count:1
    | Tree.Node (l, r) ->
      let ~total:total_l, ~count:count_l = total l in
      let ~total:total_r, ~count:count_r = total r in
      ( ~total:(total_l +. total_r),
        ~count:(count_l + count_r) )
  in
  let ~total, ~count = total tree in
  total /. Float.of_int count

(* Parallel version *)
let average_floats_par (par : Parallel.t) (tree : float Tree.t) =
  let rec (total @ portable) par (tree : float Tree.t) =
    match tree with
    | Tree.Leaf x -> ~total:x, ~count:1
    | Tree.Node (l, r) ->
      let ( (~total:total_l, ~count:count_l),
            (~total:total_r, ~count:count_r) ) =
        Parallel.fork_join2 par
          (fun par -> total par l)
          (fun par -> total par r)
      in
      ( ~total:(total_l +. total_r),
        ~count:(count_l + count_r) )
  in
  let ~total, ~count = total par tree in
  total /. Float.of_int count

(* Run one test with scheduler *)
let run_one_test ~(f : Parallel.t @ local -> 'a) : 'a =
  let module Scheduler = Parallel_scheduler_work_stealing in
  let scheduler = Scheduler.create () in
  let monitor = Parallel.Monitor.create_root () in
  let result = Scheduler.schedule scheduler ~monitor ~f in
  Scheduler.stop scheduler;
  result

(* Build test tree *)
let rec build_float_tree depth =
  if depth = 0 then
    Tree.Leaf (Random.float 100.0)
  else
    Tree.Node (build_float_tree (depth - 1), build_float_tree (depth - 1))

let main () =
  (* Test add4 *)
  let result = run_one_test ~f:(fun par -> add4 par 1 10 100 1000) in
  printf "add4 result: %d\n" result;

  (* Test tree average *)
  Random.init 42;
  let test_tree = build_float_tree 10 in

  let seq_result = average_floats test_tree in
  printf "Sequential average: %.2f\n" seq_result;

  let par_result = run_one_test ~f:(fun par -> average_floats_par par test_tree) in
  printf "Parallel average: %.2f\n" par_result

let () = main ()