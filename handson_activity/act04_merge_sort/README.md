# Zero Allocation Merge Sort

Let's implement a merge sort algorithm for integer lists in OCaml that does no
heap memory allocations. We'll use the `[@zero_alloc]` attribute to check that
our code does not allocate on the heap.

The file `merge_sort_referecence.ml` contains a standard implementation of merge
sort for reference. The file `merge_sort.ml` is where you will implement your
zero-allocation version of merge sort. The file `merge_sort_solution.ml`
contains a possible solution.

[OxCaml Stack Allocation](https://oxcaml.org/documentation/stack-allocation/intro/) will be an
invaluable resource for this activity.

## Hints

* If you want to show that a particular function does not allow a local argument
  to escape, and you know that the function is applied only to an `int`
  argument, adding an explicit type annotation (e.g., `fun (x:int) -> ...`) can
  help the type checker.
* The standard library functions such as `List.iter` may not have the right mode
  annotations to show that they do not allow a local argument to escape. You can
  always write your own version of these functions with the right mode
  annotations.
* `exclave_` is your friend. Our solution uses `exclave_` to allocate in the caller
  stack frame.