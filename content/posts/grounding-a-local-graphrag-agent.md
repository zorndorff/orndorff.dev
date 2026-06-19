+++
title = "Grounding a Fully-Local GraphRAG Agent: An Accuracy Post-Mortem"
date = "2026-06-19"
categories = ["AI", "Engineering"]
tags = ["graphrag", "local-llm", "duckdb", "agents", "gemma", "vulkan", "go"]
type = "posts"
draft = false
+++

I've been building `cbi`, a small domain-agnostic GraphRAG CLI: it ingests data
into a DuckDB knowledge graph (vectors via `vss`, full-text via `fts`, graph
queries via `duckpgq`) and exports it as a self-contained, `cat`-readable [Open
Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog) bundle —
markdown concept docs plus the database itself.

The latest piece closes the loop: `cbi agent --bundle ./some-bundle` opens a chat
TUI where a **fully local** agent answers questions about the bundle. No API keys,
no cloud, no embedding server. The whole thing runs on my desk.

The interesting part isn't that it works. It's what happened when I actually
graded it.

## The stack

Everything is on-device:

- **[kronk](https://github.com/ardanlabs/kronk)** (Ardan Labs) wraps llama.cpp for
  both LLM inference and embeddings.
- **[fantasy](https://github.com/charmbracelet/fantasy)** (Charmbracelet) drives the
  agent loop, tool-calling, and token streaming — and ships a first-class kronk
  provider, so the two snap together.
- **DuckDB** is the brain: one file holding the nodes, edges, embeddings, and a
  property graph.
- **[Bubble Tea](https://github.com/charmbracelet/bubbletea)** for the chat UI.

The model is **Gemma 4 E4B** (4.5B effective params, `Q4_K_M`, ~5 GB) for
generation and **EmbeddingGemma-300M** (768-dim) for retrieval. Both run under
**Vulkan** on an AMD Ryzen AI MAX+ 395 ("Strix Halo", Radeon 8060S / RADV).

> A wrinkle worth noting: kronk auto-detects a GPU backend, and on this box it
> would pick **ROCm** because `rocminfo` is installed. ROCm on Strix Halo APUs is
> a coin flip; Vulkan is the reliable, fast path. So the agent forces
> `KRONK_PROCESSOR=vulkan` before anything loads — which the embedded provider's
> library loader honors too. On first run it pulls the `ubuntu-vulkan` llama.cpp
> build and offloads onto the iGPU's 64 GB of addressable memory.

The agent answers by calling tools, never from memory:

| Tool | Purpose |
|------|---------|
| `schema` | node/edge types, counts, connectivity, property keys |
| `sql_query` | read-only DuckDB SQL / SQL-PGQ (guarded) |
| `hybrid_search` | vector + lexical (BM25) fusion |
| `list_docs` / `search_docs` / `read_doc` | browse the markdown concepts |

## The test harness

For ground truth you want a domain small enough to verify by hand but rich enough
to have real structure. So: **Pokémon.** A tiny fixture — 36 nodes, 66 edges:

- **Nodes:** Pokemon (20), Type (8), Trainer (5), Region (3)
- **Edges:** `HAS_TYPE` (24), `FOUND_IN` (21), `OWNED_BY` (11), `EVOLVES_TO` (10)

I pulled the answers straight from the DB, then asked the agent six questions
spanning every retrieval mode — aggregation, semantic search, single-hop graph,
multi-hop graph, and relationship lookup:

1. How many Pokémon, and what are the node types? *(aggregation)*
2. Full evolution line from Charmander? *(multi-hop)*
3. Which Pokémon does Ash Ketchum own? *(relationship)*
4. Find the "dragon that breathes flames hot enough to melt boulders." *(semantic)*
5. What types is Charizard, and what region? *(graph)*
6. List all of Eevee's evolutions. *(fan-out)*

## Round one: 3 of 6

| # | Question | Result |
|---|----------|--------|
| 1 | Count + node types | ✅ Pokemon 20, Type 8, Trainer 5, Region 3 |
| 4 | Dragon that breathes flames | ✅ Charizard — one `hybrid_search`, dead on |
| 5 | Charizard types + region | ✅ Fire, Flying; Kanto |
| 2 | Charmander evolution line | ❌ no answer — burned all its steps |
| 3 | Ash's Pokémon | ❌ wrong |
| 6 | Eevee's evolutions | ❌ **hallucinated** |

The semantic side was flawless. Question 4 is the one that makes the whole
exercise feel like magic: the prompt never says "Charizard," only a paraphrase of
its flavor text, and `hybrid_search` returns `pokemon:006` on the first try.

The graph side was where it fell apart. And every failure turned out to be *my*
bug, not the model's.

## Failure 1: the JSON operator-precedence trap

Question 6 (Eevee) and Question 3 (Ash) both died with the same DuckDB error:

```
Conversion Error: Failed to cast value to numerical:
{"attack":90,"defense":55,...} when casting from source column properties
```

This took me a minute, because the query *looked* fine:

```sql
SELECT (tgt.properties->>'name')
FROM Edges_Base e
JOIN Nodes_Base src ON e.source_id = src.node_id
JOIN Nodes_Base tgt ON e.target_id = tgt.node_id
WHERE e.is_current
  AND e.relationship_type = 'EVOLVES_TO'
  AND src.properties->>'name' = 'Eevee';   -- 💥
```

The culprit is that last line. Without parentheses, DuckDB parses

```
src.properties ->> ('name' = 'Eevee')
```

— it binds `->>` to the *boolean* `'name' = 'Eevee'`, decides you're doing array
indexing with a boolean index, and tries to cast the entire JSON blob to a number.
Boom.

The fix is one pair of parentheses:

```sql
AND (src.properties->>'name') = 'Eevee'   -- ✅
```

The embarrassing part: the worked example baked into my own `schema` tool used the
*unparenthesized* form. I was actively teaching the model the broken pattern. Fixed
the example, and added an explicit rule to the system prompt: *always parenthesize
JSON extraction in a comparison.*

## Failure 2: the model couldn't see the field names

Question 3 — "which Pokémon does Ash Ketchum own?" — failed for a second,
independent reason. The agent kept filtering on `properties->>'name' = 'Ash Ketchum'`.
But Trainer nodes don't have a `name` field. They have `trainer_name`. The model
had no way to know that; my `schema` tool listed types, counts, and connectivity,
but not the property keys.

Easy fix: surface the keys per type, straight from the data.

```sql
SELECT node_type, json_keys(ANY_VALUE(properties)) AS property_keys
FROM Nodes_Base WHERE is_current GROUP BY node_type;
```

```
Pokemon  → [attack, defense, generation, hp, name, pokedex_id]
Region   → [generation, gyms, region_name]
Trainer  → [age, badges, hometown, trainer_name]
Type     → [strong_against, type_name, weak_against]
```

Now the model can read the schema and see that trainers key on `trainer_name`. I
also added the edge *direction* explicitly (`OWNED_BY` goes Pokémon → Trainer, not
the reverse), because it had been inverting that too.

## Failure 3: the hallucination hiding in plain sight

This is the one that matters most, and it's the reason you should always grade
against ground truth instead of vibes.

Question 6, round one. The graph contains exactly three Eevee evolutions:
**Vaporeon, Jolteon, Flareon.** The agent's SQL kept erroring (failure #1), and
when it ran out of working queries, it produced this:

> Eevee can evolve into:
> - Vaporeon
> - Jolteon
> - Flareon
> - Espeon
> - Umbreon
> - Leafeon
> - Glaceon
> - Sylveon

It answered from **its own training data** — the full real-world list of eight
Eeveelutions — not from the graph. The first three are right, which is exactly what
makes it dangerous: a plausible answer that quietly drifts off the data the moment
retrieval gets hard. If I'd only checked whether the answer "looked like Eevee
evolutions," it would have sailed through.

The fix isn't a better query. It's a hard rule in the system prompt:

> Every fact in your answer must come from a tool result in this conversation.
> If the tools don't return it, say you couldn't find it in the graph. Never fill
> in, complete, or correct a list from your own knowledge.

## Round two: 5 of 6, and the sixth is honest

With the three fixes — parenthesized JSON, property keys in the schema,
anti-hallucination guardrail (plus bumping the tool-step budget from 12 to 20) —
I re-ran the failures.

| # | Question | Before | After |
|---|----------|--------|-------|
| 2 | Charmander line | no answer | ✅ Charmander → Charmeleon → Charizard |
| 6 | Eevee evolutions | hallucinated 8 | ✅ exactly Vaporeon, Jolteon, Flareon |
| 3 | Ash's Pokémon | wrong | ⚠️ honest "not found in the graph" |

Eevee is the satisfying one. Same model, same hardware, same question — it now
returns **only what's in the graph**, full stop. The five-extra-Pokémon
confabulation is gone.

Question 3 is the honest miss, and I think it's the most instructive result of the
whole exercise. The data is right there — the canonical query returns Bulbasaur,
Charmander, Squirtle, Pikachu — but the E4B model didn't compose that particular
three-way join on its own this time. The difference is that it now **fails
honestly**: "I could not find any records," rather than inventing a roster. For a
data-retrieval agent, an honest "I don't know" is a categorically better failure
than a confident wrong answer. You can build on the former.

## What I actually learned

**Retrieval and authoring are different skills.** The semantic channel
(`hybrid_search`) was perfect out of the box — fuzzy, conceptual lookups are what
embeddings are *for*. The structured channel only failed when the model had to
*write* correct SQL against a schema it couldn't fully see. Almost every fix was
about closing that visibility gap, not about a smarter model.

**Your prompt examples are training data.** A single unparenthesized example in my
schema tool propagated straight into the model's queries. Worked examples in a
system prompt aren't documentation — they're the strongest behavioral signal you're
sending. Make them correct, or you're teaching bugs at scale.

**Grade against ground truth or you're flying blind.** The Eevee hallucination is
invisible to "does this look reasonable?" It's only visible when you know the graph
holds three, not eight. Every serious RAG eval needs an answer key, not a judge that
shares the model's priors.

**Honest failure is a feature you have to design in.** Models default to filling
silence with plausible text. Getting "I couldn't find it" instead of a fabrication
took an explicit, forceful instruction — and it's worth more than another point of
raw accuracy.

The headline — 3/6 to 5/6 — undersells it. Every question in this set is provably
answerable from the graph; I verified each canonical query by hand. The system's
ceiling is 6/6. What I shipped is a local agent that hits five of them and tells you
the truth about the sixth, running entirely on a chip in my desk, under Vulkan, with
no network in the loop.

That last part still feels a little like magic.

---

*Stack: `cbi` (Go) · DuckDB 1.5 (`vss`/`fts`/`duckpgq`) · kronk + llama.cpp (Vulkan,
b9664) · Gemma 4 E4B `Q4_K_M` · EmbeddingGemma-300M `Q8_0` · fantasy · Bubble Tea ·
AMD Ryzen AI MAX+ 395 / Radeon 8060S.*
