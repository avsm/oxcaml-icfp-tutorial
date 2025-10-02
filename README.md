# A Guided Tour Through Oxidized Caml

This will be held at ICFP/SPLASH 2025, with inputs variously from Anil
Madhavapeddy, KC Sivaramkrishnan, Richard Eisenberg, Chris Casinghino, Gavin
Gray, Will Crichton, Shriram Krishnamurthi, Patrick Ferris.

URL: https://conf.researchr.org/track/icfp-splash-2025/icfp-splash-2025-tutorials
Status: WIP, unreleased

We have two 90 minute chunks, first at 1400-1530 and then 1600-1730.

# First Session

## Activity 1 (15m)

What: A pretest containing 4-5 OCaml programs in which we ask participants
questions about memory allocation, thread safety, etc.

Why: We propose this activity for two reasons:
- We want to understand the OCaml conceptual model participants have coming
  into the tutorial. For example, a “portable function” may not mean much to
  the participant that doesn’t have a proper conceptual model of thread safety.
- If we reuse the same code snippets in the slides portion, then participants
  are already familiar with the code and only need to focus on the OxCaml
  concepts. By forcing participants to wrestle with the code and concepts
  beforehand, they are more likely to engage with and better understand the
  material.

## Conceptual Model (60m)

- What: This is the slides portion of the tutorial where y’all get to teach the
  different concepts of OxCaml. This should leave participants with an
  understanding of: the difference between a mode and modality, past and future
  axes, what each axis does, etc.
- Why: This is our chance to provide the OxCaml conceptual model and provide
  answers to the pretest questions, allowing participants to self-correct their
  model.

## Activity 2 (15m)

- What: A collection of questions regarding the conceptual model of OxCaml.
- Why: We want to test participants on the conceptual model of OxCaml to see
  how effective the lecture portion of the tutorial was with an eye towards
  improving these materials for the future. We also want to see what concepts are
  difficult (e.g., do a majority of participants misunderstand modalities?).

# Break (30m)

# Second Session

## Hands-on Activity (60m)

What: We provide a set of OCaml programs and ask participants to translate them
to OxCaml. (e.g., x parameter should be local, now fix all the errors!) They
would do this in the online instance and we can gather telemetry data about the
state of their programs and the type errors they get.

Why: It’s one thing to learn about OxCaml, but it’s another to use it.
Participants should leave the tutorial with some degree of certainty that they
could use OxCaml in their own code. Participants will get the opportunity to
try it out "in the wild" and get their questions answered from experts (that
doesn’t happen often). We also get a sense of how the conceptual model, as
taught, translates to programmers code.  With telemetry data we can see where
people get stuck, as which errors they find particularly confusing. (We could
add a button to the online instance that says "this error message is unhelpful"
to see where people feel truly stuck).

*Why not do hands-on activities interspersed with the slides?*  Some participants
will just "get it" and the activities will be easy for them, for others, it
will be hard. If we did them interspersed we would have that awkward time when
we ask “who needs more time” and half the hands go up … some people are bored,
others are embarrassed that they're not done. Having time dedicated to hands-on
learning gives the slow participants the time they need to finish a problem and
get their questions answered. For the fast participants, we can have any number
of really difficult things for them to work on and they get even more
experience.

## Activity 3 (15m)

What: A posttest containing 4-5 OxCaml programs in which we ask participants
questions about mode annotations, error messages, unsafety, etc.

Why: The questions we ask will form the start of the "OxCaml Inventory," a set
of questions that target the core concepts of OxCaml and test the conceptual
model of the participants. This will give us a sense of where participants
still have difficulty and what future tools/educational material should target.
(Or maybe language changes?)