open! Base

module Printf = struct
  include Printf

  let printf fmt = Printf.ksprintf print_string fmt
end

module Slice = struct 
  type 'a t = { array : 'a array; start : int; stop : int }

  let get {array; start; _} i = 
    array.(start + i)

  let set {array; start; _} i v = 
    array.(start + i) <- v

  let length {array: _; start; stop} = 
    stop - start

  let sub t ~i ~j = 
    { array= t.array; start= t.start + i; stop= t.start + j }

  let of_array array = 
    { array; start=0; stop=Array.length array }
end

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
      Int.incr store)
  done;
  swap slice ~i:!store ~j:(length - 1);
  !store

let rec quicksort slice =
  if Slice.length slice > 1 then (
    let pivot = partition slice in
    let length = Slice.length slice in
    let left = Slice.sub slice ~i:0 ~j:pivot in
    let right = Slice.sub slice ~i:pivot ~j:length in
    quicksort left;
    quicksort right
  )

let quicksort array = quicksort (Slice.of_array array)

(* Example usage and tests *)
let () =
  let n = 1000 in
  let test_arr = Array.init n ~f:(fun _ -> Random.int n) in
  Printf.printf "Original array: ";
  Array.iter ~f:(Printf.printf "%d ") test_arr;
  Printf.printf "\n";
  quicksort test_arr;
  Printf.printf "Sorted array:   ";
  Array.iter ~f:(Printf.printf "%d ") test_arr;
  Printf.printf "\n";
  for i = 0 to n - 2 do 
    assert (test_arr.(i) <= test_arr.(i + 1))
  done
