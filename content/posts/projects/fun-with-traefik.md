+++
title = "Traefik ingress for fun and profit."
date = "2020-05-08"
categories = ["projects", "k8s", "traefik"]
type = "posts"
draft = true
+++

For this post, I would like to explore the possibilities offered by the [traefik](https://docs.traefik.io/) ingress. One of the principle advantages of runnnig workloads in k8s, in my opinion, is the ability to dynamically route and discover services using either OOTB k8s functionality or, using advanced addons like traefik, istio, kong etc.

### Covered in this post.

- Dynamic routing between 2 services.
- Dynamic routing, traffic splitting between 2 deployments of a service.

### Bonus Content:
