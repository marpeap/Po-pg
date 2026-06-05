# Garrison — Quest & Narrative System
# Status: Design Draft v1.0 — 2026-05-25
# Author: Narrative Design (claude-sonnet-4-6)
#
# Scope: Complete quest system for the TD/RPG hybrid.
# The hero explores a 15-zone open world between tower defense waves.
# Sessions: 10–30 minutes. Platform: Android landscape 960×540, touch-only.

---

## Design Principles

These four principles govern every quest decision:

**P1 — Action is the tutorial.** The game never pauses to explain. Every mechanic
is introduced by placing the player in a situation where the correct action is
obvious and rewarding.

**P2 — Every quest pays in two currencies.** Narrative rewards (lore, character
reveals, world context) and mechanical rewards (gold, tower upgrades, hero stats)
always arrive together. A quest that only gives one of the two is a weak quest.

**P3 — Sessions have a natural close.** A 10-minute session should feel complete.
A 30-minute session should feel like meaningful progress. Quest cadence is designed
so that the player always has a satisfying stopping point within reach.

**P4 — The world answers violence and curiosity equally.** Combat and exploration
must both feel like valid play styles. Pure TD players and pure explorer players
reach the same content through different doors.

---

## Reference Analysis

The following games were studied and specific mechanics extracted:

**Stardew Valley** — The bulletin board's genius is *scope hiding*: you see the
full reward before you commit, but the required items are a light nudge toward
activities you should be doing anyway. Adopted for the daily board.

**Zelda BOTW** — Shrine discovery is gated by curiosity, not combat. The player
sees a pillar of light from 300m away and chooses to investigate. Zone objectives
mirror this: the signal is visible, the path is found by wandering. Memory tablets
are adopted verbatim as the lore delivery mechanism (examine objects, get story).

**Witcher 3** — The notice board is a spatial anchor: you enter a village, you
check the board, you know the local problems. This justifies why quests are
concentrated near specific NPCs. The nested quest structure (quest A reveals
quest B, which reveals quest C) is the model for NPC chains.

**FFXIV** — Daily roulettes solve the boredom problem by randomising which of a
large pool you get each day, not by adding new content. The beast tribe trust
mechanic (reputation unlocks chain steps, not just time) is adopted for NPC chains.

**Diablo** — Bounties separate "I have 10 minutes" play from campaign play cleanly.
The daily board serves this function.

**Monster Hunter** — The hunt board uses word-of-mouth framing ("witnesses report",
"tracks found near"). This is the tone template for all quest text: no omniscient
narrator, only in-world sources.

**Pokemon** — The Pokedex as an ambient progress tracker with discoverable entries
is adopted as the Zone Codex (see section 3).

---

## 1. Main Quest Line — 15 Chapters

### World Premise

The Garrison sits at the only ford across the Ironcrest River. Beyond it, the
Ashen Reaches: lands corrupted when the Forge-Heart, an ancient weapon-amplifying
relic, shattered. Corruption manifests as the waves of enemies the player defends
against. The hero is searching for the seven Shard-Keys needed to reassemble the
Forge-Heart and end the waves permanently.

Each zone holds one piece of the answer. Each chapter is one zone.

### Lore Delivery Mechanism — Stone Echoes

Every zone contains 3 Stone Echoes: glowing fragments of the old world that play
a 2–4 line audio-text scene when tapped. No cutscene, no pause. The player reads
while walking. The echo stays highlighted in the world permanently after discovery.
This is the BOTW memory system applied to environment objects rather than photography.

Stone Echoes are never required for quest completion. They are supplementary lore
for players who want it. Their icon on the map is a small amber dot.

### TD Integration Rule

Each chapter's completion unlocks a Tower Augment: a permanent upgrade to one
tower type, justified by the lore discovery. The player does not buy it; it is
granted as a narrative reward. This is the main quest's mechanical spine.

### Chapter Breakdown

**Chapter 1 — The Ford's End** (tutorial zone, Zone 1: The Ashen Crossing)
- Zone character: ruined stone bridge, waist-high fog, scorched grass
- Narrative: The hero arrives. The first wave hits. A dying scout hands over a map
  fragment before expiring. Text: "The Reaches weren't always this. There was a
  Forge. There was a city. Go find what's left."
- Main objective: Survive the first wave. Find the Scout's Pack (proximity interact
  on a highlighted pack 80m from the castle). The pack contains Map Fragment 1.
- Stone Echoes (3): (a) a cracked milestone reading old distance markers,
  (b) a soldier's helmet embedded in the ford stones, (c) a merchant's ledger
  half-buried in ash
- TD unlock: Tower Augment — IRON CORE (Tower 1 gains +15% base HP)
- Session target: completable in 8 minutes

**Chapter 2 — The Merchant Road** (Zone 2: Dustfall Hollow)
- Zone character: collapsed marketplace, overturned wagons, coin-scattered streets
- Narrative: The scout's map points to a merchant guild vault. The guild master
  fled when the Forge-Heart shattered. His last shipment — carrying a Shard-Key
  fragment — never arrived.
- Main objective: Find 3 Ledger Pages (scattered across zone, amber glow).
  Bring pages to the Guild Board (crafting anvil interact). The reconstructed
  manifest reveals a hidden cellar location. Interact with the cellar to retrieve
  Shard Fragment 1.
- Stone Echoes: guild contracts written in blood, a child's crayon map of the
  market stalls, a smashed clock still ticking
- TD unlock: Tower Augment — TRADE WINDS (Archers in range of Tower 1 gain
  +10% gold per kill)
- Quest text (Guild Board): "Ledger 3 of 7, Dustfall Hollow Registry. Shipment
  ref: SF-1. Contents: one geode, sealed, origin Forge-City. Consignee: the
  Garrison Commander. Never arrived."

**Chapter 3 — The Shepherd's Path** (Zone 3: Greenspire Meadow)
- Zone character: tall grass, scattered livestock (ambient animals, no interaction),
  a shepherd's tower
- Narrative: A Healer NPC named Senna is trying to cure shepherds turned feral
  by corruption. She knows where a Shard-Key shard was buried by her grandmother.
- Main objective: Find Senna (marked zone, 150m from entry). Complete her first
  two NPC quests (see section 4). She then reveals the burial mound location.
  Dig site interaction yields Shard Fragment 2.
- Stone Echoes: a shepherd's prayer carved into a stone, a flock roster with all
  names crossed out, Senna's grandmother's herb journal
- TD unlock: Tower Augment — SHEPHERD'S EYE (Tower 2 gains slow-field aura,
  radius 120px, 15% slow, framed as Senna's herbal recipe applied to arrows)
- Quest text (Senna, first meeting): "I've seen you fight. You're desperate. So
  am I. Help me treat three of my flock and I'll show you something my grandmother
  hid before the Shattering. Deal?"

**Chapter 4 — The Deep Mine** (Zone 4: Ironvein Tunnels)
- Zone character: mineshaft entrance, cart tracks, flickering phosphorescent moss
- Narrative: The mine superintendent encoded the location of a Shard-Key in his
  shift logs. The logs are scattered through the mine. Enemy type dominant: Golem.
- Main objective: Collect 5 Shift Logs (deeper in the mine each one, requiring
  progressive exploration). Arrange them chronologically on the Superintendent's
  Desk (interact puzzle: drag-to-slot UI, 5 items). Decoded location: eastern
  seam. Mine through rock blockage (Resource Node, 30 strikes) to reach the seam
  and Shard Fragment 3.
- Stone Echoes: a miners' safety poster, a birthday cake mould found in a lunch
  tin, a strike record showing the day all entries stopped
- TD unlock: Tower Augment — VEIN-SIGHT (Tower 3 gains Targeting: STRONGEST
  mode by default, framed as the mine foreman's prioritisation doctrine)
- Drag puzzle note: Use simple 5-slot snap UI. No hidden interaction. Slots light
  up green on correct placement. This is the most complex puzzle in Chapter 1-5.
  Complexity ceiling for early game.

**Chapter 5 — The Flooded Temple** (Zone 5: Mirewash Ruins)
- Zone character: half-submerged stone temple, lily pads, mist over water
- Narrative: An ancient order used the temple as a relay station for the Forge-Heart's
  power. Their final transmission documented the Shattering. A Sage NPC named Orrin
  has been transcribing the glyphs for decades.
- Main objective: Find Orrin. Help him with his first two NPC quests. He deciphers
  the transmission glyph (Stone Echo cluster, 5 glyphs forming a circle). The
  decoded text reveals the Shard-Key is sealed inside the temple altar. Altar
  interact (requires Water Tower Power unlocked — soft gate) yields Shard Fragment 4.
- Stone Echoes: an order member's last letter to family, a schematic of the
  Forge-Heart drawn in chalk on stone, a ceremonial offering bowl with coins still in it
- TD unlock: Tower Augment — TIDAL SURGE (Water Tower Power cooldown -30%,
  slow duration +1.0s, framed as recovered temple hydraulic formula)
- Soft gate note: Altar requires Water Tower Power. Player must have purchased
  at least one tower with Water power. This is the first mechanical gate on the
  main quest. It is soft: a popup explains the requirement and the cost (150g +
  one tower). It never blocks progress indefinitely.

**Chapters 6–10 — Mid-game zones (Zone 6–10)**

Each follows the same structure with escalating complexity. Summary:

| Ch | Zone Name | Enemy Focus | NPC | Shard# | TD Unlock |
|----|-----------|-------------|-----|--------|-----------|
| 6 | The Ember Plains | Cavalier | Scout Lira | 5 | Fire Tower: chain ignite (+1 adjacent target) |
| 7 | The Frozen Reach | Archer Enemy | Bard Caelo | 6 | Lightning Tower: arc damage +2 secondary targets |
| 8 | The Bone Garden | Healer Enemy | Merchant Darro | 7 | Formation Doctrine: ARC unlocked without Forge cost |
| 9 | The Glass Plateau | Mixed | Sage Orrin 2 | 8 | Targeting Protocol: FIRST mode unlocked free |
| 10 | The Storm Gate | Boss wave | Scout Lira 2 | 9 | Tower Augment: GATE WARD (Tower 5 gains 2x HP, framed as the Storm Gate's old ward magic) |

Mid-game chapters introduce a new structure element: the Witness NPC. A secondary
NPC appears in the zone who was present when the Forge-Heart shattered. Their
testimony (3-tap dialogue) provides lore that the Stone Echoes only allude to.
Witnesses cannot be missed; they stand near the zone entry with a pulsing amber ring.

**Chapters 11–15 — Late-game zones (Zone 11–15)**

Late-game chapters layer two new mechanics:

CONVERGENCE QUESTS: Two NPC chains must both be at step 3+ before the chapter's
main objective unlocks. This rewards players who invested in NPC relationships.

ECHO CLUSTERS: Instead of 3 individual Stone Echoes, the zone contains one cluster
of 7 echoes arranged in a narrative sequence. Experiencing all 7 in order (number
visible on each) replays the final hours of Forge-City. These are the emotional
peaks of the narrative.

| Ch | Zone Name | Shard# | Convergence Requirement | TD Unlock |
|----|-----------|--------|------------------------|-----------|
| 11 | The Dead Archive | 10 | Sage at step 3 + Bard at step 3 | Archer Momentum: Tier 4 streak multiplier x1.75 (was x1.50) |
| 12 | The Hollow Crown | 11 | Healer at step 3 + Merchant at step 3 | Castle Regen: +0.010 rate (doubles base) |
| 13 | The Shattered Spire | 12 | Scout at step 5 | All towers: +20% arrow damage permanently |
| 14 | The Forge-Road | 13 | Any two NPCs at step 5 | Forge upgrade costs -20% (permanent session reduction) |
| 15 — Final | The Forge-Heart Chamber | Reassembly | All 5 NPCs at step 3+ | Forge-Heart reconstructed: win condition |

**Chapter 15 — The Forge-Heart Chamber (Final)**

The chamber is the only zone that is not freely traversable. It is a linear path
with 5 sealed doors, each requiring one Shard-Key group (shards are grouped in
sets of 2-3 per door). Between each door: a Stone Echo cluster playing the five
stages of the Forge-Heart's destruction. The final door opens on the Forge-Heart
pedestal. The player places the final reconstructed key. The Forge-Heart seals.

Mechanical conclusion: the wave counter resets to 0 and a "New Cycle" mode unlocks
(harder waves, same map, NG+ scaling). This is not a credits screen; it is a
mechanical state change. The game continues.

Quest text (final interact): "The Forge-Heart accepts the keys. The Reaches go
quiet for the first time in living memory. The waves will return. They always do.
But now you know how to end them again."

---

## 2. Daily Quest Board

### Board Location and Access

The Board is a physical object: a wooden post with three pinned contracts, located
5m from the castle entrance (always visible from spawn). Tap the board to open
the Daily Contracts panel. This is 1 tap from anywhere within 90px of the board.

### Reset Schedule

Contracts reset at local midnight (device time). No server dependency. New
contracts are seeded from the daily pool using `hash(day_number + player_seed)`
for deterministic but session-unique results. Three contracts are always shown.

### Contract Types (Pool of 12 archetypes, 36 total variants)

**Type A — Gather** (6 variants)
- "Collect 12 Ironwood Logs from Zone 3 or 4." Reward: 80g + 1 Forge token
- "Collect 8 Quartz Crystals from Zone 4." Reward: 90g + 1 Forge token
- "Collect 15 Healing Herbs from Zone 3 or 5." Reward: 70g + 2 Potion items
- "Collect 6 Ember Resin from Zone 6." Reward: 100g + Fire Tower 1 free use
- "Collect 10 Frozen Moss from Zone 7." Reward: 100g + Lightning Tower 1 free use
- "Collect 20 Bone Dust from Zone 8." Reward: 110g + 1 Forge token

**Type B — Combat** (6 variants)
- "Defeat 20 Infantry enemies in any zone." Reward: 75g + streak bonus +1 (lasts 1 wave)
- "Defeat 10 Cavalier enemies in Zone 6 or 7." Reward: 90g + 1 Forge token
- "Defeat 5 Elite enemies (any type)." Reward: 120g + 2 Forge tokens
- "Defeat 1 Boss enemy." Reward: 150g + permanent +5 castle HP for session
- "Defeat 30 enemies during a single wave without losing castle HP." Reward: 100g + 1 hero spell charge
- "Kill 8 Healer enemies before they can heal allies." Reward: 80g + Targeting FIRST mode free 1 wave

**Type C — Exploration** (6 variants)
- "Discover a hidden cave in Zone 4 or 5 (look for collapsed stone walls)." Reward: 85g + 1 Map Fragment hint
- "Find and examine 3 Stone Echoes in Zone 2 or 3." Reward: 70g + 1 lore codex entry
- "Interact with the Crafting Anvil in Zone 5." Reward: 60g + Forge upgrade -10% cost this session
- "Reach the Shepherd's Tower in Zone 3 without being hit by a patrol." Reward: 90g + hero move speed +15% for 1 exploration
- "Find the hidden treasure chest in Zone 6 (clue: count three dead trees from the entry)." Reward: 100g + random consumable x2
- "Visit 3 different Resource Nodes in a single exploration session." Reward: 75g + resource yield x1.5 for remainder of session

**Type D — Contract (NPC-linked)** (8 variants, unlocked after NPC chain step 1)
- Merchant Darro: "Resell 50 units of gathered resources through the Trade Post." Reward: 120g + shop discount 20% for 2 days
- Scout Lira: "Scout Zone 6 and return with a patrol route sketch (reach 3 waypoints)." Reward: 100g + enemy wave preview for next wave
- Sage Orrin: "Bring Orrin 5 transcribed glyphs (examine glyph objects in Zone 5)." Reward: 110g + 1 Tower Augment charge
- Bard Caelo: "Hear 4 new Stone Echoes and report back to Caelo." Reward: 90g + hero XP bonus x1.5 for session
- Healer Senna: "Gather 8 Violet Moss and 4 Red Bark (both in Zone 3)." Reward: 80g + 2 Mega Potions
- Merchant Darro: "Purchase one item from the Forge while at Zone 4 prices." Reward: 130g + 1 free Forge token
- Scout Lira: "Kill 15 enemies using tower fire (not hero spells)." Reward: 95g + Tower placement cooldown -50% for session
- Sage Orrin: "Stand in the Echo Cluster in Zone 5 for 30 seconds (all 7 echoes play)." Reward: 100g + castle max HP +10 for session

### Reward Tiers

| Tier | Criteria | Gold Range | Bonus |
|------|----------|-----------|-------|
| Common | Gather/Combat basic | 60–80g | 1 minor item |
| Uncommon | Exploration/Multi-step | 85–110g | 1 Forge token OR consumable x2 |
| Rare | Boss/Elite/NPC | 120–150g | Permanent session bonus OR 2 tokens |

### Boredom Threshold Analysis

Pool of 36 variants, 3 shown daily. Daily combinations = C(36,3) = 7140 unique
combinations. At 7 days/week, repetition probability within a 30-day month: less
than 2% chance of seeing the same triple. Subjective boredom onset from FFXIV
data: around day 21 of pure dailies with no story progress. The NPC chain and
zone objective systems ensure the player always has non-daily progress happening
in parallel, which resets the boredom clock. The 8 NPC-linked contract variants
only appear after step 1, adding 28+ unique combinations mid-game.

**Pool expansion schedule**: Add 6 new variants per chapter milestone (at Ch5,
Ch10, Ch15). By endgame the pool is 54 variants = 24804 combinations.

### Daily Board UI

The panel slides up from the bottom of screen (landscape). Three card rows, each
195×70px. Each card: icon (left 50px), title (bold), two-line description, reward
display (right side, gold amount + item icon). "ACCEPT" button bottom-right of
card, 72px height (touch-safe). "DECLINE" button (smaller, left of accept) allows
rerolling one contract per day. Reroll uses 15g. Max one reroll per contract per day.

---

## 3. Zone Objective System

### Concept

Each zone has a Zone Codex: a persistent record of the player's discoveries in
that zone. The Codex for Zone N is accessible from the map screen by tapping the
zone icon and selecting the scroll icon (2 taps from main HUD). The Codex shows
5 objectives, revealed progressively. Unrevealed objectives show as "???" with a
faint category icon (combat/explore/collect/secret/story).

Revelation rule: the first time the player enters a zone, objective 1 is always
revealed. Objectives 2-5 are revealed by completing preceding ones, not by time.

This is the Pokemon Pokedex model applied to spatial objectives: you see there is
something there before you know what it is.

### The 5 Objective Archetypes

Every zone uses one of each archetype, in this order:

**Objective 1 — Entry** (always revealed at first entry, always completable in first visit)
Archetype: reach a landmark or interact with one obvious object.
Example (Zone 4 — Ironvein Tunnels): "Enter the mine and examine the foreman's log."
Reward: 40g + Zone Codex entry unlocked

**Objective 2 — Gather** (revealed when Obj 1 complete)
Archetype: collect N of a zone-specific resource. N is sized for 1 exploration session.
Example (Zone 4): "Mine 50 Ironvein Quartz."
Reward: 60g + 1 Forge token + Obj 3 revealed

**Objective 3 — Combat** (revealed when Obj 2 complete)
Archetype: defeat a specific enemy type or count in this zone.
Example (Zone 4): "Defeat the Elite Golem foreman (marked on zone map once Obj 2 complete)."
Reward: 80g + permanent session bonus (zone-specific) + Obj 4 revealed
Zone 4 permanent bonus: "Ironvein Hardened — all tower HP +8 for current session"

**Objective 4 — Secret** (revealed when Obj 3 complete, description remains vague)
Archetype: find a hidden location. The zone map shows a vague region highlight (30%
of the zone area), not a precise marker. Player must explore.
Example (Zone 4 description when revealed): "There are reports of a deeper seam
below the main shaft. Miners called it the Veinheart."
Example (actual objective): Find the Veinheart chamber (hidden path behind breakable
rock wall, requires 20 mining strikes on a specific wall — wall has subtle crack texture).
Reward: 100g + unique cosmetic item (hero banner color) + Obj 5 revealed

**Objective 5 — Story** (revealed when Obj 4 complete)
Archetype: experience the full Stone Echo sequence for this zone (all 3 base echoes
plus any found during Obj 4 secret).
Example (Zone 4): "Orrin believes the mine foreman's echo cluster tells the full
story of the Shattering's effect on Ironvein. Find and experience all 4 echoes."
Reward: 120g + Lore Codex permanent entry + one-time TD bonus (specific to zone lore)
Zone 4 story TD bonus: "Vein-Memory — once per wave, the first Golem killed drops
double gold, in memory of the Ironvein miners"

### Zone Codex UI

Accessed via: HUD > Map icon (bottom-right of exploration HUD) > tap zone > scroll
icon. That is 3 taps maximum from anywhere in the exploration world. The Codex panel
slides in from the right. Completed objectives show a checkmark and the reward
claimed. Active objective shows a glowing dot and its text. Hidden objectives show
"???" with a faint category icon. The panel has no close button — tap anywhere
outside it to dismiss (follows touch convention for all overlay panels).

### Zone Completion Bonus

When all 5 objectives are complete, the zone shows a gold star on the map and
grants a permanent passive for that zone:
- Enemy gold drops in this zone +20% for all future sessions
- This reward accumulates across zones: completing all 15 zones grants +20% gold
  everywhere, which is a meaningful late-game economic multiplier.

---

## 4. NPC Quest Chains

### NPC Placement and Contact

Five NPC types, one named representative appears per zone cluster (Merchant appears
in Zones 1-3 area, Scout in Zones 4-6, Sage in Zones 5-8, Bard in Zones 7-11,
Healer in Zones 3-7). Each NPC is encountered naturally during main quest progression.
They are never teleported in; they walk a fixed patrol of 150m within their zone.

Contact: walk within 90px (the INTERACT_RADIUS already in code). The interact button
shows the NPC's name and portrait icon. Tap to open dialogue. Dialogue is 2-4 lines
per exchange, tap-to-advance, no voiceover. The NPC's portrait is a 64×64 pixel
art bust (consistent with existing sprite style).

Chain gating: each step requires that the player has completed the previous step
AND has reached a minimum wave number (ensures the chain is paced with TD progress).
Minimum wave numbers: Step 1: Wave 1, Step 2: Wave 4, Step 3: Wave 8, Step 4: Wave 14, Step 5: Wave 20.

This is the FFXIV beast tribe pacing model without server dependency.

### NPC 1 — Merchant Darro

Character backstory delivered through chain: Darro was the Forge-City's last supply
comptroller. He engineered the evacuation logistics when the Shattering began. He
survived by accident — his ledger horse went lame and he was three hours behind
the column that was destroyed. He has been supplying every garrison that has held
this ford since. He knows exactly what the Shattering cost in material terms.

**Step 1 — "The Inventory Problem"** (Wave 1+)
Text: "You look like someone who can move fast and not ask too many questions.
I need six crates recovered from my old warehouse in Dustfall. Marked with a
red D. Can't miss them."
Objective: Find 6 Supply Crates in Zone 2 (glowing red, scattered in obvious
locations — no puzzle). Return to Darro.
Reward: 80g + Merchant's Ledger (consumable: doubles next resource node yield)
Backstory fragment delivered: "I've been doing this for thirty years. Every
garrison falls. I restock the next one. Used to bother me."

**Step 2 — "Market Intelligence"** (Wave 4+)
Text: "The enemy commanders — if they have commanders — they're prioritising
something. I've seen patterns in what they destroy first. Help me confirm it."
Objective: Observe 3 enemy waves from the observation post in Zone 3 (a specific
rock outcrop 200m from castle — reach it and stand there for 1 wave). After each
wave, return to Darro for a debrief line.
Reward: 100g + Trade Intel (permanent: gold per kill +3 when wave streak is active)
Backstory: "The first garrison I supplied, the commander laughed at my data.
Said soldiers don't die to statistics. He's wrong. They die to exactly this."

**Step 3 — "The Hidden Cache"** (Wave 8+)
Text: "There's a cache I buried before the Shattering. Seven years ago. I remember
the coordinates in my head — but I need muscle to get to it. Zone 5, near the
temple. There are things in it you need."
Objective: Escort Darro to Zone 5 (he follows the hero at 80% hero speed — do
not outrun him or he stops). Reach the cache site (marked). Fight off 1 Elite
Cavalier patrol (static encounter, not a wave). Darro opens the cache.
Reward: 120g + Ancient Trade Contract (unlocks Merchant's Shop: 3 one-time
purchase items at 20% discount, replenishes on wave clear)
Backstory: "My wife packed this cache. She didn't make the evacuation. The
crates she chose to save were all things other people needed, not us."

**Step 4 — "Debt Ledger"** (Wave 14+)
Text: "I've been carrying this ledger since the Shattering. Names of everyone
who died in the supply columns. I never found anyone to give it to. But you're
going to the Forge-Heart Chamber. Could you... leave it there?"
Objective: Carry the Ledger (occupies one consumable slot during this quest).
Reach Zone 11. Find the Archive Reading Desk. Place the Ledger.
Reward: 140g + Darro's Mark (permanent: all gold costs in the game -5%, stacks
with other reductions, maximum total reduction 30%)
Backstory: "Every garrison commander I've supplied asked me the same question.
Why do you keep doing this? I never had a good answer. Maybe now I do."

**Step 5 — "Final Account"** (Wave 20+)
Text: "The ledger's placed. The account is settled. I want to do something I've
never done in thirty years: I want to fight in the last wave. Will you let me
stand beside the castle?"
Objective: Survive a full wave with Darro positioned at the castle gate (he is
a non-combat NPC — he does not fight, he just stands there, which has no mechanical
effect). After the wave, speak to Darro.
Reward: 180g + DARRO'S LEGACY (permanent, unique): "The Trading Post generates
+5g passive income at the start of each wave, representing Darro's continued
logistical work."
Backstory (final line): "Thirty years. Fifteen garrisons. One wave survived.
Worth it."

### NPC 2 — Scout Lira

Backstory: Lira was the forward scout who first reported the Shattering to the
eastern kingdoms. Her report was dismissed. By the time the armies mobilised, the
corruption had spread. She has been scouting the Reaches alone ever since, mapping
safe corridors. She is the only living person who has been inside Zone 14.

**Step 1 — "Perimeter Reading"** (Wave 1+)
Text: "You're defending a ford you don't know. Before the next wave, let me show
you three things about this terrain that will keep you alive."
Objective: Follow Lira to 3 observation points in Zone 1 (she guides, player taps
her to advance). At each point she gives a tactical tip (1-line tooltip that is
actually the game tutorial for towers, zone markers, and enemy paths — the entire
early tutorial is embedded in this quest).
Reward: 70g + Scout's Map (reveals 50% of Zone 2 map fog)
Backstory: "I filed fourteen reports before the Shattering. Fourteen. The last
one said 'immediate evacuation, all zones.' Nobody read it in time."

**Step 2 — "What Moves at Night"** (Wave 4+)
Text: "The enemy patrol routes change. I've mapped a new pattern but I need
someone to verify the eastern corridor while I check the north. Meet me at the
ridge in Zone 4 at the red marker."
Objective: Reach a waypoint in Zone 4 (requires entering Zone 4 for the first
time — soft gate that ensures zone progression). Observe a scripted patrol
(3 enemies walk a fixed route for 10 seconds, then despawn). Return to Lira.
Reward: 90g + Patrol Intel (next 2 enemy waves have their first wave enemy
positions revealed 5 seconds before spawn — telegraphed entry point glow)
Backstory: "I've watched them for seven years. They don't have a general. They
have a pattern. Understanding the pattern is survival."

**Step 3 — "The Safe Road"** (Wave 8+)
Text: "Zone 6 is Ember Plains. The patrols there are cavalry. Fast, aggressive.
I know the only safe path through. Follow me and don't deviate."
Objective: Traverse Zone 6 with Lira on a fixed path (24 waypoints, must stay
within 120px of the path or encounter a patrol ambush — 5 enemies). This is the
most movement-intensive quest in the early-mid chain.
Reward: 110g + Safe Road (Zone 6 exploration speed +30% for all future visits;
Lira has taught the optimal path permanently)
Backstory: "I lost a scout team in Zone 6. Twelve people. I made a mistake with
the route. I've rewalked it every week since. I don't make that mistake anymore."

**Step 4 — "The Last Report"** (Wave 14+)
Text: "I finished my map of Zone 14. Forty-three pages. I need to copy the key
intelligence into something the Garrison can actually use. Help me set up the
relay point in Zone 10."
Objective: Bring 3 Mapping Supplies (gathered from Resource Nodes in Zone 9-10)
to the Zone 10 relay point. Lira transcribes her notes (30-second wait — she
is visibly writing). Receive the Complete Survey.
Reward: 130g + ZONE ATLAS (permanent: all zones have 80% fog revealed on first
entry; Lira has pre-mapped them)
Backstory: "The map doesn't show what I lost making it. That's the problem with
maps. They only show the world, not what it cost to learn it."

**Step 5 — "One More Scout"** (Wave 20+)
Text: "Zone 15. The Forge-Heart Chamber. I've been to the entrance but never
inside. I need a scout report. I can't go — someone has to hold the intelligence
here. Will you go in and come back? Just a report. That's all."
Objective: Enter Zone 15 and return to Lira with the Chamber Report (interact
with the Chamber Entry Stone and then return — this is the only step in a
main quest chapter that can be triggered by an NPC chain). Lira processes the
report and gives final analysis.
Reward: 180g + LIRA'S EDGE (permanent, unique): "On each wave, Scout Lira
pre-marks 2 enemies for priority targeting. Marked enemies glow amber and yield
+8g on kill. Marks change each wave."
Final line: "Forty-three pages of maps and one verbal report. That's my life's
work. Not bad for someone who started by being ignored."

### NPC 3 — Sage Orrin

Backstory: Orrin was the Forge-Heart's chief archivist. He transcribed its operational
manuals, understood its power, and opposed its weaponisation by the military. When
the Shattering happened, he tried to warn the order that they had overloaded it.
He was right. He has never forgiven himself for not stopping it earlier.

**Step 1 — "The First Glyph"** (Wave 1+)
Text: "Ah. Someone who doesn't run from ruins. Help me copy this glyph correctly.
I've been staring at it so long I can no longer see it fresh."
Objective: Examine the glyph cluster in Zone 5 (5 individual glyph objects). Each
glyph examination plays a 2-line echo. Return to Orrin.
Reward: 70g + Glyph Cipher (reveals the text of 2 previously-undeciphered Stone
Echoes in Zone 5 — lore content only)
Backstory: "I wrote those glyphs. I was twenty-three. I thought I was preserving
history. I was writing an instruction manual for a catastrophe."

**Step 2 — "The Second Archive"** (Wave 4+)
Text: "There's a second archive. Hidden when the Shattering started. The location
is encoded in the temple's floor pattern. I need you to map the floor."
Objective: Walk the Zone 5 temple floor in a specific pattern (5 floor panels
that light up sequentially when stood on — the order is shown as a faint arrow
guide on first approach). Panel sequence reveals archive location.
Reward: 90g + Archive Access (unlocks a bonus Stone Echo cluster in Zone 7 —
Orrin's field notes from Zone 7 research)
Backstory: "The archive was my idea. I thought hiding the knowledge would protect it.
Instead, nobody knew enough to prevent the military from improvising. Improvising
with the Forge-Heart killed everyone."

**Step 3 — "What I Did Not Write"** (Wave 8+)
Text: "There is one document I did not archive. I destroyed it intentionally.
I need to tell someone what was in it, before I forget, or before I die.
Will you hear it?"
Objective: Stand with Orrin in the Zone 5 temple for 45 seconds while he speaks
(longest in-game dialogue sequence — 8 lines, tap to advance each).
Reward: 100g + Orrin's Testimony (permanent: Stone Echo content permanently
expanded — all echoes now show a second page of Orrin's annotation)
Backstory reveal (in the dialogue): The destroyed document was the Forge-Heart's
safety override manual. The military removed it before Orrin could archive it.
He tried to stop the weapon from firing at full power. He failed by 4 minutes.

**Step 4 — "Reconstruction"** (Wave 14+)
Text: "If someone reassembles the Forge-Heart without the override manual, the
same thing will happen again. I've been reconstructing the manual from memory
for seven years. I have enough. I need you to carry it into Zone 15."
Objective: Receive the Override Manual (occupies consumable slot). Bring it to
Zone 11. There is a glyph input panel — Orrin's instructions guide a 4-step
interaction (tap glyphs in sequence). The manual is encoded into the panel.
Reward: 130g + OVERRIDE FORMULA (permanent: Castle HP regen rate +0.010 —
the override dampens the corruption waves)
Backstory: "I reconstructed 97% of it from memory. The remaining 3% I guessed.
I am reasonably confident about my guess. Reasonably."

**Step 5 — "The Archivist's Peace"** (Wave 20+)
Text: "You have the Forge-Heart reassembled? Then there is one more thing I
need to do. I need to watch it seal. Not from a distance. From the chamber.
Will you take me?"
Objective: Bring Orrin to Zone 15 entry (he walks behind the hero). No combat
required — this is a narrative transit. At the entry, a 4-line final exchange.
Reward: 180g + ORRIN'S CODEX (permanent, unique): "All Tower Augments cost
0 Forge tokens to activate for the current session — Orrin has pre-applied the
formulas."
Final line: "Seven years. And the manual worked. The 3% I guessed was correct.
I am choosing to take that as evidence of the universe's sense of irony."

### NPC 4 — Bard Caelo

Backstory: Caelo was a travelling performer who happened to be in Forge-City the
night of the Shattering. They survived by hiding in a grain cellar. They have
been processing the trauma by composing the Ballad of Forge-City: a seventeen-part
epic that nobody has agreed to listen to in full. They use music and story to
preserve memories of the dead.

**Step 1 — "An Audience of One"** (Wave 1+)
Text: "You're the first person in two months who hasn't walked away when I start.
Just... listen. Two minutes. That's all I ask."
Objective: Stand within 90px of Caelo for 90 seconds (do not walk away). Caelo
performs Part 1 of the Ballad (text-on-screen, no audio voiceover — 6 lines).
Reward: 70g + Ballad Fragment 1/17 (lore collectible, viewable in Codex)
Backstory: "I've performed Part 1 forty-seven times. You're the forty-eighth
audience. You're also the first to actually stay."

**Step 2 — "Instruments of War"** (Wave 4+)
Text: "Part 2 of the Ballad describes the armoury of Forge-City. I need to
verify some of the weapon descriptions against actual surviving examples.
Help me find three intact weapon racks in Zone 4."
Objective: Find 3 Weapon Rack objects in Zone 4 (each plays a 2-line lore echo
when examined; Caelo needs to hear them — they follow the hero during this quest).
Reward: 90g + Ballad Fragment 2/17 + Caelo's Ear (passive: hero spell cooldowns
-10%, framed as "Caelo's timing coaching")
Backstory: "The weapons in Forge-City were extraordinary. The people who made
them were more so. The Ballad is about the people. The weapons are just context."

**Step 3 — "The Lost Verse"** (Wave 8+)
Text: "Part 9 of the Ballad is missing. I was composing it when the Shattering
hit. The verse described what happened in the Forge-Heart chamber in the final
moments. Only someone who was there could complete it. I need to find a survivor."
Objective: Find the hidden NPC "Survivor Maren" in Zone 8 (no map marker — the
clue is in Caelo's previous dialogue: "she always went to the bone garden when
she needed to think"). Maren is at a specific point in Zone 8. Bring Caelo to Maren.
Reward: 110g + Part 9 Completed (unlocks a 5-line echo in Zone 8 that can be heard
by any player who reaches it) + Ballad Fragments 3-9/17
Backstory: Maren tells what happened. The chamber was not an accident — the military
commander fired the Forge-Heart knowingly, targeting an enemy army. They hit it.
They also hit everything else. This is the moral core of the narrative.

**Step 4 — "Public Performance"** (Wave 14+)
Text: "The Ballad is nearly complete. But a ballad without an audience is just
notes. I want to perform at the Garrison — not just for you. Can you arrange it?"
Objective: During the next TD wave intermission, tap Caelo's icon in the HUD
(he appears as a small portrait in the exploration HUD top-bar when this step
is active). This triggers a 30-second "performance" event: Caelo's portrait
displays on screen with a gold shimmer, and all archers gain +15% damage for
that wave. This is the only quest that affects a TD wave directly.
Reward: 140g + CAELO'S CHORUS (permanent: once per 5 waves, Caelo's performance
aura activates automatically for 15 seconds, granting archers +15% damage)
Backstory: "I've performed for kings, merchants, soldiers, and ghosts. A garrison
full of archers is the finest audience I have ever had."

**Step 5 — "The Final Verse"** (Wave 20+)
Text: "The Ballad has seventeen parts. I've written sixteen. Part 17 writes
itself. It ends when the Forge-Heart seals. I need to be there to hear it.
Not in the chamber — just close. Will you let me know when it's done?"
Objective: Complete Chapter 15. Return to Caelo after the Forge-Heart seals.
He performs Part 17 (8 lines — the longest single text display in the game).
Reward: 180g + CAELO'S LEGACY (permanent, unique): "After each wave, a 10-second
performance note plays (+5g ambient income for 10 seconds — represented as Caelo
collecting donations from inspired archers). Stacks with Darro's Legacy."
Final line (Part 17, line 8): "And the Garrison held. And the Hart was sealed.
And the one who held it put down their blade and rested. For one day. Before
the next wave came."

### NPC 5 — Healer Senna

Backstory: Senna is a third-generation healer whose grandmother served the Forge-City
hospital. Her grandmother left the city the day before the Shattering to visit a
patient in a border village. She survived because of that one appointment. Senna
grew up on her grandmother's stories of Forge-City's glory and then witnessed
its ruins. She heals the corrupted survivors not to undo the Shattering but
because it is the only thing she can control.

**Step 1 — "Field Triage"** (Wave 1+)
Text: "Three of my patients collapsed near Zone 3's east tree line. I can't
carry them alone. Come."
Objective: Reach 3 waypoints in Zone 3. At each, a downed shepherd is visible.
Tap to "help carry" (the shepherd disappears — they are brought to Senna's camp
off-screen). No combat. Pure exploration.
Reward: 80g + 2 Standard Potions
Backstory: "My grandmother would have had them walking in twenty minutes. She
was better than me. I try to remember that as a goal, not a judgement."

**Step 2 — "The Herb Harvest"** (Wave 4+)
Text: "I need Violet Moss, Red Bark, and Hollow Root. Zone 3 has all three.
I'll mark the nodes on your map. But the nodes are guarded by corrupted wolves."
Objective: Gather 6 Violet Moss + 4 Red Bark + 2 Hollow Root. Each resource
node is guarded by 2-3 Cavalier enemies (static encounter, not wave). Combat
is unavoidable — this is intentional (the quest introduces the player to combat
against cavaliers before a wave features them heavily).
Reward: 90g + Senna's Salve recipe (hero heals for 8 HP every 30 seconds while
in exploration mode — passive, not consumable)
Backstory: "My grandmother wrote every recipe in this journal. I've only lost
three patients in four years. One of those losses I still think about every day."

**Step 3 — "The Corruption Study"** (Wave 8+)
Text: "I've been studying the corruption pattern. It originates from the Forge-Heart
and propagates in wave patterns — exactly like the enemy waves you fight. I need
samples from Zone 7 to confirm. The corruption there is advanced. Be careful."
Objective: Collect 5 Corruption Samples from Zone 7 (Resource Node type, but
they deal 5 damage per interaction to the hero — minor cost, teaches risk-reward).
Return samples to Senna's mobile lab (she has moved to Zone 5 for this step).
Reward: 110g + Senna's Antidote (consumable x3: removes all debuffs from hero
instantly; useful against slow arrows) + research finding displayed in Codex
Backstory: "The corruption is not malevolent. It's not evil. It's just energy
without direction. The Forge-Heart's energy, scattered. Like screaming with
no voice."

**Step 4 — "What Cannot Be Healed"** (Wave 14+)
Text: "My grandmother kept records of every patient she ever treated. I found
her final record in Zone 8. The last patient she treated before leaving Forge-City.
I need to find that patient's family. Or what's left of them."
Objective: Find the Patient Record in Zone 8 (hidden in the Bone Garden — same
area as Maren from Caelo's chain, but a different interact object). The record
names a location in Zone 10. Go to Zone 10 and examine the memorial stone.
Reward: 130g + Grandmother's Journal (permanent: all healing effects +25%,
including Senna's Salve, potions, and castle regen)
Backstory: The memorial reveals that the grandmother's last patient was the
military commander who ordered the Forge-Heart fired. She treated him for a
wound received during the battle. She did not know his role until years later.
She wrote one line in the record after learning: "I would do it again."

**Step 5 — "After the Seal"** (Wave 20+)
Text: "If the Forge-Heart seals, the corruption waves stop. My patients recover.
But the land will take generations to heal. I'll be here, treating whoever needs
it, for as long as I live. I wanted you to know that. Someone should."
Objective: Bring Senna the Forge-Heart Chamber Report (from Lira's chain, Step 5,
if completed — OR gather 10 units of any resource as a substitute for players
who skipped Lira's chain). This is the only cross-NPC dependency in step 5.
Reward: 180g + SENNA'S LEGACY (permanent, unique): "Castle HP regenerates 1 HP
every 10 seconds during exploration (while EXPLORING GSM state is active),
representing Senna's ongoing care of the Garrison's defenders."
Final line: "I will never run out of patients. I find I no longer mind."

---

## 5. Mystery and Discovery System

### Concept

The Reaches contain 10 World Anomalies: locations where the Forge-Heart's
energy left permanent physical traces. Each anomaly appears as an environmental
impossibility: a frozen waterfall mid-air, a tree growing downward from a rock
ceiling, a circle of sand that remains dry in rain. The hero cannot explain them.
Neither can the NPCs. Only by following the clues across multiple zones does the
explanation emerge.

Anomalies are always visible. They do not need to be unlocked. A player who
explores Zone 3 will see the inverted tree on their first visit. The anomaly
object is interactable immediately. But understanding it requires pieces from
other zones.

Each anomaly investigation yields one Legendary Fragment: a piece of the Warden's
Crest recipe. The Warden's Crest is the game's only legendary item — 10 fragments
needed to craft it. Each fragment is a physical GDScript resource that persists
in the session's inventory.

Warden's Crest effect: "While equipped, the hero's zone exploration reveals all
enemy types for the incoming wave before it begins. Each defeated Elite or Boss
grants +20g and restores 5 castle HP. The Garrison endures."

This is permanently the best non-chapter reward in the game. Getting all 10
requires playing the full game (all 15 zones, all anomalies).

### The 10 Anomalies

**Anomaly 1 — "The Still Flame"** (Zone 2)
Visual: A torch in the collapsed marketplace burns without fuel or oxygen. The
flame does not flicker. It has burned since the Shattering.
First interaction text: "The flame is warm. It casts no shadow. You cannot find
any fuel source."
Clue delivered: "An inscription below the bracket reads: 'Ward-Fire Class Seven.
Relay station 2-of-10. Sustains until primary source fails.' The primary source
has not failed."
Clue requires: Zone 5 Anomaly context to understand "relay station."
Fragment awarded on full investigation (requires also interacting with Zone 5
Anomaly): Fragment 1 — Ward-Iron (Warden's Crest component)

**Anomaly 2 — "The Reversed River"** (Zone 3)
Visual: A 40m section of the Greenspire stream flows uphill.
First interaction: "Water flows uphill. It has done so for seven years. Local
shepherd records note it began the night of the Shattering."
Clue: Gravity inversion field, origin point unknown. Measurement marks scratched
into streambed show it has been slowly shrinking: 40m now, was 120m initially.
Cross-zone link: Zone 9 Anomaly shows the same measurement system.
Fragment: Fragment 2 — Ward-Flow

**Anomaly 3 — "The Silent Bell"** (Zone 4 — mine interior)
Visual: A bronze bell hangs in the mine shaft. It rings, audibly, at irregular
intervals. When the player approaches, it stops. When they move away, it resumes.
First interaction: "The bell is cold. No mechanism. No wind. The miners scratched
tally marks on the wall — the bell has rung 4,118 times since the Shattering.
Someone counted."
Cross-zone link: Zone 7 has a matching bell, different tally count.
Fragment: Fragment 3 — Ward-Echo

**Anomaly 4 — "The Dry Pool"** (Zone 5)
Visual: A stone pool in the temple, completely dry, but the water surface is
visible as a shimmering distortion 30cm above the stone.
First interaction: "You can feel the water. You cannot touch it. The distortion
moves like a surface disturbed by wind that is not there."
Cross-zone link: The Zone 2 Still Flame. Both are classified as "relay station"
objects. This anomaly is the second relay.
Fragment: Fragment 4 — Ward-Veil (awarded when both Zone 2 and Zone 5 anomalies
are fully investigated — a soft multi-step requirement)

**Anomaly 5 — "The Growth Ring"** (Zone 6)
Visual: A ring of ash 80m in diameter. Inside the ring, grass grows normally.
Outside, the ember plains scorching is total. The ring is perfectly circular.
First interaction: "The circle is older than the Shattering. A shepherd's memoir
in Zone 3 (Senna's grandmother's journal, if the Senna chain is step 3+) mentions
it as a 'safety field test site' used decades before the Shattering."
Fragment: Fragment 5 — Ward-Ash

**Anomaly 6 — "The Mirror Trees"** (Zone 7)
Visual: Two identical trees, 200m apart, in perfect mirror symmetry — same
branch arrangement, same damage, same lean angle.
First interaction: "The trees are the same age. The same species does not grow
in Zone 7 natively. Both have an identical scar pattern — neither is the original."
Cross-zone link: A Stone Echo in Zone 11 (Dead Archive) shows a botanical diagram
labelled "Duplication Field Test — Class Three."
Fragment: Fragment 6 — Ward-Root

**Anomaly 7 — "The Counting Stone"** (Zone 9)
Visual: A flat stone tablet covered in numbers. The numbers change between visits.
First interaction: "The numbers are measurement readings. The unit is unfamiliar.
Some values are circled. One value is underlined and reads: '0.0000 — Stable.'"
Cross-zone link: The Zone 3 reversed river's shrinking measurement system uses
the same unit.
Fragment: Fragment 7 — Ward-Stone

**Anomaly 8 — "The Warm Ground"** (Zone 10)
Visual: A 20m patch of ground that is always warm, even in Zone 10's perpetual
cold. Snow melts immediately on it. Plants grow in a perfect circle within it.
First interaction: "Under the ground, 30cm down: a perfectly smooth disc of black
glass. Unmovable. Warm to the touch. No inscription."
Cross-zone link: Zone 14 has the same disc exposed on the surface — it was buried
here, it is visible there. The disc is a network node.
Fragment: Fragment 8 — Ward-Core

**Anomaly 9 — "The Last Soldier"** (Zone 12)
Visual: A full suit of armour, standing upright, in the middle of an open plain.
No skeleton inside. No tracks approaching. It has been there since the Shattering.
First interaction: "The armour is locked in a standing position by something
internal. Opening the visor reveals a single playing card: the Seven of Coins.
On the back: 'For when I return.' No signature."
Fragment: Fragment 9 — Ward-Guard (this is intentionally the most emotionally
affecting anomaly — no explanation is ever given for who left it or why)

**Anomaly 10 — "The First Echo"** (Zone 15 — final zone, accessible after
Chapter 15 main quest unlock)
Visual: The source of all anomalies is visible from the Forge-Heart Chamber
entrance: a crystalline sphere, 2m diameter, hovering 3m off the ground. It
does not reflect light. It absorbs it.
First interaction: "Every anomaly you have found points here. The Still Flame,
the Reversed River, the Silent Bell — they were all powered by this sphere's
residual energy. The sphere is the Forge-Heart's overflow regulator. It is still
working. It has been catching the overflow since the Shattering. It is nearly full."
The sphere is the reason the Forge-Heart has not shattered a second time.
Full investigation (requires having collected Fragments 1-9 from other anomalies):
Fragment 10 — Ward-Seal is awarded. Warden's Crest recipe becomes craftable.
Final text: "You understand now. The anomalies were not the Shattering's scars.
They were its bandages. Someone planned for this."

### Investigation UI

Anomaly investigation does not use the quest log. It uses the Codex's dedicated
"Mysteries" tab (see section 7). Each mystery shows:
- Anomaly name and zone
- Current status: Observed / Clue Found / Cross-Referenced / Understood
- Fragment count: X/10 collected
- A one-line hint toward the next step ("This anomaly connects to something in
  Zone 5 — look for matching classification markings")

The hint is only shown after "Clue Found" status. Before that, the player must
explore. This is consistent with BOTW shrine discovery: the signal is visible,
the path is the player's.

---

## 6. Tutorial and Onboarding Quests

### Design Constraint

No tutorial popup walls. No "Press this button" prompts. Every mechanic is taught
by placing the player in a situation where the correct action yields an obvious
reward. Failure states are gentle: no permanent loss in the first 3 minutes.

### The First 5 Minutes — Guided Failure Arc

The game opens on a single wave with 6 enemies (well below the 20-enemy standard)
and no towers. The castle takes minor damage regardless of what the player does.
The wave ends. The hero survives. The castle is at 70% HP.

This controlled failure is intentional. The player now wants to fix it.

**Minute 0:00 — Wave Arrival**
The WAVE INCOMING banner appears. Enemies enter from the right side of the screen.
The hero can move. Nothing explains controls. The joystick base appears wherever
the player first places a thumb on the left half of the screen (existing implementation).
Most players will discover movement within 20 seconds by prodding the screen.

**Minute 0:45 — Wave Clears**
Six enemies defeated (or one escaped — the castle took some damage). HUD shows
current HP. The castle HP bar is visible. The player has an instinct: "I need
more defense."

**Minute 1:00 — Scout Lira Appears**
Lira walks onto screen from the castle gate. Her dialogue bubble says (no tap
required — it auto-displays for 4 seconds): "You held that one. Barely. Come here,
I want to show you something." She walks toward the ARCHER button zone and stops.
Her portrait pulses.

This is the tutorial trigger: curiosity plus a character moving toward something.

**Minute 1:10 — First Archer Purchase**
When the player approaches Lira (within 90px), the interact button appears. Tap.
Lira says: "Gold. There — see the count. Touch the ARCHER button. Yes, the one
at the bottom right." The button pulses. This is the only time a specific UI
element is directly pointed to. It is earned by following Lira.

Player taps ARCHER. An archer is placed. Lira: "Watch." The next 6-enemy wave
begins automatically (10-second countdown). The archer fires. Gold drops. The
player sees the coin magnet working.

**Minute 2:00 — Wave 2 Clears**
Castle HP is higher than after Wave 1 (the archer absorbed damage). Lira: "That
is the difference one archer makes. You can get more. The gold is yours to spend."
She walks away. Her NPC chain Step 1 is now active (amber ring on her portrait
in the HUD).

**Minute 2:30 — First Exploration Prompt**
The "EXPLORER" button appears between Wave 2 and Wave 3 (existing implementation,
requires 1 tower). It pulses once. No tooltip. A player who taps it enters the
exploration mode. A player who buys another archer stays in TD. Both are valid.

If the player taps EXPLORER:

**Minute 3:00 — Zone 1 Entry**
The fade transition occurs. The hero stands at the Zone 1 entry. The Scout's Pack
(Chapter 1 objective) glows amber 80m ahead. The hero walks toward it. The glow
is magnetic. No instruction needed.

The pack interaction delivers Map Fragment 1 and the game's first piece of lore.
This is the first voluntary story beat. The player chose to go there.

**Minute 4:00 — Daily Board Discovery**
On the walk back from the pack to the castle entry, the Daily Board is visible.
It has a gentle pulse. No marker. No arrow. Most players tap it out of curiosity.
If they do, the first daily contract is visible: always a gather quest in Zone 1.
If they do not, the board persists — they will find it eventually.

**Minute 5:00 — RETURN TO GARRISON**
The RETURN button (existing implementation) is prominent. The player returns. Wave 3
begins. They have learned: movement, archer purchase, exploration entry, exploration
object interaction, and the daily board. Through action, not instruction.

### Tutorial Completion Metric

No tutorial is ever "completed." There is no tutorial state. The tutorial is the
first chapter of Scout Lira's NPC chain, which teaches terrain, towers, and zones
through its 5 steps. Players who engage with Lira learn the game thoroughly.
Players who ignore Lira learn through play. Both paths work.

---

## 7. Quest Log UI Design

### Constraint

960×540 landscape, touch-only. No more than 3 taps to access any quest information
from anywhere in the game. Minimum tap target: 72×72px. No hover states.

### Layout Architecture

The Quest Log is accessed via one tap on the JOURNAL icon in the HUD. The icon
is a scroll, 72×72px, positioned at the top-right of the HUD bar (next to the
pause button, which is already implemented). This is 1 tap from anywhere.

The Journal Panel slides up from the bottom, covering 75% of screen height
(405px tall, full width 960px). The remaining 25% (the top HUD bar) remains
visible and interactive (player can see HP, gold, wave count).

### Tab Structure (4 tabs across the top of the panel, each 240×48px)

```
[ QUESTS ]  [ CODEX ]  [ MYSTERIES ]  [ DAILY ]
```

Each tab label is 48px tall (touch-safe). Tapping a tab switches content instantly.

**QUESTS tab** — Active quest chains and main quest progress

Left column (300px wide): scrollable list of active quest chains. Each entry is
a card: 290×56px. Card content: NPC portrait (40×40px, left), quest chain name
(bold, 14pt), current step indicator ("3/5" right-aligned). Active cards have
a thin amber left border. Completed chains have a grey checkmark.

Right column (640px wide): selected quest detail. Shows:
- Quest chain name (18pt bold, top)
- Current step description (14pt, 3-4 lines max)
- Objective status: each sub-objective on its own line with checkbox icon
  (filled amber = complete, empty = pending)
- Reward preview (right-aligned row): gold amount + item icon
- "TRACK" button (bottom-right, 120×44px): places an amber compass icon on the
  world minimap pointing toward the quest's current objective location

Selecting a quest from the left list takes 1 tap. Viewing its detail is
immediate. Total: 2 taps from anywhere in game (Journal icon + quest card).

**CODEX tab** — Zone objectives and lore

Top row: zone selector. 15 small zone icons (48×48px each) in a horizontal
scroll row. Tapping a zone icon loads its Codex below. Currently active zone
is highlighted with amber border.

Below zone selector: 5 objective cards in a vertical list (full width, 56px tall
each). Completed objectives: checkmark, reward shown, greyed background.
Active objective: amber glow, full description. Hidden objectives: "???" with
category icon, light grey text.

Below objectives: Stone Echo counter ("3/3 echoes discovered") with a small
amber indicator for each found echo.

Total: 2 taps from Journal (tab tap + zone icon tap) = 3 taps total from HUD.

**MYSTERIES tab** — Anomaly investigations

10 anomaly cards in a 2-column grid (468×80px each card, 12px gap). Each card:
anomaly name (bold), zone label, status badge ("OBSERVED" / "INVESTIGATING" /
"UNDERSTOOD"), fragment icon (grey = not collected, amber = collected).

Tapping a card expands it to full-width (still within the panel) showing:
current status description, active clue (if status > OBSERVED), and the
"connects to Zone X" hint (if status = CLUE FOUND or higher).

Below the grid: Warden's Crest progress bar (0/10 fragments, fragments shown
as small icons that fill in as collected).

Total: 2 taps from Journal (tab + card) = 3 taps total.

**DAILY tab** — Daily quest board

Three contract cards (full width, 90px tall each). Each card is identical in
layout to the Daily Board world panel (so the same information appears in both
places — no context switch). "ACCEPT" button is not shown here (acceptance
happens at the world board). This tab shows: contract title, description,
reward, progress bar if accepted (0/N progress shown).

"GO TO BOARD" button at the bottom of the panel (full width, 48px): places
an amber compass icon on the map pointing toward the Daily Board.

Total: 1 tap (Journal + DAILY tab already visible if last used).

### Minimap Integration

The game minimap (top-left of HUD, 120×80px, existing or planned) shows:
- Amber dot: active quest objective location
- White dot: NPC locations (when within 300m)
- Grey dot: discovered Stone Echoes
- Pulsing amber ring: Daily Board location (only when a contract is accepted
  and not yet complete)

Tracking a quest via the QUESTS tab "TRACK" button places the amber dot on
the minimap. Only one quest can be tracked at a time. Tapping "TRACK" on a
different quest moves the dot.

### One-Thumb Reachability

All panel content is reachable with the right thumb (dominant hand, landscape).
The Journal icon is top-right. All tabs are top of the panel. The left column
quest list is scrollable with right-thumb swipe. The right column is fixed
(no scroll needed — content is max 6 lines). Tab targets are 240px wide each
(highly touch-tolerant).

The panel dismisses with a downward swipe from anywhere on the panel, or with
a tap on the 25% of screen above the panel (the HUD bar). No close button.
This is consistent with the existing overlay dismiss pattern.

---

## Implementation Notes for Godot 4.6 / GDScript

### Quest State Architecture

Quest state is session-only (ADR-009: no FileAccess in MVP). All quest progress
is stored in a QuestManager autoload singleton as a Dictionary of Dictionaries:

```gdscript
## quest_manager.gd (autoload)
## Session-scoped quest state. No persistence between sessions in MVP.

var chain_state: Dictionary = {
    "darro": {"step": 0, "complete": false},
    "lira":  {"step": 0, "complete": false},
    "orrin": {"step": 0, "complete": false},
    "caelo": {"step": 0, "complete": false},
    "senna": {"step": 0, "complete": false},
}

var zone_objectives: Dictionary = {}
## zone_objectives["zone_4"] = {"obj1": true, "obj2": false, ...}

var mystery_state: Dictionary = {}
## mystery_state["anomaly_1"] = {"status": "CLUE_FOUND", "fragment": true}

var daily_accepted: Array[String] = []
## daily_accepted = ["gather_ironwood", "defeat_cavaliers"]

var warden_fragments: int = 0

signal quest_step_advanced(npc_id: String, new_step: int)
signal zone_objective_complete(zone_id: String, obj_id: String)
signal mystery_status_changed(anomaly_id: String, new_status: String)
signal fragment_collected(fragment_id: String, total: int)
```

### NPC Interaction Pattern

NPC scripts extend Node2D and use the existing INTERACT_RADIUS proximity system
in Main.gd. The interact button label is set by the NPC's `get_interact_label()`
method (already in the interaction pattern from the RPG UX improvements noted
in MEMORY.md).

```gdscript
## npc_base.gd — base class for all quest NPCs
extends Node2D

@export var npc_id: String = ""
var _current_step: int = 0

func get_interact_label() -> String:
    return "Parler"

func on_interact() -> void:
    _current_step = QuestManager.chain_state[npc_id]["step"]
    _show_dialogue_for_step(_current_step)

func _show_dialogue_for_step(step: int) -> void:
    pass  ## Override in each NPC script

func _advance_step() -> void:
    QuestManager.chain_state[npc_id]["step"] += 1
    QuestManager.quest_step_advanced.emit(npc_id, QuestManager.chain_state[npc_id]["step"])
```

### Daily Contract Seeding

Deterministic daily selection using Godot's built-in hash:

```gdscript
## daily_board.gd
const DAILY_POOL_SIZE := 36
const CONTRACTS_PER_DAY := 3

func get_today_contracts() -> Array[String]:
    var day_number := int(Time.get_unix_time_from_system()) / 86400
    var seed_val := hash(str(day_number) + str(GameState.player_seed))
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    var indices: Array[int] = []
    while indices.size() < CONTRACTS_PER_DAY:
        var idx: int = rng.randi_range(0, DAILY_POOL_SIZE - 1)
        if idx not in indices:
            indices.append(idx)
    return indices.map(func(i): return CONTRACT_POOL[i])
```

### Zone Codex Resource

Zone objectives persist as a GDScript Resource class (session-scoped, not saved):

```gdscript
## zone_codex_entry.gd
class_name ZoneCodexEntry
extends Resource

@export var zone_id: String = ""
@export var objectives_complete: Array[bool] = [false, false, false, false, false]
@export var echoes_found: int = 0
@export var echoes_total: int = 3
@export var star_complete: bool = false
```

### Journal UI Scene Structure

The Journal Panel is a CanvasLayer child (layer=2, above the existing HUD at
layer=1). It uses a TabContainer with 4 children. The TabContainer header is
hidden and replaced by custom Button nodes (48px tall, touch-safe) that call
`tab_container.current_tab = N`. This avoids the TabContainer's default header
styling which is not touch-optimised.

The panel slides via Tween (ADR-007: AnimationPlayer forbidden on CanvasLayer):

```gdscript
## journal_panel.gd
func show_panel() -> void:
    visible = true
    var tween := create_tween()
    tween.tween_property(self, "position:y", 0.0, 0.18).set_ease(Tween.EASE_OUT)

func hide_panel() -> void:
    var tween := create_tween()
    tween.tween_property(self, "position:y", 405.0, 0.15).set_ease(Tween.EASE_IN)
    await tween.finished
    visible = false
```

---

## Balance Reference Table

| Mechanic | Value | Rationale |
|----------|-------|-----------|
| NPC step wave gate | 1/4/8/14/20 | Matches wave difficulty curve |
| Daily contract gold range | 60–180g | 10–30% of a session's expected gold income |
| Zone objective 5 star bonus | +20% gold drop per zone | Non-exploitable (zone-scoped) |
| Warden's Crest fragments | 10 total | One per anomaly; 10 anomalies is max content |
| Legendary reward | Wave preview + +20g elite bonus | Strong but not required for any difficulty |
| Daily board reroll cost | 15g | Minor friction; prevents abuse, not progress |
| NPC step 5 unique reward | Permanent passive, named | Emotional investment + mechanical differentiation |
| Anomaly "OBSERVED to UNDERSTOOD" steps | 3 states + cross-zone | Paced across multiple sessions naturally |
| Tutorial controlled failure | Wave 1 at 70% castle HP | Creates urgency without despair |
| Max total gold cost reduction | 30% (Darro 5% + Forge 20% + other 5%) | Balanced against wave scaling |

---

*End of document — Garrison Quest System v1.0*
*Next step: ADR for QuestManager autoload, GUT test scaffold for chain_state transitions*
