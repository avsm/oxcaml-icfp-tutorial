
let radix_sort lst =
  (* For 32-bit integers, we need 3 passes to check each byte. *)
  let num_passes = 4 in
  let bits_per_pass = 8 in

  let rec loop pass current_list =
    if pass >= num_passes then
      current_list
    else
      (* 1. Create 256 empty buckets (one for each possible byte value). *)
      let buckets = Array.make 256 [] in
      let shift = pass * bits_per_pass in

      (* 2. Distribute every number from the list into the correct bucket. *)
      List.iter (fun n ->
        let bucket_index = (n lsr shift) land 0xFF in
        (* Prepend the number to its bucket's list. *)
        buckets.(bucket_index) <- n :: buckets.(bucket_index)
      ) current_list;

      (* 3. Concatenate the buckets back into a single list.
         We reverse each bucket first to maintain stability. *)
      let next_list =
        List.concat (Array.to_list (Array.map List.rev buckets))
      in
      
      (* 4. Recursively call the loop for the next significant byte. *)
      loop (pass + 1) next_list
  in

  loop 0 lst

(* Example usage and tests *)
let () =
  let test_list = List.init 10 (fun _ -> Random.int 1_000) in
  Printf.printf "Original list: ";
  List.iter (Printf.printf "%d ") test_list;
  Printf.printf "\n";

  let sorted = radix_sort test_list in
  Printf.printf "Sorted list:   ";
  List.iter (Printf.printf "%d ") sorted;
  Printf.printf "\n";

  (* Test edge cases *)
  Printf.printf "\nEdge cases:\n";
  let assert_equal expected actual message =
    Printf.printf "%s: %s\n" message
      (if actual = expected then "OK" else "FAIL")
  in
  assert_equal [] (radix_sort []) "Empty list";
  assert_equal [42] (radix_sort [42]) "Single element";
  assert_equal [1;2;3;4;5] (radix_sort [1;2;3;4;5]) "Already sorted";
  assert_equal [1;2;3;4;5] (radix_sort [5;4;3;2;1]) "Reverse sorted";
  assert_equal [1; 255; 256; 257] (radix_sort [257; 256; 1; 255]) "Byte boundaries"
