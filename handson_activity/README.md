# Hands-on Activities

Each activity is contained in its own folder. Each folder contains a `dune` file
and a `README.md` file with instructions. `dune build` within each directory
will build the activity.

## Activity dependencies

We suggest the following (soft) dependencies for the activities:

```mermaid
graph LR
    act01[Activity 01: Data Races and TSAN] --> act02[Activity 02: Gensym Atomics]
    act02 --> act03[Activity 03: Gensym Capsules]
    act03 --> act04[Activity 04: Quicksort]
    act05[Activity 05: Zero Alloc Local Lists] --> act06[Activity 06: Zero Alloc Merge Sort]
    act06 --> ac07[Activity 07:  Zero Alloc Radix Sort]
```
