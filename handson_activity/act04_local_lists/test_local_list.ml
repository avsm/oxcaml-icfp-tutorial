[@@@warning "-39"]

let[@zero_alloc] rec iter_test () =
  let int_list = stack_ [1;2;3;4;5] in

  let r = stack_ (ref 0) in
  let acc_sum i = r := !r + i in
  ((Local_list.iter)[@zero_alloc assume]) int_list acc_sum;
  assert (!r = 15)

let[@zero_alloc] rec map_test () =
  let int_list = stack_ [1;2;3;4;5] in
  let l = ((Local_list.map)[@zero_alloc assume]) int_list float_of_int in
  assert (((=)[@zero_alloc assume]) l (stack_ [1.0;2.0;3.0;4.0;5.0]))

let () =
  iter_test ();
  map_test ()