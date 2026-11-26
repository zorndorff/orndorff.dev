+++
title = "jq, Meet DuckDB: Streaming JSON Filters at 5.6 GB/s From a SQL Prompt"
date = "2026-11-25"
categories = ["Engineering", "Data"]
tags = ["duckdb", "jq", "json", "benchmark", "cli", "performance", "simdjson"]
type = "posts"
description = "Lemire's sjq benchmark, redone with the DuckDB 2.0 CLI reading JSON from stdin: 10-36x faster than jq, capped by pipes, and not as streaming as it looks."
draft = false
+++

<style>
.bv{--s1:#2a78d6;--s2:#eb6834;--s3:#1baf7a;font:13px/1.35 system-ui,-apple-system,Segoe UI,sans-serif;margin:1.6em 0;color:var(--primary)}
.dark .bv{--s1:#3987e5;--s2:#d95926;--s3:#199e70}
.bv svg{width:100%;height:auto;display:block;overflow:visible}
.bv .t{fill:var(--primary)}.bv .m{fill:var(--secondary)}.bv .g{stroke:var(--border);stroke-width:1}
.bv .cap{color:var(--secondary);font-size:12.5px;margin-top:.4em}
.bv .lg{display:flex;gap:1.1em;flex-wrap:wrap;margin:.2em 0 .5em;font-size:12.5px;color:var(--secondary)}
.bv .lg i{display:inline-block;width:11px;height:11px;border-radius:3px;margin-right:.35em;vertical-align:-1px}
.bv .tabs{display:flex;gap:.4em;margin-bottom:.4em}
.bv .tabs button{font:inherit;font-size:12.5px;padding:.3em .8em;border-radius:99px;border:1px solid var(--border);background:var(--theme);color:var(--secondary);cursor:pointer}
.bv .tabs button[aria-pressed=true]{background:var(--primary);color:var(--theme);border-color:var(--primary)}
.bv rect.hit:hover+rect,.bv rect:hover{opacity:.82}
.bv-hero{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:1.6em 0}
.bv-hero div{border:1px solid var(--border);border-radius:12px;padding:14px 14px 12px;background:var(--entry)}
.bv-hero b{display:block;font-size:30px;line-height:1.05;letter-spacing:-.02em;color:var(--primary);font-variant-numeric:tabular-nums}
.bv-hero span{display:block;font-size:12.5px;color:var(--secondary);margin-top:6px}
.bv table{font-size:12.5px;font-variant-numeric:tabular-nums}
</style>

This morning Daniel Lemire published
[Command-line JSON filtering at 20 GB/s](https://lemire.me/blog/2026/11/25/command-line-json-filtering-at-20-gb-s/).
It introduces [sjq](https://github.com/simdjson/sjq), which runs the jq language on top of simdjson.
On his 64-core Xeon, jq needs 11.5 seconds to pull `.user.screen_name` out of 1 GB of tweets.
sjq does it in 0.31 s on one thread and 0.05 s on 32.

My first thought was: *I already have a vectorized, multithreaded JSON engine on my PATH. It's called DuckDB.*
DuckDB 2.0's CLI reads `/dev/stdin` and writes to stdout like any other Unix filter.
So I took Lemire's nine workloads and his data generator, and wrote each jq filter as a SQL query.
Then I timed both tools with input streaming in on stdin.

<div class="bv-hero"><div><b>5.6 GB/s</b><span>pull one field out of 1 GB of NDJSON (stdin from file)</span></div><div><b>35.8×</b><span>faster than jq on that same job</span></div><div><b>1.63 GB/s</b><span>the same query through a real <code>cat |</code> pipe</span></div><div><b>4.7 GiB</b><span>peak memory for that pipe run (jq: 4 MiB)</span></div></div>

**The short version:** on newline-delimited JSON, DuckDB beats jq by **4.4–7.6×** on a single thread, through a plain pipe.
Let it use every core and fed from a file, it reaches **35.8×**.
The two catches, a pipe that caps it and memory that is anything but streaming, turned out to be the most interesting part.
All the scripts and raw hyperfine results are in [zorndorff/streaming-duckdb-bench](https://github.com/zorndorff/streaming-duckdb-bench).

## The setup

The inputs are the same files Lemire used, built by his `make_data.py` from simdjson's `twitter.json`:

- `tweets.ndjson`: 1 GB, one tweet per line (230,138 lines).
- `timeline.json`: one 840 MB pretty-printed `{"statuses": [...]}` document.

The machine is my desk box, an AMD Ryzen AI MAX+ 395 with 32 threads, running jq 1.8.2, DuckDB v2.0.0 and hyperfine 2.0.
It is a different machine from Lemire's, so don't compare my numbers with his directly.
(jq alone takes 6.9 s here against his 11.5 s.)

The trick on the DuckDB side is not to let it infer a schema.
`read_json` would build a full typed struct for every tweet, nested entities and all.
`read_ndjson_objects` hands back each line as a raw `JSON` value, and the `->>` operator pulls out only the path you ask for.
That's the SQL version of sjq's "parse only what the filter needs", and it was about 5× faster than schema inference in my first tests:

```bash
# jq -r .user.screen_name
cat tweets.ndjson | duckdb -list -noheader -c \
  "SELECT json->>'\$.user.screen_name' FROM read_ndjson_objects('/dev/stdin')"
```

One DuckDB 2.0 gotcha: the CLI now has an "agent mode". If an AI-agent environment variable is set and stdout isn't a terminal, it switches to markdown tables with row caps.
That's great for Claude and terrible for a Unix filter, so the bench passes `-no-agent -no-init` explicitly.

Every one of the nine queries is checked against jq with md5 at full size, at 1 and 32 threads, through both a pipe and a redirect.
**The output is byte-for-byte identical**, with a few honest asterisks I cover at the end.

## The results

There are two ways to "stream into stdin", and DuckDB cares a lot about which one you use:

- **Pipe:** `cat file | duckdb …`. stdin is a real pipe and can't be seeked.
- **Redirect:** `duckdb … < file`. stdin is still a file descriptor, but the kernel hands DuckDB a regular, seekable file.

Use the tabs to switch between them:

<div class="bv" id="bv-bars">
<div class="tabs" role="group" aria-label="input mode">
<button aria-pressed="true" data-m="pipe">pipe: cat file | duckdb</button>
<button aria-pressed="false" data-m="redirect">redirect: duckdb &lt; file</button>
</div><div class="lg"><span><i style="background:var(--s1)"></i>jq 1.8.2</span><span><i style="background:var(--s2)"></i>DuckDB, 1 thread</span><span><i style="background:var(--s3)"></i>DuckDB, 32 threads</span></div>
<div data-p="pipe"><svg viewBox="0 0 720 429" role="img" aria-label="Throughput in GB/s per workload"><line class="g" x1="168.0" x2="168.0" y1="14" y2="425"/><text class="m" x="168.0" y="10" text-anchor="middle" font-size="11">0 GB/s</text><line class="g" x1="249.3" x2="249.3" y1="14" y2="425"/><text class="m" x="249.3" y="10" text-anchor="middle" font-size="11">1 GB/s</text><line class="g" x1="330.7" x2="330.7" y1="14" y2="425"/><text class="m" x="330.7" y="10" text-anchor="middle" font-size="11">2 GB/s</text><line class="g" x1="412.0" x2="412.0" y1="14" y2="425"/><text class="m" x="412.0" y="10" text-anchor="middle" font-size="11">3 GB/s</text><line class="g" x1="493.3" x2="493.3" y1="14" y2="425"/><text class="m" x="493.3" y="10" text-anchor="middle" font-size="11">4 GB/s</text><line class="g" x1="574.7" x2="574.7" y1="14" y2="425"/><text class="m" x="574.7" y="10" text-anchor="middle" font-size="11">5 GB/s</text><line class="g" x1="656.0" x2="656.0" y1="14" y2="425"/><text class="m" x="656.0" y="10" text-anchor="middle" font-size="11">6 GB/s</text><text class="t" x="158" y="43.5" text-anchor="end">minify (-c .)</text><rect x="168" y="24" width="6.1" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · minify (-c .): 0.07 GB/s (14.335 s)</title></rect><text class="m" x="179.1" y="32" font-size="10.5">0.07</text><rect x="168" y="35" width="46.4" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · minify (-c .): 0.57 GB/s (1.882 s)</title></rect><text class="m" x="219.4" y="43" font-size="10.5">0.57</text><rect x="168" y="46" width="69.6" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · minify (-c .): 0.86 GB/s (1.255 s)</title></rect><text class="m" x="242.6" y="54" font-size="10.5">0.86</text><text class="t" x="158" y="88.5" text-anchor="end">pretty-print (.)</text><rect x="168" y="69" width="5.6" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · pretty-print (.): 0.07 GB/s (15.587 s)</title></rect><text class="m" x="178.6" y="77" font-size="10.5">0.07</text><rect x="168" y="80" width="42.7" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · pretty-print (.): 0.53 GB/s (2.043 s)</title></rect><text class="m" x="215.7" y="88" font-size="10.5">0.53</text><rect x="168" y="91" width="66.9" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · pretty-print (.): 0.82 GB/s (1.304 s)</title></rect><text class="m" x="239.9" y="99" font-size="10.5">0.82</text><text class="t" x="158" y="133.5" text-anchor="end">extract a field</text><rect x="168" y="114" width="12.6" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · extract a field: 0.16 GB/s (6.913 s)</title></rect><text class="m" x="185.6" y="122" font-size="10.5">0.16</text><rect x="168" y="125" width="70.5" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · extract a field: 0.87 GB/s (1.238 s)</title></rect><text class="m" x="243.5" y="133" font-size="10.5">0.87</text><rect x="168" y="136" width="132.2" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · extract a field: 1.63 GB/s (0.660 s)</title></rect><text class="m" x="305.2" y="144" font-size="10.5">1.63</text><text class="t" x="158" y="178.5" text-anchor="end">select and build objects</text><rect x="168" y="159" width="12.6" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · select and build objects: 0.15 GB/s (6.948 s)</title></rect><text class="m" x="185.6" y="167" font-size="10.5">0.15</text><rect x="168" y="170" width="68.2" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · select and build objects: 0.84 GB/s (1.280 s)</title></rect><text class="m" x="241.2" y="178" font-size="10.5">0.84</text><rect x="168" y="181" width="132.4" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · select and build objects: 1.63 GB/s (0.659 s)</title></rect><text class="m" x="305.4" y="189" font-size="10.5">1.63</text><text class="t" x="158" y="223.5" text-anchor="end">string interpolation</text><rect x="168" y="204" width="12.3" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · string interpolation: 0.15 GB/s (7.105 s)</title></rect><text class="m" x="185.3" y="212" font-size="10.5">0.15</text><rect x="168" y="215" width="54.6" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · string interpolation: 0.67 GB/s (1.599 s)</title></rect><text class="m" x="227.6" y="223" font-size="10.5">0.67</text><rect x="168" y="226" width="123.7" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · string interpolation: 1.52 GB/s (0.706 s)</title></rect><text class="m" x="296.7" y="234" font-size="10.5">1.52</text><text class="t" x="158" y="268.5" text-anchor="end">regular expression</text><rect x="168" y="249" width="5.7" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · regular expression: 0.07 GB/s (15.231 s)</title></rect><text class="m" x="178.7" y="257" font-size="10.5">0.07</text><rect x="168" y="260" width="43.8" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · regular expression: 0.54 GB/s (1.992 s)</title></rect><text class="m" x="216.8" y="268" font-size="10.5">0.54</text><rect x="168" y="271" width="118.5" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · regular expression: 1.46 GB/s (0.737 s)</title></rect><text class="m" x="291.5" y="279" font-size="10.5">1.46</text><text class="t" x="158" y="313.5" text-anchor="end">count elements (1 doc)</text><rect x="168" y="294" width="10.5" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · count elements: 0.13 GB/s (6.500 s)</title></rect><text class="m" x="183.5" y="302" font-size="10.5">0.13</text><rect x="168" y="305" width="28.1" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · count elements: 0.35 GB/s (2.431 s)</title></rect><text class="m" x="201.1" y="313" font-size="10.5">0.35</text><rect x="168" y="316" width="27.9" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · count elements: 0.34 GB/s (2.453 s)</title></rect><text class="m" x="200.9" y="324" font-size="10.5">0.34</text><text class="t" x="158" y="358.5" text-anchor="end">minify (-c .) (1 doc)</text><rect x="168" y="339" width="6.2" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · minify (-c .): 0.08 GB/s (11.026 s)</title></rect><text class="m" x="179.2" y="347" font-size="10.5">0.08</text><rect x="168" y="350" width="24.1" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · minify (-c .): 0.30 GB/s (2.833 s)</title></rect><text class="m" x="197.1" y="358" font-size="10.5">0.30</text><rect x="168" y="361" width="24.1" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · minify (-c .): 0.30 GB/s (2.834 s)</title></rect><text class="m" x="197.1" y="369" font-size="10.5">0.30</text><text class="t" x="158" y="403.5" text-anchor="end">group_by (1 doc)</text><rect x="168" y="384" width="9.9" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · group_by: 0.12 GB/s (6.915 s)</title></rect><text class="m" x="182.9" y="392" font-size="10.5">0.12</text><rect x="168" y="395" width="27.0" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · group_by: 0.33 GB/s (2.531 s)</title></rect><text class="m" x="200.0" y="403" font-size="10.5">0.33</text><rect x="168" y="406" width="26.9" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · group_by: 0.33 GB/s (2.546 s)</title></rect><text class="m" x="199.9" y="414" font-size="10.5">0.33</text></svg></div>
<div data-p="redirect" hidden><svg viewBox="0 0 720 429" role="img" aria-label="Throughput in GB/s per workload"><line class="g" x1="168.0" x2="168.0" y1="14" y2="425"/><text class="m" x="168.0" y="10" text-anchor="middle" font-size="11">0 GB/s</text><line class="g" x1="249.3" x2="249.3" y1="14" y2="425"/><text class="m" x="249.3" y="10" text-anchor="middle" font-size="11">1 GB/s</text><line class="g" x1="330.7" x2="330.7" y1="14" y2="425"/><text class="m" x="330.7" y="10" text-anchor="middle" font-size="11">2 GB/s</text><line class="g" x1="412.0" x2="412.0" y1="14" y2="425"/><text class="m" x="412.0" y="10" text-anchor="middle" font-size="11">3 GB/s</text><line class="g" x1="493.3" x2="493.3" y1="14" y2="425"/><text class="m" x="493.3" y="10" text-anchor="middle" font-size="11">4 GB/s</text><line class="g" x1="574.7" x2="574.7" y1="14" y2="425"/><text class="m" x="574.7" y="10" text-anchor="middle" font-size="11">5 GB/s</text><line class="g" x1="656.0" x2="656.0" y1="14" y2="425"/><text class="m" x="656.0" y="10" text-anchor="middle" font-size="11">6 GB/s</text><text class="t" x="158" y="43.5" text-anchor="end">minify (-c .)</text><rect x="168" y="24" width="6.2" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · minify (-c .): 0.08 GB/s (14.189 s)</title></rect><text class="m" x="179.2" y="32" font-size="10.5">0.08</text><rect x="168" y="35" width="61.5" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · minify (-c .): 0.76 GB/s (1.421 s)</title></rect><text class="m" x="234.5" y="43" font-size="10.5">0.76</text><rect x="168" y="46" width="91.1" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · minify (-c .): 1.12 GB/s (0.959 s)</title></rect><text class="m" x="264.1" y="54" font-size="10.5">1.12</text><text class="t" x="158" y="88.5" text-anchor="end">pretty-print (.)</text><rect x="168" y="69" width="5.6" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · pretty-print (.): 0.07 GB/s (15.519 s)</title></rect><text class="m" x="178.6" y="77" font-size="10.5">0.07</text><rect x="168" y="80" width="54.7" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · pretty-print (.): 0.67 GB/s (1.596 s)</title></rect><text class="m" x="227.7" y="88" font-size="10.5">0.67</text><rect x="168" y="91" width="80.0" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · pretty-print (.): 0.98 GB/s (1.091 s)</title></rect><text class="m" x="253.0" y="99" font-size="10.5">0.98</text><text class="t" x="158" y="133.5" text-anchor="end">extract a field</text><rect x="168" y="114" width="12.7" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · extract a field: 0.16 GB/s (6.864 s)</title></rect><text class="m" x="185.7" y="122" font-size="10.5">0.16</text><rect x="168" y="125" width="111.0" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · extract a field: 1.37 GB/s (0.786 s)</title></rect><text class="m" x="284.0" y="133" font-size="10.5">1.37</text><rect x="168" y="136" width="455.4" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · extract a field: 5.60 GB/s (0.192 s)</title></rect><text class="m" x="628.4" y="144" font-size="10.5">5.60</text><text class="t" x="158" y="178.5" text-anchor="end">select and build objects</text><rect x="168" y="159" width="12.7" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · select and build objects: 0.16 GB/s (6.878 s)</title></rect><text class="m" x="185.7" y="167" font-size="10.5">0.16</text><rect x="168" y="170" width="106.4" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · select and build objects: 1.31 GB/s (0.821 s)</title></rect><text class="m" x="279.4" y="178" font-size="10.5">1.31</text><rect x="168" y="181" width="447.1" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · select and build objects: 5.50 GB/s (0.195 s)</title></rect><text class="m" x="620.1" y="189" font-size="10.5">5.50</text><text class="t" x="158" y="223.5" text-anchor="end">string interpolation</text><rect x="168" y="204" width="12.2" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · string interpolation: 0.15 GB/s (7.138 s)</title></rect><text class="m" x="185.2" y="212" font-size="10.5">0.15</text><rect x="168" y="215" width="76.0" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · string interpolation: 0.93 GB/s (1.149 s)</title></rect><text class="m" x="249.0" y="223" font-size="10.5">0.93</text><rect x="168" y="226" width="335.8" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · string interpolation: 4.13 GB/s (0.260 s)</title></rect><text class="m" x="508.8" y="234" font-size="10.5">4.13</text><text class="t" x="158" y="268.5" text-anchor="end">regular expression</text><rect x="168" y="249" width="5.7" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · regular expression: 0.07 GB/s (15.195 s)</title></rect><text class="m" x="178.7" y="257" font-size="10.5">0.07</text><rect x="168" y="260" width="56.3" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · regular expression: 0.69 GB/s (1.552 s)</title></rect><text class="m" x="229.3" y="268" font-size="10.5">0.69</text><rect x="168" y="271" width="132.5" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · regular expression: 1.63 GB/s (0.659 s)</title></rect><text class="m" x="305.5" y="279" font-size="10.5">1.63</text><text class="t" x="158" y="313.5" text-anchor="end">count elements (1 doc)</text><rect x="168" y="294" width="10.4" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · count elements: 0.13 GB/s (6.547 s)</title></rect><text class="m" x="183.4" y="302" font-size="10.5">0.13</text><rect x="168" y="305" width="31.4" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · count elements: 0.39 GB/s (2.177 s)</title></rect><text class="m" x="204.4" y="313" font-size="10.5">0.39</text><rect x="168" y="316" width="31.4" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · count elements: 0.39 GB/s (2.175 s)</title></rect><text class="m" x="204.4" y="324" font-size="10.5">0.39</text><text class="t" x="158" y="358.5" text-anchor="end">minify (-c .) (1 doc)</text><rect x="168" y="339" width="6.2" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · minify (-c .): 0.08 GB/s (11.025 s)</title></rect><text class="m" x="179.2" y="347" font-size="10.5">0.08</text><rect x="168" y="350" width="26.5" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · minify (-c .): 0.33 GB/s (2.579 s)</title></rect><text class="m" x="199.5" y="358" font-size="10.5">0.33</text><rect x="168" y="361" width="26.8" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · minify (-c .): 0.33 GB/s (2.556 s)</title></rect><text class="m" x="199.8" y="369" font-size="10.5">0.33</text><text class="t" x="158" y="403.5" text-anchor="end">group_by (1 doc)</text><rect x="168" y="384" width="9.8" height="9" rx="2" fill="var(--s1)"><title>jq 1.8.2 · group_by: 0.12 GB/s (6.956 s)</title></rect><text class="m" x="182.8" y="392" font-size="10.5">0.12</text><rect x="168" y="395" width="30.4" height="9" rx="2" fill="var(--s2)"><title>DuckDB, 1 thread · group_by: 0.37 GB/s (2.246 s)</title></rect><text class="m" x="203.4" y="403" font-size="10.5">0.37</text><rect x="168" y="406" width="30.5" height="9" rx="2" fill="var(--s3)"><title>DuckDB, 32 threads · group_by: 0.37 GB/s (2.245 s)</title></rect><text class="m" x="203.5" y="414" font-size="10.5">0.37</text></svg></div>
<div class="cap">Throughput = input bytes ÷ mean wall time (hyperfine, 3 runs of jq, 10 of DuckDB). Higher is better. Same scale on both tabs.</div>
<script>(function(){var r=document.getElementById("bv-bars");r.querySelectorAll("button").forEach(function(b){b.onclick=function(){r.querySelectorAll("button").forEach(function(x){x.setAttribute("aria-pressed",x===b)});r.querySelectorAll("[data-p]").forEach(function(p){p.hidden=p.dataset.p!==b.dataset.m})}})})();</script>
</div>

jq is a flat 0.07–0.16 GB/s whichever way you feed it.
DuckDB's best NDJSON number goes from **1.63 GB/s** through a pipe to **5.60 GB/s** with a redirect.

<details><summary>Full numbers (mean seconds)</summary>

| workload | jq | pipe 1t | pipe 32t | pipe vs jq | redirect 1t | redirect 32t | redirect vs jq |
|---|---|---|---|---|---|---|---|
| minify (-c .) | 14.34 s | 1.88 s | 1.26 s | 11.4× | 1.42 s | 0.96 s | 14.8× |
| pretty-print (.) | 15.59 s | 2.04 s | 1.30 s | 11.9× | 1.60 s | 1.09 s | 14.2× |
| extract a field | 6.91 s | 1.24 s | 0.66 s | 10.5× | 0.79 s | 0.19 s | 35.8× |
| select and build objects | 6.95 s | 1.28 s | 0.66 s | 10.5× | 0.82 s | 0.20 s | 35.2× |
| string interpolation | 7.10 s | 1.60 s | 0.71 s | 10.1× | 1.15 s | 0.26 s | 27.4× |
| regular expression | 15.23 s | 1.99 s | 0.74 s | 20.7× | 1.55 s | 0.66 s | 23.1× |
| count elements (doc) | 6.50 s | 2.43 s | 2.45 s | 2.6× | 2.18 s | 2.17 s | 3.0× |
| minify (-c .) (doc) | 11.03 s | 2.83 s | 2.83 s | 3.9× | 2.58 s | 2.56 s | 4.3× |
| group_by (doc) | 6.92 s | 2.53 s | 2.55 s | 2.7× | 2.25 s | 2.24 s | 3.1× |

</details>

## The pipe is the ceiling, and threads past four make it worse

Is the pipe itself too slow? No: `cat tweets.ndjson | cat > /dev/null` moves the whole gigabyte in 0.16 s, about 6.7 GB/s.
The limit is how DuckDB *consumes* a non-seekable stream.
My guess, which I haven't verified in DuckDB's source: with a regular file every thread can seek to its own byte range, but with a pipe the stream has to be read in order and handed out, and that serial step becomes the bottleneck.

I swept `SET threads=N` on the field-extraction query:

<div class="bv"><svg viewBox="0 0 720 270" role="img" aria-label="DuckDB throughput vs threads, pipe vs redirect"><line class="g" x1="56" x2="630" y1="236.0" y2="236.0"/><text class="m" x="48" y="240.0" text-anchor="end" font-size="11">0</text><line class="g" x1="56" x2="630" y1="206.0" y2="206.0"/><text class="m" x="48" y="210.0" text-anchor="end" font-size="11">1</text><line class="g" x1="56" x2="630" y1="176.0" y2="176.0"/><text class="m" x="48" y="180.0" text-anchor="end" font-size="11">2</text><line class="g" x1="56" x2="630" y1="146.0" y2="146.0"/><text class="m" x="48" y="150.0" text-anchor="end" font-size="11">3</text><line class="g" x1="56" x2="630" y1="116.0" y2="116.0"/><text class="m" x="48" y="120.0" text-anchor="end" font-size="11">4</text><line class="g" x1="56" x2="630" y1="86.0" y2="86.0"/><text class="m" x="48" y="90.0" text-anchor="end" font-size="11">5</text><line class="g" x1="56" x2="630" y1="56.0" y2="56.0"/><text class="m" x="48" y="60.0" text-anchor="end" font-size="11">6</text><line class="g" x1="56" x2="630" y1="26.0" y2="26.0"/><text class="m" x="48" y="30.0" text-anchor="end" font-size="11">7</text><text class="m" x="56.0" y="256" text-anchor="middle" font-size="11">1</text><text class="m" x="170.8" y="256" text-anchor="middle" font-size="11">2</text><text class="m" x="285.6" y="256" text-anchor="middle" font-size="11">4</text><text class="m" x="400.4" y="256" text-anchor="middle" font-size="11">8</text><text class="m" x="515.2" y="256" text-anchor="middle" font-size="11">16</text><text class="m" x="630.0" y="256" text-anchor="middle" font-size="11">32</text><text class="m" x="343.0" y="269" text-anchor="middle" font-size="11">threads (SET threads=N)</text><text class="m" x="48" y="22" text-anchor="end" font-size="11">GB/s</text><path d="M56.0,194.2 L170.8,162.8 L285.6,124.9 L400.4,74.9 L515.2,57.0 L630.0,57.0" fill="none" stroke="var(--s3)" stroke-width="2" stroke-dasharray=""/><circle cx="56.0" cy="194.2" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>redirect, 1 threads: 1.39 GB/s, peak RSS 180 MiB</title></circle><circle cx="170.8" cy="162.8" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>redirect, 2 threads: 2.44 GB/s, peak RSS 324 MiB</title></circle><circle cx="285.6" cy="124.9" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>redirect, 4 threads: 3.70 GB/s, peak RSS 536 MiB</title></circle><circle cx="400.4" cy="74.9" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>redirect, 8 threads: 5.37 GB/s, peak RSS 1026 MiB</title></circle><circle cx="515.2" cy="57.0" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>redirect, 16 threads: 5.97 GB/s, peak RSS 2011 MiB</title></circle><circle cx="630.0" cy="57.0" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>redirect, 32 threads: 5.97 GB/s, peak RSS 3840 MiB</title></circle><text class="t" x="640.0" y="61.0" font-size="12">&lt; file</text><path d="M56.0,209.4 L170.8,190.0 L285.6,162.8 L400.4,164.4 L515.2,171.6 L630.0,184.9" fill="none" stroke="var(--s3)" stroke-width="2" stroke-dasharray="6 5"/><circle cx="56.0" cy="209.4" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>pipe, 1 threads: 0.89 GB/s, peak RSS 1206 MiB</title></circle><circle cx="170.8" cy="190.0" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>pipe, 2 threads: 1.53 GB/s, peak RSS 1367 MiB</title></circle><circle cx="285.6" cy="162.8" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>pipe, 4 threads: 2.44 GB/s, peak RSS 1547 MiB</title></circle><circle cx="400.4" cy="164.4" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>pipe, 8 threads: 2.39 GB/s, peak RSS 2027 MiB</title></circle><circle cx="515.2" cy="171.6" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>pipe, 16 threads: 2.15 GB/s, peak RSS 2989 MiB</title></circle><circle cx="630.0" cy="184.9" r="4.5" fill="var(--s3)" stroke="var(--theme)" stroke-width="2"><title>pipe, 32 threads: 1.70 GB/s, peak RSS 4863 MiB</title></circle><text class="t" x="640.0" y="188.9" font-size="12">cat |</text><text class="m" x="285.6" y="150.8" text-anchor="middle" font-size="11">pipe peaks at 4 threads</text></svg><div class="cap">Workload 03 (<code>.user.screen_name</code>) on the 1 GB NDJSON file, best of 3 runs per point. Solid: stdin redirected from the file. Dashed: stdin is a real pipe.</div></div>

With a redirect, it scales nicely up to about 16 threads.
Through a pipe it tops out around **4 threads** at roughly 2.4 GB/s, then gets *slower* as more threads are added.
If you have to pipe into DuckDB, try `SET threads=4`. On this workload and machine it beat the default, but that's one query measured best-of-3, so check it on yours.

## "Streaming" is doing a lot of work in that sentence

This is the part that surprised me.
jq really is a streaming filter: its peak RSS was **4 MiB** on every NDJSON workload.
DuckDB is a query engine that happens to read a stream:

| workload | jq | DuckDB 1t, pipe | DuckDB 32t, pipe | DuckDB 1t, redirect | DuckDB 32t, redirect |
|---|---|---|---|---|---|
| 03 extract a field | 4 MiB | 1,205 MiB | 4,857 MiB | 181 MiB | 3,837 MiB |
| 06 regular expression | 4 MiB | 1,346 MiB | 6,610 MiB | 312 MiB | 5,556 MiB |
| 08 minify (-c .) (doc) | 3,357 MiB | 6,285 MiB | 6,287 MiB | 5,484 MiB | 5,486 MiB |


Through a pipe on one thread, DuckDB's peak memory is about the size of the input.
It looks like it buffers the stream rather than processing it in bounded memory.
`… | head -1` doesn't save you either: it still read the full gigabyte, in the same time and the same ~5 GB of memory.
Switching the output to `COPY … TO '/dev/stdout'`, or setting `preserve_insertion_order=false`, made no difference.
For a 1 GB file on a 128 GB box that's fine. For an endless `tail -f` log, reach for jq or sjq.

## One big document: modest wins, and one trap

On the single 840 MB `timeline.json`, DuckDB wins by 3.0–4.3× and gets **no** benefit from threads.
That makes sense: it's one JSON value, so it's one parse.

The trap was `group_by`. My first version did the natural SQL thing: `unnest` the statuses array, then `GROUP BY`.
It produced the correct answer… in **32.1 seconds**, which is *nearly five times slower than jq*, with most of that time spent in the kernel.
Pulling the strings out takes 2.5 s; the `unnest` cost the other 30.
My best guess, which I haven't proven, is that each chunk `unnest` emits drags the 840 MB source value along with it.
The fix is to never unnest at all and aggregate inside the list:

```sql
SELECT to_json(list_transform(
         list_sort(map_entries(list_histogram(
           json_extract_string(json, '$.statuses[*].user.lang')))),
         lambda e: {'lang': e.key, 'n': e.value}))
FROM read_json_objects('/dev/stdin', format='unstructured',
                       maximum_object_size=4000000000);
```

<div class="bv"><svg viewBox="0 0 720 114" role="img" aria-label="group_by on the 840 MB document: seconds"><defs><pattern id="bv-hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="6" height="6" fill="var(--s3)"/><line x1="0" y1="0" x2="0" y2="6" stroke="var(--theme)" stroke-width="2.4"/></pattern></defs><line class="g" x1="230.0" x2="230.0" y1="14" y2="110"/><text class="m" x="230.0" y="10" text-anchor="middle" font-size="11">0 s</text><line class="g" x1="290.0" x2="290.0" y1="14" y2="110"/><text class="m" x="290.0" y="10" text-anchor="middle" font-size="11">5 s</text><line class="g" x1="350.0" x2="350.0" y1="14" y2="110"/><text class="m" x="350.0" y="10" text-anchor="middle" font-size="11">10 s</text><line class="g" x1="410.0" x2="410.0" y1="14" y2="110"/><text class="m" x="410.0" y="10" text-anchor="middle" font-size="11">15 s</text><line class="g" x1="470.0" x2="470.0" y1="14" y2="110"/><text class="m" x="470.0" y="10" text-anchor="middle" font-size="11">20 s</text><line class="g" x1="530.0" x2="530.0" y1="14" y2="110"/><text class="m" x="530.0" y="10" text-anchor="middle" font-size="11">25 s</text><line class="g" x1="590.0" x2="590.0" y1="14" y2="110"/><text class="m" x="590.0" y="10" text-anchor="middle" font-size="11">30 s</text><line class="g" x1="650.0" x2="650.0" y1="14" y2="110"/><text class="m" x="650.0" y="10" text-anchor="middle" font-size="11">35 s</text><text class="t" x="220" y="37" text-anchor="end">jq 1.8.2</text><rect x="230" y="24" width="83.0" height="18" rx="3" fill="var(--s1)"><title>jq 1.8.2: 6.92 s</title></rect><text class="t" x="319.0" y="37" font-size="12">6.9 s</text><text class="t" x="220" y="67" text-anchor="end">DuckDB: unnest + GROUP BY</text><rect x="230" y="54" width="385.1" height="18" rx="3" fill="url(#bv-hatch)"><title>DuckDB: unnest + GROUP BY: 32.09 s</title></rect><text class="t" x="621.1" y="67" font-size="12">32.1 s</text><text class="t" x="220" y="97" text-anchor="end">DuckDB: list_histogram</text><rect x="230" y="84" width="30.6" height="18" rx="3" fill="var(--s3)"><title>DuckDB: list_histogram: 2.55 s</title></rect><text class="t" x="266.6" y="97" font-size="12">2.5 s</text></svg><div class="cap"><code>.statuses | group_by(.user.lang)</code> on the single 840 MB document, piped in. Lower is better. Same output, byte for byte.</div></div>

## Fine print

- **Pretty-print (02):** DuckDB's `json_pretty` indents by 4 spaces. Its output is byte-identical to `jq --indent 4 .`, but the benchmark times plain `jq .`.
- **Minify (01, 08):** these use `json(json)`, which really parses and re-serializes. A bare `SELECT json` would be a passthrough and would only "match" because the input is already compact.
- **Regex (06):** DuckDB's optimizer quietly rewrites `regexp_matches(t, 'rt')` into `contains(t, 'rt')`, so the headline number isn't a regex at all. Forcing RE2 with the equivalent pattern `'(rt)'` gives the same output and was actually *faster*: 1.07 s on 1 thread and 0.45 s on 32, both with a redirect. Also, `lower()` is Unicode-aware while jq's `ascii_downcase` isn't. They agree on this data, but not on every input.
- **Equivalence is per dataset.** The SQL matches jq on these files, but NULL printing, missing fields and malformed lines would behave differently.
- **No sjq row.** I didn't run sjq on this machine, so I can't put it on these charts. The harness takes `SJQ=/path/to/sjq` if you want the real head-to-head.
- **Method:** hyperfine with 3 runs of jq and 10 of DuckDB, one warm-up each, and the files in page cache. The 1-thread runs aren't CPU-pinned.

## So, should you alias jq to DuckDB?

No, but you should know it's there.
jq is still the better *language* for poking at JSON, and sjq (go read Lemire's post) is in a different league for raw speed.
What surprised me is how far a general-purpose SQL engine gets just by reading stdin.
It's 10.5× faster than jq through a pipe, and 35.8× when it can seek, with byte-identical output.
And the moment the filter turns into a join, a window function or a `GROUP BY` over a hundred files, you're already holding the right tool.

Run it yourself:

```bash
git clone https://github.com/zorndorff/streaming-duckdb-bench && cd streaming-duckdb-bench
scripts/make_data.sh && scripts/verify.sh && scripts/run_bench.sh
INPUT=redirect scripts/run_bench.sh
```
