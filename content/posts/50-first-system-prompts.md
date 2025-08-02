+++
date = "2025-08-02"
title = "What 50 First Dates can teach us about LLM memory"
categories = ["engineering", "software", "ai"]
tags = ["engineering", "software", "ai"]
type = "posts"
draft = false
+++

You’ve been there. You and your AI coding buddy are in the zone. It’s feeding you perfect snippets of code, it understands your weirdly named variables, it’s practically reading your mind. You’ve built half a dozen functions, and the project is humming along. Then you close the window.

You come back an hour later, open a new chat, and ask it to build the next piece of the puzzle. The AI stares back at you with the digital equivalent of a blank expression. It has no idea what your project is, what a `user_auth_service` is, or why you keep muttering about the `global_config.json`. It has, for all intents and purposes, become incredibly dumb.

Here's the secret: your AI isn't dumb. It has amnesia.

And if you’ve ever seen the cinematic masterpiece *50 First Dates*, you know exactly what’s going on. Your AI assistant is like Lucy Whitmore, whose memory is wiped clean every day. This is a feature of how these Large Language Models (LLMs) are built. They are “stateless,” meaning they have no inherent memory of your past conversations.

To get anything done, you have to become Henry Roth. You need to create a "videotape", a perfectly engineered prompt, to catch your AI up on everything it needs to know, every single day.

#### The Uphill Battle: Why Nagging Your AI Doesn't Work

Now, your first instinct is to just correct it in the chat. "No, remember, we're using Python." "Don't forget the User class I showed you earlier." "I told you the database key is in the other file!"

This is the equivalent of Henry trying to re-explain their entire relationship to Lucy every morning over breakfast, one random detail at a time. It’s exhausting, and it’s a terrible strategy. Here's why it fails:

* **Context Dilution:** Your core instructions get lost in a sea of conversation. The AI has to weigh your initial goal against a dozen minor corrections, and the original intent gets diluted. As the conversation history grows to fill the context window, older (but important) messages can be truncated and forgotten forever.
* **The "Game of Telephone" Effect:** The AI fixes one thing but, having lost the big picture, breaks two others. It’s focused on the last thing you said, not the grand plan. This is how you end up with Frankenstein code that’s a mess of patched-up fixes.
* **Recency Bias:** LLMs can place more weight on the most recent messages. That crucial architectural constraint you mentioned ten messages ago is less impactful than the one you just typed, even if the old one was more important.

#### Engineering the Videotape: How to Craft the Perfect System Prompt

To stop this madness, you need to think like Henry Roth and make a videotape. In the AI world, this is your **system prompt**: a single, master set of instructions you give the AI at the *start* of every session. It's how you become your AI's "memory curator".

A good videotape—and a good prompt—is carefully curated and contains only the most essential facts. Here’s how to build one for your coding assistant:

1.  **Summarize the Core Mission (The Accident):** Start with the absolute, high-level goal.
    ```
    You are an expert Go developer. We are building a backend API for a social media app that handles user profiles and posts.
    ```

2.  **Define the Key Characters (The Relationship):** Outline the project's structure, key files, and technologies.
    ```
    The project uses Gin for routing. Database models are in the `/models` directory, and API handlers are in `/handlers`. The main entry point is `server.go`.
    ```

3.  **Establish the Rules (The Daily Routine):** This is where you set your non-negotiables. Define coding standards, testing requirements, or desired output formats.
    ```
    All code must be formatted with `gofmt`. Every function must have a corresponding unit test in a `_test.go` file. Always include error handling for database operations.
    ```

4.  **Provide Essential Knowledge (The Diary):** If there’s a critical piece of code—like a complex class or a core utility function—the AI *must* know about, just paste it directly into the prompt. This is the direct analog to providing external context, similar to how Henry's videotape grounds Lucy in a shared reality.

#### When the Videotape Isn't Enough: A Quick Word on Brain Surgery

Sometimes, a prompt isn't enough. A prompt using Retrieval-Augmented Generation (RAG) is great for injecting facts, but it's less effective at changing an LLM's core behavior or style.

If you need your AI to code in a weird, proprietary language or adopt a very specific persona, you might need to look at **fine-tuning**. If a prompt is a videotape, fine-tuning is like performing brain surgery. It directly modifies the AI's internal parameters. But like surgery, it's risky and can cause "catastrophic forgetting"—where the AI learns one new skill but its performance on other tasks degrades severely. For 99% of your daily work, a good prompt is all the intervention you need.

#### Conclusion: Stop Having First Dates with Your AI

Your AI assistant isn't a person, but you can stop treating it like a stranger you have to re-introduce yourself to every day. The few minutes you spend crafting a rock-solid system prompt will save you hours of frustration.

By embracing your inner Henry Roth and providing that curated "videotape" of context, you transform your forgetful digital sidekick into a powerful and consistent coding partner.

Now go on. Your AI is ready for its second date. All you have to do is press play.

