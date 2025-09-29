---
dimension: 16:9
theme: default
---

# Oxidized OCaml: *data-race freedom, systems programming, and more!*

**A Conceptual Overview**

ICFP Tutorial

## The Promise and Peril of Parallelism

OCaml 5 unleashed parallel programming with a multicore-aware runtime and effects...

...but also unleashed chaos: race conditions, nondeterministic bugs, and hard-to-reason-about code.

## Oxidized Caml

- Fine-grained memory control
- Full parallel power
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

but what about data races? Dangling pointers?

{pause}

Modes allow us to express richer programs while maintaining safety

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
  Printf.printf "Read: %d\n" p.r (* Whoops! Bad memory access *)
```

{.remark title="Locality restriction"}
Local values cannot escape their region.

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

### Data races require 4 ingredients

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

  3) `uncontended` values can be used as `contended` (subtyping)

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

## Using shared memory safely

OxCaml provides mechanism for synchronization when shared memory is necessary

- **Atomics:** for single values

- **Capsules:** for multiple values, or complex operations

{pause}

```ocaml
let (gensym @ portable) =
  let count = Atomic.make 0 in
  fun () ->
    let n = Atomic.fetch_and_add count 1 in
    Printf.sprintf "gsym_%d" n

let gen_many par n = 
  Parallel.Arrays.Array.init par n (fun _ -> gensym ())
```

{pause up}

# Anil's Slides

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

{speaker-note}
Note the use of labeled tuples, a new OCaml 5.4 feature. The sequential version
is straightforward recursive traversal.
{speaker-note}
