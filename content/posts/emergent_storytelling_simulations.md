+++
title = "Emergent Storytelling: How Simple Rules Create Compelling Narratives"
date = "2025-12-12"
categories = ["Engineering", "Fun"]
tags = ["AI"]
type = "posts"
draft = false
+++

I have been working on the concept of 'Dwarf Fortress for storytelling with LLMs' for years now and, I've finally managed to assemble all of the pieces needed to do this at scale.

The following is a Claude summary of the project:

## The Story That Wrote Itself

The Captain of the Guard struck without warning. Dilol Caverncats, a human engraver, collapsed under the first blow to the hand—muscle bruising through the pig tail glove, wrist bending unnaturally, tendons tearing. Dilol stood up. The Captain struck again. Again, Dilol rose. Eleven times the combat logs recorded those three defiant words: "The engraver stands up."

Meanwhile, across the fortress, life continued. Snamoz Fiendyawn smoothed floors. Amec Fastenamazes detailed walls. Two residents felt embarrassment over lacking bedrooms. Violence and normalcy, side by side—the dark humor that defines life in a Dwarf Fortress.

This narrative wasn't written by a game designer. No script dictated this moment. No dialogue tree led here. This story emerged from a few simple rules, a monitoring system, and the chaotic beauty of simulated life.

## The Death of Scripted Stories

Traditional video game narratives follow a script. Even games that pride themselves on "player choice" typically offer branching paths through pre-written content. The writer anticipates every major decision, crafts responses, and builds a story tree that players navigate.

This approach has given us incredible stories. But it has limits:

1. **Finite Content**: Once you've explored all branches, the story is exhausted
2. **Predictable Patterns**: Players learn to recognize the "important" moments
3. **Author Omniscience**: The writer knows what's significant before it happens
4. **Scale Constraints**: Each storyline requires explicit authoring time

Emergent gameplay offers a different paradigm: define the rules, simulate the world, and let stories arise from the interactions between systems.

## Why Dwarf Fortress?

Dwarf Fortress has been called a "story generator" for good reason. The game simulates thousands of systems in parallel:

- **Individual Psychology**: Every dwarf has personality traits, preferences, relationships, memories, and emotional responses
- **Social Dynamics**: Friendships form, marriages happen, rivalries develop, factions emerge
- **Economic Systems**: Trade routes, resource scarcity, job assignments, skill development
- **Environmental Pressures**: Cave-ins, floods, sieges, forgotten beasts, miasma
- **Historical Continuity**: Events build on prior events; the past shapes the present

None of these systems exist to tell a specific story. They exist to simulate their domain faithfully. Stories are a byproduct—but what stories they create.

The challenge is capture. Dwarf Fortress generates these narratives in real-time, but they exist as transient game state, disappearing as the simulation moves forward. What happened three months ago in game-time? Unless you were watching and taking notes, it's lost.

## MindLogger: Capturing the Ephemeral

MindLogger is a system designed to solve this problem. It captures the cognitive and behavioral state of individual units (dwarves, humans, elves, even goblins) as they go about their lives in the fortress. The system has three components:

### 1. The DFHack Monitor (Lua)

A Lua script runs inside Dwarf Fortress via DFHack, polling monitored units every few ticks to detect state changes:

```lua
function monitor.step()
    for unit_id, state in pairs(MonitorState) do
        local unit = df.unit.find(unit_id)

        if not unit or dfhack.units.isDead(unit) then
            -- Log death event and cleanup
            monitor.remove_unit(unit_id)
        else
            -- Check for changes
            check_emotions(unit, state)
            check_behavior(unit, state)
            check_reports(unit, state)
            check_stress(unit, state)

            -- Flush new events to disk
            if #state.write_buffer > 0 then
                exporters.flush_buffer(unit_id, state.write_buffer)
                state.write_buffer = {}
            end
        end
    end
end
```

The monitor tracks:

- **Emotions**: New entries in `unit.status.current_soul.personality.emotions`
- **Behavior**: Job changes (working, socializing, idle)
- **Combat Reports**: Violence, hunting, sparring
- **Stress**: Significant changes in stress levels (crossing thresholds)

Each detected change creates an event:

```lua
local event = {
    type = "mindlog_emotion",
    timestamp = { year = 107, seconds72 = 25 },
    hf_id = 10467,
    site_id = 688,
    emotion_type = "EMBARRASSMENT",
    thought_type = "LackBedroom",
    severity = 0,
    subthought_id = -1
}
```

### 2. NDJSON Export

Events are serialized to newline-delimited JSON and written to disk in real-time. Each monitored unit gets its own file:

```
data/mindlog_4954.ndjson
data/mindlog_7992.ndjson
data/mindlog_10467.ndjson
```

This format is:
- **Streamable**: Events append without rewriting the entire file
- **Human-readable**: Open with any text editor to inspect
- **Tool-friendly**: Easy to parse line-by-line in any language

### 3. Database Import (Go)

A Go CLI tool imports NDJSON files into DuckDB:

```go
func processMindlogFile(database *db.DB, path string, batchSize int, currentID *int) (int, error) {
    scanner := bufio.NewScanner(file)
    var batch []db.MindlogEvent

    for scanner.Scan() {
        rawJSON := scanner.Bytes()

        // Extract indexed fields
        var raw mindlogRawEvent
        json.Unmarshal(rawJSON, &raw)

        // Store full JSON blob plus indexed columns
        event := db.MindlogEvent{
            ID:        *currentID,
            Type:      raw.Type,
            HfID:      raw.HfID,
            SiteID:    raw.SiteID,
            Year:      raw.Timestamp.Year,
            Seconds72: raw.Timestamp.Seconds72,
            Data:      rawJSON,  // Full JSON preserved
        }

        batch = append(batch, event)

        if len(batch) >= batchSize {
            database.BatchInsertMindlogEvents(batch)
            batch = nil
        }
    }
    return count, nil
}
```

The database schema balances structured queries with flexible JSON storage:

```sql
CREATE TABLE mindlog_events (
    id INTEGER PRIMARY KEY,
    type TEXT NOT NULL,          -- Indexed for filtering
    hf_id INTEGER NOT NULL,      -- Indexed for per-character queries
    site_id INTEGER,
    year INTEGER NOT NULL,       -- Indexed for timeline queries
    seconds72 INTEGER NOT NULL,  -- Fine-grained time within year
    data JSON NOT NULL           -- Full event data
);
```

Indexes enable fast queries by character, event type, or time range, while the JSON blob preserves all event-specific details.

## From Data to Story

Once imported, the real magic happens: querying. DuckDB's JSON support lets us ask questions like:

**What happened to Dilol Caverncats?**

```sql
SELECT
    data->'details'->>'text' as event_text
FROM mindlog_events
WHERE hf_id = 7992
    AND type = 'mindlog_report'
ORDER BY seconds72
```

Result:
```
The captain of the guard punches the engraver in the right hand...
The force bends the right wrist, tearing apart the muscle...
The engraver stands up.
The engraver stands up.
The captain of the guard punches the engraver in the upper body...
```

**Who experienced emotions during this time?**

```sql
SELECT
    hf_id,
    data->>'emotion_type' as emotion,
    data->>'thought_type' as thought
FROM mindlog_events
WHERE type = 'mindlog_emotion'
```

Result:
```
hf_id  | emotion        | thought
-------|----------------|-------------
10467  | EMBARRASSMENT  | LackBedroom
6336   | EMBARRASSMENT  | LackBedroom
```

**What were other dwarves doing during the beating?**

```sql
SELECT
    hf_id,
    data->'details'->>'job_type' as activity,
    data->'details'->'position'->>'z' as level
FROM mindlog_events
WHERE type = 'mindlog_action'
    AND seconds72 = 25
```

Result:
```
hf_id  | activity     | level
-------|--------------|------
4954   | DetailFloor  | 120
11069  | DetailWall   | 120
```

These queries reveal not just *what* happened, but *context*: who witnessed it, what else was going on, how the fortress responded (or didn't).

## The Beating of Dilol Caverncats: Emergent Drama

Let's return to our opening narrative with new understanding. The system captured 64 events across 18 individuals during a brief game session. Most were mundane: engraving walls, smoothing floors, feeling embarrassed about housing.

But for Dilol, the session was anything but mundane. The combat report system (which fires when units are involved in violence) generated a flood of events:

- Initial punch to the hand
- Wrist injury detail (torn muscle)
- Multiple "stands up" events (Dilol refusing to stay down)
- Punches to body, neck, leg, foot
- Each blow recorded with body part and armor details

The narrative wrote itself. The data showed:

1. **Power Imbalance**: Captain of the Guard vs. Engraver (no combat skills)
2. **Persistence**: 11 instances of standing back up
3. **One-sided Nature**: Only the Captain's attacks logged, Dilol never counter-attacked
4. **Mundane Backdrop**: Other dwarves continued working, unaware or unconcerned
5. **Social Context**: Two others felt embarrassment over bedrooms *during* the beating

These details weren't authored. They emerged from:
- Dwarf Fortress's justice system (likely Dilol violated a mandate or broke a rule)
- Combat mechanics (damage calculations, knockdown, standing)
- Job assignment system (other dwarves kept working)
- Emotion system (housing satisfaction independent of violence)
- Report logging (only combat reports generated for Dilol)

## What Makes This Special?

### 1. Author Ignorance

The most powerful aspect of emergent narratives is that *the author doesn't know what's significant*. When I started the MindLogger session, I had no idea a beating would occur. The monitoring system treats all events equally: bedroom embarrassment and life-threatening violence get the same structured logging.

Significance emerges from *analysis*, not *capture*. This inverts traditional storytelling.

### 2. Unscripted Confluence

The juxtaposition of violence and mundanity wasn't planned. It happened because the simulation doesn't care about narrative pacing. Jobs don't pause for drama. Emotions don't wait for appropriate moments. The result is authentic—because it's indifferent.

### 3. Inexhaustible Stories

Traditional game content is finite. Complete all quests, explore all dialogue trees, and you're done. But emergent systems generate stories infinitely. Each fortress is unique. Each dwarf's life is unique. Each session produces new data.

MindLogger captured one session in one fortress with 18 individuals. How many other stories occurred simultaneously? What about the 200 other dwarves in the fortress? What happened last year? Next year?

### 4. Retroactive Significance

The beating only became significant when I *looked* for a story. I could have queried for emotion patterns, or job efficiency, or stress trajectories. Each lens would reveal different narratives in the same data.

This is how real historians work: they don't witness events thinking "this will be important." They analyze records later, finding patterns and meaning in hindsight.

## The Simple Rules

MindLogger succeeds because it embraces simplicity:

**In-game (Lua):**
- Poll units every N ticks
- Check if emotions list grew
- Check if job changed
- Check if new reports appeared
- Check if stress changed significantly
- Write changes to file

**Import (Go):**
- Read NDJSON files line by line
- Extract common fields for indexes
- Preserve full JSON for flexibility
- Batch insert for performance

**Analysis (SQL):**
- Filter by character, event type, or time
- Extract details from JSON
- Join with legends data for names/context
- Order chronologically

No machine learning. No natural language processing. No complex narrative generation. Just: capture state changes, store them efficiently, query them flexibly.

The complexity is in *Dwarf Fortress itself*—the thousands of simulated systems interacting. MindLogger simply watches and records.

## Future Possibilities

This system opens doors:

**Automatic Biography Generation**: Given a historical figure ID, generate a life story from birth to death using both legends data (major historical events) and MindLogger data (daily experiences).

**Psychological Profiles**: Track emotion patterns over time. Which dwarves are resilient under stress? Who forms friendships quickly? Who isolates?

**Social Network Analysis**: Map relationships through social job tracking. Who drinks together? Who trains together? How do social networks correlate with stress resistance?

**Event Causality**: Link job changes to emotions. Did the goblin attack cause anxiety? Did the masterwork creation improve mood? Correlation analysis on event streams.

**Predictive Modeling**: Given current stress, job satisfaction, and social connections, can we predict tantrum risk? This isn't authoring—it's emergent behavioral science.

**Interactive Narratives**: Use the TUI to browse fortress members, select interesting individuals, and read auto-generated stories from their event timelines.

**Multi-Perspective Histories**: The same event (like Dilol's beating) might appear in multiple unit logs. Combine perspectives for richer narratives.

## The Lesson: Design Systems, Not Stories

The insight here applies beyond Dwarf Fortress:

**Don't write stories—write rules that generate stories.**

This approach requires:

1. **Robust Simulation**: Systems must interact in complex, non-trivial ways
2. **Comprehensive Logging**: Capture state changes faithfully
3. **Flexible Analysis**: Don't pre-decide what's "important"
4. **Retroactive Interpretation**: Find meaning in hindsight

Games like Dwarf Fortress, RimWorld, Crusader Kings, and Wildermyth understand this. They create narrative *potential*, not narrative *script*. The stories players tell about these games are emergent, unique, unrepeatable.

MindLogger takes this further by making the invisible visible. Dwarf Fortress already generates these stories—most players just can't see them all. The simulation runs too fast, involves too many actors, creates too much data.

With structured capture and analysis, we can slow down, rewind, examine. We can ask questions the game never anticipated. We can find stories the developers never imagined.

## Conclusion: Eleven Times

"The engraver stands up."

Those four words appear eleven times in the combat logs. They're generated by a simple game rule: if knocked down, attempt to stand. No AI decided this was dramatically satisfying. No narrative designer planned this moment of defiance.

Yet it's the most powerful element of the story—because it's *real* (within the simulation). Dilol didn't stand up because the script demanded a heroic moment. Dilol stood up because that's what Dwarf Fortress units do.

And that's what makes emergent narratives special: they're true to the world's rules, not the author's intentions. They surprise us. They reveal patterns we didn't design. They generate meaning from simulation.

All it takes is a few simple rules—and the patience to watch what emerges.

---

## Technical Appendix

**Project**: Dwarf Explorer Prime
**Repository**: [dwarf-explorer](https://github.com/your-repo-here)
**Technologies**:
- DFHack (Lua scripting for Dwarf Fortress)
- Go 1.22+
- DuckDB (embedded analytical database)
- Cobra (CLI framework)

**Key Files**:
- `scripts_modinstalled/mindlogger/monitor.lua` - Event capture system
- `cmd/mindlogger_import.go` - NDJSON import implementation
- `internal/db/schema.go` - Database schema definitions

**Try It Yourself**:

```bash
# Install MindLogger in your DF mods folder
cp -r scripts_modinstalled/mindlogger ~/.dwarffortress/mods/

# In Dwarf Fortress, via DFHack console:
mindlogger start all

# Play for a while, then flush data:
mindlogger flush

# Import into database:
./dfe mindlogger-import --input data/

# Query the data:
./dfe query --sql "SELECT type, COUNT(*) FROM mindlog_events GROUP BY type"

# Generate a narrative (coming soon):
./dfe show 7992
```

**Further Reading**:
- [Dwarf Fortress Development](http://www.bay12games.com/dwarves/)
- [DFHack Documentation](https://docs.dfhack.org/)
- [Emergent Gameplay on Wikipedia](https://en.wikipedia.org/wiki/Emergent_gameplay)
- [RimWorld's Storytelling Philosophy](https://ludeon.com/blog/)
