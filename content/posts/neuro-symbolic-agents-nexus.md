+++
date = "2026-04-09"
title = "Small LLMs, Big Reasoning: How a Neuro-Symbolic Expert System Makes Haiku Agents Reliable"
categories = ["AI", "Engineering"]
tags = ["llm", "expert-systems", "agents", "nexus", "ecs", "duckdb"]
type = "posts"
draft = false
+++

There's a dirty secret in the AI agent space: most agent frameworks hand the model a bag of tools and pray. The model decides what to query, how to reason about results, and what conclusions to draw. For demos, this works great. For anything you'd actually bet your job on — compliance audits, student intervention decisions, infrastructure monitoring — it's a liability.

What if the model didn't have to reason at all?

I've been building [Nexus](https://github.com/SandwichLabs/nexus), a neuro-symbolic expert system that splits the work: the LLM handles perception (understanding what you're asking), and a deterministic rule engine handles reasoning (evaluating conditions, firing rules, producing conclusions). The results are traceable, reproducible, and — here's the kicker — work with models as small as Haiku.

## The Problem with Pure-LLM Agents

When you ask GPT-4 or Claude to analyze a dataset, you're asking it to do everything at once: parse the data, figure out what matters, apply domain logic, and generate conclusions. Every step is probabilistic. Run it twice, get different answers. Ask it to explain why it flagged an account and you get a plausible-sounding narrative that may or may not match what actually happened.

For brainstorming? Fine. For compliance?

- **"Why was this account flagged for structuring?"** needs a traceable answer, not a vibes-based one.
- **"Why is this student on academic probation?"** has a specific, rule-based answer that parents and administrators need to verify.
- **"Why did this device get marked as degraded?"** should point to the exact threshold violation, not an LLM's interpretation of "it seemed off."

LLMs are great at understanding language. They're terrible at consistent, auditable reasoning over structured data. I think most people building agent systems know this, but the tooling hasn't caught up yet.

## The Split: Perception vs. Reasoning

Nexus is built on a pretty simple architectural bet: **use the LLM for what it's good at, use deterministic code for what it's not.**

Three layers:

1. **LLM Perception Layer** — Translates natural language into structured intent. "Which students are at risk?" becomes `{domains: ["k12"], concerns: ["academic_performance", "risk"]}`. This is what models genuinely excel at.

2. **ECS Rule Engine** — A match-resolve-act cycle that evaluates rules against entity-component data. Rules are JSON definitions with condition trees (`AND`, `OR`, `GT`, `LT`, `CONTAINS`), not prompts. The engine is entirely deterministic — same input, same output, every time.

3. **DuckDB Property Graph** — Nodes, edges, and components stored with temporal versioning, hybrid search (BM25 + vector), and SQL/PGQ queries. The data layer that both the LLM and the engine operate on.

The critical insight: rules are *data*, not code. A domain expert (or an LLM, via the `teach` command) authors rules in JSON. The engine evaluates them mechanically. No model in the loop at evaluation time.

```json
{
  "name": "flag_structuring",
  "domain": "fincomp",
  "archetype": ["fincomp.Account", "fincomp.Transaction", "fincomp.VelocityMetrics"],
  "condition": {
    "op": "AND",
    "children": [
      {"op": "GT", "field": "fincomp.VelocityMetrics.txn_count_24h", "value": 5},
      {"op": "GT", "field": "fincomp.Transaction.amount", "value": 8000},
      {"op": "LT", "field": "fincomp.Transaction.amount", "value": 10000},
      {"op": "EQ", "field": "fincomp.Transaction.channel", "value": "cash"}
    ]
  },
  "actions": [
    {
      "type": "attach",
      "component": "fincomp.ComplianceFlag",
      "instance": "structuring",
      "data": {
        "flag_type": "aml_alert",
        "severity": "critical",
        "description": "Potential structuring: multiple sub-threshold cash transactions"
      }
    }
  ]
}
```

When this rule fires, you can trace exactly why: the entity had more than 5 transactions in 24 hours, the amount was between $8,000 and $10,000, and the channel was cash. No ambiguity. No hallucination. No "the model thought it looked suspicious."

## Making It Agent-Friendly

So. Here's the thing that took me longer than I'd like to admit: the expert system can be brilliant, but if the CLI is designed for humans reading text tables, an AI agent can't use it effectively.

Nexus exposes its entire state through commands designed for agentic consumption:

```bash
nexus status --format json        # System snapshot in one call
nexus entities --has iot.Alert    # Filter by component type
nexus entity "device:sensor-003"  # Full component inspection
nexus rules test alert_low_gpa --entity "Alice Johnson"  # Per-condition trace
nexus eval --diff                 # Before/after change tracking
```

These aren't afterthoughts. A Haiku agent doesn't need to be smart enough to write SQL or reason about thresholds. It just needs to call `status`, read the JSON, call `entities --has`, drill into the interesting ones, and narrate what it finds.

The model's job shrinks from "analyze everything" to "read structured results and write a coherent report." Turns out that's a task small models handle surprisingly well.

Here's what that looks like in practice — a Claude agent running an IoT status report through the Nexus CLI:

![Nexus Agent Demo](/nexus-agent-demo.gif)

## The Experiment: Three Domains, One Haiku

To actually prove this works (and not just hand-wave about it), I seeded Nexus with three completely different domains:

- **K-12 Education**: 10,000 students, 14 rules (letter grades, GPA alerts, honor roll, attendance, accommodations)
- **IoT Monitoring**: 29 devices, 7 rules (temperature thresholds, battery alerts, packet loss, maintenance schedules)
- **Financial Compliance**: 25 accounts, 8 rules (AML, sanctions screening, structuring detection, KYC expiration)

All three domains run in a single Nexus instance — 10,364 entities, 32 rules, evaluated in 3 engine cycles. Then I pointed Haiku subagents at each domain with the same instruction: "Report on the status of our [domain]."

### What Haiku Found

**K-12 Education** (16 tool calls, 127 seconds): The agent identified 1,554 students with failing grades, 1,050 on academic probation, and 2,290 on honor roll. It drilled into individual students — finding one (Carlotta Ruiz) who was flagged for missing assignments but actually showed strong GPA and active Tier 2 intervention progress. It recommended triaging the 824 missing-assignment cases for parent engagement and cross-referencing attendance warnings against social determinants. Not a boilerplate report. Contextual analysis.

**IoT Monitoring** (7 tool calls, 29 seconds): Identified 11 devices with 26 total alerts. Flagged three critical devices by severity: one completely offline (0% battery, 100% packet loss), two degraded with multiple concurrent alerts. Recommended immediate battery replacement and a signal booster for the affected zone. Done in under 30 seconds.

**Financial Compliance** (9 tool calls, 30 seconds): Found 14 flagged accounts and identified two immediate SAR-filing candidates — Aleksei Petrov (risk score 95, OFAC/EU sanctions match, $340k weekly wire volume) and Fatima Al-Rashid (risk score 92, OFAC SDN partial match). Caught a classic structuring pattern: Carlos Mendez with 22 transactions of $9,800 cash deposits just below the $10,000 reporting threshold. The agent recommended specific regulatory actions per account. Honestly, I was a little surprised how crisp the compliance findings were.

### Why This is Remarkable

None of these reports required the model to *reason* about the data. The rule engine already did the reasoning — it evaluated conditions, fired rules, attached alert components with typed severity levels and descriptions. Haiku's job was to read the structured output and present it coherently. That's why a small, fast, cheap model produces reports that are as *correct* as what a larger model would generate — the correctness comes from the engine, not the model.

The traces are fully auditable. When Haiku says "Aleksei Petrov was flagged for sanctions," you can verify exactly why:

```bash
$ nexus rules test flag_sanctions_match --entity "ACCT-015"
Rule: flag_sanctions_match
Entity: 10040 "ACCT-015"

Archetype match:
  + fincomp.Account — present
  + fincomp.SanctionsCheck — present

Condition evaluation:
  + fincomp.SanctionsCheck.match_found EQ true — actual: true -> PASS

Result: WOULD FIRE
Actions:
  attach fincomp.ComplianceFlag#sanctions {"flag_type":"sanctions_hit","severity":"critical"}
```

No black box. No "the model decided." The condition was `match_found == true`, the entity had `match_found: true`, so the rule fired. That's the kind of traceability that compliance officers, school administrators, and operations teams actually need.

## The Architecture That Makes This Work

A few design decisions that matter more than they look:

**Domain-agnostic engine.** The ECS engine never checks for specific component types like `k12.Student` or `fincomp.Account`. Rules, schemas, and component types are all data. The same engine evaluates education rules and sanctions rules without a single line of domain-specific code. (I spent way too long making sure this was true across all three test domains.)

**Keyed component instances.** An entity can have multiple components of the same type: `k12.AcademicAlert#low_gpa` and `k12.AcademicAlert#truancy` coexist on one student. This lets rules compose — a student can accumulate multiple alerts from different rules without conflict.

**Structured output, not free text.** Every command supports `--format json`. The agent never parses human-readable tables — it reads typed JSON with predictable schemas. This is probably the single biggest thing that makes small models reliable: they're not interpreting ambiguous text, they're reading structured data.

**Eval diff.** `nexus eval --diff` shows exactly what changed: which entities gained or lost components, which fields were modified and from what to what. The agent can report on changes without doing before/after comparison gymnastics.

## Why This Matters

The industry is converging on a pattern: pair LLMs with structured tools. But most implementations still ask the model to *decide* — to write queries, evaluate results, form judgments. That works until it doesn't, and when it doesn't, you can't explain why.

The neuro-symbolic split inverts this. The model doesn't decide anything about the data. It translates natural language to structured queries (perception), and it translates structured results to natural language reports (presentation). The middle part — the actual analysis, the rule evaluation, the condition checking — is deterministic code that produces the same output every time and can be audited after the fact.

What this means in practice:
- **Small models work.** Haiku at $1/M tokens produces the same *correct* findings as Opus at $15/M because correctness comes from the engine.
- **Results are traceable.** Every alert traces back to a specific rule, specific conditions, specific field values.
- **Domains are portable.** Swap the fixtures and the same system monitors students, devices, or bank accounts.
- **Experts stay in control.** Rules are authored by humans (or by LLMs under human review via `teach`). The engine is a tool, not an oracle.

The factory must grow — but the reasoning must be deterministic.

---

*Nexus is open source at [github.com/SandwichLabs/nexus](https://github.com/SandwichLabs/nexus). Built with Go, DuckDB, and a healthy distrust of probabilistic reasoning for high-stakes decisions.*
