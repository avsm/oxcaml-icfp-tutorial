(* Note, using a list will change the complexity of the Radix Sort, 
   but there is no way to get it zero_alloc with the current implementation 
   of arrays because elements are global *)

let[@zero_alloc] rec list_concat (ls : int list list @ local) = exclave_
  let[@zero_alloc] rec concat l1 l2 = exclave_
    match l1 with 
      | [] -> l2
      | hd :: tl -> hd :: concat tl l2 
  in
  match ls with 
  | [] -> []
  | [l] -> l
  | hd :: tl -> concat hd (list_concat tl)

let[@zero_alloc opt] rec list_iter (f : ('a @ local -> unit) @ local) (ls : 'a list @ local) = exclave_
  match ls with 
  | [] -> ()
  | h :: tl -> (
    f h; 
    list_iter f tl
  )

let[@zero_alloc opt] rec list_map f ls = exclave_
  match ls with 
  | [] -> []
  | hd :: tl -> (f hd) :: list_map f tl

let[@zero_alloc] list_rev ls = exclave_
  let[@zero_alloc] rec loop ls acc = exclave_ (
    match ls with 
    | [] -> acc
    | h :: tl -> loop tl (h :: acc)
  ) 
  in loop ls []

let[@zero_alloc] rec list_create len value = exclave_
  if len = 0 then []
  else 
    value :: list_create (len - 1) value

let[@zero_alloc] list_bucket_cons lss idx value = exclave_
  let[@zero_alloc] rec cons i ls = exclave_
    (match ls with 
    | [] -> []
    | hd :: tl when i = idx -> (value :: hd) :: tl
    | hd :: tl -> hd :: (cons (i + 1) tl))
  in cons 0 lss

let[@zero_alloc opt] rec list_fold_left f init ls = exclave_ 
  match ls with 
    | [] -> init 
    | hd :: tl -> list_fold_left f (f init hd) tl

let[@zero_alloc opt] radix_sort lst = exclave_
  let num_passes = 4 in
  let bits_per_pass = 8 in

  let[@zero_alloc opt] rec loop pass (current_list : int list @ local) = exclave_
    if pass >= num_passes then
      current_list
    else
      let buckets = list_create 256 [] in
      let shift = pass * bits_per_pass in

      let buckets = list_fold_left (fun buckets n -> exclave_
        let bucket_index = (n lsr shift) land 0xFF in
        list_bucket_cons buckets bucket_index n
      ) buckets current_list in

      let next_list = list_concat (list_map list_rev buckets) in
      
      loop (pass + 1) next_list
  in 
  loop 0 lst

(* Example usage and tests *)
let () =
  let test_list = [5; 2; 8; 1; 9; 3; 7; 4; 6] in
  Printf.printf "Original list: ";
  list_iter (fun (x:int) -> Printf.printf "%d " x) test_list;
  Printf.printf "\n";

  let sorted = radix_sort test_list in
  Printf.printf "Sorted list:   ";
  list_iter (fun (x:int) -> Printf.printf "%d " x) sorted;
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
