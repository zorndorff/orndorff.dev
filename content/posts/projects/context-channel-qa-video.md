+++
title = "QA Walkthrough Video with Claude Code, ffmpeg, and ImageMagick"
date = "2026-03-01"
categories = ["projects", "ai", "cloudflare"]
tags = ["claude-code", "ffmpeg", "imagemagick", "cloudflare-workers", "qa"]
type = "posts"
draft = false
+++

## Screenshots in a Folder Aren't a Demo Reel

I'm building [ContextChannel](https://github.com/sandwich-labs/context-channel-app) -- an edge-native content curation platform on Cloudflare Workers (Hono, D1, Drizzle ORM, HTMX, the whole neo-brutalist vibe). I needed to do a full QA pass across the entire user journey and wanted to document it in a way that wasn't just 25 PNGs rotting in a folder.

So I did the QA with an AI agent and then had it turn the screenshots into a video. In one session. Here's how that went.

## Let the Robot Click Things

I've been using [Claude Code](https://claude.ai/code) for most of my dev work on this project. I also built a headless Chrome automation CLI called **Rodney** that I wired up as a Claude Code skill (basically Puppeteer with opinions). I pointed Claude at my local dev server and told it to walk through every flow and screenshot each step.

Rodney clicked through 23 steps across the full app -- landing page, early access signup, OTP login, admin approval, channel archive, the Interceptor (a Web Share Target for saving links), RSS feeds, subscriptions, invitations, and logout. Each step got a numbered screenshot dumped into `qa-screenshots/`.

Good start. But I wanted something I could actually show someone without saying "okay now open image 14."

## The One-Session Video Pipeline

I asked Claude Code to generate a walkthrough video from the screenshots. It wrote a bash script using **ffmpeg** and **ImageMagick** that:

1. Composites each screenshot on the left side of a 1920x1080 frame (dark background)
2. Generates a Signal Yellow (#FFD700) explanation panel on the right with the step number, action name, and what's being tested
3. Stitches all 23 frames into an H.264 MP4 at 2.5 seconds per frame

The explanation panels follow the same neo-brutalist design language as the app -- Courier Bold headers, hard black borders, zero border-radius. It looks intentional, not like a slideshow someone panic-assembled in Keynote before a standup.

Final output: 1920x1080, ~60 seconds, 1.7MB.

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%;">
  <iframe
    src="https://www.youtube.com/embed/-iABQaCE_5I"
    style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen>
  </iframe>
</div>

## It's a Reusable Tool Now

The bash script got saved at `tools/qa-video/make-qa-video.sh` with a Claude skill so I can re-run it whenever the app changes. The guts are simple -- a `FRAMES` array mapping filenames to step metadata, an ImageMagick loop that composites each frame, and a final ffmpeg concat. No exotic dependencies. If you have ImageMagick and ffmpeg (and you probably do), it just works.

Add a screenshot, update the frame list, run the skill. New video.

## The Workflow That's Actually Good

Here's what I like about this: the AI agent that wrote my database queries and auth middleware also ran the QA and produced the video. The context never left the conversation. Claude knows the app, knows the design language, knows what each screen is supposed to look like, and can turn all of that into a presentable artifact without me context-switching into five different tools.

A year ago this would've been a manual afternoon. Now it's a conversation and a bash script.

---

**Stack:** Cloudflare Workers, Hono, D1, Drizzle ORM, HTMX
**Tools:** Claude Code, Rodney (headless Chrome CLI), ffmpeg, ImageMagick
**Source:** [context-channel-app](https://github.com/sandwich-labs/context-channel-app)
