+++
title = "When Docker Says 'not found' But ls Says 'it's right there': A glibc/musl Comedy of Errors"
date = "2025-07-12"
categories = ["Engineering"]
tags = ["Docker", "Debugging", "TailwindCSS", "Alpine Linux", "glibc", "musl"]
type = "posts"
draft = false
+++

You know that moment when your computer is gaslighting you? When you run `ls` inside a Docker container, see your executable sitting there with perfect permissions, but when you try to run it, the shell just shrugs and says "not found"? 

Welcome to my Saturday morning.

## The Setup: A Simple Go + TailwindCSS Build

I was working on a straightforward Dockerfile for a Go web app that uses TailwindCSS. Nothing fancy—just download the tailwindcss binary, make it executable, run it to process some CSS, and move on with life.

```dockerfile
RUN curl -sL https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-x64 -o tailwindcss && \
    chmod +x tailwindcss && \
    ./tailwindcss -i cmd/web/styles/input.css -o cmd/web/assets/css/output.css
```

The build kept failing with:

```
/bin/sh: ./tailwindcss: not found
```

But when I added `ls -la tailwindcss` right before the execution, there it was:

```
-rwxr-xr-x    1 root     root     120628068 Jul 12 13:59 tailwindcss
```

Perfect permissions. Right where it should be. Yet somehow, "not found."

## The Plot Twist: It's Not About the File

After some detective work (and adding `file tailwindcss` to the build), the mystery unraveled:

```
tailwindcss: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), 
dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, 
for GNU/Linux 3.2.0, BuildID[sha1]=..., not stripped
```

Ah. There's the smoking gun: `dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2`.

The tailwindcss binary expects glibc (GNU C Library), but Alpine Linux—my base image of choice—uses musl libc. When the shell tries to execute the binary, it can't find the dynamic linker it needs, so it just reports "not found" instead of something more helpful like "incompatible binary format" or "missing dynamic linker."

Because why would error messages be intuitive?

## The Fix: gcompat to the Rescue

The solution is surprisingly simple. Alpine provides a compatibility package called `gcompat` that adds a glibc compatibility layer:

```dockerfile
FROM golang:1.24-alpine AS build
RUN apk add --no-cache curl gcompat  # <- The hero
```

That's it. One additional package, and suddenly the tailwindcss binary can find its dynamic linker and run happily.

## The Deeper Lesson: Docker Base Images Have Opinions

This whole adventure reminded me that Docker base images aren't just "Linux with different package managers." They make fundamental choices about system libraries that can bite you when you're pulling in pre-compiled binaries from the wild.

Alpine's decision to use musl instead of glibc makes perfect sense—musl is smaller, simpler, and more secure. But it also means that a huge chunk of pre-compiled Linux binaries won't work out of the box.

Other options I considered:
- Switch to a glibc-based image like `golang:1.24` (Debian-based)
- Find a musl-compiled version of tailwindcss
- Compile tailwindcss from source in the container

But `gcompat` was the path of least resistance, and sometimes that's exactly what you need when you just want to process some CSS and get on with your life.

## The Takeaway

Next time Docker gaslight you with a "not found" error on a file that clearly exists, remember: it might not be about permissions or paths. It might be about fundamental incompatibilities hiding behind unhelpful error messages.

And maybe, just maybe, the solution is a single package install away.

Happy debugging!