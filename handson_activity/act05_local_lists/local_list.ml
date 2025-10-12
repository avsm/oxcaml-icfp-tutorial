let rec iter l f =
  match l with
  | [] -> ()
  | x::xs -> f x; iter xs f

let rec map l f =
  match l with
  | [] -> []
  | x::xs -> f x::map xs f