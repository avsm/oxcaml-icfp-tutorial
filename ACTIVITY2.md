# Activity 2: OxCaml Solutions to Parallel Programming Challenges (15 minutes)

## Instructions

Now that you've learned about OxCaml's mode system, let's revisit the problems
from Activity 1 and see how OxCaml solves them. We'll use the same code
examples but with OxCaml's compile-time guarantees.

Compare your answers from Activity 1 with the solutions OxCaml provides!

---

## Problem 1 solved: Data-Race-Free Parallel Tree Processing

Remember the tree averaging problem? Here's how OxCaml makes it safe:

```ocaml
# module Tree = struct
    type 'a t =
      | Leaf of 'a
      | Node of 'a t * 'a t
  end;;
module Tree : sig type 'a t = Leaf of 'a | Node of 'a t * 'a t end

# module Thing = struct
    module Mood = struct
      type t =
        | Happy
        | Neutral
        | Sad
    end

    type t : mutable_data = {
      price : float;
      mutable mood : Mood.t
    }

    let create ~price ~mood = { price; mood }
    let price (t @ contended) = t.price  (* Safe: price is immutable *)
    let _mood t = t.mood  (* Requires uncontended access *)
    let _cheer_up t = t.mood <- Happy
    let _bum_out t = t.mood <- Sad
  end;;
module Thing :
  sig
    module Mood : sig type t = Happy | Neutral | Sad end
    type t = { price : float; mutable mood : Mood.t; }
    val create : price:float -> mood:Mood.t -> t
    val price : t @ contended -> float
    val _mood : t -> Mood.t
    val _cheer_up : t -> unit
    val _bum_out : t -> unit
  end

# let average_par (par : Parallel.t) tree =
    let rec (total @ portable) par tree =
      match tree with
      | Tree.Leaf x -> ~total:(Thing.price x), ~count:1
      | Tree.Node (l, r) ->
        let ( (~total:total_l, ~count:count_l),
              (~total:total_r, ~count:count_r) ) =
          Parallel.fork_join2 par
            (fun par -> total par l)
            (fun par -> total par r)
        in
        ( ~total:(total_l +. total_r),
          ~count:(count_l + count_r) )
    in
    let ~total, ~count = total par tree in
    total /. Float.of_int count;;
val average_par : Parallel_kernel.t -> Thing.t Tree.t -> float = <fun>
```

### What OxCaml Provides:

1. **`@ contended` mode**: The compiler knows `Thing.price` can be safely read even when the value might be accessed by multiple domains
2. **`@ portable` functions**: Only portable functions can be passed to `fork_join2`, ensuring no data races
3. **Compile-time checking**: If `cheer_up` was called on a contended value, compilation would fail!

#### The Four Elements of Data Race Prevention

Remember from Activity 1 - a data race needs four things:
1. **Code running in parallel** (different domains)
2. **Same memory location** accessed by multiple domains
3. **At least one write** to that location
4. **Not atomic** operations

OxCaml's modes eliminate these systematically:

**Rule 1 (Contention)**: If two or more domains may access the same value, at most one may consider it `uncontended`. Others must consider it `contended`.

**Rule 2 (Mutable Access)**: Reading or modifying a `mutable` field requires `uncontended` access. Can't touch mutable data when `contended`!

This means: *If it compiles, no data race is possible.* The compiler enforces **sequential consistency** - you can reason about your parallel code by considering all possible sequential interleavings.

### Try This:
```
TODO
# This compiles and runs safely!
$ dune exec act2/tree_average_parallel.exe
```

---

## Problem 2 solved: Safe Parallel Quicksort

Remember the unsafe array mutations? OxCaml provides **slices**:

```ocaml
# module Capsule = Basement.Capsule;;
module Capsule = Basement.Capsule

# module Par_array = Parallel.Arrays.Array;;
module Par_array = Parallel.Arrays.Array

# module Slice = Parallel.Arrays.Array.Slice;;
module Slice = Parallel.Arrays.Array.Slice

# let swap slice ~i ~j =
    let temp = Slice.get slice i in
    Slice.set slice i (Slice.get slice j);
    Slice.set slice j temp;;
val swap : ('a : value mod contended). 'a Slice.t -> i:int -> j:int -> unit =
  <fun>

# let partition slice =
    let length = Slice.length slice in
    let pivot_index = Random.int length in
    swap slice ~i:pivot_index ~j:(length - 1);
    let pivot = Slice.get slice (length - 1) in
    let store_index = ref 0 in
    for i = 0 to length - 2 do
      if Slice.get slice i <= pivot then begin
        swap slice ~i ~j:!store_index;
        Int.incr store_index
      end
    done;
    swap slice ~i:!store_index ~j:(length - 1);
    !store_index;;
val partition : int Slice.t -> int = <fun>

# let rec quicksort_seq slice =
    if Slice.length slice > 1 then begin
      let pivot = partition slice in
      let length = Slice.length slice in
      let left = Slice.sub slice ~i:0 ~j:pivot in
      let right = Slice.sub slice ~i:pivot ~j:length in
      quicksort_seq left;
      quicksort_seq right [@nontail]
    end;;
Line 7, characters 21-25:
Error: This value escapes its region.

# let rec quicksort_par parallel slice =
    if Slice.length slice <= 1000 then
      (* Use sequential for small arrays *)
      quicksort_seq slice
    else begin
      let pivot = partition slice in
      let (), () =
        Slice.fork_join2
          parallel
          ~pivot
          slice
          (fun parallel left -> quicksort_par parallel left)
          (fun parallel right -> quicksort_par parallel right)
      in
      ()
    end;;
Line 4, characters 7-20:
Error: Unbound value quicksort_seq
Hint: Did you mean quicksort_par?
```

### What OxCaml Provides:

1. **Slices are `local`**: They can't escape their scope, preventing aliasing bugs
2. **`Slice.fork_join2`**: Splits array into non-overlapping parts, each `uncontended`
3. **Compile-time safety**: Impossible to access overlapping regions

### The Capsule Wrapper:
```ocaml
# let sort_capsule ~scheduler ~mutex array =
    let monitor = Parallel.Monitor.create_root () in
    Parallel_scheduler_work_stealing.schedule scheduler ~monitor ~f:(fun parallel ->
      Capsule.Mutex.with_lock mutex ~f:(fun password ->
        Capsule.Data.iter array ~password ~f:(fun array ->
          let array = Par_array.of_array array in
          quicksort_par parallel (Slice.slice array) [@nontail]
        ) [@nontail]
      ) [@nontail]
    );;
Line 3, characters 5-46:
Error: Unbound module Parallel_scheduler_work_stealing
```

**Capsules** protect the array, ensuring exclusive access during sorting.

---

## Problem 3 solved: Safe Shared Counters

Remember the race condition with counters? OxCaml offers two solutions:

### Solution 1: Atomics (mode-crossing)
```ocaml
# module Atomic = Portable.Atomic;;
Line 1, characters 17-32:
Error: Unbound module Portable
Hint: Did you mean Floatable or Intable?

# let add_many_par_atomic par arr =
    let total = Atomic.make 0 in
    let seq = Parallel.Sequence.of_iarray arr in
    Parallel.Sequence.iter par seq ~f:(fun x ->
      Atomic.update total ~pure_f:(fun t -> t + x)
    );
    Atomic.get total;;
Line 2, characters 17-28:
Alert deprecated: module Base.Atomic
[2016-09] this element comes from the stdlib distributed with OCaml.
Use [Atomic] from [Portable] (or [Core], which reexports it from
[Portable]) instead.

Line 5, characters 7-20:
Alert deprecated: module Base.Atomic
[2016-09] this element comes from the stdlib distributed with OCaml.
Use [Atomic] from [Portable] (or [Core], which reexports it from
[Portable]) instead.

Line 5, characters 7-20:
Error: Unbound value Atomic.update
```

### Solution 2: Capsules (explicit synchronization)
```ocaml
# let concurrent_counter () =
    let (P key) = Capsule.create () in
    let mutex = Capsule.Mutex.create key in
    let counter = Capsule.Data.create (fun () -> ref 0) in

    let increment () =
      Capsule.Mutex.with_lock mutex ~f:(fun password ->
        Capsule.Data.iter counter ~password ~f:(fun r ->
          r := !r + 1
        )
      )
    in
    increment;;
val concurrent_counter : unit -> unit -> unit = <fun>
```

### What OxCaml Provides:

1. **Mode crossing**: `Atomic.t` is always uncontended and portable
2. **Capsule passwords**: Can't access data without proper synchronization
3. **Compile-time enforcement**: Forgot to lock? Won't compile!

#### Why Atomics Work: Mode Crossing

Atomic references mode cross both contention and portability, meaning they are
always uncontended and always portable, regardless of the kind of the `['a]`
type parameter.


This is why `Atomic.t` solves the parallelism problem:
- **Always `uncontended`**: Multiple domains can access atomically without data races
- **Always `portable`**: Can be safely passed between domains
- **Type system enforced**: The compiler guarantees these properties

#### Capsules: Explicit Synchronization

When atomics aren't enough (complex operations, multiple values), capsules provide explicit locking:

1. Capsule.create () -> unique key
2. Capsule.Mutex.create key -> shareable mutex (consumes key)
3. Capsule.Data.create -> protected data
4. Capsule.Mutex.with_lock -> get password for exclusive access

---

## Problem 4 solved: Portable Functions

Remember the accumulator that captured mutable state? OxCaml prevents this:

```ocaml
# let make_bad_accumulator init =
    let sum = ref init in
    fun x ->
      sum := !sum + x;
      !sum;;
val make_bad_accumulator : int -> int -> int = <fun>

# let make_good_accumulator init =
    let sum = Atomic.make init in
    fun x ->
      Atomic.fetch_and_add sum x;;
Line 2, characters 15-26:
Alert deprecated: module Base.Atomic
[2016-09] this element comes from the stdlib distributed with OCaml.
Use [Atomic] from [Portable] (or [Core], which reexports it from
[Portable]) instead.

Line 4, characters 7-27:
Alert deprecated: module Base.Atomic
[2016-09] this element comes from the stdlib distributed with OCaml.
Use [Atomic] from [Portable] (or [Core], which reexports it from
[Portable]) instead.

val make_good_accumulator : int -> int -> int = <fun>

# let make_pure_accumulator init =
    fun x -> init + x;;
val make_pure_accumulator : int -> int -> int = <fun>
```

### What OxCaml Provides:

1. **Rule: Portable functions see external values as `contended`**
2. **Can't mutate contended refs**: Compile error if you try!
3. **Atomics cross modes**: Safe for concurrent use

#### The Portable Rules

There are four key rules for `portable`:

**Rule 1 (Safety)**: Only a `portable` value is safe to access from outside the domain that created it.

**Rule 2 (Closure)**: If a `portable` function refers to a value outside its definition, then (a) that value must be `portable`, and (b) the value is considered `contended` inside the function.

**Rule 3 (Subtyping)**: A `portable` value may be used as though it is `nonportable`.

**Rule 4 (Deep)**: Every component of a `portable` value must be `portable`.

This is why `make_bad_accumulator` fails:
```ocaml
# let make_bad_accumulator init =
    let sum = ref init in    (* sum is not portable! *)
    fun x ->                 (* Can't capture non-portable values *)
      sum := !sum + x;       (* Also: can't mutate contended refs *)
      !sum;;
val make_bad_accumulator : int -> int -> int = <fun>
```

The compiler prevents this at multiple levels!

---

## Problem 5 solved: Parallel Sequences

Remember the inefficient array copying? OxCaml provides high-level operations:

```ocaml
# let add_many_par par arr =
    let seq = Parallel.Sequence.of_iarray arr in
    Parallel.Sequence.reduce par seq ~f:(fun a b -> a + b)
    |> Option.value ~default:0;;
val add_many_par : Parallel_kernel.t -> int iarray @ portable -> int = <fun>
```

### What OxCaml Provides:

1. **Immutable arrays (`iarray`)**: Safe to share between domains
2. **`Parallel.Sequence`**: High-level operations with automatic chunking
3. **Granularity control**: Library handles when to go sequential

#### Why `iarray` Works

Immutable arrays have the `immutable_data` kind, which provides **mode crossing**:
- **Crosses portability**: Can be passed between domains safely
- **Crosses contention**: Multiple domains can access without `uncontended` requirement

From the mode crossing table:
```
| Kind           | Constraint                    | Crosses  |
| immutable_data | no functions or mutable fields, deeply | portability, contention |
```

This means `iarray` can be shared read-only between multiple domains with zero copying!

---

## Problem 6 solved: Read-Only Sharing with `shared` Mode

Remember the image blur problem? OxCaml has the `shared` mode:

```ocaml
(* Module signature for Image with shared access *)
module type Image_sig = sig
  type t : mutable_data
  val get : t @ shared -> x:int -> y:int -> float
  val set : t -> x:int -> y:int -> float -> unit
end
```

### What OxCaml Provides:

1. **`shared` mode**: Between `contended` and `uncontended`
2. **Read-only parallel access**: Multiple domains can read
3. **Compile-time enforcement**: Can't write to shared values

### The Mode Hierarchy:
```
uncontended (exclusive) -> shared (read-only) -> contended (no access)
```

#### Understanding `shared` Mode

The `shared` mode is the solution to a key problem: what if multiple domains need to **read** the same mutable data structure?

- **`uncontended`**: Only one domain can access (exclusive)
- **`contended`**: Can't access mutable fields at all
- **`shared`**: Multiple domains can read, but none can write

This is achieved through **aliased capsule keys**:
```ocaml
# let (P key) = Capsule.create () in      (* unique key *)
    (* let key = Capsule.Key.share key in  (* now aliased -> shared access *) *)
    ();;
- : unit = ()
```

When a capsule key is aliased, accessing the capsule provides `shared` rather than `uncontended` access to the data.

---

## Comparison Table: OCaml vs OxCaml

| Problem | Standard OCaml | OxCaml Solution |
|---------|---------------|-----------------|
| Data races | Runtime crashes | Compile-time prevention |
| Function passing | Unsafe between domains | `@ portable` requirement |
| Mutable fields | Always accessible | Requires `uncontended` |
| Array parallelism | Manual splitting | Slices with `fork_join` |
| Shared counters | Mutex or Atomic | Modes + Capsules/Atomics |
| Read-only sharing | Not expressible | `@ shared` mode |

---

## Key Concepts Test

### Question 1: Modes
What's the difference between these?
```ocaml
val f1 : Thing.t -> int;;
val f2 : Thing.t @ contended -> int;;
val f3 : Thing.t -> int @@ portable;;
```
```mdx-error
Line 1, characters 1-24:
Error: Value declarations are only allowed in signatures
Line 1, characters 3-38:
Error: Value declarations are only allowed in signatures
Line 1, characters 3-38:
Error: Value declarations are only allowed in signatures
```

### Question 2: Why This Fails
Why won't this compile?
```ocaml
# let bad_parallel par =
    let data = ref 0 in
    Parallel.fork_join2 par
      (fun _ -> data := 1)
      (fun _ -> data := 2);;
Line 4, characters 17-21:
Error: This value is contended but expected to be uncontended.
```

**Answer**: This fails on multiple levels:
1. **Rule 2 of portable**: The function captures `data` from outside, but `ref` is not portable
2. **Rule 2 of contended**: Even if it could capture `data`, it would be `contended` inside the function, and you can't mutate contended refs

The compiler enforces data-race freedom by making this impossible to express!

### Question 3: Capsule Purpose
What problem do capsules solve that atomics don't?

**Answer**: Capsules solve several problems:
1. **Complex operations**: Atomics only work for simple operations (increment, set, etc.). Capsules can protect arbitrary complex operations under a single lock.
2. **Multiple values**: Atomics protect single values. Capsules can protect entire data structures with multiple related values.
3. **Shared mode**: Capsules enable `shared` mode for read-only parallel access to mutable data. Atomics don't provide this.
4. **Explicit locking**: Sometimes you need explicit control over when locks are acquired/released.

### Question 4: Mode Crossing
Why can `float * float` be freely shared between domains but `float array` cannot?

**Answer**:
- `float * float` has `immutable_data` kind - no mutable fields, so it crosses both portability and contention
- `float array` has `mutable_data` kind - has mutable elements, so it only crosses portability, not contention

From the mode crossing table:
| Kind           | Constraint              | Crosses              |
| immutable_data | no mutable fields       | portability, contention |
| mutable_data   | no functions            | portability only     |

`array` elements can be mutated, so multiple domains accessing it could cause data races without `uncontended` access.

---

## Reflection

Compare with your Activity 1 answers:

1. **Solved Problems**: Which parallelism challenges does OxCaml completely eliminate?

2. **Remaining Challenges**: What aspects of parallel programming still require careful thought?

3. **Mental Model Update**: How has your understanding of safe parallelism changed?

4. **Practical Impact**: Which OxCaml feature would most help your current projects?

---

## Try It Yourself!

Run the examples:
```
# Sequential baseline
$ dune exec act1/tree_average.exe
$ dune exec act1/quicksort.exe

# Parallel with OxCaml safety
$ dune exec act2/tree_average_parallel.exe
$ dune exec act2/quicksort_parallel.exe
$ dune exec act2/array_sum_parallel.exe
```

Experiment:
1. Try breaking the safety rules - see the compiler errors!
2. Measure speedup on different tree depths
3. Compare atomic vs capsule performance

---

## Summary: The Complete Picture

### Mode System Rules (Reference)

#### Contention Rules:
1. **Parallel access**: At most one domain may consider a value `uncontended`
2. **Mutable access**: Mutable fields require `uncontended` access
3. **Subtyping**: `uncontended` can be used as `contended`
4. **Deep**: Components of `contended` values are `contended`

#### Portability Rules:
1. **Domain safety**: Only `portable` values cross domain boundaries
2. **Closure**: `portable` functions see external values as `contended`
3. **Subtyping**: `portable` can be used as `nonportable`
4. **Deep**: Components of `portable` values must be `portable`

### Mode Crossing (The Secret Sauce)

Types with appropriate **kinds** can ignore certain mode requirements:

```ocaml
# type immutable_pair : immutable_data = float * float;;
type immutable_pair = float * float

# type mutable_record : mutable_data = { mutable x: int };;
type mutable_record = { mutable x : int; }
```

### The Safety Guarantee

Every parallel program that compiles is **sequentially consistent**. You can
reason about it by considering all possible sequential interleavings of domain
actions. No "impossible" states due to data races.

Data-race freedom gives us back the power to reason intuitively about our code,
no matter how buggy it might get.

---

*Key Insight: OxCaml doesn't just catch bugs - it makes entire classes of parallel programming errors impossible through compile-time checking. If it compiles, it's data-race free!*
