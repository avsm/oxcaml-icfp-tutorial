# Zero Alloc Radix Sort

Let's implement a radix sort algorithm for integer lists in OCaml that does no
heap memory allocations. We'll use the `[@zero_alloc]` attribute to check that
our code does not allocate on the heap.

The file `radix_sort_referecence.ml` contains a standard implementation of radix
sort for reference.  The file `radix_sort.ml` is where you will implement your
zero-allocation version of the algorithm.
