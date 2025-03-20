
+++
date = "2025-03-20"
title = "AI Plays: The Elevator Saga"
categories = ["engineering", "software", "ai"]
tags = ["engineering", "software", "ai"]
type = "posts"
draft = false
+++

<iframe width="560" height="315" src="https://www.youtube.com/embed/yghB-cCi96k?si=nE7KMdj1Kv2nlWpw" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

Ever tried [Elevator Saga](https://play.elevatorsaga.com/)? It's that addictive JavaScript challenge where you control elevators to transport impatient virtual humans. Sure, you *could* spend hours crafting the perfect algorithm... or you could do what I did and let AI handle the heavy lifting.

## Tools

- **[Claude 3.5](https://www.anthropic.com/claude)**: Model I prefer for generating code and specifications. It's like having a coding buddy who never sleeps.
- **[Whisper](https://openai.com/research/whisper)**: For transcribing my ramblings into something resembling a coherent spec.
- **[LLM](https://llm.datasette.io/)**: A command-line tool to interact with AI models like Claude and generate code from my documentation and spec.


## My Lazy Developer Workflow

I built a four-step AI pipeline that took me from "what even is an elevator API?" to passing the first four levels with minimal effort:

### 1. Documentation Heist 🕵️

First, I needed to understand the game without actually reading anything:

```bash
odt net:fetch:page --url https://play.elevator-saga.com/documentation
```

This custom tool from my DevTools collection scraped the docs and converted them to markdown. No manual reading required!

[Documentation Export](https://github.com/zorndorff/ai-plays-elevators/blob/main/documentation.md)

### 2. Stream-of-Consciousness to Spec 🎙️

Instead of writing a boring spec document, I grabbed my phone and recorded a 20-minute rambling session about elevators:

> "So what if everyone wants to go to the same floor? And should an elevator stop if it's already full? Oh, and what about that annoying thing where all elevators cluster together..."

I fed this verbal chaos through Whisper for transcription, then had Claude 3.5 turn my elevator fever dream into an actual specification. This was requested as a "junior-friendly implementation guide" to help tailor the specification to an AI's level.

[Specification](https://github.com/zorndorff/ai-plays-elevators/blob/main/spec.md)


### 3. Tests Without Tears ✅

With my spec in hand, generating tests was as simple as:

```bash
echo '<documentation>`cat documentation.md`</documentation><specification>`cat specification.md`</specification>' | llm -m claude-3-5-sonnet "Generate unit tests for this elevator system. Make them exhaustive and slightly passive-aggressive." > tests.js
```

Okay, I didn't actually request passive-aggressive tests, but the thoroughness was impressive. The AI churned out a suite of tests that covered a ton of edge cases. However they didn't work outside the elevator saga environment, so I had to tweak them a bit to fit the game.

[Tests](https://github.com/zorndorff/ai-plays-elevators/blob/main/elevator-os.tests.js)


### 4. The AI Writes My Homework 🤖

For the finale, I threw everything at Claude:

```bash
echo '<documentation>`cat documentation.md`</documentation><specification>`cat specification.md`</specification><tests>`cat tests.js`</tests>' |
llm -m claude-3-5-sonnet "You're now an elevator algorithm expert with an unhealthy obsession for efficiency. Implement the system described in the <specification> using methods defined in the <documentation>." > give_me_victory.js
```

## It Actually Worked?!

Shockingly, yes! The generated code sailed through the first four levels without breaking a sweat. Here's proof:

<iframe width="560" height="315" src="https://www.youtube.com/embed/yghB-cCi96k?si=nE7KMdj1Kv2nlWpw" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

The entire process took roughly 15 minutes of my time, mostly spent talking about elevators into my phone while walking my dog.

## Why This Matters

This isn't just about being lazy (though that's a bonus). It's about:

1. **Changing the developer's role** from typing code to designing systems
2. **Rapid prototyping** that would take hours with traditional methods
3. **Using voice as a programming interface** - because talking is faster than typing

## Next Steps

Could this approach scale to more complex problems? Yes! It applies well as a tool for build services using 'domain driven design'. My current goal is to conquer all Elevator Saga levels by iteratively improving the specification rather than diving into the code myself.

And yes, I realize the irony of spending more time writing this blog post than actually solving the programming challenge. Such is the life of a modern developer.

Want to try this approach yourself? All the tools mentioned are available online, and I've posted my full elevator specification [here](https://github.com/zorndorff/ai-plays-elevators/) for inspiration. Happy automating!
