---
dimension: 16:9
theme: default
---

# Oxidized OCaml: *data-race freedom, systems programming, and more!*

**A Conceptual Overview**

ICFP Tutorial

## Oxidized Caml

- Fine-grained memory control
- Full parallel power of OCaml 5
- Zero data races
- Compile-time verification

{pause up}

## Types Provide Safety

```ocaml
"hello" + 42
 ^^^^^
Error: This expression has type  
 string 
but an expression was expected of type  
 int
```

OCaml 5 introduced parallelism ... and data races, nondeterministic bugs. Yay!

OxCaml provides finer-grained memory control, have you debugged a C++ segfault?

*OCaml types can't prevent all unsafe actions*

{pause}

Modes provide safety guarantees while using powerful, and dangerous, features

{pause up}

# A Conceptual Overview of Modes

{.definition title="What are Modes?"}
Modes assign properties to values

- **Types** describe what a value is
- **Modes** describe a property of the value

{pause}

Example properties

- A value is read only

- A value is stack allocated

{pause}

- A function can be called from any domain

{pause}

- A function won't yield

{pause}

A property may refine how a value can be used: *a stack-allocated value cannot escape its region*

{pause}

Modes provide safety and control over new OCaml features: parallelism, memory layout, etc

{pause up}

# Example 1: Safe stack allocation

```ocaml
type pixel = { r: int; g: int; b: int }

let new_pixel r g b = 
  let p = { r=r; g=g; b=b } in
  p
```

{pause}

Normally we can ignore memory and just rely on the GC

{pause}

## OxCaml provides facilities for controlling allocation

{pause}

```ocaml
type pixel = { r: int; g: int; b: int }

let new_pixel r g b = 
  let p @ local = { r=r; g=g; b=b } in
  p
```

{pause up}

Modes provide guardrails — so you don't pull a C++ and shoot yourself in the foot

```text
let new_pixel r g b = 
  let p @ local = { r=r; g=g; b=b } in
  p
  ^
Error: This value escapes its region.
```

{pause}

The `local` mode describes an allocation property: a value allocated on the stack, i.e., "locally." Typical OCaml values are allocated on the heap, i.e., "globally."

{pause}

Now, we can't forget about memory and rely on the GC, because **returning a stack allocated value would result in a dangling pointer!**

{pause}

```ocaml
let () = 
  let p = new_pixel 255 0 0 in
  print_int p.r (* Whoops! Bad memory access *)
```

{.remark title="Locality restriction"}
Local values cannot escape their region.

Use the `exclave_` annotation to allocate local return values on the *caller's stack*

```ocaml
type pixel = { r: int; g: int; b: int }

let new_pixel r g b = 
  exclave_ { r=r; g=g; b=b }

let () = 
  let p @ local = new_pixel 255 0 0 in
  print_int p.r
```

{pause center}
<div style="border: 2px dashed #888; padding: 20px; margin: 20px; background: #f0f0f0;">
  [PLACEHOLDER DIAGRAM: Show stack frame with local allocation vs heap with global allocation]
</div>

{pause up}

# Example 2: Safe parallelism

OCaml 5 unleashed parallel programming with a multicore-aware runtime and effects...

...but also unleashed chaos: race conditions, nondeterministic bugs, and hard-to-reason-about code.

{pause up}

## OCaml 5 introduced a new class of error: Data Races

```ocaml
let gensym = 
  let count = ref 0 in 
  fun () -> 
    count := !count + 1 ;
    Printf.sprintf "gsym_%d" !count

let gen_many par n = 
  Parallel.Arrays.Array.init par n (fun _ -> gensym ())
```

What could happen if `gen_many` is called with $n \geq 2$?

{pause}

```text
Domain 1                    Domain 2
--------                    --------
!count (0)                  
                            !count (0)
count := 0 + 1             
                            count := 0 + 1
!count (1)             
                            !count (1)
```

Resulting array: `[| "gsym_1"; "gsym_1" |]` Duplicate symbols? Unexpected!

{pause center}

We want to *statically prevent* `gensym` from running on parallel domains, just like we statically prevent adding a string to an int.

{pause up}

## Sequential Consistency

{.definition #seq-consistency title="Sequential Consistency"}
A program can be understood by considering all possible **interleavings**
(but not reorderings) of each domain's operations.

- Without data-race freedom, there is no sequential consistency.
- With data-race freedom, sequential consistency can be guaranteed.

Data-race freedom gives programmers the power to reason intuitively about our code, no matter how buggy it might get.

{pause up}

## Data races require 4 ingredients

1. **Parallel execution** - Code running in different parallel domains
2. **Shared memory** - A location accessible by multiple domains
3. **At least one write** - One domain is modifying the data
4. **No synchronization** - The domains are not using `Atomic.t` or similar

{pause}

```ocaml
let gensym = 
  let count = ref 0 in (* (2) shared memory *)
  (* (4)     ^^^^^^                  
         bare ref: no synchronization *)
  fun () -> 
    count := !count + 1 ; (* (3) a write *)
    Printf.sprintf "gsym_%d" !count

let gen_many par n = 
  (* (1) parallel execution, when n > 1 *)
  Parallel.Arrays.Array.init par n (fun _ -> gensym ())
```

{pause}

Removing any one of these ingredients results in race-free code.

Let's see how modes prevent us from having all 4

{pause up}

## Modes for Parallelism

There are four key modes for expressing parallelism constraints.

{pause}
The contention modes are: `uncontended < shared < contended`

- `uncontended`, *"I have exclusive access"*
- `shared`, *"other domains might be reading this"*
- `contended`, *"another domain can write to this"*

{pause}
The portability modes are `portable < nonportable`

- `portable`, *"safe to access from any domain"*
- `nonportable`, *"only safe in the creating domain"*

{pause up}

## Contention in Detail

{.theorem title="Rules of Contention"}
  1) If multiple domains access a value, at most one sees it as `uncontended`
  2) Cannot read/write mutable fields of `contended` records/arrays
  3) `uncontended` values can be used as `contended` (submoding)
  4) Components of `contended` values are `contended` (deep)

{pause up}

```ocaml
module User = struct
  type t : mutable_data = {
    id : Uuid.t;
    mutable last_active : float
  }

  let id (t @ contended) = t.id               
  (* OK: immutable field *)

  let last_active (t @ contended) = t.last_active                 
  (* ERROR: mutable field! *)

  let active_now (t @ uncontended) = t.last_active <- Unix.time ()  
  (* OK: we have exclusive access *)
end
```

{pause}

{.remark title="Contention restriction"}
Mutable fields of a contended value cannot be read or written

{.remark title="Shared restriction"}
Mutable fields of a shared value cannot be written

{pause up}

## The Portability Rules

{.theorem title="Rules of Portability"}
  1. Only `portable` values can cross domain boundaries
  2. A `portable` function can only access values defined inside itself as `uncontended`,  <br> or external values that are both `portable` and `contended`
  3. `portable` values can be used as `nonportable` via subtyping
  4. Components of `portable` values must themselves be `portable`

{pause}

```ocaml
let gensym @ portable = 
  let count = ref 0 in
  fun () -> 
    count := !count + 1 ;
    (* ERROR: ^^^^^ 
       access of contended mutable state *)
    Printf.sprintf "gsym_%d" !count

let gen_many par n = 
  Parallel.Arrays.Array.init par n (fun _ -> gensym ())
```

{pause center}

Because `count` is defined outside of the `gensym` function, it is *contended* and can't be read or written

{.remark title="Portability restriction"}
Portable functions cannot capture uncontended mutable state

{pause up}

```ocaml
let (factorial @ portable) n =
  let acc @ uncontended = ref 1 in
  let rec (loop @ nonportable) i =
    if i > 1 then (
      acc := !acc * i;  (* OK: `acc` is uncontended *)
      loop (i - 1)      (* and `loop` is nonportable *)
    )
  in loop n;
  !acc
```

{pause}

The factorial example shows how portable functions can contain nonportable
helpers that access local state.

The key is that the state doesn't escape the region in which it's defined, and the inner `loop` that captures the uncontended state isn't portable.

{pause up}

## Safely Working with Mutable State

Sometimes we actually need shared mutable state, OxCaml provides three components:

1. Use **atomics** for shared counters
2. Use **capsules** for deeply mutable structures
3. Use **parallel arrays** for array-based algorithms

{pause}

## Atomics

```ocaml
let gensym = 
  let count = Atomic.make 0 in 
  fun () -> 
    let n = Atomic.fetch_and_add count 1 in 
    Printf.sprintf "gsym_%d" n 
```

{pause center}

Note that `Atomic.t` crosses both portability and contention, and is safe to access from any domain.

However, it's more expensive than regular operations and only prevents data races, not race conditions!

{pause up}

## Capsules

Now let's look at more complex mutable state management for deeply nested structures.

{.definition title="Capsules" #capsules}
Associate mutable state with locks, ensuring exclusive access. Capsules use the type system to track which values have access. An existential "password" proves that value hold the lock.

{pause #capsules}

```ocaml
let gensym = 
  (* 1. Encapsulated data *)
  let counter = Capsule.Data.create (fun () -> ref 0) in
  (* 2. Create capsule and get key *)
  let (P key) = Capsule.create () in
  (* 3. Create mutex from key *)
  let mutex = Capsule.Mutex.create key in
  (* 4. Access with lock *)
  let increment () =
    Capsule.Mutex.with_lock mutex ~f:(fun password ->
      Capsule.Data.extract counter ~password ~f:(fun c ->
        c := !c + 1 ; !c))
  in
  fun () -> 
    Printf.sprintf "gsym_%d" (increment ())

```

{pause center}
<div style="border: 2px dashed #888; padding: 20px; margin: 20px; background: #f0f0f0;">
  [DIAGRAM: Show capsule containing data, protected by mutex, accessed via password]
</div>

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

## Fork/Join Parallelism

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

{pause}
Before we show an example of capsules, let's first also look at parallel slices. We will use both capsules and parallel slices to speed up a mutable sorting algorithm.

- A slice is a `local` view of a portion of an array.
- A slice *borrows* a segment of the array, only allowing access to a contiguous subset of its indices.
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

