+++
title = "Want an LLM to Be a Domain Expert? Build It a Wiki — Automatically."
date = "2026-06-25"
categories = ["AI", "Engineering"]
tags = ["graphrag", "local-llm", "knowledge-graph", "okb", "edtech", "agents"]
type = "posts"
draft = false
+++

Everyone wants their LLM to be an expert in *their* thing — their product, their
policies, their field. The default playbook is to fine-tune a model on it. That's
expensive, opaque, frozen the day you finish, and it still makes things up.

There's a cheaper, more honest move: don't teach the model your domain. **Hand it a
wiki.**

## The idea

Take your pile of documents. Have a model read all of it and write the wiki you wish
existed — every concept as its own page, every relationship as a link between pages, the
whole thing backed by a database the model can search and traverse.

Now point an agent at that wiki. It doesn't answer from memory; it answers by *looking
things up* — and every fact it gives you traces back to a real source passage. When the
wiki doesn't have the answer, it says so instead of inventing one.

That's the whole trick. The expertise lives in the wiki, not in the weights. So making
the model an expert in a new domain is just: generate a new wiki. I built a tool that
does exactly this — [`okb`](/posts/the-expert-is-the-graph/), the open-knowledge-bundler
— and the last post made the case on benchmarks. This one is a real example.

## A real one: K–12 teaching

I pointed it at **22 K–12 pedagogy documents** — federal practice guides, research
syntheses, district policy. Out came one auto-generated wiki:

- **3,360 concepts**, **4,251 relationships** between them
- one portable **24 MB** file — host it, email it, embed it
- every concept linked back to the exact source it came from
- **built entirely on one workstation. $0 in AI API spend. Nothing left the machine.**

Then a teacher's question: *which evidence-based interventions help struggling readers
build fluency, and who recommends them?* The local agent worked the wiki in 11 lookups
and came back with three named interventions and **seven real citations** — What Works
Clearinghouse, IRIS, peer-reviewed studies. **Zero fabricated.** That last part is the
whole game in education: a chatbot that invents a citation is worse than useless to a
teacher.

## Why this shape wins

- **Grounded.** Answers are assembled from cited facts, not generated vibes.
- **Honest.** No source, no answer — it declines instead of bluffing.
- **Private & cheap.** Builds and runs local. No per-token bill, no data leaving the box.
- **Portable.** One file. The same wiki works under a tiny local model *or* a frontier
  one — you pick per job.
- **Repeatable.** Pedagogy was the example, not the limit. Swap the documents, get a new
  expert. A compliance manual. A product catalog. Your own runbooks.

The moat was never a smarter model. It's a trustworthy body of knowledge the model can
stand on — and now you can manufacture that in an afternoon.

What domain would you point it at first?
