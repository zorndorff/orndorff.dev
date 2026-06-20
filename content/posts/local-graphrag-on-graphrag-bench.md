+++
title = "Coverage, Density, and Model Size: A Fully-Local GraphRAG-Bench Run"
date = "2026-06-20"
categories = ["AI", "Engineering"]
tags = ["graphrag", "local-llm", "duckdb", "agents", "gemma", "benchmark", "evaluation", "go"]
type = "posts"
draft = false
+++

This is the third post on `cbi`, my local GraphRAG agent. The
[first](/posts/grounding-a-local-graphrag-agent/) grounded it against
hallucination; the [second](/posts/how-small-can-a-local-graphrag-agent-go/)
swept model sizes on a toy graph. This one points it at a *real* external
benchmark — [GraphRAG-Bench](https://github.com/GraphRAG-Bench/GraphRAG-Benchmark) —
and runs the whole thing, **including the LLM judge, entirely on my desk**. No
API keys, nothing leaves the box.

The result is three findings that only make sense together: a context-window
fix, a counterintuitive result about graph size, and a model-size jump that ties
them up.

## The setup: three local models, zero cloud

GraphRAG-Bench gives you a document corpus and graded questions (Fact Retrieval,
Complex Reasoning, Contextual Summarize, Creative Generation), and scores answers
with an LLM judge — by default `gpt-4o-mini`. I wanted the *whole* loop local:

- **Graph construction.** GraphRAG-Bench targets systems that build a graph from
  prose. `cbi` ingests structured graphs, so I added an extraction pass:
  **Qwen3.6-35B** (a local llama.cpp server, thinking disabled) reads the medical
  corpus in chunks and emits entities + relations. The full corpus →
  **3,875 nodes / 7,137 edges / 23 medical types**.
- **Answering.** The system under test: `cbi agent` on local **Gemma 4** (E4B or
  12B), querying the DuckDB graph via SQL + hybrid search.
- **Judging.** I pointed GraphRAG-Bench's `generation_eval` at the **same local
  Qwen-35B** (its API mode speaks OpenAI, so `base_url=localhost`) with local BGE
  embeddings. The judge correctly separated a hedge ("tools don't say which is
  most common", 0.23) from a right-via-reasoning answer (0.66) on validation, so
  I trusted it.

Index-time and query-time models are deliberately different: a strong model
*builds* the graph; a small one *answers* from it.

## Finding 1: the context window was the real bug

The first real run produced 5 blank answers — all "context window is full". The
agent was loading Gemma at kronk's default **8k** context, and a multi-step tool
loop (the schema-bearing system prompt + several large query results piling up)
blew past it on exactly the questions that needed the most lookups.

Gemma 4 supports **128k** natively (256k on the 12B+). So I loaded it at 128k and
loosened the per-tool output caps. The five blank questions — one of which made
*nine* tool calls — all came back with real answers. The lesson is dull but
important: with agentic tool loops, the context budget isn't about the prompt,
it's about the *accumulation*, and the default was an order of magnitude too small.

## Finding 2: more graph made the small model *worse*

With the context fixed, the obvious move was to scale the graph. My first run used
~24% of the corpus (1,462 nodes); the full corpus is 3,875. Same 32 questions,
same small E4B model, bigger graph. The score went **down**:

```
E4B overall answer_correctness
  24% graph (1462 nodes)  █████████████████░░░░░░░░░░░░░ 0.334
  full graph (3875 nodes) ████████████████░░░░░░░░░░░░░░ 0.319   ← bigger graph, slips
```

Not noise from a couple of blanks, either — excluding blanks, Fact-Retrieval
correctness *dropped* from 0.32 to 0.25, and per-question deltas were a wide spread
of gains and losses.

The reason is a methodology trap I walked into honestly: those 32 questions were
*selected* because the 24% graph already covered them. So the full corpus added no
new **coverage** for them — only **density**. And for a small model, density is
noise: `hybrid_search` returns more near-duplicate entities to sift, query results
get larger, and the agent has more chances to latch onto the wrong node. Bigger
graph, more ways to get confused.

That felt like a dead end. It wasn't — it was half of the actual finding.

## Finding 3: the 12B exploits the density the E4B drowned in

Same 32 questions, same full graph, swap E4B (4.5B effective params) for **Gemma 4
12B**:

```
answer_correctness — only the model changed
  Fact Retrieval        E4B ██████████████░░░░░░  0.277   12B █████████████████████░  0.411
  Complex Reasoning     E4B █████████████████░░░  0.342   12B ██████████████████████  0.440
  Contextual Summarize  E4B █████████████████░░░  0.332   12B ██████████████████████████  0.515
  Creative Generation   E4B ████████████████░░░░  0.325   12B ███████████████████████  0.454
  OVERALL               E4B ████████████████░░░░  0.319   12B ███████████████████████  0.455
```

**+0.136 overall — a 43% relative jump — on every question type.** And the
long-form weakness from the size sweep largely closed:

| metric | E4B | 12B |
|---|--:|--:|
| Summarize — coverage | 0.05 | **0.19** |
| Creative — coverage | 0.05 | **0.29** |
| Creative — faithfulness | 0.00 | **1.00** |

Here's the part that ties the whole post together. Finding 2 said the full graph
*hurt* the small model (0.334 → 0.319). The 12B on that **same dense graph** scores
**0.455**. So:

```
  24% graph + E4B   0.334     small model, lean graph
  full graph + E4B  0.319     small model drowns in the density
  full graph + 12B  0.455     capable model turns density into signal
```

Graph coverage and model capability aren't independent knobs. **Adding graph
density only pays off if the model is strong enough to exploit it.** A small model
faced with a richer graph gets *more confused, not more correct*; the same graph
in front of a bigger model becomes the advantage it was supposed to be. If I'd
only run the E4B, I'd have concluded "more graph doesn't help" — exactly backwards.

## The cost, and an honest ceiling

None of this is free:

```
            latency/question   tool-calls   step-budget blanks
  E4B            66 s             6.9              2
  12B           175 s            9.0              4
```

The 12B is **2.7× slower** and more thorough (9 tool calls vs 7), and it ran out
of its 20-step budget on 4 questions — blanks that actually *drag its scores
down*, so 0.455 is a floor, not a ceiling. (Raising the step budget is the next
experiment.) On this hardware — an AMD Strix Halo, 128 GB unified memory — the 12B
at 128k context and the 37 GB Qwen judge can't co-reside on the GPU, so extraction,
answering, and judging run as separate phases. The local-everything story has a
real operational tax.

## What I'd tell you in one line

A fully-local GraphRAG stack is not only possible, it's *measurable* end to end —
and measuring it surfaced something a cloud-API run would have buried under a
single accuracy number: **coverage, density, and model capability are one
coupled system.** Tune one without the others and you can make the whole thing
worse while believing you improved it.

---

*Stack: `cbi` (Go) · DuckDB 1.5 (`vss`/`fts`/`duckpgq`) · kronk + llama.cpp
(Vulkan) · graph extraction & judge: Qwen3.6-35B · answerer: Gemma 4 E4B / 12B
`Q4_K_M` @ 128k ctx · BGE-small embeddings · GraphRAG-Bench medical corpus, 32-question
stratified sample, local LLM judge. AMD Ryzen AI MAX+ 395 / Radeon 8060S.*
