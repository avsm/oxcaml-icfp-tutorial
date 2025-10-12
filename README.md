# A Guided Tour Through Oxidized Caml

This will be held at ICFP/SPLASH 2025, with inputs variously from Gavin Gray,
Anil Madhavapeddy, KC Sivaramkrishnan, Richard Eisenberg, Chris Casinghino,
Will Crichton, Shriram Krishnamurthi, Patrick Ferris.

URL: <https://conf.researchr.org/track/icfp-splash-2025/icfp-splash-2025-tutorials>

We have two 90 minute sessions that repeat, first at 1400-1530 and then
1600-1730.

# Getting started

Use the pre-built Docker Hub image.

1. Open this folder in VS Code
2. Click "Reopen in Container" when prompted
   - OR: `Cmd/Ctrl + Shift + P` → "Dev Containers: Reopen in Container"

The docker image has three switches installed

```bash
$ opam switch
#  switch      compiler                                          description
→  5.2.0+ox    ocaml-variants.5.2.0+ox                           5.2.0+ox
   5.3         ocaml-base-compiler.5.3.0                         5.3
   5.3.0+tsan  ocaml-option-tsan.1,ocaml-variants.5.3.0+options  5.3.0+tsan
```

# Session Outline

## Conceptual Model (60m)

- What: A slides introduction to OxCaml, these slides try to capture
  "the spirit" of the language rather than its exact implementation as
  that might change. This should leave participants with an
  understanding of: what is a  mode, locality, local allocation, contention,
  portability, and how these work together for data-race freedom.
- Why: This is our chance to provide the OxCaml conceptual model and provide
  answers to the pretest questions, allowing participants to self-correct their
  model.

## Activity (15m)

- What: A collection of questions regarding the conceptual model of OxCaml.
- Why: We want to test participants on the conceptual model of OxCaml to see
  how effective the lecture portion of the tutorial was with an eye towards
  improving these materials for the future.

# Second Session

The "conceptual model" slides will be run twice, however, we do have
a coding activity for those that really want write OxCaml
code. This activity may also be done asynchronously throughout the week
and ask us questions during the week.

## Hands-on Activity

What: We provide a set of OCaml programs and ask participants to translate them
to OxCaml with a specific goal in mind (e.g., *parallelize* the algorithm). We
provide a GitHub codespace so that participants do not need to set up OxCaml on
their local machine.

Why: It’s one thing to learn about OxCaml, but it’s another to use it.
Participants should leave the tutorial with some degree of certainty that they
could use OxCaml in their own code. Participants will get the opportunity to
try it out "in the wild" and get their questions answered from experts (that
doesn’t happen often). We also get a sense of how the conceptual model, as
taught, translates to programmers code. We can keep an eye on what problems
participants have, and if there's reoccurring difficulties that should
be better addressed in future material.

*Why not do hands-on activities interspersed with the slides?*  Some participants
will just "get it" and the activities will be easy for them, for others, it
will be hard. If we did them interspersed we would have that awkward time when
we ask “who needs more time” and half the hands go up … some people are bored,
others are embarrassed that they're not done. Having time dedicated to hands-on
learning gives the slow participants the time they need to finish a problem and
get their questions answered. For the fast participants, we can have any number
of really difficult things for them to work on and they get even more
experience.
