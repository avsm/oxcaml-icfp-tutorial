(* Merge sort implementation for integer lists in OCaml *)

(* Helper function to split a list into two halves *)
let rec split lst =
  match lst with
  | [] -> ([], [])
  | [_] -> (lst, [])
  | x :: y :: rest ->
      let (left, right) = split rest in
      (x :: left, y :: right)

(* Merge two sorted integer lists into one sorted list *)
let rec merge left right =
  match left, right with
  | [], _ -> right
  | _, [] -> left
  | x :: xs, y :: ys ->
      if x <= y then
        x :: merge xs right
      else
        y :: merge left ys

(* Merge sort algorithm for integers *)
let rec merge_sort lst =
  match lst with
  | [] -> []
  | [x] -> [x]
  | _ ->
      let (left, right) = split lst in
      let sorted_left = merge_sort left in
      let sorted_right = merge_sort right in
      merge sorted_left sorted_right

(* Example usage and tests *)
let () =
  let test_list = [5; 2; 8; 1; 9; 3; 7; 4; 6] in
  Printf.printf "Original list: ";
  List.iter (Printf.printf "%d ") test_list;
  Printf.printf "\n";

  let sorted = merge_sort test_list in
  Printf.printf "Sorted list:   ";
  List.iter (Printf.printf "%d ") sorted;
  Printf.printf "\n";

  (* Test edge cases *)
  Printf.printf "\nEdge cases:\n";
  Printf.printf "Empty list: %s\n"
    (if merge_sort [] = [] then "OK" else "FAIL");
  Printf.printf "Single element: %s\n"
    (if merge_sort [42] = [42] then "OK" else "FAIL");
  Printf.printf "Already sorted: %s\n"
    (if merge_sort [1;2;3;4;5] = [1;2;3;4;5] then "OK" else "FAIL");
  Printf.printf "Reverse sorted: %s\n"
    (if merge_sort [5;4;3;2;1] = [1;2;3;4;5] then "OK" else "FAIL")