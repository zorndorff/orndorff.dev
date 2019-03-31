---
title: "Starting a homelab for kubernetes development"
date: 2018-08-02T12:09:01-06:00
categories: ["projects", "kubernetes"]
tags: ["projects", "kubernetes", "fun", "k3s]
draft: false
---

## The problem

Local development environments are full of tradeoffs.
Do you optimize for ease of installation, or "production" environment fidelity?
Do you seed a subset of your production data for testing, or do you generate random datasets?
Should it each service(persistence, api, batch) in the application be optional when developing new features?
If you're like me, these considerations are often a stumbling block on the path to a working prototype. Even worse, delegating this design work to your future self is a recipe for bad juju when the inevitable happens and you curse your past self for procrastination.

## The solution

What If there was a way to avoid these compromises altogether? You've probably guessed this much but, I'm talking about Kubernetes. The cloud native orchestration solution that's swallowed the competition whole.

## The plan

As part of my Feed Machine project resuscitation efforts, I'll be using kubernetes to create a 'just works' development lab for rapid iteration on a V0.1 prototype. The first component of this will be a small 3-5 node kubernetes cluster running the k3s distribution, my "Home Lab".

Of course, this is an experimental approach and there are several questions I'd like to answer.

- Is kubernetes on a small cluster "3-5 nodes", worth the headache?
- Can ?
- How much overhead does k3s incur on a small setup.

Next in the series. "Bootstrapping kubernetes on cheap hardware"
