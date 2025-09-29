---
dimension: 16:9
theme: default
---

# Data-Race Free Parallel Programming with Oxidised OCaml

**A Conceptual Overview**

ICFP Tutorial

## The Promise and Peril of Parallelism

OCaml 5 unleashed parallel programming with a multicore-aware runtime and effects...

...but also unleashed chaos: race conditions, nondeterministic bugs, and hard-to-reason-about code.

## Oxidized Caml

**Guaranteed data-race freedom** through a sophisticated mode system

- Full parallel power
- Zero data races
- Compile-time verification

{pause up}

# Part 1: Understanding Data Races

{.definition title="What is a Data Race?"}
A race condition where two parallel accesses to the same memory location conflict.

## The Four Horsemen of Data Races

1. **Parallel execution** - Code running in different parallel domains
2. **Shared memory** - A location accessible by multiple domains
3. **At least one write** - One domain is modifying the data
4. **No synchronization** - The domains are not using `Atomic.t` or similar

{pause up}

## A Simple Example

```ocaml
type t = { mutable f : int }
let reference = ref 1
let record = { f = 2 }
let arr = [| 3; 4 |]
```

{pause}

Two domains running in parallel:

```ocaml
(* Domain A *)
let fun1 () =
  reference := 2;
  record.f <- 3;
  arr.(0) <- 4;
  print_int arr.(1)
```

{pause}

```
(* Domain B *)
let fun2 () =
  reference := 3;          (* Data race! write vs write *)
  print_int record.field;  (* Data race! read vs write *)
  arr.(0) <- arr.(0) + 1;  (* Two data races! *)
  print_int arr.(1)        (* OK: read vs read *)
```

{pause up}
## Why Data Races Are Catastrophic

### Example: A Gold Trading Disaster

```ocaml
let price_of_gold = ref 0.0
let initialised = ref false
```
Domain A (initialization):
```ocaml
price_of_gold := calculate_price_of_gold ();
initialised := true
```
Domain B (trading):
```ocaml
if !initialised then
  if !price_of_gold < really_good_price_for_gold then
    buy_lots_of_gold ()
```

{pause}

Without data-race freedom, the compiler or CPU can **reorder** operations! Domain A might set `initialised := true` **before** setting the price! As a result, we buy gold at price 0.0.

The potential reorderings existing for performance optimization by both the compiler and CPU. Sequential consistency is lost.

{pause center}

## Sequential Consistency

{.definition #seq-consistency title="Sequential Consistency"}
A program can be understood by considering all possible **interleavings**
(but not reorderings) of each domain's operations.

- Without data-race freedom, there is no sequential consistency.
- With data-race freedom, sequential consistency can be guaranteed.

Data-race freedom gives programmers the power to reason intuitively about our code, no matter how buggy it might get.

{pause up}

# Part 2: The Mode System Foundation

{.definition title="What are Modes?"}
Modes describe the *circumstances* of a value in an OxCaml program, and not its *shape*.

- **Types** describe what a value is.
- **Modes** describe what you can do with that value.

{pause}
## Example: Stack Allocation

```ocaml
let f () =
  let x @ local = [1; 2; 3] in  (* allocated on stack *)
  let y @ global = [4; 5; 6] in (* allocated on heap *)
  x, y  (* Error! Can't return local value *)
```

TODO: clarify the new @ syntax

{pause center}
<div style="border: 2px dashed #888; padding: 20px; margin: 20px; background: #f0f0f0;">
  [PLACEHOLDER DIAGRAM: Show stack frame with local allocation vs heap with global allocation]
</div>

## Modes for Parallelism

There are four key modes for expressing parallelism constraints.

{pause center}
The contention modes are `contended` ←→ `uncontended`

- `uncontended` says that *"I have exclusive access"*
- `contended` says that *"others might be accessing this in parallel"*

{pause center}
The portability modes are `portable` ←→ `nonportable`

- `portable` says that this is *"safe to access from any domain"*
- `nonportable` says this is *"only safe in the creating domain"*

{pause center}

{.remark title="Contention and portability work together"}
These two axes work together to prevent data races. <br>
Contention prevents parallel mutation, while portability prevents unsafe cross-domain accesses.

{pause up}
## Contention in Detail

{.theorem title="Rules of Contention"}
1) If multiple domains access a value, at most one sees it as `uncontended`
2) Cannot read/write mutable fields of `contended` records/arrays
3) `uncontended` values can be used as `contended` (subtyping)
4) Components of `contended` values are `contended` (deep)

{pause}

```ocaml
module Thing = struct
  type t = {
    price : float;          (* immutable field *)
    mutable mood : Mood.t   (* mutable field *)
  }

  let price (t @ contended) = t.price               (* OK: immutable field *)
  let mood (t @ contended) = t.mood                 (* ERROR: mutable field! *)
  let cheer_up (t @ uncontended) = t.mood <- Happy  (* OK: we have exclusive access *)
end
```

{pause}
{.remark}
Immutable fields are always safe to read, while mutable fields require exclusive access. This is enforced at compile time.

{pause up}
## The Portability Rules

{.theorem title="Rules of Portability"}
1. Only `portable` values can cross domain boundaries
2. A `portable` function can only access values defined inside itself as `uncontended`,  <br> or external values that are both `portable` and `contended`
3. `portable` values can be used as `nonportable` via subtyping
4. Components of `portable` values must themselves be `portable`

{pause}

```ocaml
let (factorial @ portable) n =
  let a @ uncontended = ref 1 in  (* created inside *)
  let rec (loop @ nonportable) i =
    if i > 1 then (
      a := !a * i;  (* OK: loop sees a from outside *)
      loop (i - 1)  (* but loop is nonportable *)
    )
  in loop n;
  !a
```

{pause center}
```ocaml
(* This would fail: *)
let (bad_factorial @ portable) n =
  let a = ref 1 in
  let rec (loop @ portable) i =  (* trying to be portable *)
    a := !a * i;  (* ERROR: a is contended here! *)
    loop (i - 1)
  in
  loop n
```

{pause}
{.remark}
The factorial example shows how portable functions can contain nonportable
helpers that access local state.<br>
The key is that the state doesn't escape the region in which it's defined.

{pause up}
## Mode Inference and Annotations

Where do we put all these new mode annotations?

{pause}
In `.mli` signature files:
```ocaml
val price : t @ contended -> float @@ portable
```

{pause}
In `.ml` implementations:
```ocaml
let rec (total @ portable) par tree = ...
```

{pause}
As global defaults at the start of a file:
```ocaml
@@ portable  (* at top of .mli *)
type t
val create : price:float -> mood:Mood.t -> t
val price : t @ contended -> float  (* no need for @@ portable *)
```

{.remark}
Mode inference works like normal OCaml type inference, but explicit annotations help
with error messages and documentation, and are highly recommended.

{pause up}
# Part 3: Fork/Join Parallelism

{.definition title="Fork/Join Pattern"}
Computation is split up into independent tasks that run in parallel, and the results are combined into one output.

{pause}
```ocaml
let add4 (par : Parallel.t) a b c d =
  let a_plus_b, c_plus_d =
    Parallel.fork_join2 par
      (fun _ -> a + b)  (* Task 1 *)
      (fun _ -> c + d)  (* Task 2 *)
  in
  a_plus_b + c_plus_d
```

{pause center}
<div style="border: 2px dashed #888; padding: 20px; margin: 20px; background: #f0f0f0;">
  [DIAGRAM: Show main thread forking into two parallel tasks, then joining]
</div>

{pause up}
## Tree Averaging: Sequential Version

```ocaml
type 'a t =
| Leaf of 'a
| Node of 'a t * 'a t  end

(* TODO avsm: we havent explained mutable_data kind yet *)
type thing : mutable_data = {
  price : float;
  mutable mood : Mood.t }
let price (t @ contended) = t.price
```

```ocaml
let average_seq tree =
  let rec total tree =
    match tree with
    | Leaf x -> ~total:(x.price), ~count:1
    | Node (l, r) ->
      let ~total:total_l, ~count:count_l = total l in
      let ~total:total_r, ~count:count_r = total r in
      ( ~total:(total_l +. total_r),
        ~count:(count_l + count_r) )
  in
  (* TODO avsm: not explained labeled tuples *)
  let ~total, ~count = total tree in
  total /. Float.of_int count
```
{pause up}
## Tree Averaging: Parallel Version

```ocaml
let average_par (par : Parallel.t) tree =
  let rec (total @ portable) par tree =
    match tree with
    | Leaf x -> x.price, 1
    | Node (l, r) ->
      let ( (total_l, count_l),
            (total_r, count_r) ) =
        Parallel.fork_join2 par
          (fun par -> total par l)  (* Process left subtree *)
          (fun par -> total par r)  (* Process right subtree *)
      in
      ( (total_l +. total_r),
        (count_l +  count_r) ) in
  let total, count = total par tree in
  total /. Float.of_int count
```

{pause}
- `total` must be `portable` to be used in `fork_join2`
- Tree elements become `contended` in parallel tasks
- `Thing.price` works because it accepts a `contended` argument
- A work-stealing scheduler handles load balancing; more on that next.

{pause up}
## Running with a Scheduler

This can all be automatically scheduled across available cores by
selecting a suitable scheduler:

```ocaml
let run_parallel ~f =
  let module Scheduler = Parallel_scheduler_work_stealing in
  let scheduler = Scheduler.create () in
  let monitor = Parallel.Monitor.create_root () in
  let result = Scheduler.schedule scheduler ~monitor ~f in
  Scheduler.stop scheduler;
  result

let () =
  let test_tree = build_tree 15 in  (* 32,768 leaves *)
  let result = run_parallel ~f:(fun par ->
    average_par par test_tree
  ) in
  Printf.printf "Average: %.2f\n%!" result
```

{pause}
TODO avsm: sort table styling

| Tree Size | Sequential | Parallel (8 cores) | Speedup |
|-----------|------------|-------------------|---------|
| 2^10 nodes | 0.002s | 0.001s | 2.0x |
| 2^15 nodes | 0.063s | 0.011s | 5.7x |
| 2^20 nodes | 2.1s | 0.31s | 6.8x |

Custom schedulers can be defined as first-class modules, but the
default heartbeat-based one is a hassle-free default.

{pause up}
## Mode Crossing and Kinds

{.definition title="Kinds"}
Types can have also have "kinds" that describe their properties and what modes they can cross.

| Kind | Requirements | Crosses |
|------|-------------|---------|
| `immutable_data` | No functions or mutable fields (deeply) | portability, contention |
| `mutable_data` | No functions (deeply) | portability |
| `value` (TODO avsm: the default?) | None | none |

```ocaml
type t : mutable_data = {  (* Explicitly declare kind *)
  price : float;
  mutable mood : Mood.t }  (* Now Thing.t crosses portability automatically *)

(* Generic function using kinds *)
let always_portable (x : ('a : mutable_data) @ nonportable) : 'a @ portable =
  let y @ portable = x in  (* OK: 'a crosses portability *)
  y
```

{.remark title="Use kinds to reduce manual type annotations"}
Kinds reduce annotation burden significantly.<br>Most data types are either
`immutable_data` or `mutable_data`, so they "just work" across domains.

{pause up}

# Part 4: Working with Mutable State

Fork/join works great for functional code, but what about imperative algorithms? OxCaml provides three components:
1. Use **atomics** for shared counters
2. Use **capsules** for deeply mutable structures
3. Use **parallel arrays** for array-based algorithms

{pause}
## Atomics

```ocaml
let average_with_atomics par tree =
  let total = Atomic.make 0.0 in
  let count = Atomic.make 0 in
  let rec go par tree =
    match tree with
    | Leaf x ->
       Atomic.update total ~pure_f:(fun t -> t +. x.price);
       Atomic.incr count
    | Node (l, r) ->
       let (), () = Parallel.fork_join2 par
         (fun par -> go par l)
         (fun par -> go par r)
       in ()
   in
   go par tree;
   Atomic.get total /. Float.of_int (Atomic.get count)
```

{pause center}
Note that `Atomic.t` crosses both portability and contention, and is safe to access from any domain.<br>
However, it's more expensive than regular operations and only prevents data races, not race conditions!

{pause up}
## Capsules

Now let's look at more complex mutable state management for deeply nested structures.

{.definition title="Capsules" #capsules}
Associate mutable state with locks, ensuring exclusive access. Capsules use the type system to track which values have access. An existential "password" proves that value hold the lock.

{pause #capsules}
```ocaml
(* 1. Encapsulated data *)
let capsule_ref : (int ref, 'k) Capsule.Data.t =
  Capsule.Data.create (fun () -> ref 0)

(* 2. Create capsule and get key *)
let (P key) = Capsule.create () in

(* 3. Create mutex from key *)
let mutex = Capsule.Mutex.create key in

(* 4. Access with lock *)
Capsule.Mutex.with_lock mutex ~f:(fun password ->
  Capsule.Data.iter capsule_ref ~password ~f:(fun r ->
    r := !r + 1
  ))
```
 
{pause center}
<div style="border: 2px dashed #888; padding: 20px; margin: 20px; background: #f0f0f0;">
  [DIAGRAM: Show capsule containing data, protected by mutex, accessed via password]
</div>

{pause}
Before we show an example of capsules, let's first also look at parallel slices. We will use both capsules and parallel slices to speed up a mutable sorting algorithm.

- A slice is a `local` view of a portion of an array.
- A slice _borrows_ a segment of the array, only allowing access to a contiguous subset of its indices.
- We can implement a standard sequential quicksort using slices:

{pause up}

First let's implement the partition phase:

```ocaml
module Slice = Parallel.Arrays.Array.Slice

let swap slice ~i ~j =
  let temp = Slice.get slice i in
  Slice.set slice i (Slice.get slice j);
  Slice.set slice j temp

let partition slice =
  let length = Slice.length slice in
  let pivot = Random.int length in
  swap slice ~i:pivot ~j:(length - 1);
  let pivot = Slice.get slice (length - 1) in
  let store = ref 0 in
  for i = 0 to length - 2 do
    if Slice.get slice i <= pivot
    then (
      swap slice ~i ~j:!store;
      Int.incr store)
  done;
  swap slice ~i:!store ~j:(length - 1);
  !store
```

{pause center}
Then we can use the slices to do an in-place **sequential** quicksort:

```ocaml
let rec quicksort slice =
  if Slice.length slice > 1
  then (
    let pivot = partition slice in
    let length = Slice.length slice in
    let left = Slice.sub slice ~i:0 ~j:pivot in
    let right = Slice.sub slice ~i:pivot ~j:length in
    quicksort left;
    quicksort right [@nontail])
```

{pause center}
Now let's turn this into a parallel quicksort. The `partition` function remains the same, but recursively sorting `left`
and `right` are independent tasks and could run in parallel.

```ocaml
module Par_array = Parallel.Arrays.Array

let rec quicksort parallel slice =
  if Slice.length slice > 1 then (
    let pivot = partition slice in
    let _ = Slice.fork_join2 parallel ~pivot slice
        (fun parallel left -> quicksort parallel left)
        (fun parallel right -> quicksort parallel right)
    in ())
```

Slices provide safe views into the mutable arrays. `fork_join2` splits the slice, ensuring each task only sees its portion.

{pause center}

Actually running this also requires a scheduler like before, which requires the uses of capsules to make sure the array we are passing is not itself mutated in parallel with the current `quicksort`:

```ocaml
let quicksort ~scheduler ~mutex array =
  let monitor = Parallel.Monitor.create_root () in
  Parallel_scheduler_work_stealing.schedule scheduler ~monitor ~f:(fun parallel ->
      Capsule.Mutex.with_lock mutex ~f:(fun password ->
        Capsule.Data.iter array ~password ~f:(fun array ->
          let array = Par_array.of_array array in
          quicksort parallel (Slice.slice array) [@nontail])
        [@nontail])
      [@nontail])
```

{pause up}
## The Shared Mode

We can now combine capsules and parallel arrays to run data parallel algorithms over *mutable* data. This requires introducing a new *shared mode*.

{.definition title="Shared Mode"}
A third contention mode between `contended` and `uncontended` that allows parallel reads but no writes.

```ocaml
type t : mutable_data   (* image data is mutable *)

val load : string -> t
val of_array : float array -> width:int -> height:int -> t

(* these take a contended image but as safe as they are 
   immutable properties (only the image contents change, not the dimensions) *)
val width : t @ contended -> int  
val height : t @ contended -> int

(* [set] requires exclusive access to the image *)
val set : t -> x:int -> y:int -> float -> unit
(* [get] can be shared among instances for parallel reads *)
val get : t @ shared -> x:int -> y:int -> float
```

{pause up}

```ocaml
let filter ~scheduler ~key image =
  let monitor = Parallel.Monitor.create_root () in
  Parallel_scheduler_work_stealing.schedule scheduler ~monitor ~f:(fun parallel ->
    let width = Image.width (Capsule.Data.project image) in
    let height = Image.height (Capsule.Data.project image) in
    let pixels = width * height in
    let data =
      Parallel_array.init parallel pixels ~f:(fun i ->
        let x = i % width in
        let y = i / width in
        Capsule.Key.access_shared key ~f:(fun access ->
          let image =
            Capsule.Data.unwrap_shared image ~access
          in
          blur_at image ~x ~y))
    in
    Parallel_array.to_array data
    |> Image.of_array ~width ~height)
```

{.remark}
Shared mode crucial for read-heavy parallel algorithms. Without it, mutexes would serialize all access.

{pause up}

## Common OxCaml Pitfalls and Solutions

TODO discuss.

{.example title="Forgetting Mode Annotations"}
```ocaml
(* Bad: missing annotations in .mli *)
val process : Thing.t -> float
(* Good: explicit about requirements *)
val process : Thing.t @ contended -> float @@ portable
```

{.example title="Over-synchronization"}
```ocaml
(* Bad: mutex for read-only access *)
Capsule.Mutex.with_lock mutex ~f:(fun password -> just_read_data password)
(* Good: use shared access *)
Capsule.Key.access_shared key ~f:(fun access -> just_read_data access)
```

{pause center}
{.example title="Fine-grained Parallelism"}
```ocaml
(* Bad: parallelize tiny operations *)
Parallel.fork_join2 par (fun _ -> x + 1) (fun _ -> y + 1)
(* Good: batch work *)
Parallel.fork_join2 par
  (fun par -> process_large_dataset1 par data1)
  (fun par -> process_large_dataset2 par data2)
```

The compiler catches safety issues, but performance requires thought.

## Migration Strategies from Sequential OCaml Code

1. Add kind annotations to types

```ocaml
type config : immutable_data = { ... }
type state : mutable_data = { ... }
```

2. Add `@@ portable` to .mli files
```ocaml
@@ portable
(* Now all functions default to portable *)
```
3. Fix mode errors
- Add `@ contended` to parameters that need it
- Convert mutable fields to immutable or Atomic.t
- Use capsules for complex mutable state

4. Add parallelism
- Replace recursive calls with fork_join
- Use Parallel.Sequence for collections
- Add schedulers and benchmarks


{pause up}

## Resources and Next Steps

TODO