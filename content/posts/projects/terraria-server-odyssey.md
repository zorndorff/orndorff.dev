+++
title = "The Terraria Server Odyssey: A Tour of Modern Deployment Options"
date = "2026-02-01"
categories = ["projects", "devops", "gaming"]
tags = ["terraria", "fly.io", "ansible", "cloudflare", "sprites", "homelab"]
type = "posts"
draft = false
+++

> **A note from the co-author:** This post was written collaboratively with [Claude](https://claude.ai), who also did most of the actual infrastructure work — reading docs, writing Ansible roles, debugging crashed services over SSH, and talking me out of increasingly cursed networking solutions. When we hit the Fly.io memory wall at 2am, Claude suggested the boring VPS approach that actually worked. Fair to say this server wouldn't be running without the assist. — *Zac*

My son casually mentioned he'd been playing Terraria with friends. "You know," I said, brain already spinning up infrastructure diagrams, "I could set up a dedicated server so you guys don't have to host it yourselves."

He shrugged. "Sure, that'd be cool."

And just like that, I was nerd sniped. What followed was a three-day odyssey through modern deployment platforms, each promising simplicity and each revealing unexpected limitations. TCP port 7777 — how hard could it be?

## The Mission

The requirements seemed simple enough: a persistent Terraria server that my son's friends could connect to by typing in an address. No client-side software to install, no VPN nonsense, just `server.example.com:7777` and they're in. I already run a Factorio server, so I figured I knew what I was getting into.

I did not know what I was getting into.

## Stop 1: Sprites (The Shiny New Thing)

I'd been itching to try [Sprites](https://sprites.dev), Fly.io's new persistent micro-VM platform. They're pitched as "like having a small, stateful computer you can spin up on demand" — perfect for a game server, right?

The developer experience is genuinely slick:

```bash
sprite create terraria-server
sprite use terraria-server
sprite exec apt install -y unzip
sprite exec ./TerrariaServer.bin.x86_64 -config serverconfig.txt
```

Sprites give you a public URL like `https://terraria-server.sprites.app`. Sounds perfect until you read the fine print: that URL only handles **HTTP/HTTPS traffic**.

> "Routes to port 8080 by default (or first HTTP port opened)"

Terraria doesn't speak HTTP. It's raw TCP on port 7777, and the Sprites reverse proxy has no idea what to do with a game client trying to establish a proprietary binary connection. The packets hit Cloudflare's edge and get rejected as malformed HTTP.

There's `sprite proxy` for TCP traffic, but it only forwards to your **local machine**. Great for development, useless for a kid in another state trying to join the server.

**Verdict**: Sprites are fantastic for web services. For raw TCP game servers? Dead end.

## Stop 2: Cloudflare Tunnel (Works, But...)

"Wait," I thought, "I have Cloudflare! Their Tunnel product can proxy arbitrary TCP!"

And it can. The `cloudflared` daemon creates outbound-only tunnels from your server to Cloudflare's edge:

```bash
# Server side
cloudflared tunnel --hostname terraria.example.com --url tcp://localhost:7777

# Client side
cloudflared access tcp --hostname terraria.example.com --url localhost:7777
```

Catch the problem? **Both sides need cloudflared installed.** Every player who wants to join needs to install software, run a command, and *then* connect their game client to localhost.

"Hey kids, before you can play, just install this daemon and run this terminal command" is not going to fly with middle schoolers. Cloudflare Spectrum can do transparent TCP proxying without client software, but that's Enterprise pricing for what should be a fun side project.

**Verdict**: Technically works, but the client requirement defeats the entire purpose.

## Stop 3: Fly.io Direct (So Close!)

Since Sprites run on Fly.io infrastructure anyway, why not deploy directly? Fly.io explicitly supports TCP services:

```toml
# fly.toml
[[services]]
  internal_port = 7777
  protocol = "tcp"

  [[services.ports]]
    port = 7777
```

I built a Docker image following the official Terraria server docs, deployed it, and watched the logs. World generation kicked off: "Creating underground houses... Placing altars... Settling liquids..."

At 55%, the machine died. Redeployed. Died again at 60%. The health checks kept failing mid-generation.

The culprit: **memory**. Terraria's world generation loads the entire map into RAM. A medium world needs around 1.2-1.5GB just for generation, before any players connect. Fly.io's `shared-cpu-1x` comes with 1GB, and the process was getting OOM-killed mid-generation.

Bumping to 2GB would work, but `shared-cpu-1x` with 2GB memory runs about $14/month. At that price, a Hetzner VPS with 2GB costs €4/month — a third of the price with more predictable behavior.

**Verdict**: TCP support is there, but RAM requirements push you toward pricier tiers where a simple VPS wins on economics.

## Stop 4: Ansible + Hetzner (The Boring Solution That Works)

Sometimes boring is beautiful. I already had an Ansible role for my Factorio server, so I duplicated the structure:

```
ansible/game_server/roles/terraria/
├── defaults/main.yaml      # Configuration variables
├── tasks/install.yml       # Download, extract, configure
├── handlers/main.yml       # Service restart handler
├── files/terraria.service  # systemd unit
└── templates/serverconfig.txt.j2
```

The key configuration:

```yaml
# defaults/main.yaml
terraria_version: "1449"
terraria_port: 7777
world_autocreate: 2        # 1=small, 2=medium, 3=large
world_difficulty: 0        # 0=normal, 1=expert, 2=master
server_password: "{{ lookup('env', 'TERRARIA_PASSWORD') | default('', true) }}"
```

Deploy with one command:

```bash
TERRARIA_PASSWORD="secret" ansible-playbook -i inventory/hosts.ini game_server/deploy_terraria.yaml
```

The world generated on the first try. The systemd service keeps it running through reboots. And critically: my son texted his friends an IP address, they typed it in, and they were playing within minutes. No downloads, no terminal commands, no "ask your dad for help."

**Verdict**: Not glamorous, but it just works.

## The Takeaways

Three days of yak-shaving for what ended up being a straightforward Ansible role. But I learned a few things worth sharing:

1. **TCP is a second-class citizen in the cloud-native world.** HTTP gets automatic TLS, edge caching, DDoS protection, and slick developer experiences. TCP gets "use a VPS." This is a real gap in the modern platform landscape.

2. **Read the networking fine print.** Sprites, Cloudflare Tunnel, and similar products are designed for web traffic. They *can* do TCP, but with caveats that matter for game servers.

3. **Memory requirements hide in unexpected places.** I expected Terraria to be lightweight. World generation eating 1.5GB caught me off guard. Always check resource usage during initialization, not just steady-state operation.

4. **Sometimes the old ways are best.** A €4/month VPS with a systemd service isn't exciting, but it's predictable, debuggable, and doesn't require explaining TCP tunneling to twelve-year-olds.

The Fly.io Docker config is still in the repo — maybe I'll revisit it when Fly offers better small-instance RAM options. But for now, the Hetzner server is humming along, the world has been thoroughly explored, and I'm told the Eye of Cthulhu didn't stand a chance.

Mission accomplished.
