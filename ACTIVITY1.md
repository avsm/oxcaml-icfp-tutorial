# Activity 1: OCaml Pretest - Understanding Parallelism Challenges (15 minutes)

## Instructions

This pretest explores your current understanding of OCaml's memory management, thread safety, and parallelism challenges. Please answer all questions to the best of your ability - there are no penalties for incorrect answers!

For each code snippet:
1. Read the code carefully
2. Answer the associated questions
3. Note any uncertainties you have

Keep your answers for comparison with Activity 2, where we'll see how OxCaml solves these issues.

---

## Problem 1: Data Races in Parallel Tree Processing

Consider this tree averaging implementation:

```ocaml
(* Run this code in act1/tree_average.ml *)
module Tree = struct
  type 'a t =
    | Leaf of 'a
    | Node of 'a t * 'a t
end

module Thing = struct
  type t = {
    price : float;
    mutable mood : string
  }

  let create ~price ~mood = { price; mood }
  let price t = t.price
  let mood t = t.mood
  let cheer_up t = t.mood <- "Happy"
end

let average tree =
  let rec total tree =
    match tree with
    | Tree.Leaf x -> (Thing.price x, 1)
    | Tree.Node (l, r) ->
      let (total_l, count_l) = total l in
      let (total_r, count_r) = total r in
      (total_l +. total_r, count_l + count_r)
  in
  let (total, count) = total tree in
  total /. float_of_int count
```

Now imagine trying to parallelize this:

```ocaml
(* Pseudo-code - this won't compile in standard OCaml *)
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

### Questions:

1. **Data Race Risk**: If multiple domains access the same `Thing.t` value and one calls `cheer_up`, what could go wrong?

2. **Function Passing**: Why can't we safely pass the `total` function to `Domain.spawn` in standard OCaml?

3. **Memory Sharing**: What prevents safe sharing of the tree structure between domains?

4. **Compiler Help**: What compile-time guarantees would you want to prevent data races?

---

## Problem 2: Mutable State and Race Conditions

```ocaml
(* Run this in act1/quicksort.ml *)
let partition arr low high =
  let pivot = arr.(high) in
  let i = ref (low - 1) in
  for j = low to high - 1 do
    if arr.(j) < pivot then begin
      incr i;
      let temp = arr.(!i) in
      arr.(!i) <- arr.(j);
      arr.(j) <- temp
    end
  done;
  let temp = arr.(!i + 1) in
  arr.(!i + 1) <- arr.(high);
  arr.(high) <- temp;
  !i + 1

let rec quicksort arr low high =
  if low < high then begin
    let pi = partition arr low high in
    quicksort arr low (pi - 1);
    quicksort arr (pi + 1) high
  end
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
let counter = ref 0

let increment n =
  for i = 1 to n do
    counter := !counter + 1
  done

let parallel_increment () =
  let d1 = Domain.spawn (fun () -> increment 1000) in
  let d2 = Domain.spawn (fun () -> increment 1000) in
  Domain.join d1;
  Domain.join d2;
  !counter
```

Attempted fix with a lock:

```ocaml
let mutex = Mutex.create ()
let safe_counter = ref 0

let increment_with_lock n =
  for i = 1 to n do
    Mutex.lock mutex;
    safe_counter := !safe_counter + 1;
    Mutex.unlock mutex
  done
```

### Questions:

1. **Race Condition**: In the first version, what values might `parallel_increment ()` return and why?

2. **Lock Overhead**: What's the performance problem with the mutex version?

3. **Better Solution**: OCaml 5 has `Atomic.t`. How does this help? What would you still need to be careful about?

4. **Compile-time Safety**: What if the compiler could prove there were no data races without needing locks or atomics?

---

## Problem 4: Function Portability and Closures

```ocaml
let make_accumulator init =
  let sum = ref init in
  fun x ->
    sum := !sum + x;
    !sum

let acc1 = make_accumulator 0
let acc2 = make_accumulator 100

(* Try to use in parallel *)
let parallel_accumulate () =
  let d1 = Domain.spawn (fun () ->
    List.map acc1 [1; 2; 3]
  ) in
  let d2 = Domain.spawn (fun () ->
    List.map acc1 [4; 5; 6]  (* Same accumulator! *)
  ) in
  (Domain.join d1, Domain.join d2)
```

### Questions:

1. **Closure Problem**: What does `acc1` capture that makes it unsafe for parallel use?

2. **Domain Boundaries**: Why can't we safely pass `acc1` between domains?

3. **Pure Alternative**: How would you rewrite `make_accumulator` to be safe for parallel use?

4. **Compiler Tracking**: What would the compiler need to track about functions to know if they're safe to pass between domains?

---

## Problem 5: Parallel Sequences and Reductions

```ocaml
(* Sequential sum *)
let sum_array arr =
  Array.fold_left (+) 0 arr

(* Naive parallel attempt *)
let sum_array_parallel arr =
  let mid = Array.length arr / 2 in
  let arr1 = Array.sub arr 0 mid in
  let arr2 = Array.sub arr mid (Array.length arr - mid) in

  let t1 = Domain.spawn (fun () -> sum_array arr1) in
  let t2 = Domain.spawn (fun () -> sum_array arr2) in

  Domain.join t1 + Domain.join t2
```

### Questions:

1. **Memory Overhead**: What's inefficient about creating `arr1` and `arr2`?

2. **Shared Access**: If we could share the original array safely between domains (read-only), how would that help?

3. **Granularity**: For small arrays, parallelism hurts performance. How should this be handled?

4. **Abstraction**: What higher-level parallel operations would you want (like parallel map/reduce)?

---

## Problem 6: Read-Only Sharing

```ocaml
type image = {
  width : int;
  height : int;
  pixels : float array;  (* Grayscale values *)
}

let blur image =
  let result = Array.copy image.pixels in
  (* Blur operation reads from image.pixels, writes to result *)
  for i = 0 to Array.length result - 1 do
    (* Read neighboring pixels from image.pixels *)
    (* Write blurred value to result.(i) *)
    ()
  done;
  { image with pixels = result }

(* Parallel blur - each domain processes part of the image *)
let blur_parallel image =
  (* How to safely share image.pixels for reading? *)
  (* Multiple domains need to read the same data *)
  (* But no domain should modify it *)
  ...
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
