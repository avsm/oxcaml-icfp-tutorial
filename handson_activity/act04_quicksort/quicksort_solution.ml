module Capsule = Portable.Capsule.Expert
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
      let (), () = 
        Slice.fork_join2 par ~pivot slice 
          (fun par left -> quicksort par left)
          (fun par right -> quicksort par right) 
      in () 
    ) 

  let quicksort ~scheduler ~mutex array =
    let monitor = Parallel.Monitor.create_root () in
    Parallel_scheduler_work_stealing.schedule scheduler ~monitor ~f:(fun parallel ->
      Capsule.Mutex.with_lock mutex ~f:(fun password ->
        Capsule.Data.iter array ~password ~f:(fun array ->
          let array = Par_array.of_array array in
          quicksort parallel (Slice.slice array) [@nontail])
        [@nontail])
      [@nontail])

(* Example usage and tests *)
let () =
  let scheduler =
    (Parallel_scheduler_work_stealing.create [@alert "-experimental"]) ()
  in
  let n = 10000 in

  let (P key) = Capsule.create () in
  let mutex = Capsule.Mutex.create key in
  let array =
    Capsule.Data.create (fun () -> Array.init n (fun _ -> Random.int n))
  in
  quicksort ~scheduler ~mutex array ;
  Capsule.Mutex.with_lock mutex ~f:(fun password ->
    Capsule.Data.iter array ~password ~f:(fun array ->
      Array.iter (Printf.printf "%d ") array ;
      for i = 0 to n - 2 do 
        assert (array.(i) <= array.(i + 1))
      done ) )
