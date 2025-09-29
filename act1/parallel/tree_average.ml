(* Sequential tree averaging example *)

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

  type t = {
    price : float;
    mutable mood : Mood.t
  }

  let create ~price ~mood = { price; mood }
  let price { price; _ } = price
  let _mood { mood; _ } = mood
  let _cheer_up t = t.mood <- Happy
  let _bum_out t = t.mood <- Sad
end

let average (tree : Thing.t Tree.t) =
  let rec total tree =
    match tree with
    | Tree.Leaf x -> (Thing.price x, 1)
    | Tree.Node (l, r) ->
      let (total_l, count_l) = total l in
      let (total_r, count_r) = total r in
      (total_l +. total_r, count_l + count_r)
  in
  let (total, count) = total tree in
  total /. (float_of_int count)

(* Build a test tree *)
let rec build_tree depth =
  if depth = 0 then
    Tree.Leaf (Thing.create ~price:(Random.float 100.0) ~mood:Thing.Mood.Neutral)
  else
    Tree.Node (build_tree (depth - 1), build_tree (depth - 1))

let main () =
  Random.init 42;
  let test_tree = build_tree 10 in (* 2^10 = 1024 leaves *)
  let start_time = Sys.time () in
  let result = average test_tree in
  let end_time = Sys.time () in
  Printf.printf "Sequential average: %.2f\n" result;
  Printf.printf "Time: %.3f seconds\n" (end_time -. start_time)

let () = main ()