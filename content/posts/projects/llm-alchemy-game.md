+++
title = "Building a Non-Deterministic Merge Game with LLMs"
date = "2025-11-01"
categories = ["projects", "ai", "llm", "cloudflare"]
tags = ["llm", "cloudflare-workers", "astro", "game"]
type = "posts"
draft = false
+++

## What I Built and Why

I've always enjoyed those element-combining merge games like Doodle God or Little Alchemy. You know the ones - Water + Fire = Steam, Earth + Water = Mud, that sort of thing. There's something satisfying about discovering combinations, but after playing a few, I started noticing a fundamental limitation: every combination is pre-determined. Everyone who plays gets exactly the same results. The discovery phase is fun, but once you know the combinations, there's no variance.

This got me thinking about large language models and their vast knowledge of concepts and relationships. What if, instead of hardcoding every possible combination, we let an LLM decide what happens when you combine elements? The result would be probabilistic rather than deterministic - your Steam might be different from my Steam, and the same combination might yield different results on different playthroughs.

I spent an afternoon building a prototype to test this idea, and I think the results are more interesting than traditional merge games.

## The Problem with Traditional Merge Games

Traditional merge games are essentially large lookup tables. Developers pre-define every possible combination, which means:

1. The scope is limited by how many combinations someone manually creates (usually a few hundred at most)
2. Everyone has the same experience
3. The discovery is finite and reproducible
4. Creating new combinations requires developer intervention

This works fine for what it is, but it leaves a lot of potential unexplored. What if you want to combine Fire with Ocean? Or Volcano with Time? If the developer didn't think of it and code it, it simply won't work.

## How LLMs Change the Game

Large language models have been trained on vast amounts of text describing concepts, their properties, and their relationships. This means they have a working understanding of what happens when you combine things - not from explicit programming, but from learned patterns in how humans describe and think about combinations.

By using an LLM as the combination engine, you get several interesting properties:

1. **Infinite combinations**: The model can reason about any pair of elements, even ones you've never tried before
2. **Contextual understanding**: The model knows that combining Fire with Ocean might create Steam, but also might create Obsidian if it's thinking about volcanic activity
3. **Probabilistic outputs**: Because LLMs are probabilistic by nature, the same combination might yield different results depending on the model's sampling
4. **Emergent complexity**: As you discover more elements, the possibility space grows exponentially without any additional programming

Of course, this approach has tradeoffs. The combinations are less predictable, which might frustrate players who want consistent rules. The responses require API calls, which adds latency and cost. And you need to handle cases where the model produces nonsensical results.

## Implementation Details

The game starts you with four classical elements: Water 💧, Fire 🔥, Earth 🌍, and Air 💨. When you click two elements to combine them, the game sends a request to Cloudflare Workers AI running Llama 3.3 70B.

I'm using Cloudflare's JSON Mode, which lets you enforce a specific schema for the response. This was critical for reliability - without it, the model sometimes returns text explanations instead of structured data. With JSON Mode, every response has the same shape: an element name, a description, and an emoji.

The prompt is fairly simple - I give the model the two input elements and ask it to determine what combining them would create. The model returns the new element, and that gets added to your collection. All discoveries are saved to localStorage, so you can come back and continue building your collection.

The stack is deliberately simple:
- **Astro.js** for the framework - mostly static site generation with islands of interactivity
- **Cloudflare Workers AI** for the LLM inference - no API keys needed, just a Workers AI binding
- **Vanilla TypeScript** for the client-side interactions
- **Tailwind** for styling

I specifically avoided React or other heavy frameworks because this doesn't need them. The interactive parts are small and isolated, which is exactly what Astro's island architecture is designed for.

## What I Learned

The most interesting finding is that the probabilistic nature of LLMs actually makes for better gameplay in this context. In a traditional merge game, once you've discovered a combination, repeating it is just grinding. But with this approach, there's always a small chance you'll get something different, which keeps the discovery phase interesting even on repeated playthroughs.

The second finding is that Cloudflare's Workers AI is remarkably fast for this use case. Most combinations return in under a second, which is fast enough that the game doesn't feel sluggish. The edge deployment helps - the inference is happening close to the user rather than round-tripping to a central API.

The main challenge was handling cases where the model produces weird or nonsensical results. I added some prompt engineering to encourage sensible combinations, but occasionally you'll still get something strange. I decided to embrace this as a feature rather than trying to eliminate it entirely - sometimes getting "Miasma" from a bizarre combination is part of the fun.

## Try It Out

The game is live at [https://llm-alchemy.orndorff.dev/](https://llm-alchemy.orndorff.dev/). Your discoveries persist in localStorage, so you can come back and keep building your collection.

Source code is available at [GitHub](https://github.com/sandwich-labs/alchemist-fun) if you want to see how it works or deploy your own version. The project includes comprehensive test coverage with Vitest, and deploys to Cloudflare's edge network.

## Where This Could Go

This was an afternoon experiment, but I think there are some interesting directions it could go:

1. **Multiplayer discovery**: Share your discovered elements with other players and see how different their combinations are
2. **Themed variants**: Use different prompts to create fantasy, sci-fi, or cooking-themed versions
3. **Element properties**: Give elements properties that affect future combinations
4. **Combination history**: Show players the chain of combinations that led to complex elements

For now though, it's just a fun proof of concept that LLMs can be used for game mechanics beyond chatbots and NPCs. The probabilistic nature that makes them unreliable for some tasks actually makes them more interesting for procedural generation and discovery mechanics.

---

**Tech Stack:**
- Astro.js + TypeScript
- Cloudflare Workers AI (Llama 3.3 70B)
- Tailwind CSS
- Vitest for testing

**Links:**
- Play: [https://llm-alchemy.orndorff.dev/](https://llm-alchemy.orndorff.dev/)
- Source: [GitHub](https://github.com/sandwich-labs/alchemist-fun)
