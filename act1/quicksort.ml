(* Sequential quicksort example *)

let swap arr ~i ~j =
  let temp = arr.(i) in
  arr.(i) <- arr.(j);
  arr.(j) <- temp

let partition arr ~left ~right =
  let pivot_index = left + Random.int (right - left + 1) in
  swap arr ~i:pivot_index ~j:right;
  let pivot = arr.(right) in
  let store_index = ref left in
  for i = left to right - 1 do
    if arr.(i) <= pivot then begin
      swap arr ~i ~j:!store_index;
      incr store_index
    end
  done;
  swap arr ~i:!store_index ~j:right;
  !store_index

let rec quicksort arr ~left ~right =
  if left < right then begin
    let pivot_index = partition arr ~left ~right in
    quicksort arr ~left ~right:(pivot_index - 1);
    quicksort arr ~left:(pivot_index + 1) ~right
  end

let test_array size =
  Array.init size (fun _ -> Random.int 1000)

let main () =
  Random.init 42;
  let sizes = [100; 1000; 10000] in
  List.iter (fun size ->
    let arr = test_array size in
    let start_time = Sys.time () in
    quicksort arr ~left:0 ~right:(size - 1);
    let end_time = Sys.time () in

    (* Verify it's sorted *)
    let is_sorted =
      let rec check i =
        if i >= Array.length arr - 1 then true
        else if arr.(i) > arr.(i+1) then false
        else check (i + 1)
      in
      check 0
    in

    Printf.printf "Array size %d: sorted=%b, time=%.3f seconds\n"
      size is_sorted (end_time -. start_time)
  ) sizes

let () = main ()