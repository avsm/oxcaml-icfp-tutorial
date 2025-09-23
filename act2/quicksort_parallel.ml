(* Parallel quicksort with capsules and slices *)

open Base
open Stdio
module Capsule = Basement.Capsule

module Par_array = Parallel.Arrays.Array
module Slice = Parallel.Arrays.Array.Slice

let swap slice ~i ~j =
  let temp = Slice.get slice i in
  Slice.set slice i (Slice.get slice j);
  Slice.set slice j temp

let partition slice =
  let length = Slice.length slice in
  let pivot_index = Random.int length in
  swap slice ~i:pivot_index ~j:(length - 1);
  let pivot = Slice.get slice (length - 1) in
  let store_index = ref 0 in
  for i = 0 to length - 2 do
    if Slice.get slice i <= pivot then begin
      swap slice ~i ~j:!store_index;
      Int.incr store_index
    end
  done;
  swap slice ~i:!store_index ~j:(length - 1);
  !store_index

(* Sequential quicksort for comparison *)
let rec quicksort_seq slice =
  if Slice.length slice > 1 then begin
    let pivot = partition slice in
    let length = Slice.length slice in
    let left = Slice.sub slice ~i:0 ~j:pivot in
    let right = Slice.sub slice ~i:pivot ~j:length in
    quicksort_seq left;
    quicksort_seq right [@nontail]
  end

(* Parallel quicksort using fork_join2 on slices *)
let rec quicksort_par parallel slice =
  if Slice.length slice <= 1000 then
    (* Use sequential for small arrays *)
    quicksort_seq slice
  else begin
    let pivot = partition slice in
    let (), () =
      Slice.fork_join2
        parallel
        ~pivot
        slice
        (fun parallel left -> quicksort_par parallel left)
        (fun parallel right -> quicksort_par parallel right)
    in
    ()
  end

(* Wrapper to sort a capsule-protected array *)
let sort_capsule ~scheduler ~mutex array =
  let monitor = Parallel.Monitor.create_root () in
  Parallel_scheduler_work_stealing.schedule scheduler ~monitor ~f:(fun parallel ->
    Capsule.Mutex.with_lock mutex ~f:(fun password ->
      Capsule.Data.iter array ~password ~f:(fun array ->
        let array = Par_array.of_array array in
        quicksort_par parallel (Slice.slice array) [@nontail]
      ) [@nontail]
    ) [@nontail]
  )

(* Test harness *)
let test_array size =
  Array.init size ~f:(fun _ -> Random.int 10000)

let is_sorted arr =
  let rec check i =
    if i >= Array.length arr - 1 then true
    else if arr.(i) > arr.(i+1) then false
    else check (i + 1)
  in
  check 0

let main () =
  Random.init 42;
  let module Scheduler = Parallel_scheduler_work_stealing in
  let scheduler = Scheduler.create () in

  let sizes = [1000; 10000; 100000] in
  List.iter ~f:(fun size ->
    (* Sequential version *)
    let arr_seq = test_array size in
    let start_time = Unix.gettimeofday () in
    let arr_seq_par = Par_array.of_array arr_seq in
    quicksort_seq (Slice.slice arr_seq_par);
    let time_seq = Unix.gettimeofday () -. start_time in
    let sorted_seq = is_sorted arr_seq in

    (* Parallel version with capsule *)
    let (P key) = Capsule.create () in
    let mutex = Capsule.Mutex.create key in
    let capsule_array = Capsule.Data.create (fun () -> test_array size) in

    let start_time = Unix.gettimeofday () in
    sort_capsule ~scheduler ~mutex capsule_array;
    let time_par = Unix.gettimeofday () -. start_time in

    (* Check if sorted *)
    let sorted_par = Capsule.Mutex.with_lock mutex ~f:(fun password ->
      Capsule.Data.extract capsule_array ~password ~f:(fun arr ->
        is_sorted arr
      )
    ) in

    printf "Array size %d:\n" size;
    printf "  Sequential: sorted=%b, time=%.3f s\n" sorted_seq time_seq;
    printf "  Parallel:   sorted=%b, time=%.3f s (speedup %.2fx)\n"
      sorted_par time_par (time_seq /. time_par);
    printf "\n"
  ) sizes;

  Scheduler.stop scheduler

let () = main ()
