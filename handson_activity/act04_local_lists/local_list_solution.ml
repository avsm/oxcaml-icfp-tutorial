let rec iter (l @ local) f =
  match l with
  | [] -> ()
  | x::xs -> f x; iter xs f

let rec map (l @ local) f =
  match l with
  | [] -> exclave_ []
  | x::xs ->
      exclave_ (f x::map xs f)