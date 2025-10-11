(* Merge sort implementation for integer lists in OCaml *)

(* Helper function to split a list into two halves *)
let [@zero_alloc] rec split (lst @ local) = exclave_
  match lst with
  | [] -> ([], [])
  | [_] -> (lst, [])
  | x :: y :: rest ->
      let (left, right) = split rest in
      (x :: left, y :: right)

(* Merge two sorted integer lists into one sorted list *)
let [@zero_alloc] rec merge (left : int list @ local) (right : int list @ local) =
  match left, right with
  | [], _ -> right
  | _, [] -> left
  | x :: xs, y :: ys ->
      if x <= y then
        exclave_ (x :: merge xs right)
      else
        exclave_ (y :: merge left ys)

(* Merge sort algorithm for integers *)
let [@zero_alloc] rec merge_sort (lst @ local) = exclave_
  match lst with
  | [] -> []
  | [x] -> [x]
  | _ ->
      let (left, right) = split lst in
      let sorted_left = merge_sort left in
      let sorted_right = merge_sort right in
      let res = merge sorted_left sorted_right in
      res

let rec list_iter (f : 'a @ local -> unit) (lst : 'a list @ local) =
  match lst with
  | [] -> ()
  | x :: xs ->
      f x;
      list_iter f xs

(* Example usage and tests *)
let () =
  let test_list = [5; 2; 8; 1; 9; 3; 7; 4; 6] in
  Printf.printf "Original list: ";
  list_iter (fun (x:int) -> Printf.printf "%d " x) test_list;
  Printf.printf "\n";

  let sorted = merge_sort test_list in
  Printf.printf "Sorted list:   ";
  list_iter (fun (x:int) -> Printf.printf "%d " x) sorted;
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
