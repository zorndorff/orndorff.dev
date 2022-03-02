+++
title = "Running Rust on Arm with docker"
date = "2020-05-08"
categories = ["projects", "k8s", "rust", "rpi"]
type = "posts"
+++

I have a small home lab kubernetes cluster running k3s from rancher labs. As part of that deployment, the traefik ingress controller is included. This post is first in a series where I muddle through exploring the traefik ingress using a rust webserver.


### Covered in this post.

- Rust workloads on k8s with ARM and Docker.

### What will be running?

Since my home lab cluster runs on 4 raspberry pi's, some work will be needed to get a properly formatted image. For this I'll be using docker buildx to build our images for multiple targets.
This post will review the steps needed to get a working docker image deployed onto an ARM cluster using docker and kubernetes.

Setup [buildx](https://www.docker.com/blog/getting-started-with-docker-for-arm-on-linux/) for Arm Images.

```bash
# enable experimental buildx commands.
export DOCKER_CLI_EXPERIMENTAL=enabled
# enable arm64 containers on your local machine through qemo.
docker run --rm --privileged docker/binfmt:820fdd95a9972a5308930a2bdfb8573dd4447ad3
# create builder
docker buildx create --name arm-builder
```

Dockerfile:

```docker
FROM rustlang/rust:nightly-slim as builder
WORKDIR /usr/src/ping-server
COPY . .
RUN cargo install --path .

FROM debian:buster-slim
RUN apt-get update
COPY --from=builder /usr/local/cargo/bin/ping-server /usr/local/bin/ping-server
CMD ["ping-server"]
```

Feel free to modify this for your own use, it should work with the [example repo](https://github.com/zorndorff/rust-ping-server)

Building the included Rust language docker image + echo server.

```docker
# enable experimental buildx commands.
export DOCKER_CLI_EXPERIMENTAL=enabled
# enable arm64 containers on your local machine through qemo.
docker run --rm --privileged docker/binfmt:820fdd95a9972a5308930a2bdfb8573dd4447ad3
# create builder
docker buildx create --name arm-builder

docker buildx use pi-builder
docker buildx build --platform linux/amd64,linux/arm/v7,linux/arm/v6,linux/arm/arm64 -t us.gcr.io/orndorff-ops/rust-ping-server . --push
```


