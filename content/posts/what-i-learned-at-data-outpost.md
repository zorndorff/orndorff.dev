+++
date = "2026-11-08"
title = "What I Learned at Data Outpost"
description = "Where agentic data platforms are heading in 2026–27: curation over contraptions."
categories = ["AI", "Data"]
tags = ["ai", "agents", "data", "semantic-layer", "duckdb", "motherduck", "observability", "evals"]
type = "posts"
draft = false
+++

Last week I spent two days at MotherDuck's [Outpost](https://www.dataoutpost.ai/): a hands-on workshop on building analytics agents, then a full day of talks and a panel. It confirmed my suspicion that AI/LLMs have reached the level of a junior-to-intermediate data analyst or data support specialist. To be effective, the environment, documentation, and tools matter more than anything else. Through 2026–27, the model stops being the interesting variable. The environment is.

Jordan Tigani opened his keynote by calling SQL writing "a solved problem." Agents no longer one-shot a query; they explore the data the way an analyst does. On the panel, Shreya Shankar shared her Data Agent Benchmark: the best frontier agents, without a carefully curated semantic layer, land at about **70% pass@1**. Students who pre-processed the data and built semantic layers got another **15% or more**.

That's the junior analyst. Technically capable, fast, and wrong about a third of the time because nobody told them how the business works. As Shreya put it, "if you're making business decisions, you don't want your agent to be right only 70% of the time."

Closing that gap comes down to three pillars.

## Data Organization

LLMs are like a new hire, every time. When given a task, they have to orient themselves to your organization's information: where it lives, how it's organized, and how it can be retrieved. The more complex and complicated your data's organization (domain randomness notwithstanding), the longer and more expensive that process will be. That requires normalization and standard layouts wherever possible. Each new way of laying out your data adds compounding costs for anyone new to the catalog, whether machine or human.

A RISC-V CPU startup described their onboarding as: "attach this database, and now just talk to Claude." Code review, CI, issues, chat, and simulator logs all land in one warehouse, so there's exactly one place to orient to. About two-thirds of the company queries it every day, and "no one is writing SQL."

Tigani's line for this pillar: **curation is better than context**. "Curation, having the right data and the right data model, is more powerful for enabling the agents than having exactly the right things in your context layer." A perfect context file can't save a bad model.

## Data Documentation & Context

The documentation has to say what the data actually means. Tigani again: for years teams wrote docs and nobody read them, "but now the agent reads those docs all the time, so they are just as important to get right as the data itself."

Mehdi's workshop example was ARR. Ask "what is the ARR for this week?" Is that the billing from every Sunday, or a seven-day window? "Every answer is kind of correct." The SQL is easy. Picking the definition is the job, and the agent can't know which one finance uses unless you write it down.

It doesn't need to be fancy. Nobody on stage pitched a metrics API. The answer was markdown: "just simple markdown to start goes a really long way." Rules like "keep money in cents until the final `SELECT`" are exactly what a senior analyst would tell a new hire.

Bind the documentation to the data, not to the harness. A skill only loads when the agent decides the task calls for it. MotherDuck's *guides* are the same markdown, but attached to the dataset and served through the MCP, so "the agent can't skip that context before querying the database."

Sam McFarland from Canva showed the best trick of the conference for growing this layer from usage. Their `execute_sql` tool requires every query to end with two comments:

```sql
-- purpose: <intent of the query>
-- keywords: <business-specific terms or company lingo>
```

Each session runs 20–50 queries, so the business vocabulary piles up for free. One team says "learning activations," another says "first lesson," and now search knows they're the same thing.

## Routine Observability and Improvement Loop

Build observability into how the system is or isn't satisfying requests. If a metric is unreliable to access, improve it.

Mehdi: "As soon as you put an agent out there, you should have observability from day one." Without it you miss the hidden cost of self-healing. An agent writes a bad query, hits an error, retries, and the user gets a correct answer. What you don't see is that "it will repeat that a thousand times across your users." Sam put it more bluntly: "sit down and read traces."

Two loops worth stealing:

- **Must-refuse evals.** Canva heard of someone using HR history to rank line managers by worst attrition. "Actually, no, can we not do that?" Test what the agent should *not* answer.
- **User feedback as grading.** The RISC-V team's first help bot was so verbose someone told them "silence is also a correct answer." Thumbs-up reactions now feed their evals.

## Curation over contraptions

What surprised me most is that the wins on stage weren't elaborate. What worked was basic data hygiene, written-down context, and a sane layout. What failed was the clever stuff.

Fleetio's first data agent had a name, a mascot, and a broad mandate. Michael Rhee: "What went wrong was a mixture of the state of the art at the time, probably a lot of over-engineering… and not being clear on what problem we were trying to solve." The second version was unnamed, did tedious work, and was measured by merged PRs. It worked.

It's tempting to automate around a messy catalog: a routing agent that guesses which of five databases holds the answer, a reconciliation step that guesses which "revenue" you meant, a retry loop that runs until the query stops erroring. Each is a Rube Goldberg machine built around a problem you could fix at the source by renaming a table, writing a paragraph of markdown, or deleting a duplicate.

At its simplest, the alternative is a small set of flat files in a bucket, queryable through a standard chat interface. Queries are graded by user feedback. Documentation lives as data skills and guides next to the files. A developer or agent watches those insights and fixes whatever doesn't meet the standard.

MotherDuck's stack shows how few moving parts that takes:

- **Guides** are the documentation: markdown attached to a dataset.
- **Flights** are the organization and the loop: scheduled jobs next to the data that handle ingestion, and can run an agent that watches a dashboard for numbers that look wrong.
- **Dives** are the watching: lightweight data apps the agent builds from chat. Tigani's whole keynote was a Dive, built without writing SQL or Python.

That's what we've been building at Otus, too. Our customer data warehouse is deliberately boring: Parquet and Iceberg on S3, DuckDB on top, dbt marts. Early on, an aggregation across all 1.8 million student records came back in about 400 ms, and a teacher–course mapping for every district that took 20+ minutes in the old monolith ran in 325 ms. This year we stopped building one-off API integrations for our AI and pointed it at the warehouse instead. The plan from there is to collapse ~40 tools into one agent with six, and give each session its own entitled slice of the warehouse rather than parsing SQL for safety. Less machinery, better data.

You don't need an elaborate stack to get value. You need the basics done well. The hard part isn't the model anymore, and it isn't the automation either. It's the same work we've always owed a new hire: a tidy place to work, a clear explanation of what things mean, and someone checking the work and fixing what keeps going wrong. The difference is that this new hire starts over every single session, so every shortcut you take on hygiene gets paid for again, every time.
