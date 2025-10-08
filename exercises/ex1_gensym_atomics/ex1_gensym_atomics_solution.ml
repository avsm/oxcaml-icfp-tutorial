let gensym =
  let counter = Atomic.make 0 in
  fun () ->
    let c = Atomic.fetch_and_add counter 1 in
    Printf.sprintf "gsym_%d" c

let fork_join_demo par =
  let (l,r) =
    Parallel.fork_join2 par
      (fun _ -> "left")
      (fun _ -> "right")
  in
  assert (l = "left" && r = "right")

let gensym_pair par =
  let (s1,s2) =
    Parallel.fork_join2 par
    (fun _ -> gensym ())
    (fun _ -> gensym ())
  in
  assert (s1 <> s2)

(* Run parallel computation *)
let run_parallel ~f =
  let module Scheduler = Parallel_scheduler_work_stealing in
  let scheduler = Scheduler.create () in
  let monitor = Parallel.Monitor.create_root () in
  let result = Scheduler.schedule scheduler ~monitor ~f in
  Scheduler.stop scheduler;
  result

let () =
  run_parallel ~f:fork_join_demo;
  run_parallel ~f:gensym_pair
