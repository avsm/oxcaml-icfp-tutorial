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

{pause center}

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

