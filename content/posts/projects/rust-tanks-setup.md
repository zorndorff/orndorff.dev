---
title: "Destroy some tanks with rust : 1"
date: 2019-12-27T12:09:01-06:00
categories: ["projects", "rust", "games"]
tags: ["projects", "rust", "fun"]
draft: true

---

## What?

I've always been fascinated with game development, my first steps into software were through text-adventure and tank warfare(ala scorched earth) games I cobbled together in TI-83 basic. Although I work primarily on the web these days, there was something overwhelmingly satisfying about making those ultra low poly characters jitter across the screen at 2 fps. So, in that spirit, let's try and put together a small, buggy and broken game in Rust! Everyone's favorite entry on the "I should set aside some time to learn that" list.
Starting from the wonderful [arwegameyet.com](http://arewegameyet.com/categories/engines/). I'd like to implement a barebones version of [scorched earth](https://en.wikipedia.org/wiki/Scorched_Earth_(video_game)). Why Scorched Earth? For one thing, I think it would be cool. For another, the turned based physics, deformable terrain and simple 2d graphics are all features I'm very curious how to pull off in Rust.

For this post, I'll limit the scope to getting a simple title screen rendering.

To start, you'll need rust installed and a new project initialized.
(https://www.rust-lang.org/tools/install)[rust install]

```shell
cargo create --bin my-tank-game

```


```rust
main () {


}
```



### Resources

1. [arwegameyet.com](http://arewegameyet.com/#res)
1. [AGuideToRustGameFrameworks2019](https://wiki.alopex.li/AGuideToRustGameFrameworks2019)
1. [Piston Engine Tutorials](https://github.com/PistonDevelopers/Piston-Tutorials)
