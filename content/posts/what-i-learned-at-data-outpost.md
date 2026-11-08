+++
date = "2026-11-08"
title = "What I Learned at Data Outpost"
categories = ["AI", "Data"]
tags = ["ai", "agents", "data", "semantic-layer", "duckdb", "motherduck", "observability", "evals"]
type = "posts"
draft = true
+++

Last week I spent two days at MotherDuck's Outpost: a hands-on workshop on building analytics agents on Nov 4, then a full conference day of talks and a panel on Nov 5.

What did I learn from Outpost? It confirmed my suspicion that AI/LLMs have reached the level of a junior-to-intermediate data analyst or data support specialist. That means that to be effective, the environment, the documentation, and the tools matter more than anything else.

Every talk pointed the same way. Jordan Tigani opened his keynote by calling SQL writing "a solved problem," and offered to argue the point with anyone afterwards. Agents don't one-shot a query anymore. They explore the data the way an analyst does: run a few queries, check the joins, iterate. Then on the panel, Shreya Shankar shared results from her Data Agent Benchmark. The best frontier agents, without a carefully curated semantic layer, land at about **70% pass@1** on questions that span several databases. Students who pre-processed the data and built semantic layers got another **15% or more**.

That's the junior analyst. Technically capable, fast, and wrong about a third of the time because nobody told them how the business actually works. As Shreya put it, "if you're making business decisions, you don't want your agent to be right only 70% of the time."

Successfully integrating frontier intelligence into data workflows (reporting, analysis, and data product creation) depends on 3 key pillars. None of them are exotic. They're basic data hygiene, written-down context, and a habit of checking the work, and at Outpost they beat clever automation every time.

## Data Organization

LLMs are like a new hire, every time. When given a task, they have to orient themselves to your organization's information: where it lives, how it's organized, and how it can be retrieved. The more complex and complicated your data's organization (domain randomness notwithstanding), the longer and more expensive that process will be.

A simple example: querying a standardized set of tables with consistent, documented patterns takes far less time and fewer tokens than a system where each domain object's layout and relationships have to be discovered anew for every table, schema, and database. That requires normalization and standard layouts wherever possible. Each new way of laying out your data adds compounding costs for anyone new to the catalog, machine or human.

The new-hire comparison wasn't just mine. A RISC-V CPU startup described their onboarding as: "attach this database, and now just talk to Claude." They pull code review, CI, issues, chat, job schedulers, and simulator logs into a single warehouse, so there is exactly one place to orient to. About two-thirds of the company queries it every day, and in their words, "no one is writing SQL."

Tigani's version of this pillar: **curation is better than context**. "Curation, having the right data and the right data model, is more powerful for enabling the agents than having exactly the right things in your context layer." A perfect context file can't save a bad model.

Shreya made the cost side explicit. Pre-processed, well-shaped data doesn't just raise accuracy. It makes agents cheaper, because they waste fewer exploratory queries figuring out where things are. Frontier agents are expensive, and orientation is where a lot of that money goes.

One talk on extracting structured data from private-market documents added a warning I've lived through. Ask an agent how to handle an awkward column and "I bet you what the AI will propose is to change this column from a string to a JSON blob." Ten minutes later the PR is out and everybody's happy, but "that would have been the worst way to lose information," because "when you store data, you should think about how you'll query that data." The speaker's process was raw → transform → model, with the data model designed *last*, and "one fact, one source": keep conflicting values, each tagged with where it came from.

## Data Documentation & Context

What does the information actually mean? What are the domain rules? How does the catalog answer questions?

Tigani had a great line on this: for years teams wrote docs and nobody read them. "But now the agent reads those docs all the time, so they are just as important to get right as the data itself."

Mehdi's workshop example was ARR. If you ask "what is the ARR for this week?", do you take the billing from every Sunday, or a seven-day window? "Every answer is kind of correct." That's the problem in miniature. The SQL is easy. Picking the definition is the actual job, and the agent has no way to know which one your finance team uses unless you write it down. The goal is that the CEO and the intern get the same number, whether a human or an agent runs the query.

The good news is that the documentation doesn't need to be fancy. Nobody on stage pitched a big metrics API. The working answer was markdown. Mehdi: "just simple markdown to start goes a really long way." The workshop's level-one setup was a DuckDB CLI plus a skill file with rules like:

- read the schema before writing SQL
- keep money in cents until the final `SELECT`
- show the SQL under every answer

That's the stuff a senior analyst would tell a new hire on day one.

Where the context lives matters as much as what it says. A skill only loads when the agent decides the task calls for it. Ask a question straight about the data and it might never open the file. MotherDuck's *guides* are the same idea, markdown, but attached to the dataset and served through the MCP, so "the agent can't skip that context before querying the database." Bind the documentation to the data, not to the harness.

My own note from the workshop: table and column descriptions (`COMMENT ON`) work, but they're hard for humans to read and review. It's easier to keep the table descriptions and their setup together in a single markdown file next to the data, where a person can read the whole thing top to bottom and a PR can change it.

Sam McFarland from Canva showed my favorite trick of the conference for building this layer from usage instead of writing it all by hand. Their data MCP has just two tools, `execute_sql` and `search_data` ("search is life"). The `execute_sql` description requires every query to end with two comment lines:

```sql
-- purpose: <intent of the query>
-- keywords: <business-specific terms or company lingo>
```

Each session runs 20–50 queries, so the business context of a problem space builds up for free. From that log they mine top keywords by department, acronym expansions, and synonyms. One team calls it "learning activations," another calls it "first lesson," and now search knows they're the same thing. Insiders say "MRR," outsiders ask "is search working?" The documentation has to cover both.

Even then, Tigani warned: "you could have the best context in the world, and sometimes the AI might decide not to use it at all." Which leads to the third pillar.

## Routine Observability and Improvement Loop

Build observability into how the system is or isn't satisfying requests and tasks. If a given metric is unreliable to access, improve it. Measure success and failure through continuous observation and classification.

Mehdi was blunt about it: "As soon as you put an agent out there, you should have observability from day one, just to know what people have asked and where the model failed." Then he pointed out a cost you won't see without it. Agents self-heal: they write a bad query, hit an error, and retry until it works. The user sees a correct answer. What you don't see is that "it will repeat that a thousand times across your users." Once you have traces, you can point an agent at the logs and ask what keeps breaking, then fix it at the source.

Sam's version was simpler: "I implore every one of you: if you're doing this in your organization, sit down and read traces."

Some concrete loops from the sessions:

- **Known-answer evals.** "When I give this prompt, 'What was revenue in February?', there is a specific answer it's supposed to return." (Tigani)
- **Must-refuse evals.** Canva heard of someone using an HR history table to rank line managers by worst attrition. "Actually, no, can we not do that?" Test for what the agent should *not* answer.
- **Blunt outcome metrics.** Michael Rhee from Fleetio said their first data agent (with a name and a mascot) failed. The second was unnamed, did tedious work, and opened PRs against the warehouse. The metric: "if it merges 10 PRs in the next month, that's a pretty good metric."
- **User feedback as grading.** The RISC-V team's first help bot was so verbose that someone told them "silence is also a correct answer." Thumbs-up reactions now feed their evals. Their root-cause debug agents went from about 60% to 80% first-try accuracy.
- **Use the warehouse to watch the warehouse.** Agent usage doubled their spend. They queried their own usage stats for tables that get written but never read, some at read/write ratios of 1 to 100,000, and cut spend by 66%.

Every organization that wants to integrate AI into its processes and products will need to focus on these 3 areas to succeed, whether the product is internal or customer facing.

## Boring beats clever

The thing that surprised me most: the wins on stage weren't elaborate. Nobody showed a multi-agent orchestration framework with a dozen specialized roles handing tasks to each other. What worked was basic data hygiene, written-down context, and a sane layout. What failed were the clever ones.

Fleetio is the cleanest example. Their first data agent had a name, a mascot, and a broad mandate. Rhee: "What went wrong was a mixture of the state of the art at the time, probably a lot of over-engineering (that's my bad, I'll fully take the point for that), and not being clear on what problem we were trying to solve." The second version was unnamed, did tedious work, and was measured by merged PRs. It worked.

It's tempting to reach for automation to paper over a messy catalog: a routing agent that figures out which of five databases holds the answer, a reconciliation step that guesses which "revenue" you meant, a retry loop that keeps going until the query stops erroring. Each of those is a Rube Goldberg machine built around a problem you could fix at the source by renaming a table, writing a paragraph of markdown, or deleting a duplicate. Fix the data and you don't need the contraption. Build the contraption instead and it becomes one more thing the next agent (and the next human) has to figure out.

Mehdi's point about self-healing agents is the same lesson from the other direction. "People say, 'I don't need observability, the agent is working.' Yes, but maybe the agent could work faster and cheaper." An agent that eventually gets there by retrying is a contraption hiding a hygiene problem.

## What does that look like in practice?

At its simplest, it can be a small set of flat files in a bucket, queryable through a standard chat interface. Queries are graded based on user feedback. Documentation takes the form of data skills and guides co-located with the files. A developer or agent watches those insights and optimizes wherever the execution or output doesn't meet the standard.

MotherDuck's own stack shows how few moving parts that takes. Three plain building blocks cover all three pillars:

- **Guides** are the documentation. They're markdown attached to a dataset and served to the agent when it connects. No metrics API, no modeling language: a paragraph saying "ARR is always taken from Sunday," and a note to keep money in cents.
- **Flights** are the organization and the loop. They're scheduled or event-based jobs that run next to the data. They handle ingestion and transforms (the RISC-V team brings everything in through Flights), and the workshop's "Dive Keeper" agent ran as one, watching a dashboard for numbers that look wrong. Mehdi floated another: a daily Flight that reviews all the guides and sends warnings to Slack.
- **Dives** are the watching. They're lightweight data apps the agent builds from chat. Tigani's entire keynote was a Dive, and he "didn't have to know any SQL or Python or any other programming language" to build it. Mehdi's view is that chat is where you build and UIs are where you watch: "a dedicated custom UI where I drag and drop things, I don't think that will survive."

That's it. Markdown, scheduled jobs, and simple apps, sitting on top of well-organized data. The workshop climbed from a DuckDB CLI and a skill file on a laptop up to a custom server-side agent, but every level stood on the same foundation, and the early levels did most of the work. You don't need the top of the ladder to get value. You need the bottom rungs done well.

Fleetio's other lesson fits here too: make it multiplayer. They put their data agent in a public Slack channel, and people learned how to use it by reading each other's threads. Then it "got out": product managers, engineering managers, and engineers started using it to make changes to the warehouse, and their Salesforce admin started running analysis with it. Feedback in public is also feedback you can grade.

My biggest takeaway is that the hard part isn't the model anymore, and it isn't the automation either. It's the same work we've always owed a new hire: a tidy place to work, a clear explanation of what things mean, and someone checking the work and fixing what keeps going wrong. The difference is that this new hire starts over every single session, so every shortcut you take on hygiene gets paid for again, every time.
