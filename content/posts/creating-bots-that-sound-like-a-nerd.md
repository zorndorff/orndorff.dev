+++
date = "2026-08-07"
title = "Fine tuning a small model that sounds like me, mostly"
categories = ["experiments"]
tags = ["gemma4", "ai", "experiments"]
type = "posts"
draft = false
+++

I’ve been experimenting with how much of our personality is encoded in the data we generate every day. We all have a digital exhaust—years of emails, texts, and chat logs. I figured, if I could distill 10 years of my own communication into a small, specialized model, I could create a personal AI that sounds like me.

The result is a 73 MB LoRA "voice cartridge" that makes stock Gemma 4 E4B text like me—blind-judged 31/40 times over its base model.

The best part? The entire pipeline runs on machines I control. No raw data ever leaves my local environment.

Here is the workflow I used to turn a Google Takeout tarball into a personal style engine.

### The Pipeline: From Takeout to LoRA

The goal was to train a model on *style*—the cadence, the punctuation, the signature words—not on facts. The pipeline was designed to be format-agnostic and privacy-preserving.

#### 1. Extract & Normalize
I started with a Google Takeout archive containing Gmail mbox, Google Voice HTML files, and Google Chat JSON. The first step was to run adapters for each format, normalizing everything into a common `threads.jsonl` contract: a simple turn-based conversation structure (`{who: me|them, text}`).

#### 2. Scrub & Pair
Next, I ran a scrub script to replace PII (phone numbers, addresses) with `{{TOKEN}}` placeholders. From the normalized threads, every inbound message paired with my reply became a training pair. This yielded 6,593 real dialogue pairs—the core signal for style.

#### 3. Train & Deploy
I bundled the dataset, config, and a training script into a single `bundle.tar.zst`. This bundle was shipped to a rented NVIDIA L4 GPU. Using Unsloth QLoRA on Gemma 4 E4B, I ran a single epoch. The resulting 73 MB adapter was then converted to a GGUF file and served alongside the stock base model.

### The Results: Style Fingerprints

The most compelling evidence is the style-fingerprint table. After training, the LoRA model showed a significant shift toward my communication habits:

| Metric (40 held-out real messages) | Me (real) | Base + LoRA | Stock Gemma 4 |
| :--- | :--- | :--- | :--- |
| Median reply length | 67 chars | 46 chars | 668 chars |
| Starts lowercase | 52% | 15% | 0% |
| Emoticons `:)` | 20% | 5% | 0% |
| Exclamation marks | 18% | 12% | 78% |
| Signature words per 100 replies | 35 | 52 | 12 |
| **Blind judge "sounds like the author"** | — | **31/40 (78%)** | 5/40 (+4 ties) |

The LoRA model was not only shorter and more casual but also captured my signature word density. The blind judge, a third-party model, was highly convinced.

The most striking anecdote? An inbound "Yo. New phone. Who is this?" was replied to by the LoRA with "ah, this is Zac. tall guy from the B-Sanders stuff." Stock Gemma 4, meanwhile, replied, "Hello! I am Gemma 4, a Large Language Model developed by Google DeepMind."

### The Honest Limitations

To be clear, this is a sketch, not a clone. The process revealed several critical limitations that need to be addressed before this becomes a production tool.

#### 1. The Memorization Gap
The model trained on a corpus of 10,807 messages, but the loss chart was misleading. The model quickly memorized the repetitive short-reply mass of the corpus in the first 5% of the epoch. While the blind judge was convinced, a trained loss function would have declared victory/disaster wrongly. The verdict here is: **Behavioral evaluation is the scorecard, not the training loss.**

#### 2. Reasoning Sabotage
When I tried to integrate a local knowledge graph (KG) to ground facts, the model’s internal reasoning channel silently burned the `max_tokens` budget. The model would return empty content with `finish_reason: length`, which looked exactly like "model returned no JSON." This failure mode recurred at judge time. Lesson: **always-reasoning models need explicit budget management for structured-output tasks.**

#### 3. The Caricature Effect
The LoRA overshoots my signature words (52/100 vs my real 35) and undershoots lowercase starts (15% vs 52%). One epoch of mixed data gets you a *recognizable sketch*, not a clone.

***

### 🚀 What’s Next: The Roadmap

The current setup is a proof-of-concept. To move toward a production-ready personal voice, I’m prioritizing:

1.  **Dialogue-only Polish Epoch:** Running a second, lower-learning-rate epoch on dialogue-only pairs to tighten up the style mechanics without introducing new data.
2.  **Multi-turn Training:** Current pairs are single-turn. Real threads have context. Formatting k-turn windows is the next biggest quality lever.
3.  **Preference Tuning (DPO):** Using the SxS judge verdicts as cheap preference labels. This is the most direct way to align the model with a human style.


### Technical Summary

*   **Corpus:** 6,593 real dialogue pairs (3,835 chat / 1,556 SMS / 1,202 email).
*   **Training:** Gemma 4 E4B, QLoRA r16/α16, 1 epoch, 440 steps.
*   **Artifact Size:** 73 MB GGUF adapter.
*   **Hardware:** AMD Strix Halo APU (serving) + NVIDIA L4 (training).

The idea of a personal LLM is exciting, but the reality is that style is a complex, multi-faceted signal. The pipeline works, but the next steps—especially preference tuning—are what will turn a caricature into a clone.

