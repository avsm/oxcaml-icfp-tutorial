(* The aim of this activity is to understand how to use capsules. We're going to
   stick with the non-atomic references in `gensym`. Use capsules to ensure that
   gensym is safe for parallel access (and the code will compile). *)

open Basement

(* Here is an example snippet to show how to create and use capsules. *)
let safe_ref (init : int) =
  (* Create capsule and extract key to bind the type variable *)
  let (P key) = Capsule.create () in
  (* Create encapsulated data bound to the same key type *)
  let r = Capsule.Data.create (fun () -> ref init) in
  (* Create mutex from key *)
  let mutex = Capsule.Mutex.create key in

  (* Access with lock *)
  let read () =
    Capsule.Mutex.with_lock mutex ~f:(fun password ->
        Capsule.Data.extract r ~password ~f:(fun (r : int ref) -> !r))
  in
  let write (v : int) =
    Capsule.Mutex.with_lock mutex ~f:(fun password ->
        Capsule.Data.extract r ~password ~f:(fun r -> r := v))
  in
  (read, write)

let gensym =
  (* Create capsule and extract key to bind the type variable *)
  let (P key) = Capsule.create () in

  (* Create encapsulated data bound to the same key type *)
  let counter = Capsule.Data.create (fun () -> ref 0) in

  (* Create mutex from key *)
  let mutex = Capsule.Mutex.create key in

  (* Access with lock *)
  let fetch_and_incr () =
    Capsule.Mutex.with_lock mutex ~f:(fun password ->
        Capsule.Data.extract counter ~password ~f:(fun c ->
            c := !c + 1;
            !c))
  in
  fun () -> "gsym_" ^ Int.to_string (fetch_and_incr ())

let parallel_read_write par =
  let r = safe_ref 0 in
  let read, write = r in
  Parallel.fork_join2 par
    (fun _ ->
      for _ = 1 to 1000 do
        ignore (read ())
      done)
    (fun _ ->
      for i = 1 to 1000 do
        write i
      done)
  |> ignore

(* Test that gensym produces distinct symbols in parallel *)

let gensym_pair par =
  let s1, s2 =
    Parallel.fork_join2 par (fun _ -> gensym ()) (fun _ -> gensym ())
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
  run_parallel ~f:parallel_read_write;
  run_parallel ~f:gensym_pair
