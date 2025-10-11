open! Await
module Scheduler = Parallel_scheduler_work_stealing
module Par_array = Parallel.Arrays.Array
module Slice = Par_array.Slice

let swap slice ~i ~j =
  let temp = Slice.get slice i in
  Slice.set slice i (Slice.get slice j);
  Slice.set slice j temp

let partition slice =
  let length = Slice.length slice in
  let pivot = Random.int length in
  swap slice ~i:pivot ~j:(length - 1);
  let pivot = Slice.get slice (length - 1) in
  let store = ref 0 in
  for i = 0 to length - 2 do
    if Slice.get slice i <= pivot
    then (
      swap slice ~i ~j:!store;
      incr store)
  done;
  swap slice ~i:!store ~j:(length - 1);
  !store

  let rec quicksort par slice =
    if 1 < Slice.length slice then ( 
      let pivot = partition slice in 
      let #((), ()) = 
        Slice.fork_join2 par ~pivot slice 
          (fun par left -> quicksort par left)
          (fun par right -> quicksort par right) 
      in () 
    ) 

  let quicksort ~scheduler ~mutex array =
    Scheduler.parallel scheduler ~f:(fun parallel ->
      Await_blocking.with_await Terminator.never ~f:(fun wait ->
      Capsule.Mutex.with_lock wait mutex ~f:(fun access ->
        (Capsule.Data.unwrap ~access array
        |> Par_array.of_array
        |> Slice.slice
        |> quicksort parallel)[@nontail])
      [@nontail])
    [@nontail])

(* Example usage and tests *)
let () =
  let scheduler =
    (Parallel_scheduler_work_stealing.create [@alert "-experimental"]) ()
  in
  let n = 10000 in

  let (P mutex) = Capsule.Mutex.create () in
  let array =
    Capsule.Data.create (fun () -> Array.init n (fun _ -> Random.int n))
  in
  quicksort ~scheduler ~mutex array ;
  Await_blocking.with_await Terminator.never ~f:(fun wait ->
  Capsule.Mutex.with_lock wait mutex ~f:(fun access ->
    let array = Capsule.Data.unwrap ~access array in
    Array.iter (Printf.printf "%d ") array ;
    for i = 0 to n - 2 do 
      assert (array.(i) <= array.(i + 1))
    done))
