(* Parallel tree averaging with OxCaml data-race freedom *)

open Base
open Stdio

module Tree = struct
  type 'a t =
    | Leaf of 'a
    | Node of 'a t * 'a t
end

module Thing = struct
  module Mood = struct
    type t =
      | Happy
      | Neutral
      | Sad
  end

  type t : mutable_data = {
    price : float;
    mutable mood : Mood.t
  }

  let create ~price ~mood = { price; mood }
  let price (t @ contended) = t.price  (* Safe: price is immutable *)
  let _mood t = t.mood  (* Requires uncontended access *)
  let _cheer_up t = t.mood <- Happy
  let _bum_out t = t.mood <- Sad
end

(* Sequential version for comparison *)
let average_seq (tree : Thing.t Tree.t) =
  let rec total tree =
    match tree with
    | Tree.Leaf x -> ~total:(Thing.price x), ~count:1
    | Tree.Node (l, r) ->
      let ~total:total_l, ~count:count_l = total l in
      let ~total:total_r, ~count:count_r = total r in
      ( ~total:(total_l +. total_r),
        ~count:(count_l + count_r) )
  in
  let ~total, ~count = total tree in
  total /. Float.of_int count

(* Parallel version using fork_join2 *)
let average_par (par : Parallel.t) tree =
  let rec (total @ portable) par tree =
    match tree with
    | Tree.Leaf x -> ~total:(Thing.price x), ~count:1
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

(* Build a test tree *)
let rec build_tree depth =
  if depth = 0 then
    Tree.Leaf (Thing.create ~price:(Random.float 100.0) ~mood:Thing.Mood.Neutral)
  else
    Tree.Node (build_tree (depth - 1), build_tree (depth - 1))

(* Run parallel computation with scheduler *)
let run_parallel ~f =
  let module Scheduler = Parallel_scheduler_work_stealing in
  let scheduler = Scheduler.create () in
  let monitor = Parallel.Monitor.create_root () in
  let result = Scheduler.schedule scheduler ~monitor ~f in
  Scheduler.stop scheduler;
  result

let main () =
  Random.init 42;
  let test_tree = build_tree 15 in (* 2^15 = 32768 leaves *)

  (* Sequential version *)
  let start_time = Unix.gettimeofday () in
  let result_seq = average_seq test_tree in
  let time_seq = Unix.gettimeofday () -. start_time in
  printf "Sequential average: %.2f (%.3f seconds)\n" result_seq time_seq;

  (* Parallel version *)
  let start_time = Unix.gettimeofday () in
  let result_par = run_parallel ~f:(fun par -> average_par par test_tree) in
  let time_par = Unix.gettimeofday () -. start_time in
  printf "Parallel average:   %.2f (%.3f seconds)\n" result_par time_par;
  printf "Speedup: %.2fx\n" (time_seq /. time_par)

let () = main ()
