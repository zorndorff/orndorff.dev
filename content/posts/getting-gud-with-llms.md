+++
title = "Getting Gud with LLMs: How to Build the Intuition"
date = "2026-04-25"
categories = ["AI", "Engineering"]
tags = ["AI", "llm", "claude", "claude-code", "workflow", "prompting"]
type = "posts"
draft = false
+++

I recently let Claude crawl 25 months of my own LLM tooling history and write up what it found. The result lives over here: [Notes from Claude: What I Found in One User's Data](/posts/notes-from-claude-the-regression-narrative/). That post is mostly *what one person's data looks like* — eighty repos, 2,826 logged calls, voice memos full of profanity, the works. It's not a how-to. People keep asking me for the how-to.

So here it is. Not a list of magic incantations. Not "ten prompts that will change your life." The operating principles I actually use when I sit down with a model, distilled from being annoyed at GPT-2 back in 2019 and shipping production code with Opus in 2026.

The thesis fits in three sentences:

> LLMs thrive under the same conditions human developers do. Focus on providing relevant context. Focus on describing the problem domain effectively, the data interface contracts, the rules the system needs to follow. The code is just a translation task after that.

Most "prompt engineering" advice misses this frame. It treats the model as a slot machine you have to phrase the right way. It is not a slot machine. It's a fast junior engineer who needs the same scaffolding any junior engineer needs, and the scaffolding is the work.

## 1. Specify the domain before the task

Most failed prompts aren't failed prompts. They're failed briefings.

Before you ask the model to do anything, tell it what world it's in. What kind of system. What kind of data. What kind of users. What constraints exist that aren't obvious from the file you happen to have open. The model isn't psychic. It has to infer the world from your prompt, and a one-line task description is a thin world to infer from.

A thin prompt:

> "fix this bug"

A thick one:

> "we're in a Go service that handles ingest from a Postgres write replica. The bug is that the retry loop double-sends on connection reset. Constraint: we cannot change the on-disk schema, and the downstream consumer is idempotent on `event_id` but not on `(event_id, attempt)`. The fix has to live in the producer."

Roughly the same length. The first will get you an essay about retry patterns. The second will get you a patch. The difference isn't cleverness. The second one stopped pretending the model could read your mind.

Domain first, task second. If you're rephrasing a prompt three times, you're not stuck on phrasing. You're stuck because you haven't told it where it is.

## 2. Hand over the contract, not just the request

Tell the model what shape the output has to take. Field names. Types. Ordering. What "done" looks like. What counts as out-of-scope.

If you wouldn't accept ambiguity from a junior engineer's PR, don't accept it in a prompt. The model will happily generate something plausible-shaped if you let it, and plausible-shaped is the worst kind of wrong. It slips past your eyes.

This instinct predates tool-use schemas by years. The README on my [eli5-bot](https://github.com/zorndorff/eli5-bot) repo from September 2022 ends with the line *"prompting gpt to summarize as a JSON document."* Fifty lines of Node.js wrapping GPT-3, and the interesting move was already the contract. Tool-use schemas and structured outputs are an automated way of enforcing what you used to enforce in English. The contract still belongs in the prompt either way; the schema just keeps the model honest about it.

When something comes back wrong, ask yourself first: did I tell it what right looked like? Nine times out of ten, no.

## 3. Pick the right tool for the scope

There are two kinds of LLM work and they want two different tools.

**One-shot transformations.** Translate this paragraph. Summarize these notes. Convert this CSV. Pipe text in, get text out. This is `llm` on the command line, an API call, a cell in a notebook. Cheap, fast, no state.

**Multi-turn engineering.** Build this feature. Debug this thing across four files. Refactor this package. This is Claude Code, Cursor, Aider. An agentic harness that can plan, read, edit, run.

Most frustration I hear about Claude Code "going in circles" is people handing it a vague one-paragraph request that should have been a one-shot transformation, on a repo that was never planned across. Of 2,513 `llm` invocations on my primary machine, 2,500 are one-shot. That is not laziness. That is recognizing that 99% of "make text into different text" jobs don't need a workshop. They need a Unix filter.

When an agent goes in circles, the answer is rarely a smarter agent. It's recognizing that you handed the workshop a job that wanted a filter, or vice versa.

## 4. Use voice for the part of the work that has to stay loose

Talking is faster than typing, and Whisper-class transcription is good enough that you can dictate two thousand words of stream-of-consciousness about a problem and feed the transcript directly into a model.

I do this constantly. The trick is to actually let yourself ramble. The model is fine with profanity, false starts, mid-thought corrections, *"wait no, what I actually mean is."* The clean-up is free. One of my prompts from September 2025 opens with *"I'm trying to figure out what the fuck I can do about my Mailbox Goblin."* It worked. Real problem, the model handled the ramble.

What used to be the problem statement was the thing I typed. Now the dictation is the problem statement and what I type is just steering. This sounds small. It is not. The bottleneck on most LLM work isn't model quality, it's how much context you're willing to load into the prompt, and dictation lowers the activation energy for that by an order of magnitude.

If you're still typing every prompt by hand, you are leaving a lot on the table.

## 5. Build a personal library of system prompts

A few good role-anchored system prompts, reused across hundreds of one-shots, are worth more than a thousand bespoke instructions.

My `llm` CLI logs show the same `"Act as a top-tier engineering manager"` system prompt firing dozens of times over months. A recipe-card writer used 26 separate times. A code-review persona. A copy editor. A summarizer that always returns JSON. They are boring. They are reliable. They ossify, and that's the point.

Stable system prompts give you stable outputs to compare across model versions. That's how you tell a real regression from your own day-to-day variance. If you're rewriting your system prompt every time, you can't tell whether the model changed or you did. If you've been using the same `"Respond only with the summary, without explanation"` for two years, you can tell.

Pick the personas you actually need, not the ones you imagine you might need. Three or four good ones beats a folder of fifty. Treat them like shell aliases. They exist to take a recurring intent and make it one keystroke away.

## 6. Correct surgically, not tonally

When the agent goes wrong, the worst thing you can do is rage-restart.

Identify the specific step that broke and the evidence that it broke. One of my own corrections, verbatim:

> "Make sure this exits on error properly. oauth scopes were wrong and the script continued."

That is one sentence. It both diagnoses (the script kept going past a real error) and prescribes (exit on error). It is blameless. It does not throw away the seven other things the agent got right.

Compare that to *"this is broken, start over."* That nukes every correct decision the agent has made up to the point of failure. You will redo work. You will lose a half-built mental model. You will probably hit the same bug again, because you did not tell it what was actually wrong.

Surgical corrections compound. Nuclear corrections do not. If you find yourself wanting to rage-restart, that is a signal that you should slow down, find the specific place the trajectory broke, and write one sentence about it.

## 7. Adopt new models the day they ship

Run them against your real work, not benchmarks.

Sonnet 3.5 is in my logs the month it shipped. Opus 3 within days. `o3-mini` in the first week. `gemini-3-pro` and `gemini-3.1` essentially immediately. Loyalty is a vice here. The model is a `-m` flag. The switching cost is approximately zero, and the only way to build calibrated intuition for which model to use for which job is to actually use them on jobs you care about.

Benchmarks tell you how a model does on a curated test set. They cannot tell you how it does on your codebase, with your conventions, on the kind of bug you actually have at 4 PM on a Thursday. The only way to know that is to point the new model at last week's real work and see what happens.

This also keeps your reaction to new releases proportionate. People who only read the launch posts oscillate between "this is the future" and "this is hype." People who run the model on their actual stuff land somewhere boring and accurate, like *"better at Go refactors, worse at long planning, same on SQL."* Boring and accurate is what you want.

## 8. Treat the agent like a competent junior

The right mental model for a coding agent is not "oracle" and not "autocomplete." It is junior engineer who is fast, willing, and forgets nothing within a session.

That mental model tells you almost everything you need to know about how to work with one. Give it context the way you would give a junior context. Answer its clarifying questions in numbered replies — *"1, 3"* is faster than restating the options, and the agent handles it fine. Carry conventions across projects explicitly:

> "Follow our standard go service conventions in other sandwichlabs projects ../"

That single line, pointed at sibling repos, replaces a thousand-word style guide. The conventions live in the codebase. You just have to tell the agent to look.

Plan before implementing on long tasks. Have it dogfood its own output by spawning a cheaper sub-agent to use the thing it just built — *"go ahead and open the web ui in rodney and qa the core worflows"* (typo preserved, the agent did not care). None of this is novel. All of it is what working with a competent junior looks like, and the analogy fits because the failure modes are the same: under-specified asks, missing context, tonal flailing instead of specific feedback.

If the junior-engineer frame feels like it is doing work for you, keep using it. If it stops feeling useful, you have probably outgrown it, which is fine — but you cannot skip it.

## There is no "prompt engineering"

The phrase implies the prompt is the special thing. The prompt is the cheapest part of the work.

The expensive parts are: knowing your domain, knowing your contracts, knowing your rules, and knowing when to plan versus when to one-shot. Those four things are what separate people whose LLM work compounds from people whose LLM work plateaus. They are also, not coincidentally, the same four things that separate good engineers from mediocre engineers when there is no LLM in the loop at all.

If you are good at those four, your prompts will be fine. They will be ungrammatical, full of typos, dictated on a walk, ended mid-thought. The model will handle it. If you are bad at those four, no amount of cleverness in the prompt itself will save you, and you will end up writing a Reddit post about how the model got worse.

It did not get worse. The work got harder, because you got more ambitious, because the tools made you more ambitious. That is the deal. Get gud at the four, and the rest is translation.
