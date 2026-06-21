+++
title = "The Expert Is the Graph: A Local GraphRAG Toolkit for Micro-Scale Domain Experts"
date = "2026-06-21"
categories = ["AI", "Engineering"]
tags = ["graphrag", "local-llm", "duckdb", "agents", "gemma", "claude", "benchmark", "evaluation", "okf", "go"]
type = "posts"
draft = false
+++

This is the post I've been building toward across three earlier ones. It pulls the
whole system together — the toolkit, the agent, the benchmarks — and ends on the
experiment that reframed the entire project for me: I handed the *same* knowledge
graph to a tiny local model and to a frontier model (Claude Sonnet), graded both
with the same judge, and **the frontier model didn't win**.

That result is the thesis. When you put a domain behind a good retrieval layer,
the expertise lives in the *graph*, not the model reading it. Which means you can
build something I've started calling a **micro-scale domain expert**: a small,
portable, inspectable knowledge artifact that any agent — a 4-bit model on your
laptop or a frontier model in the cloud — can pick up and answer from. This post
is about the toolkit that makes those, and the evidence that the cheap part (the
model) is interchangeable while the valuable part (the graph) is where the work
goes.

If you want the prior detail: [post 1](/posts/grounding-a-local-graphrag-agent/)
grounded the agent against hallucination, [post 2](/posts/how-small-can-a-local-graphrag-agent-go/)
swept model sizes, and [post 3](/posts/local-graphrag-on-graphrag-bench/) ran an
external benchmark fully locally. This one is self-contained.

## What the system is

`cbi` is a small, domain-agnostic GraphRAG CLI in Go. The whole idea is that *all*
domain knowledge lives in data + a YAML config, and the tooling is generic. You
point it at a domain, and out the other end comes a self-contained knowledge
artifact plus an agent that can answer questions about it — with nothing leaving
your machine.

The data model is deliberately boring: **nodes** (typed entities with properties,
an embedding, optional geometry, and SCD-Type-2 temporal versioning) and **edges**
(typed, directed, weighted, also temporal). One DuckDB file holds all of it, and
four extensions turn that one file into a hybrid search engine:

| Extension | Role |
|-----------|------|
| `vss` | vector similarity (HNSW index over embeddings) |
| `fts` | full-text / BM25 lexical search |
| `spatial` | geometry + distance |
| `duckpgq` | property-graph queries (`MATCH`, `GRAPH_TABLE`) |

Search is the three channels fused: BM25 (lexical) + cosine (semantic) combined
with Reciprocal Rank Fusion, with graph traversal on top. It's a lot of capability
for one `cat`-able file and no services.

### The tools the toolkit gives you

The CLI is the surface. Each command does one job in the pipeline from raw data to
a queryable, shareable expert:

| Command | What it does |
|---------|--------------|
| `cbi init` | create the DuckDB graph, load extensions, build schema + indexes + property graph |
| `cbi ingest` | batch-load nodes/edges (NDJSON or JSON), embed, temporal-stamp |
| `cbi query` | hybrid search (vector + lexical + RRF), optional temporal filter |
| `cbi graph` | raw SQL / SQL-PGQ over the property graph |
| `cbi schema` | LLM-friendly schema readout (types, counts, property keys, edge directions) |
| `cbi generate` | a self-contained static site bundle (with a D3 graph viewer) for object-storage hosting |
| `cbi generate okf` | an **OKF bundle**: markdown concept docs + the database, as a portable knowledge artifact |
| `cbi generate okf --skill --include-db` | the same, packaged as a self-contained **agent skill** (`SKILL.md` + `.duckdb` + config) |
| `cbi agent` | a fully-local chat agent (or one-shot `--ask`) over a bundle |
| `cbi answer` | batch-answer a question set, emitting answers + retrieved context as JSON |
| `cbi eval` | score an agent's answers against a known-answer key, deterministically |

The keystone is **`cbi generate okf`**. An [Open Knowledge
Format](https://github.com/GoogleCloudPlatform/knowledge-catalog) bundle is just a
directory: a `SKILL.md` that explains the domain and how to query it, one markdown
concept document per entity (with relationships rendered as cross-links you can
follow by eye), and the DuckDB file itself. It's simultaneously human-readable,
agent-readable, and precisely queryable. **That bundle is the micro-expert.** Hand
it to anything that can read files and run SQL, and it knows your domain.

### The local agent

`cbi agent --bundle ./some-bundle` opens a chat TUI backed entirely by on-device
models. Inference and embeddings run via [kronk](https://github.com/ardanlabs/kronk)
(llama.cpp); the agent loop, tool-calling, and streaming run via
[fantasy](https://github.com/charmbracelet/fantasy), which ships a first-class
kronk provider so the two snap together. The model is **Gemma 4** (E2B up to 12B,
`Q4_K_M`) for generation and **EmbeddingGemma-300M** (768-dim) for retrieval, both
under **Vulkan** on an AMD Ryzen AI MAX+ 395 ("Strix Halo"). No API keys, no
cloud, no embedding server.

The agent answers only by calling tools — `schema`, `sql_query` (read-only),
`hybrid_search`, and `list_docs`/`search_docs`/`read_doc` — never from memory.
That last constraint is load-bearing, and it's the first thing the benchmarks
taught me.

## Lesson 1: grounding is a feature you design in

The first time I graded the agent (against a hand-built Pokémon graph, six
questions with answers pulled straight from the DB), it got 3 of 6 — and the worst
failure wasn't a wrong answer, it was a *convincing* one. Asked for Eevee's
evolutions, where the graph holds exactly three, it returned all eight real-world
Eeveelutions. It had quietly answered from training data the moment its SQL errored
out. The first three were right, which is what made it dangerous.

The fix wasn't a smarter model. It was a hard rule — *every fact must come from a
tool result in this conversation; if the tools don't return it, say you couldn't
find it* — plus making the schema honest (surfacing per-type property keys and edge
directions, because the model was guessing field names and inverting relationships).
That took it to 5 of 6, with the sixth failing *honestly*: "I couldn't find it in
the graph." For a retrieval agent, an honest "I don't know" is a categorically
better failure than a confident fabrication. You can build on the former.

That single design choice — engineered honesty — is what makes everything
downstream trustworthy. It's also what lets a *small* model be useful: when it
can't do something, it declines instead of inventing.

## Lesson 2: capability is real, and measurable per-pattern

How small can the model be? I auto-generated 83 Pokémon questions (templated over
every relation, gold answers straight from SQL) and ran the two smallest Gemma
tiers head to head, scored deterministically — recall, exact-match, and precision
(which catches over-generation with no LLM judge in the loop).

```
Overall exact-match accuracy (n=83)

  E2B  (~2.3B, Q4_K_M)   ████████████░░░░░░░░░░░░░░░░░░░░░ 34.9%  (29/83)
  E4B  (~4.5B, Q4_K_M)   ████████████████████████████░░░░░ 83.1%  (69/83)
```

Double the parameters, ~2.4× the accuracy. But the *shape* of the gap is the
useful part: E2B collapses on **reverse traversal** ("which Pokémon are Fire type"
— filter the target, gather the sources, invert the edge) at 7% while E4B is
direction-agnostic at 80%. And the result I keep coming back to: **honest failure
scales down with the model.** E2B fails far more often, but ~72% of its failures
are honest "not found" — virtually the same honest share as E4B's. The small model
is dramatically less capable but barely more deceptive. The grounding holds.

So model size buys *capability* (harder query shapes, multi-answer completeness),
but not *integrity* — that you get from design. Hold onto that distinction; it's
about to do real work.

## Lesson 3: a real corpus, judged locally

Pokémon is a toy. To test against something external I pointed the system at
[GraphRAG-Bench](https://github.com/GraphRAG-Bench/GraphRAG-Benchmark)'s **medical**
track — a ~1 MB prose corpus with graded questions in four styles (Fact Retrieval,
Complex Reasoning, Contextual Summarize, Creative Generation), normally scored by a
`gpt-4o-mini` judge.

`cbi` ingests structured graphs, so I added an extraction pass: a local Qwen-35B
read the corpus in chunks and emitted entities + relations → **3,875 nodes / 7,137
edges / 23 types**. Then I ran the *entire* evaluation loop locally — answering with
Gemma, and **judging with the same local Qwen** (GraphRAG-Bench's eval speaks
OpenAI, so I pointed `base_url` at localhost) plus local BGE embeddings. Nothing
left the box.

Three findings stacked up. First, a dull but critical bug: the agent was loading at
llama.cpp's default 8k context, and long tool loops overflowed it into blank
answers — Gemma 4 supports 128k, so I loaded it there and the blanks vanished.
Second, scaling the graph from 24% to the full corpus made the *small* E4B model
slightly **worse** (0.334 → 0.319): the extra density was noise it drowned in.
Third, the same dense graph in front of **Gemma 12B** jumped to **0.455**, and with
a more generous tool-step budget to **0.520** overall answer-correctness — led by
Complex Reasoning at 0.590. Coverage and model capability aren't independent: adding
graph density only pays off if the model is strong enough to exploit it.

For context, the published GraphRAG-Bench medical systems (GPT-4o-mini as both
generator and judge) sit in roughly the **0.54–0.68** band per question type. A
4-bit local 12B with a naïve one-pass graph landing at **0.52**, judged by a
*different* model, is closer than I expected — and it set up the real question.

## The centerpiece: same graph, frontier brain

Here's the experiment that reframed everything. The OKF bundle is a portable skill
— so what happens if I hand it not to the local Gemma, but to a *frontier* model?

I spun up **Claude Sonnet subagents**, gave each the same medical OKF skill bundle,
and let them answer the same 32-question sample using the skill's *generic* toolkit
— the `duckdb` CLI, `cbi query`, and the markdown concept docs — under the same
"ground every fact in the bundle, no outside knowledge" rule. Then I scored their
answers with the **same local Qwen judge** that graded the local agent. Apples to
apples on everything except the brain doing the reading.

```
Answer-correctness, same graph, same judge (n=32)

  question type          local 12B@32   Sonnet      Δ
  Fact Retrieval            0.404        0.429     +0.025   Sonnet
  Complex Reasoning         0.590        0.453     −0.137   12B
  Contextual Summarize      0.565        0.517     −0.048   12B
  Creative Generation       0.520        0.563     +0.043   Sonnet
  ─────────────────────────────────────────────────────────────
  OVERALL                   0.520        0.491     −0.029   ~tie
```

**The frontier model did not win.** A model orders of magnitude larger, reading the
exact same knowledge graph, scored *0.491 — statistically a tie with, and nominally
below, a 4-bit 12B running on my desk.* Swapping the answerer for a far stronger one
moved the overall number by essentially nothing.

That's the whole thesis in one table. **The expertise is in the graph.** Sonnet is a
vastly better reasoner and writer — and you can see exactly where that buys
something: it wins Fact Retrieval and Creative Generation, the tasks that reward
clever navigation (it traversed `IS_A` hierarchies to surface symptoms the 12B gave
up on) and grounded prose. But it cannot retrieve facts that *aren't in the graph*.
On adrenocortical-carcinoma symptoms — where the gold answer lists fifteen and the
graph holds two — Sonnet navigated harder and still hit the same wall. Pheochromocytoma
had no node at all; no amount of intelligence reads a node that doesn't exist.

The 12B's win on Complex Reasoning (+0.137) comes with an honest caveat: the local
agent ran a tight per-question loop of up to 32 tool steps, while the Sonnet
subagents answered in batches with lighter retrieval. A per-question, retrieval-heavy
Sonnet run would likely close most of that gap. But that *strengthens* the thesis,
not weakens it: the difference between the two answerers is dominated by **how hard
they retrieve**, not how smart they are. Tune the retrieval and the graph, and the
choice of model becomes a question of cost, privacy, and prose — not correctness.

## What this is good for: micro-scale domain experts

Put the three lessons together — grounding is design, capability is measurable, and
the graph is the expert — and a build pattern falls out.

A **micro-scale domain expert** is a single OKF bundle for one bounded domain: your
product's data, an internal runbook corpus, a regulatory standard, a research
literature, a customer's catalog. It is:

- **Self-contained.** One directory: markdown you can read, a database you can
  query, a `SKILL.md` that explains both. No service to run, nothing to deploy to
  *use* it.
- **Portable across brains.** The same bundle works under a 4-bit local model (for
  privacy, cost, air-gapped, or just snappy) *and* a frontier model (for the hardest
  reasoning or the best prose) — because the interface is "read files, run SQL,"
  which everything speaks. You are not locked to one model; you pick per job.
- **Inspectable.** When it's wrong, you `cat` the concept doc or run the SQL and see
  *why*. The failure is a missing edge, not an inscrutable weight. That's a
  debuggable system, which an end-to-end fine-tune is not.
- **Cheap to make, and the cost is in the right place.** The benchmarks say the
  model is interchangeable, so you don't spend there. You spend on **extraction
  quality** — getting the right entities, resolved and de-duplicated, with a clean
  relation vocabulary. That's the lever, and it's a data problem you can attack
  incrementally and measure.

This is a different shape from "fine-tune a model on your domain" (expensive,
opaque, frozen, hallucination-prone) and from "stuff everything in a context window"
(no structure, no traversal, re-paid every query). A micro-expert is a durable,
queryable, versioned artifact — the temporal model even lets you ask it what it knew
*last quarter*. You build a fleet of these, one per domain, and route any agent you
like at whichever one it needs.

The honesty work makes the fleet trustworthy: a micro-expert that declines when the
graph is silent — instead of confabulating — is one you can actually wire into
something. And because the same `cbi eval` / `cbi answer` harness grades any bundle
against any answer key, "is this expert good enough for this job?" is a number you
measure, not a vibe you assert.

## Where the work goes next

If the model is interchangeable and the graph is the expert, then the entire game is
**extraction quality** — and the medical run showed exactly where the current,
throwaway extractor falls short: duplicate entities (`hodgkin_lymphoma`, `_2`,
`_3`), a sprawling 150-relation vocabulary with inconsistent directions, missing
nodes, and facts attached to the wrong granularity. Sonnet's wall on adrenocortical
symptoms was a *graph* failure, full stop.

So the next build is a fully-local, in-process extraction pipeline inside `cbi`: a
12–32B model (no external server — kronk can constrain its output to a JSON schema
via grammar sampling) running bootstrap-an-ontology → extract → glean for recall →
resolve entities by embedding-clustering → normalize the relation vocabulary and
direction → ingest. And the validation is already written: re-run this exact
frontier-vs-small benchmark and watch the Fact-Retrieval numbers — the
extraction-bound ones — move. If the thesis holds, *that's* where the points are.

The system that started as "can a tiny model answer graph questions on my laptop"
turned into something more interesting: a way to manufacture portable, honest,
model-agnostic domain experts, where the intelligence you're buying is in the data
you curate, not the model you run. The frontier model tying a 4-bit local one on the
same graph isn't a knock on the frontier model. It's the best news in the project:
it means the expensive, scarce thing isn't the bottleneck. The graph is. And graphs,
you can build.

---

*Stack: `cbi` (Go) · DuckDB 1.5 (`vss`/`fts`/`spatial`/`duckpgq`) · kronk + llama.cpp
(Vulkan) · answerers: Gemma 4 E2B/E4B/12B `Q4_K_M` (local) and Claude Sonnet
(over the OKF skill bundle) · graph extraction + judge: Qwen3.6-35B (local) ·
EmbeddingGemma-300M / BGE-small embeddings · GraphRAG-Bench medical corpus,
32-question stratified sample, same local judge across both answerers ·
AMD Ryzen AI MAX+ 395 / Radeon 8060S.*
</content>
