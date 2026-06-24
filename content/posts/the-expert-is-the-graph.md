+++
title = "The Expert Is the Graph: A 4-Bit Local Model Out-Answered Frontier Claude on Its Own Data"
date = "2026-06-23"
categories = ["AI", "Engineering"]
tags = ["graphrag", "local-llm", "duckdb", "agents", "gemma", "claude", "benchmark", "evaluation", "okf", "go"]
type = "posts"
draft = false
+++

For the last couple of weeks I've been building `okb`, a small, domain-agnostic
knowledge bundle producing tool. It ingests data into a DuckDB knowledge graph, exports it
as a portable, `cat`-readable [open knowledge format](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) bundle packaged as a Claude compatible 'skill'. Also ships a chat agent that
answers questions about the bundle powered by [kronk](https://www.kronkai.com/). All running **fully local**, on a single AMD chip on
my desk. No API keys, no cloud, no embedding server.

I started with a narrow question: *how small can a local model be and still answer
graph questions usefully?* I ended somewhere I didn't expect, a fully self-contained system for bundling domain knowledge into portable 'skills' that works well enough that a local 12B model can perform on-par with a frontier model on retrieval tasks.

This is the story of how I got to those numbers, and why I think they point at a
genuinely different way to package domain knowledge for AI: not by fine-tuning a
model, but by building a small, inspectable, **model-agnostic** graph that any
agent can pick up and answer from. The expensive, scarce thing — a frontier model —
turns out not to be the bottleneck. The graph is. And graphs, you can build.

## The system, in one breath

`okb` keeps a deliberately boring data model — typed **nodes** (entities with
properties and an embedding) and typed, directed **edges** — in one DuckDB file.
Four DuckDB extensions turn that file into a hybrid search engine: `vss` for vector
similarity, `fts` for BM25 lexical search, `spatial` for geometry, and `duckpgq`
for property-graph traversal (`MATCH`, `GRAPH_TABLE`). Search fuses the lexical and
semantic channels with Reciprocal Rank Fusion, with graph queries on top.

The payoff artifact is what I call an **OKF bundle**: a directory holding a
`SKILL.md` that explains the domain, one markdown concept doc per entity (with
relationships rendered as cross-links you can follow by eye), and the database
itself. It's human-readable, agent-readable, and precisely queryable at the same
time. Hand that one directory to anything that can read files and run SQL, and it
knows your domain. **That bundle is the product.**

The local agent (`okb agent --bundle ./some-bundle`) answers over it using
**Gemma 4** for generation and **EmbeddingGemma-300M** for retrieval, both running
under Vulkan on an AMD Ryzen AI MAX+ 395 ("Strix Halo"). It answers *only* by
calling tools — `schema`, read-only `sql_query`, `hybrid_search`, and doc browsing —
never from memory. That last constraint turned out to be load-bearing, and it's the
first thing the benchmarks taught me.

## Lesson 1: grounding is a feature you design in

The first time I graded the agent — against a hand-built Pokémon graph, six
questions, answers pulled straight from the DB — it got 3 of 6. The worst failure
wasn't a wrong answer; it was a *convincing* one. Asked for Eevee's evolutions,
where the graph holds exactly three, it returned all eight real-world Eeveelutions.
The moment its SQL errored out, it quietly answered from training data instead. The
first three were right, which is exactly what made it dangerous.

The fix wasn't a smarter model. It was a hard rule in the system prompt — *every
fact must come from a tool result in this conversation; if the tools don't return
it, say you couldn't find it* — plus making the schema honest (surfacing per-type
property keys and edge directions, because the model had been guessing field names
and inverting relationships). That took it to 5 of 6, with the sixth failing
*honestly*: "I couldn't find it in the graph."

For a retrieval agent, an honest "I don't know" is a categorically better failure
than a confident fabrication. You can build on the former. That single design
choice — engineered honesty — is what makes everything downstream trustworthy, and
it's what lets a *small* model be useful: when it can't do something, it declines
instead of inventing.

## Lesson 2: capability is real, and measurable per-pattern

How small can the model go? I auto-generated 83 Pokémon questions (templated over
every relation, gold answers straight from SQL) and ran the two smallest Gemma
tiers head to head, scored deterministically — recall, exact-match, and precision
(which catches over-generation with no LLM judge in the loop).

```
Overall exact-match accuracy (n=83)

  E2B  (~2.3B, Q4_K_M)   ████████████░░░░░░░░░░░░░░░░░░░░░ 34.9%  (29/83)
  E4B  (~4.5B, Q4_K_M)   ████████████████████████████░░░░░ 83.1%  (69/83)
```

Double the parameters, ~2.4× the accuracy. But the *shape* of the gap was the
useful part. The small model collapses on **reverse traversal** ("which Pokémon are
Fire type" — filter the target, gather the sources, invert the edge) at 7%, while
E4B is direction-agnostic at 80%. And the result I keep coming back to: **honest
failure scales *down* with the model.** E2B fails far more often, but ~72% of its
failures are honest "not found" — virtually the same honest share as E4B's. The
small model is dramatically less capable but barely more deceptive. The grounding
holds even when the model is weak.

So model size buys *capability* — harder query shapes, multi-answer completeness —
but not *integrity*. That you get from design. Hold onto that distinction; it's
about to do real work.

## Lesson 3: a real corpus, judged locally

Pokémon is a toy. To test against something external I pointed the system at
[GraphRAG-Bench](https://github.com/GraphRAG-Bench/GraphRAG-Benchmark)'s **medical**
track — a ~1 MB prose corpus with graded questions in four styles (Fact Retrieval,
Complex Reasoning, Contextual Summarize, Creative Generation), normally scored by a
`gpt-4o-mini` judge.

`okb` ingests structured graphs, so I needed an extraction pass to turn prose into a
graph. As a first cut I had a local Qwen-35B read the corpus in chunks and emit
entities + relations — a throwaway script, one pass, no cleanup. Then I ran the
*entire* evaluation loop locally: answering with Gemma, and **judging with the same
local Qwen** (GraphRAG-Bench's eval speaks OpenAI, so I pointed `base_url` at
localhost). Nothing left the box.

Two findings stacked up. First, a dull but critical bug: the agent was loading at
llama.cpp's default 8k context, and long tool loops overflowed it into blank
answers — Gemma 4 supports 128k, so I loaded it there and the blanks vanished.
Second, coverage and capability are coupled: scaling the graph made the *small* E4B
model slightly worse (it drowned in the extra density), while the same dense graph
in front of **Gemma 12B** turned that density into signal and climbed to **0.520**
overall answer-correctness, led by Complex Reasoning at 0.590.

For context, the published GraphRAG-Bench medical systems (GPT-4o-mini as both
generator and judge) sit in roughly the **0.54–0.68** band. A 4-bit local 12B with
a naïve one-pass graph, judged by a *different* model, landing at **0.52** was
closer than I expected — and it set up the real question.

## The pivot: same graph, frontier brain

The OKF bundle is a portable skill. So what happens if I hand it not to local Gemma,
but to a *frontier* model?

I spun up **Claude Sonnet** subagents, gave each the same medical bundle, and let
them answer the same 32-question sample using the bundle's *generic* toolkit — the
`duckdb` CLI, `okb query`, the markdown docs — under the same "ground every fact,
no outside knowledge" rule. Then I scored them with the **same local judge** that
graded the local agent. Apples to apples on everything except the brain doing the
reading.

```
Answer-correctness, same graph, same judge (n=32)

  question type          local 12B    Sonnet      Δ
  Fact Retrieval            0.404       0.429    +0.025  Sonnet
  Complex Reasoning         0.590       0.453    −0.137  12B
  Contextual Summarize      0.565       0.517    −0.048  12B
  Creative Generation       0.520       0.563    +0.043  Sonnet
  ──────────────────────────────────────────────────────────
  OVERALL                   0.520       0.491    −0.029  ~tie
```

**The frontier model did not win.** A model orders of magnitude larger, reading the
exact same graph, scored *0.491 — a statistical tie with, and nominally below, a
4-bit 12B running on my desk.* Sonnet is a far better reasoner and writer, and you
can see exactly where that buys something — it edges ahead on Fact Retrieval and
Creative Generation. But it cannot retrieve facts that *aren't in the graph*. Asked
for adrenocortical-carcinoma symptoms, where the gold answer lists fifteen and the
graph held two, Sonnet navigated harder and hit the same wall. Pheochromocytoma had
no node at all — and no amount of intelligence reads a node that doesn't exist.

That's the thesis in one table: **the expertise is in the graph, not the model
reading it.** Which means the bottleneck — and the place all the leverage lives — is
*extraction*. So I went and built a real one.

## The payoff: build a better graph, and the small model pulls ahead

The throwaway Qwen script left obvious damage in the graph: duplicate entities
(`hodgkin_lymphoma`, `_2`, `_3`), a sprawling ~150-relation vocabulary with
inconsistent directions, missing nodes, and facts attached at the wrong
granularity. So I built a proper extraction pipeline *inside* `okb`, fully local and
in-process — a local 12B running five stages with no external server:

1. **Bootstrap an ontology** — propose a compact, closed set of entity types and
   directional relations from a sample of the corpus (then let me edit it).
2. **Extract** — per chunk, emit entities + relations as structured JSON
   (constrained decoding for valid JSON; the closed vocabulary enforced in code).
3. **Glean** — a recall pass that re-reads each chunk for what the first pass missed.
4. **Resolve** — embed every entity and merge duplicates into canonical nodes.
5. **Normalize** — collapse the relation vocabulary to one canonical direction.

Then I re-ran the *exact same* 32-question benchmark. The first full run **regressed
hard** — 0.405, well below the old Qwen graph's 0.520. That failure turned out to be
the most instructive part of the whole project.

The culprit was entity resolution doing its job too aggressively. My first clustering
pass used single-linkage: if A is similar to B and B to C, all three merge. On a
medical corpus that chains catastrophically — `cancer` ~ `breast cancer` ~
`adenocarcinoma` ~ … — and **120+ distinct cancers collapsed into one
`disease:cancer` node** carrying 349 aliases. Fact Retrieval cratered from 0.404 to
0.285. Over-merging destroys a graph as thoroughly as under-merging does; you just
can't see it in the node count.

The fix was **representative-based (leader) clustering**: a candidate joins a
cluster only if it's similar to that cluster's *representative*, not merely to some
member — which kills the transitive chaining — with an LLM adjudicator settling the
genuinely ambiguous pairs. The 349-alias hub broke back apart into 81 distinct
cancer subtypes. And the score didn't just recover, it took the lead:

```
GraphRAG-Bench medical, same 32 questions, same local judge

  graph + answerer                       overall   Fact Retrieval
  v1: Qwen-35B one-pass + local 12B     ░░░ 0.520   0.404
  Sonnet over the v1 bundle             ░░░ 0.491   0.429
  okb extract (over-merged) + 12B       ░░  0.405   0.285   ← the regression
  okb extract (leader-clustering) + 12B ███ 0.581   0.452   ← fixed
```

**0.581 overall** — beating both the 35B-built graph (0.520) and frontier Sonnet
(0.491), with Fact Retrieval — the most extraction-bound metric — recovering to
**0.452**, ahead of Sonnet's 0.429. Same small local answerer throughout. The only
thing that changed was the quality of the graph it was reading.

That's the thesis, confirmed and then flipped: a better graph didn't just close the
gap to the frontier model, it lifted a 4-bit local model *past* it. **Entity
resolution turned out to be the single highest-leverage knob in the system** — and
it's a data-engineering problem, not a model problem.

## What this is good for: micro-scale domain experts

Put the lessons together — grounding is design, capability is measurable, and the
graph is the expert — and a build pattern falls out. A **micro-scale domain expert**
is a single OKF bundle for one bounded domain: your product's data, an internal
runbook corpus, a regulatory standard, a research literature, a customer's catalog.
It is:

- **Self-contained.** One directory — markdown you can read, a database you can
  query, a `SKILL.md` that explains both. Nothing to deploy to *use* it.
- **Portable across brains.** The same bundle works under a 4-bit local model (for
  privacy, cost, or air-gapped use) *and* a frontier model (for the hardest
  reasoning or the best prose), because the interface is "read files, run SQL,"
  which everything speaks. You pick the model per job; you're not locked in.
- **Inspectable.** When it's wrong, you `cat` the concept doc or run the SQL and see
  *why*. The failure is a missing edge, not an inscrutable weight.
- **Cheap to make, and the cost is in the right place.** The benchmarks say the
  model is interchangeable, so you don't spend there. You spend on **extraction
  quality** — the right entities, resolved and de-duplicated, with a clean relation
  vocabulary. That's the lever, and it's measurable: the same harness that found the
  over-merge regression in minutes is the one that proved the fix.

This is a different shape from "fine-tune a model on your domain" (expensive,
opaque, frozen, hallucination-prone) and from "stuff everything into a context
window" (no structure, no traversal, re-paid every query). A micro-expert is a
durable, queryable, versioned artifact — you build a fleet of them, one per domain,
and route whatever agent you like at whichever one it needs.

The system that started as "can a tiny model answer graph questions on my laptop"
turned into something more interesting: a way to manufacture portable, honest,
model-agnostic domain experts where the intelligence you're buying lives in the data
you curate, not the model you run. A 4-bit model on my desk beating frontier Claude
on the same benchmark isn't a knock on Claude. It's the best news in the project — it
means the expensive, scarce thing isn't the bottleneck. The graph is. And graphs,
you can build.

---

*Stack: `okb` (Go) · DuckDB 1.5 (`vss`/`fts`/`spatial`/`duckpgq`) · kronk +
llama.cpp (Vulkan) · answerers: Gemma 4 E2B/E4B/12B `Q4_K_M` (local) and Claude
Sonnet (over the OKF bundle) · in-process extraction + local judge: Qwen3.6-35B /
Gemma 4 12B · EmbeddingGemma-300M / BGE-small embeddings · GraphRAG-Bench medical
corpus, 32-question stratified sample, same local judge across every answerer ·
AMD Ryzen AI MAX+ 395 / Radeon 8060S.*
