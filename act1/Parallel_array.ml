let init n f =
  let a = Array.init n (fun _ -> Obj.magic 0) in
  let mid = n/2 in
  let d1 = Domain.spawn (fun () ->
    for i = 0 to mid do
      a.(i) <- f i
    done)
  in
  let d2 = Domain.spawn (fun () ->
    for i = mid + 1 to n - 1 do
      a.(i) <- f i
    done)
  in
  Domain.join d1;
  Domain.join d2;
  a