# Cross-GDD Review Report — v2

**Date**: 2026-05-19
**GDDs Reviewed**: 10 (+ game-concept.md, game-pillars embedded in game-concept.md)
**Systems Covered**: game-state, hero-movement, camera, castle, enemy-wave, economy,
  archer-formation, hud, archer-tower, forge
**Entity Registry**: design/registry/entities.yaml (loaded — 10 formulas, 26+ constants)
**Previous Report**: design/gdd/gdd-cross-review-2026-05-19.md (verdict: FAIL — superseded by this report)

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **B-01 — Archer Formation missing `tower_purchased` inbound signal** *(RESOLVED — fix applied 2026-05-19)*

**GDDs involved**: `archer-formation.md` (Interactions table), `archer-tower.md` (R3)

`archer-tower.md` R3 defines a slot-release contract: when `tower_purchased` fires,
Archer Formation must release `TOWER_ARCHERS_COUNT = 2` occupied slots to the tower.
However, `archer-formation.md` Interactions table (§ "Interactions with Other Systems")
does NOT list `tower_purchased` as an inbound signal from Archer Tower. A programmer
reading only `archer-formation.md` would miss this slot-release behavior entirely.

**Fix applied**: Added `← Signal | Archer Tower | tower_purchased | On tower purchase`
row to archer-formation.md Interactions table.

---

### Warnings (should resolve, but do not block architecture)

⚠️  **W-01 — Camera GDD lists Economy as downstream for `cam_pos`; Economy GDD has no such dependency**

`camera.md` Interactions table lists Economy as a downstream receiver of `cam_pos`
for an off-screen indicator feature. The Economy GDD has no corresponding upstream
dependency on Camera. If the off-screen indicator uses camera position, Economy must
document that dependency. Likely: Economy does not use `cam_pos` directly — the
off-screen indicator logic lives in HUD or a separate IndicatorManager. Resolve by
clarifying which system owns the off-screen coin indicator.

**Recommended**: Remove Economy from Camera's downstream in `camera.md`, or add Camera
as an upstream dep in `economy.md` with a note explaining the off-screen indicator data flow.

---

⚠️  **W-02 — Hero Movement reads `SHOOT_IVTL` (owned by Archer Formation) but does not list Archer Formation as upstream**

`hero-movement.md` references `SHOOT_IVTL` (the shared fire timer) but the Dependencies
section does not list Archer Formation as the authoritative owner. Archer Formation GDD
clarifies "SHOOT_IVTL — Authoritative owner: this GDD" in the tuning knobs table. The
bidirectionality note at the bottom of `archer-formation.md` flags this for `/design-review`.

**Recommended**: Add Archer Formation as an upstream dep in `hero-movement.md` with
interface: "reads SHOOT_IVTL for shared fire timer coordination."

---

⚠️  **W-03 — Constant name mismatch: `SPAWN_IVTL` (game-state.md) vs `SPAWN_INTERVAL` (enemy-wave.md)**

`game-state.md` references the wave spawn interval as `SPAWN_IVTL`.
`enemy-wave.md` defines this constant as `SPAWN_INTERVAL`.
One of these is stale. The entity registry (`entities.yaml`) does not record this constant
by either name — it is not registered as a shared constant.

**Recommended**: Align both GDDs on one name (`SPAWN_INTERVAL` preferred — more readable),
register it in `entities.yaml`, and confirm the authoritative owner is enemy-wave.md.

---

⚠️  **W-04 — Stale "(Provisional — [X] GDD not yet written)" notes remain in multiple GDDs**

Several GDDs were authored early and contain notes like "(Provisional — economy GDD not yet
written)" or "(Provisional — forge GDD not yet written)". All 10 MVP GDDs are now authored.
These provisional notes are stale and could mislead programmers into thinking those systems
are unspecified.

**GDDs with stale provisional notes** (non-exhaustive — grep `Provisional` across gdd/):
castle.md, hero-movement.md, enemy-wave.md, game-state.md

**Recommended**: Remove all "Provisional — [X] GDD not yet written" notes across all GDDs
before implementation begins.

---

⚠️  **W-05 — Stale open-question in `archer-tower.md` OQ-4: states archer-formation.md does not define the Archer Tower interface, but it now does**

`archer-tower.md` OQ-4 reads: "This GDD defines R3 (slot-release contract) but
archer-formation.md does not yet describe the tower interface. Update archer-formation.md
before implementation." This was resolved: archer-formation.md now lists Archer Tower as a
downstream dependent with the R3 interface. OQ-4 should be marked RESOLVED.

**Recommended**: Update OQ-4 in `archer-tower.md` to `[RESOLVED — archer-formation.md
updated 2026-05-19]`.

---

⚠️  **W-06 — Multiple GDD headers show `Status: Needs Revision` contradicting systems-index.md which shows all as `Designed`**

9 of 10 system GDDs have `> **Status**: Needs Revision` in their header block.
`systems-index.md` lists all 10 MVP GDDs with `Status: Designed`.
This contradicts itself and would block any skill that checks for "Needs Revision"
status (including `/gate-check` cross-reference).

**Recommended**: Update all 9 GDD headers from `Needs Revision` → `Designed` *(applied 2026-05-19)*.

---

⚠️  **W-07 — `session_reset` signal ordering not specified across game-state.md, archer-formation.md, economy.md**

When `game_over` / `session_restart` fires, multiple systems reset simultaneously:
Economy resets gold to 60, Archer Formation resets to 2 archers, Enemy Wave clears
active enemies. No GDD specifies the order in which these resets execute, or whether
they are atomic within a single frame. If reset order matters (e.g., Economy queries
Archer Formation's `current_archer_count` during reset), a race could produce a
one-frame glitch state.

**Recommended**: Document reset ordering policy in the governing ADR (Architecture phase).
A single `session_reset_completed` signal emitted by Game State Machine after all
system resets is the standard Godot pattern — add this as an ADR constraint.

---

⚠️  **W-08 — Same-frame edge case: game_over fires while a dwell timer is at 0.79 s (one tick before completing)**

If a castle receives lethal damage on the same frame that a dwell timer completes
(0.8 s reached) in Economy or Archer Tower, two events fire simultaneously:
`dwell_completed` (zone action) and `game_over`. The order of processing is undefined
across GDDs. A zone purchase could theoretically be credited after `game_over` resets
economy state.

**Recommended**: Specify in the ADR that `game_over` takes priority over all pending
zone events. Zone systems should check `is_game_over: bool` before applying any purchase.
Document this as an ADR constraint.

---

## Game Design Issues

### Blocking

*None.*

---

### Warnings

*(No design theory warnings — see below.)*

---

## Design Theory Assessment

### Pillar Coverage

All 10 system GDDs explicitly serve at least one of the 4 design pillars:
1. **Un seul doigt, zéro friction** — hero-movement, touch-input architecture, zone dwell model
2. **Chaque pièce d'or est une décision** — economy, archer-formation cost tiers, archer-tower, forge
3. **L'armée se voit grandir** — archer-formation V-formation visual growth
4. **Tension sans panique** — enemy-wave scaling, castle HP stakes, HUD clarity

No pillar drift detected. No anti-pillar violations detected.

D-02 (Forge redesign: modal menu → 4 spatial FORGE_ZONEs) resolved the prior anti-pillar
violation. All zone interactions are joystick-only.

---

### Cognitive Load

Simultaneously active decisions during a typical gameplay moment: **1–2 maximum**
(movement direction + zone entry/avoidance). All other systems are passive responders.
Well below the 4-system cognitive overload threshold.

---

### Dominant Strategy

No dominant strategy detected. Cost tier structure (ARCHER_COST_TIER_1=30g vs
ARCHER_COST_TIER_2=60g, TOWER_COST=100g, FORGE_COST=200g) and wave DPS requirements
table (D-4 in archer-formation.md) confirm that investing only in archers creates a
late-wave marginal failure at n=6 (waves 11–13). Multiple spending vectors required.

---

### Economic Loop

| Resource | Sources | Sinks | Balance |
|----------|---------|-------|---------|
| Gold | Enemy drops (15g/kill) | Archer recruit (30/60g), Tower (100g), Forge (200g) | Bounded — formation cap and finite upgrades prevent runaway accumulation |
| Archer slots | Recruitment | Tower purchase (releases 2 slots) | Fixed ceiling 8, release-reclaim dynamic via tower |
| Enemy HP | Wave scaling (+3 HP/wave) | Formation DPS | Balanced — see D-4 table |

No unbounded positive feedback loops. No resource with source but no sink.

---

### Difficulty Curve

Enemy HP scales linearly (+3 HP/wave, 1–13 waves: 30→66 HP).
Enemies per wave scales linearly (+1.15/wave: 5→20 enemies).
Formation DPS scales discretely by player recruitment choices.
DPS requirement table (D-4) shows that players must recruit continuously — the curve
is designed to demand consistent gold management, not burst recruitment. Compatible.

---

### Player Fantasy Coherence

All systems present a compatible player identity: **a mobile commander who grows their
force through position and economy, never through direct combat action**. No system
contradicts this identity. Economy, Archer Formation, Archer Tower, and Forge all
reinforce the "growing force" fantasy from different angles.

---

## Cross-System Scenario Walkthroughs

**Scenarios walked**: 4

1. Wave start → enemy spawns → formation fires → castle contact
2. Gold accumulation → zone dwell → archer recruit → formation expansion
3. Tower purchase → slot release → TOWER_ARCHERS_COUNT transferred *(B-01 scenario)*
4. game_over trigger → simultaneous reset across Economy, Archer Formation, Enemy Wave

---

### Blockers

🔴 **Scenario 3 — Tower Purchase Fan-Out** *(RESOLVED — B-01 fix applied)*

**Systems involved**: Economy → Archer Tower → Archer Formation

Trigger: Player dwells 0.8 s in TOWER_ZONE with ≥ 100g.
Economy deducts 100g, emits `tower_purchased`.
Archer Tower receives signal, applies R3 slot-release contract.
Archer Formation must receive `tower_purchased` and release 2 slots.

**Failure mode (pre-fix)**: Archer Formation's Interactions table did not list
`tower_purchased` as an inbound signal. The slot-release behavior was documented in
Archer Tower (R3) but invisible to Archer Formation's programmer. The 2 slots would
not be released, causing: formation count = 8 even though 2 archers are now in the tower;
next `recruit_purchased` would be silently discarded (capacity guard). Bug is silent.

**Fix applied**: `← Signal | Archer Tower | tower_purchased | On tower purchase` row
added to archer-formation.md Interactions table.

---

### Warnings

⚠️  **Scenario 4 — game_over + simultaneous zone dwell completion**

**Systems involved**: Castle → Game State Machine → Economy / Zone / Archer Formation

If a dwell timer completes (0.8 s) on the same frame that Castle takes lethal damage:
- `dwell_completed` fires → Economy processes purchase → gold deducted, `recruit_purchased` emitted
- `game_over` fires → Archer Formation resets to 2 slots, gold resets to 60

Race condition: the recruit may be processed before or after the reset depending on
signal processing order. If after: `recruit_purchased` fires on a just-reset formation
(3 archers at session start instead of 2). If before: recruit is discarded (formation
reset immediately overwrites). Either is acceptable but should be explicitly specified.

**Recommendation**: ADR constraint — `game_over` handler disconnects all zone signals
before emitting; or, zone systems check `is_game_over` before applying purchases.

---

### Info

ℹ️  **Scenario 1 — `session_reset` signal processing order**

Economy, Archer Formation, and Enemy Wave all listen for `game_over` / `session_restart`.
No GDD specifies which system processes first. For MVP, processing order does not affect
visible game state (each system resets independently). Document in the ADR for safety.

---

## GDDs Flagged for Action

| GDD | Action Required | Type | Priority |
|-----|----------------|------|----------|
| `archer-formation.md` | Add `tower_purchased` inbound signal to Interactions table | Consistency — B-01 | ~~BLOCKING~~ → RESOLVED |
| `archer-formation.md` | Update Status header from "Needs Revision" → "Designed" | Housekeeping — W-06 | Applied |
| `archer-tower.md` | Mark OQ-4 as RESOLVED | Housekeeping — W-05 | Warning |
| `hero-movement.md` | Add Archer Formation as upstream dep (SHOOT_IVTL) | Consistency — W-02 | Warning |
| `camera.md` | Clarify Economy downstream or remove | Consistency — W-01 | Warning |
| `game-state.md` / `enemy-wave.md` | Align `SPAWN_IVTL` vs `SPAWN_INTERVAL` constant name | Consistency — W-03 | Warning |
| All 9 remaining GDDs | Update Status header to "Designed" | Housekeeping — W-06 | Applied |

---

## Verdict: CONCERNS

No blocking consistency or design theory issues remain after the B-01 fix.
Warning-level items (W-01 through W-08) should be resolved during ADR authoring —
they identify interface ambiguities that will be crystallised by the ADRs.

**Architecture may proceed.** `/create-architecture` is the recommended next step.

### Resolved blockers since v1 report:
- All 13 consistency/design blockers from gdd-cross-review-2026-05-19.md resolved
- B-01 (archer-formation.md missing tower_purchased signal) — resolved 2026-05-19
- All GDD Status headers updated to "Designed" — 2026-05-19

---

*Report generated by /review-all-gdds skill. Supersedes gdd-cross-review-2026-05-19.md.*
