+++
title = "How Small Can a Local GraphRAG Agent Go? An E2B-vs-E4B Sweep"
date = "2026-06-19"
categories = ["AI", "Engineering"]
tags = ["graphrag", "local-llm", "duckdb", "agents", "gemma", "benchmark", "evaluation", "go"]
type = "posts"
draft = false
+++

In the [last post](/posts/grounding-a-local-graphrag-agent/) I built a fully-local
GraphRAG agent — `cbi agent`, answering questions over a DuckDB knowledge graph
with a Gemma model running on an AMD Strix Halo chip — and then turned the
six-question hand-check into a repeatable harness (`cbi eval`) that scores answers
deterministically against a ground-truth key.

A harness invites the obvious question: **how small can the model be before the
whole thing falls apart?** Smaller means faster and cheaper, and on a local box
that's the difference between snappy and sluggish. So I ran the smallest two Gemma
4 tiers head to head over a real test set and graded every answer.

Short version: the jump from **E2B to E4B** — roughly 2.3B to 4.5B effective
parameters, both at `Q4_K_M` — more than doubles exact-match accuracy. But the
more interesting results are *where* the small model breaks, and the one place it
doesn't.

## The test set: 83 questions, generated from the graph itself

Six hand-written questions don't make a benchmark. So I generated a full set the
same way [MetaQA](https://github.com/yuyuz/MetaQA) was built from WikiMovies: by
templating over every relation in the knowledge base and pulling the gold answers
straight out of the database with SQL. The fixture is a small Pokémon graph (36
nodes, 66 edges) — small enough that I can verify every answer by hand, structured
enough to exercise real graph traversal.

That yields **83 questions**, each tagged by retrieval pattern and traversal
direction so the leaderboard can slice them:

| Pattern | Direction | Count | Example |
|---------|-----------|------:|---------|
| `evolve` / `region` / `types` / `owner` | forward (entity → attribute) | 59 | "What type is Charmander?" |
| `by_type` / `by_region` / `by_trainer` | reverse (attribute → entities) | 15 | "Which Pokémon are Fire type?" |
| `evo_line` | multi-hop | 5 | "Full evolution line from Bulbasaur?" |
| `count` | aggregation | 4 | "How many Pokémon are there?" |

Because the gold answers are *sets* of entities, scoring is deterministic and
needs no LLM judge: **recall** (did the answer cover the gold set), **exact**
(every gold item present — Hits@all), and **precision** (of the known entities the
answer named, how many were gold — this is what catches over-generation). A failure
that disclaims ("not found in the graph") is tallied as an *honest miss*,
separately from a confident wrong answer. The whole sweep is one command:

```
cbi eval --bundle okf-bundle --questions pokemon-qa.jsonl --vocab vocab.txt \
         --tier small --tier medium --by dir --out results.jsonl
```

Each tier loads once and answers all 83 in-process. Everything below is measured,
on-device, under Vulkan — no network in the loop.

## The headline

```
Overall exact-match accuracy (n=83)

  E2B  (~2.3B, Q4_K_M)   ████████████░░░░░░░░░░░░░░░░░░░░░░ 34.9%  (29/83)
  E4B  (~4.5B, Q4_K_M)   ████████████████████████████░░░░░░ 83.1%  (69/83)
```

Roughly double the parameters, roughly 2.4× the accuracy. E4B at 83% is a genuinely
useful local data-retrieval agent. E2B at 35% is not — *as a general answerer*. But
hold that thought, because where it fails turns out to matter as much as how often.

## Finding 1: the small model collapses on reverse traversal

Split the single-hop questions by direction — "what type is X" (walk the edge
forward, entity → attribute) versus "which Pokémon are Fire type" (walk it
backwards, attribute → entities) — and the gap explodes:

```
Forward vs reverse traversal (exact %)

  E2B
    forward  ██████████████░░░░░░░░░░░░░░░░░░░░ 40.7%  (24/59)
    reverse  ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  6.7%  (1/15)
  E4B
    forward  ████████████████████████████░░░░░░ 81.4%  (48/59)
    reverse  ███████████████████████████░░░░░░░ 80.0%  (12/15)
```

E4B is essentially **direction-agnostic** — 81% forward, 80% reverse. E2B falls off
a cliff: 41% forward to **7% reverse**, one correct answer out of fifteen.

Why is reverse harder? The edges are stored directed (`Pokémon —HAS_TYPE→ Type`).
"What type is Charmander" filters on the source and reads the target — natural.
"Which Pokémon are Fire type" has to filter on the *target* and gather all the
*sources*, which means the model must understand the edge direction, invert it, and
write a `GROUP BY`-shaped query. E4B does this reliably; E2B mostly can't form the
inverted query and gives up. (This echoes a finding from the first post's MetaQA
spot-check, where even E4B stumbled on a two-hop reverse — direction is the axis of
difficulty for graph QA, and model size buys robustness to it.)

## Finding 2: honest failure scales *down* with the model

Here's the result I didn't expect, and the one I care about most. Break all 83
outcomes into exact / honest-miss / partial / confident-wrong:

```
How failures break down (of all 83)

         exact  honest-miss  partial  wrong
  E2B    ████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒░░░
         exact=29  honest=39  partial= 7  wrong= 8
  E4B    ████████████████████████████▓▓▓▓░░
         exact=69  honest=10  partial= 0  wrong= 4
```

E2B fails **54 times** — but **39 of those are honest** "I couldn't find it in the
graph." Only 8 are confident-wrong. The honest share of failures is **72% for E2B
and 71% for E4B** — nearly identical. The small model is dramatically *less capable*
but barely *more deceptive*. The anti-hallucination guardrail from the first post —
"every fact must come from a tool result; if the tools don't return it, say so" —
holds just as well on the weaker model.

And the confident-wrong answers aren't fabrications either. Reading them, they're
evasions, not inventions:

> **Q:** What type is Charizard? **(gold: Fire, Flying)**
> **E2B:** "Charizard is a Pokemon. It has two types associated with it."
>
> **Q:** What type is Wartortle? **(gold: Water)**
> **E4B:** "Wartortle has the type(s) listed in the result of the last query."

Both models *found the right rows* and then failed to **name** them — a
competence/answer-surfacing failure, not a hallucinated roster. Nothing in this
entire run produced the kind of plausible-but-fabricated list (the eight-Eevee
problem) that started this whole investigation. That's the grounding work paying
off twice: it survived a brand-new domain *and* a much smaller model.

(An honest caveat about my own scoring: those evasive non-answers get bucketed as
"wrong" only because they name no gold entity *and* don't trip the disclaimer
keyword match. A keyword heuristic for "honest miss" is crude; a few of these are
really honest-ish. I'd rather report that than launder it.)

## Finding 3: which patterns are hard

```
Per-mode exact % (sorted by E4B)

  mode                     E2B                E4B
  by_region   ░░░░░░░░░░   0% (0/3)    ██████████ 100% (3/3)
  evo_line    ████░░░░░░  40% (2/5)    ██████████ 100% (5/5)
  count       █████░░░░░  50% (2/4)    ██████████ 100% (4/4)
  evolve      █████████░  90% (9/10)   ██████████ 100% (10/10)
  region      ██░░░░░░░░  25% (5/20)   ██████████ 100% (20/20)
  owner       ███░░░░░░░  33% (3/9)    █████████░  89% (8/9)
  by_type     █░░░░░░░░░  12% (1/8)    █████████░  88% (7/8)
  by_trainer  ░░░░░░░░░░   0% (0/4)    █████░░░░░  50% (2/4)
  types       ████░░░░░░  35% (7/20)   █████░░░░░  50% (10/20)
```

Two things jump out. First, **`evolve` is the easiest for both** (E2B 90%, E4B
100%) — it's a forward hop between two nodes of the *same* type, so there's no
direction confusion and no field-name ambiguity. It's the cleanest query in the set
and even the small model nails it.

Second, and more surprising: **`types` is the *hardest* mode for E4B** (50%), below
several reverse patterns. The reason isn't retrieval — it's that many Pokémon are
*dual-type* (Charizard is Fire **and** Flying), so exact-match demands the answer
name *both*, and E4B frequently retrieved the types but surfaced only one, or
described them without naming them (see the Wartortle evasion above). Single-answer
forward questions like `region` it gets 100%; the moment the gold set has two items,
its exact-match rate halves. That's a precision-of-*expression* problem, and it's
exactly the kind of thing you only see when you grade against a real key instead of
eyeballing.

## Finding 4: the speed you're buying

```
Accuracy vs speed (the trade)

  E2B: 34.9% exact |  8.5 s/question | 11.8 min for all 83
  E4B: 83.1% exact | 17.1 s/question | 23.6 min for all 83
```

E4B costs about **2× the wall-clock** for **2.4× the accuracy** — a good trade when
you care about answers. (The local provider under-reports generated tokens today,
so I'm using wall-clock as the cost signal, not token counts.) The one place E4B
gets genuinely expensive is multi-hop: those five evolution-line questions averaged
58 seconds and 7 tool-steps each, because the model walks the chain one query at a
time. If latency mattered more than completeness, that's the mode you'd special-case.

## So how small is too small?

For *general* graph QA on this hardware, **E4B is the floor** — 83% with honest
failures is a tool you can build on; 35% is not. But "too small" depends on the job:

- E2B aces **forward, single-hop, single-answer** questions ("what does X evolve
  into" — 90%) at half the latency. As a **fast triage tier** for simple lookups,
  it's viable — and crucially, when it *can't* answer it **fails safe** ~72% of the
  time rather than making something up.
- The moment you need **reverse traversal, multi-answer sets, or multi-hop**, you
  want E4B. The capability gap there isn't incremental, it's categorical.

None of which I could have said before building the harness. That's the whole
point: "how small can the model be" stops being a vibe and becomes a number you can
measure per-pattern, per-direction, per-domain — and re-measure the day a new model
or a new bundle lands. The agent, the test set, and the grader all run on the same
chip, offline, in about twenty minutes.

Next I want to point this at a real external benchmark —
[GraphRAG-Bench](https://github.com/GraphRAG-Bench/GraphRAG-Benchmark) — and see how
a tiny local agent stacks up against the framework-scale systems. More on that soon.

---

*Stack: `cbi` (Go) · DuckDB 1.5 (`vss`/`fts`/`duckpgq`) · kronk + llama.cpp (Vulkan,
b9664) · Gemma 4 E2B / E4B `Q4_K_M` · EmbeddingGemma-300M · fantasy · AMD Ryzen AI
MAX+ 395 / Radeon 8060S. 83 questions auto-generated from the graph, single run per
tier, deterministic set-based scoring.*
