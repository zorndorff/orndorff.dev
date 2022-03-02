---
title: "Run home assistant in k3s - IOT for everyone"
date: 2019-05-28T23:06:03-05:00
categories: ["projects", "kubernetes"]
tags: ["projects", "kubernetes", "fun", "k3s"]
draft: false
---

As a new home owner and nerd, I've been leaning into the "smart home" trend. Naturally, this makes for a great excuse to tinker with the latest IOT technology and to experiment
with distributed computing. What better test bed for working with the 'Service Mesh' than coordinating micro-computer devices and sensors?
To that end, I've chosen to use Rancher's IOT focused kubernetes distribution [k3s](https://githuub). I plan to write more about my setup in the future but, for now I'd just like
to share my configuration for running the HomeAssistant platform on kubernetes cluster with a zwave gateway.

This is only going to be useful for a very specific niche but, I though I'd share.

<script src="https://gist.github.com/zorndorff/2eef7d2deb8d385be8a950396312283b.js"></script>

<script src="https://gist.github.com/zorndorff/f3af995f6c25ed0a605dfbed4769d91f.js"></script>

Once you've `kubectl apply -f .` these, you should have a functioning home assistant deployment running on your local cluster (minikube, k3s, etc).
