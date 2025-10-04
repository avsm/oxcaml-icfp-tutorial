# Activity 1: OCaml Pretest - Understanding Parallelism Challenges (15 minutes)

## Instructions

This pretest explores your current understanding of OCaml's memory management, thread safety, and parallelism challenges. Please answer all questions to the best of your ability - there are no penalties for incorrect answers!

For each code snippet:
1. Read the code carefully
2. Answer the associated questions
3. Note any uncertainties you have

Keep your answers for comparison with Activity 2, where we'll see how OxCaml solves these issues.

TODO: KC is building a vastly simplified OCaml 5 version of Parallel.fork_join2 so we can use the same interfaces below.

---

## Problem 1: Data Races in Parallel Tree Processing

Consider this tree averaging implementation:

```ocaml
# module Tree = struct
    type 'a t =
      | Leaf of 'a
      | Node of 'a t * 'a t
  end;;
module Tree : sig type 'a t = Leaf of 'a | Node of 'a t * 'a t end

# module Thing = struct
    type t = {
      price : float;
      mutable mood : string
    }

    let create ~price ~mood = { price; mood }
    let price t = t.price
    let mood t = t.mood
    let cheer_up t = t.mood <- "Happy"
  end;;
module Thing :
  sig
    type t = { price : float; mutable mood : string; }
    val create : price:float -> mood:string -> t
    val price : t -> float
    val mood : t -> string
    val cheer_up : t -> unit
  end

# let average tree =
    let rec total tree =
      match tree with
      | Tree.Leaf x -> (Thing.price x, 1)
      | Tree.Node (l, r) ->
        let (total_l, count_l) = total l in
        let (total_r, count_r) = total r in
        (total_l +. total_r, count_l + count_r)
    in
    let (total, count) = total tree in
    total /. Float.of_int count;;
val average : Thing.t Tree.t -> float = <fun>

# (* Example usage *)
  let test_tree =
    Tree.Node (
      Tree.Leaf (Thing.create ~price:10.0 ~mood:"Happy"),
      Tree.Node (
        Tree.Leaf (Thing.create ~price:20.0 ~mood:"Sad"),
        Tree.Leaf (Thing.create ~price:30.0 ~mood:"Neutral")
      )
    );;
val test_tree : Thing.t Tree.t =
  Tree.Node (Tree.Leaf {Thing.price = 10.; mood = "Happy"},
   Tree.Node (Tree.Leaf {Thing.price = 20.; mood = "Sad"},
    Tree.Leaf {Thing.price = 30.; mood = "Neutral"}))

# average test_tree;;
- : float = 20.
```

Now imagine trying to parallelize this:

```ocaml
(* Pseudo-code - this won't compile in standard OCaml. TODO KC to add fork_join2 version. *)
let average_parallel tree =
  let rec total tree =
    match tree with
    | Tree.Leaf x -> (Thing.price x, 1)
    | Tree.Node (l, r) ->
      (* PARALLEL: compute these simultaneously *)
      let (total_l, count_l) = Domain.spawn (fun () -> total l) in
      let (total_r, count_r) = Domain.spawn (fun () -> total r) in
      let (tl, cl) = Domain.join total_l in
      let (tr, cr) = Domain.join total_r in
      (tl +. tr, cl + cr)
  in
  total tree
```
```mdx-error
Line 8, characters 34-66:
Error: This expression has type (float * int) Domain.t
       but an expression was expected of type 'a * 'b
```

### Questions:

1. **Data Race Risk**: If multiple domains access the same `Thing.t` value and one calls `cheer_up`, what could go wrong?

2. **Function Passing**: Why can't we safely pass the `total` function to `Domain.spawn` in standard OCaml?

3. **Memory Sharing**: What prevents safe sharing of the tree structure between domains?

4. **Compiler Help**: What compile-time guarantees would you want to prevent data races?

---

## Problem 2: Mutable State and Race Conditions

```ocaml
# let partition arr low high =
    let pivot = arr.(high) in
    let i = ref (low - 1) in
    for j = low to high - 1 do
      if arr.(j) < pivot then begin
        Int.incr i;
        let temp = arr.(!i) in
        arr.(!i) <- arr.(j);
        arr.(j) <- temp
      end
    done;
    let temp = arr.(!i + 1) in
    arr.(!i + 1) <- arr.(high);
    arr.(high) <- temp;
    !i + 1;;
val partition : int array -> int -> int -> int = <fun>

# let rec quicksort arr low high =
    if low < high then begin
      let pi = partition arr low high in
      quicksort arr low (pi - 1);
      quicksort arr (pi + 1) high
    end;;
val quicksort : int array -> int -> int -> unit = <fun>

# (* Example usage *)
  let arr = [| 3; 1; 4; 1; 5; 9; 2; 6; 5 |];;
val arr : int array = [|3; 1; 4; 1; 5; 9; 2; 6; 5|]

# quicksort arr 0 (Array.length arr - 1);;
- : unit = ()

# arr;;
- : int array = [|1; 1; 2; 3; 4; 5; 5; 6; 9|]
```

Attempting to parallelize the recursive calls:

```ocaml
(* Pseudo-code - problematic parallel version *)
let rec quicksort_parallel arr low high =
  if low < high then begin
    let pi = partition arr low high in
    (* DANGER: Both domains mutate the same array! *)
    let t1 = Domain.spawn (fun () -> quicksort_parallel arr low (pi - 1)) in
    let t2 = Domain.spawn (fun () -> quicksort_parallel arr (pi + 1) high) in
    Domain.join t1;
    Domain.join t2
  end
```

### Questions:

1. **Array Safety**: Even though the two recursive calls work on different parts of the array, why is this still potentially unsafe?

2. **Compiler Verification**: What would need to be tracked at compile-time to ensure the two domains don't overlap their array accesses?

3. **Alternative Approach**: How would you need to restructure this to be safe for parallelism?

---

## Problem 3: Shared Counters and Atomics

```ocaml
# let counter = ref 0;;
val counter : int ref = {Base.Ref.contents = 0}

# let increment n =
    for i = 1 to n do
      counter := !counter + 1
    done;;
val increment : int -> unit = <fun>

# (* This would have race conditions if run in parallel: *)
  let parallel_increment () =
    let d1 = Domain.spawn (fun () -> increment 1000) in
    let d2 = Domain.spawn (fun () -> increment 1000) in
    Domain.join d1;
    Domain.join d2;
    !counter;;
val parallel_increment : unit -> int = <fun>
```

Attempted fix with a lock:

```ocaml
# let mutex = Stdlib.Mutex.create ();;
val mutex : Mutex.t = <abstr>

# let safe_counter = ref 0;;
val safe_counter : int ref = {Base.Ref.contents = 0}

# let increment_with_lock n =
    for i = 1 to n do
      Stdlib.Mutex.lock mutex;
      safe_counter := !safe_counter + 1;
      Stdlib.Mutex.unlock mutex
    done;;
val increment_with_lock : int -> unit = <fun>
```

### Questions:

1. **Race Condition**: In the first version, what values might `parallel_increment ()` return and why?

2. **Lock Overhead**: What's the performance problem with the mutex version?

3. **Better Solution**: OCaml 5 has `Atomic.t`. How does this help? What would you still need to be careful about?

4. **Compile-time Safety**: What if the compiler could prove there were no data races without needing locks or atomics?

---

## Problem 4: Function Portability and Closures

```ocaml
# let make_accumulator init =
    let sum = ref init in
    fun x ->
      sum := !sum + x;
      !sum;;
val make_accumulator : int -> int -> int = <fun>

# let acc1 = make_accumulator 0;;
val acc1 : int -> int = <fun>

# let acc2 = make_accumulator 100;;
val acc2 : int -> int = <fun>

# (* Sequential usage example *)
  List.map ~f:acc1 [1; 2; 3];;
- : int list = [1; 3; 6]

# (* The parallel version would have race conditions: *)
  let parallel_accumulate () =
    let d1 = Domain.spawn (fun () ->
      List.map ~f:acc1 [1; 2; 3]
    ) in
    let d2 = Domain.spawn (fun () ->
      List.map ~f:acc1 [4; 5; 6]  (* Same accumulator! *)
    ) in
    (Domain.join d1, Domain.join d2);;
val parallel_accumulate : unit -> int list * int list = <fun>
```

### Questions:

1. **Closure Problem**: What does `acc1` capture that makes it unsafe for parallel use?

2. **Domain Boundaries**: Why can't we safely pass `acc1` between domains?

3. **Pure Alternative**: How would you rewrite `make_accumulator` to be safe for parallel use?

4. **Compiler Tracking**: What would the compiler need to track about functions to know if they're safe to pass between domains?

---

## Problem 5: Parallel Sequences and Reductions

```ocaml
# (* Sequential sum *)
  let sum_array arr =
    Array.fold arr ~init:0 ~f:(+);;
val sum_array : int array -> int = <fun>

# (* Example *)
  sum_array [| 1; 2; 3; 4; 5 |];;
- : int = 15

# (* Naive parallel attempt *)
  let sum_array_parallel arr =
    let mid = Array.length arr / 2 in
    let arr1 = Array.sub arr ~pos:0 ~len:mid in
    let arr2 = Array.sub arr ~pos:mid ~len:(Array.length arr - mid) in

    let t1 = Domain.spawn (fun () -> sum_array arr1) in
    let t2 = Domain.spawn (fun () -> sum_array arr2) in

    Domain.join t1 + Domain.join t2;;
val sum_array_parallel : int array -> int = <fun>

# sum_array_parallel [| 1; 2; 3; 4; 5; 6; 7; 8 |];;
- : int = 36
```

### Questions:

1. **Memory Overhead**: What's inefficient about creating `arr1` and `arr2`?

2. **Shared Access**: If we could share the original array safely between domains (read-only), how would that help?

3. **Granularity**: For small arrays, parallelism hurts performance. How should this be handled?

4. **Abstraction**: What higher-level parallel operations would you want (like parallel map/reduce)?

---

## Problem 6: Read-Only Sharing

```ocaml
# type image = {
    width : int;
    height : int;
    pixels : float array;  (* Grayscale values *)
  };;
type image = { width : int; height : int; pixels : float array; }

# let blur image =
    let result = Array.copy image.pixels in
    (* Blur operation reads from image.pixels, writes to result *)
    for i = 0 to Array.length result - 1 do
      (* Simplified: just copy for demonstration *)
      (* In real blur: read neighboring pixels from image.pixels *)
      (* Write blurred value to result.(i) *)
      result.(i) <- image.pixels.(i)
    done;
    { image with pixels = result };;
val blur : image -> image = <fun>

# (* Example *)
  let img = { width = 2; height = 2; pixels = [| 1.0; 2.0; 3.0; 4.0 |] };;
val img : image = {width = 2; height = 2; pixels = [|1.; 2.; 3.; 4.|]}

# let blurred = blur img;;
val blurred : image = {width = 2; height = 2; pixels = [|1.; 2.; 3.; 4.|]}
```

### Questions:

1. **Read Sharing**: Why is it safe for multiple domains to read `image.pixels` simultaneously?

2. **Write Protection**: How could the compiler ensure no domain accidentally writes to the shared data?

3. **Current Limitations**: Why can't standard OCaml express "read-only shared access"?

---

## Reflection Questions

After completing the problems above:

1. **Main Challenges**: What are the three biggest obstacles to safe parallelism in OCaml?

2. **Compiler Role**: What kinds of compile-time checking would help most?

3. **Runtime vs Compile-time**: Which safety guarantees should be compile-time vs runtime?

4. **Mental Model**: What concepts are you most uncertain about regarding parallel OCaml?

---

## Key Takeaways

Write down:
- Three things that make parallel programming difficult in standard OCaml
- Three compile-time guarantees you wish you had
- Three questions you hope will be answered in the OxCaml section

---

*Note: Save your answers! In Activity 2, we'll revisit these exact problems and see how OxCaml's mode system provides compile-time solutions to prevent these issues.*
