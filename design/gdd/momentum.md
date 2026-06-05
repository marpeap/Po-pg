# Momentum

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-20
> **Implements Pillar**: Pillar 2 — Chaque pièce d'or est une décision | Pillar 4 — Tension sans panique
> **Sprint**: Sprint 5 — new system

## Overview

The Momentum system rewards consecutive kills within a narrow time window by incrementing a kill streak counter that activates damage multipliers across three tiers. Each enemy killed within `STREAK_WINDOW = 4.0 s` of the previous kill advances the streak. If 4 seconds pass without a kill, the streak resets to zero. At tier thresholds (5, 10, 15 kills), the formation's effective projectile damage increases by a multiplier, making the army more lethal while the player sustains pressure. The streak is automatic — no additional input required. It decays passively through inaction and resets on wave end.

## Player Fantasy

The player feels a palpable surge when the formation tears through a dense wave at full momentum — arrows hit faster, enemies fold faster, and the HUD pulsates with each streak tier reached. This is the "flow state" mechanic: the game rewards players who charge into the enemy line and keep killing rather than retreating to safety. Momentum is the invisible force that makes an aggressive player feel unstoppable in wave 7 versus a cautious player who breaks their streak collecting gold. The tension of "don't let the streak drop" gives Pillar 4 ("Tension sans panique") a second dimension: threat is not only the castle HP bar, but also the streak timer ticking toward zero while the next enemy cluster hasn't yet reached arrow range.

The fantasy is *the run* — a continuous flow of decisive movement, kills, and escalating power. Momentum makes the player feel like they are building toward something with every kill, not just waiting for waves to end.

## Detailed Design

### Core Rules

1. **Kill streak counter**: The formation maintains a `kill_streak: int` initialized to 0 at session start and at each wave end. The counter is unbounded above.

2. **Streak advancement**: When any enemy's HP reaches 0 (killed by any projectile from Archer Formation), and `time_since_last_kill ≤ STREAK_WINDOW`, `kill_streak += 1`. "Last kill" is the most recent enemy death, regardless of which archer delivered the killing blow.

3. **Streak window**: `time_since_last_kill` counts up from 0 each frame starting after the most recent kill. When `time_since_last_kill > STREAK_WINDOW = 4.0 s`, the streak resets: `kill_streak = 0`. The window does not restart mid-wave — it is a simple elapsed-time gate.

4. **Streak reset events**: `kill_streak` resets to 0 on:
   - `time_since_last_kill > STREAK_WINDOW` (natural decay)
   - Wave end (after last enemy dies, before inter-wave pause begins)
   - `session_restart` or `game_over`

   The wave-end reset is intentional: each wave begins at zero, preventing streak from carrying forward and trivializing later waves.

5. **Streak tier thresholds and damage multipliers**:

   | Tier | kill_streak Range | Multiplier | Effect |
   |------|-----------------|------------|--------|
   | NONE | 0–4 | × 1.00 | Normal DPS — no visual effect |
   | TIER_1 | 5–9 | × `STREAK_MULT_T1 = 1.15` | +15% PROJ_DAMAGE per hit |
   | TIER_2 | 10–14 | × `STREAK_MULT_T2 = 1.30` | +30% PROJ_DAMAGE per hit |
   | TIER_3 | 15+ | × `STREAK_MULT_T3 = 1.50` | +50% PROJ_DAMAGE per hit |

6. **Multiplier application**: The streak multiplier applies to `PROJ_DAMAGE` as a runtime modifier. The implementation computes `effective_damage = floor(PROJ_DAMAGE × streak_multiplier(kill_streak))` at the moment each projectile resolves its collision. `PROJ_DAMAGE` constant is not modified — only the collision handler reads the multiplier. This preserves the unmodified constant for all other systems (balance formulas, test references).

7. **Ownership**: Momentum is owned by Archer Formation (as a sub-component). Economy is notified via `streak_tier_changed(new_tier: int)` for gold bonus logic (see rule 8). HUD reads `kill_streak` and `streak_tier` directly from Archer Formation.

8. **Gold momentum bonus**: At each tier transition (NONE→TIER_1, TIER_1→TIER_2, TIER_2→TIER_3), Economy receives `streak_tier_changed` and immediately grants a one-time gold bonus: `STREAK_GOLD_BONUS = [0, 10, 20, 30]g` (index by new tier). This bonus is not from a coin — it is a direct balance credit. No visual coin spawns. Economy emits `gold_changed`. This creates a secondary incentive to reach and maintain streak tiers.

9. **Streak HUD visibility**: `kill_streak` and `streak_tier` are exposed by Archer Formation to the HUD. The HUD displays the streak counter and tier indicator. Visual design of the HUD element is owned by the HUD GDD.

---

### States and Transitions

| Streak State | Condition | DPS Multiplier |
|---|---|---|
| NONE | `kill_streak` 0–4 OR `time_since_last_kill > STREAK_WINDOW` | × 1.00 |
| TIER_1 | `kill_streak` 5–9 AND within window | × 1.15 |
| TIER_2 | `kill_streak` 10–14 AND within window | × 1.30 |
| TIER_3 | `kill_streak` ≥ 15 AND within window | × 1.50 |

Transitions:
- Any tier → NONE: `time_since_last_kill > STREAK_WINDOW` (decay), wave end, or session reset
- NONE → TIER_1: `kill_streak` reaches 5 via consecutive kills within window
- TIER_1 → TIER_2: `kill_streak` reaches 10
- TIER_2 → TIER_3: `kill_streak` reaches 15
- Any tier → lower tier: NOT possible during a single wave (streak only increases within a window, then fully resets — never decrements incrementally)

---

### Interactions with Other Systems

| Direction | System | Data / Signal | When |
|-----------|--------|---------------|------|
| ← Event | Enemy Wave | enemy HP → 0 (kill event) | Each enemy death — Archer Formation detects HP = 0 on collision |
| ← Signal | Game State Machine | `session_restart`, `game_over` | Resets `kill_streak` to 0 |
| ← Event | Enemy Wave | `wave_cleared` | Resets `kill_streak` to 0 at wave end |
| → Signal | Economy | `streak_tier_changed(new_tier: int)` | On tier transition — Economy grants gold bonus |
| → Expose | HUD | `kill_streak: int`, `streak_tier: int` | Each frame — HUD reads for display |
| → Modify | Archer Formation | `effective_damage` in collision handler | Each projectile collision — multiplier applied |

## Formulas

### M-1 — streak_multiplier(kill_streak)

`streak_multiplier(k) = STREAK_MULT_T3 if k ≥ 15 else STREAK_MULT_T2 if k ≥ 10 else STREAK_MULT_T1 if k ≥ 5 else 1.0`

| kill_streak | Multiplier | effective_damage (PROJ_DAMAGE = 8) |
|---|---|---|
| 0–4 | 1.00 | 8 |
| 5–9 | 1.15 | 9 (floor(9.2)) |
| 10–14 | 1.30 | 10 (floor(10.4)) |
| 15+ | 1.50 | 12 |

---

### M-2 — effective_damage(PROJ_DAMAGE, kill_streak)

`effective_damage = floor(PROJ_DAMAGE × streak_multiplier(kill_streak))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base projectile damage | PROJ_DAMAGE | int | 4–16 | Archer Formation constant — not modified |
| Kill streak | kill_streak | int | 0–∞ | Current streak counter |
| Multiplier | streak_multiplier | float | 1.00–1.50 | Tier-based multiplier |
| Effective damage | effective_damage | int | ≥ 0 | Actual HP deducted per projectile hit |

**Output range (PROJ_DAMAGE = 8):** 8 (no streak) → 12 (TIER_3).

**Example:** kill_streak = 12 (TIER_2), PROJ_DAMAGE = 8 → `effective_damage = floor(8 × 1.30) = floor(10.4) = 10`.

---

### M-3 — streak_dps_boost(n, kill_streak)

`streak_dps(n, k) = (n × effective_damage(8, k)) / SHOOT_IVTL`

| n | Streak NONE | Streak TIER_1 | Streak TIER_2 | Streak TIER_3 |
|---|---|---|---|---|
| 2 | 17.8 | 20.0 | 22.2 | 26.7 |
| 4 | 35.6 | 40.0 | 44.4 | 53.3 |
| 6 | 53.3 | 60.0 | 66.7 | 80.0 |
| 8 | 71.1 | 80.0 | 88.9 | 106.7 |

At TIER_3 with n=8, DPS = 106.7 — sufficient to clear the Wave 13 requirement (52.8 DPS) with a 2× margin. This makes the full-army + full-streak state feel definitively dominant.

---

### M-4 — streak_window_kill_requirement(wave)

To sustain TIER_1 (5 kills before streak resets), the formation needs one kill every `STREAK_WINDOW / (5 - 1) = 1.0 s`. At formation DPS of 17.8 (n=2, no streak) against Wave 5 enemies (42 HP), `time_to_kill ≈ 2.36 s`. The player cannot reach TIER_1 with only 2 archers at Wave 5 — they must have recruited to n ≥ 4 (TTK ≈ 1.18 s) to build momentum.

This creates a mechanical coupling between formation size and momentum access:

| n | Wave 5 TTK | Kills/4s | TIER_1 reachable? |
|---|---|---|---|
| 2 | 2.36 s | 1.7 | No — streak decays before 5 kills |
| 4 | 1.18 s | 3.4 | No — borderline (3–4 kills in window) |
| 6 | 0.79 s | 5.1 | Yes — barely |
| 8 | 0.59 s | 6.8 | Yes — comfortable |

Momentum is therefore a mid-to-late game mechanic that rewards the player for having recruited heavily — it is the payoff for making the right spending decisions in early waves.

## Edge Cases

- **If two projectiles kill an enemy in the same frame** (overkill): only one kill event fires (`enemy HP → 0` is detected once). `kill_streak` increments once per enemy death, not once per projectile. No double-increment.

- **If kill_streak is at 4 and the streak window expires before the 5th kill**: `kill_streak` resets to 0, tier remains NONE. The counter does not roll back through previous tiers — it always returns to 0. The player must restart the streak from scratch.

- **If the Forge applies a `PROJ_DAMAGE` upgrade mid-wave**: `PROJ_DAMAGE` changes at runtime. `effective_damage` uses the new value immediately on the next collision. The streak multiplier still applies to the new `PROJ_DAMAGE` constant — no stale reference.

- **If `STREAK_WINDOW` is very short (< 1.0 s) during tuning**: Streaks become unreachable at normal kill rates. This is outside the safe range (minimum 2.0 s). Log a warning at session start.

- **If the formation is at n=2 throughout the run**: Per Formula M-4, TIER_1 is unreachable at Wave 5. The system is invisible to the player in this case. This is intentional — Momentum is a reward for economic investment, not a baseline feature.

- **If wave_cleared and session_restart fire simultaneously** (should not occur in normal GSM flow): streak resets once. No double-reset side effects.

- **If `effective_damage` rounds to the same value for two different tiers** (e.g., PROJ_DAMAGE = 7: `floor(7 × 1.15) = floor(8.05) = 8` = same as PROJ_DAMAGE at NONE tier): The DPS gain is zero despite tier advancement. This is a tuning edge case — `PROJ_DAMAGE × (STREAK_MULT_Tn − 1.0) ≥ 1` should hold for each tier to guarantee a meaningful effective_damage increase. Validate during balance pass.

## Dependencies

### Upstream (Momentum depends on)

| System | Type | Interface |
|--------|------|-----------|
| Archer Formation | Hard | Momentum is a sub-component of Archer Formation. Reads `PROJ_DAMAGE` and `SHOOT_IVTL` for formula context. Receives kill events from the projectile collision handler (enemy HP → 0). |
| Enemy Wave | Hard | Kill events triggered by enemy HP reaching 0. Momentum reads no data from Enemy Wave directly — it piggybacks on the kill resolution inside Archer Formation's collision logic. |
| Game State Machine | Hard | Listens for `session_restart`, `game_over` to reset streak. |
| Enemy Wave | Soft | Listens for `wave_cleared` to reset streak at wave end. |

### Downstream (systems that depend on Momentum)

| System | Type | Interface |
|--------|------|-----------|
| Archer Formation | Hard | Reads `effective_damage` in projectile collision handler to determine actual HP deduction. Reads `streak_tier` to trigger visual effects (flash intensity, glow). |
| Economy | Soft | Receives `streak_tier_changed(new_tier)` to grant tier transition gold bonuses. Economy is not blocked if signal is not connected — gold bonus is optional. |
| HUD | Soft | Reads `kill_streak: int` and `streak_tier: int` for streak counter display. HUD can function without this (omit the counter). |

### Bidirectional Note

Archer Formation owns Momentum as a sub-system. The "dependency" from Archer Formation to Momentum and back is internal to the Archer Formation module — not a cross-system cycle. Externally: Momentum emits `streak_tier_changed` → Economy reads it. Economy does not emit back to Momentum. No cycle.

## Tuning Knobs

| Knob | Default | Safe Range | Too Low | Too High |
|------|---------|-----------|---------|---------|
| `STREAK_WINDOW` | 4.0 s | 2.0–8.0 s | Streaks require unrealistically fast kill rates — TIER_1 never reached by n ≤ 6 | Streak stays active during inter-wave pause (passive gold bonus between waves) — eliminates time pressure |
| `STREAK_MULT_T1` | 1.15 | 1.05–1.25 | Bonus barely noticeable; TIER_1 not worth pursuing | Tier gap too large — TIER_1 alone produces too much DPS at low n |
| `STREAK_MULT_T2` | 1.30 | 1.15–1.50 | Linear to TIER_1; no escalation sensation | TIER_2 makes Waves 11–13 trivial even at n=4 |
| `STREAK_MULT_T3` | 1.50 | 1.30–2.00 | Feels like a minor bonus at the skill ceiling | Breaks wave balance entirely at n=8 — enemies die before reaching castle |
| `STREAK_GOLD_BONUS` per tier | [0, 10, 20, 30]g | [0, 5–15, 10–30, 15–50]g | Gold bonus meaningless; no incentive to advance tiers | Gold bonus from TIER_3 alone equals several enemy kills — competes with normal gold economy |
| Tier 1 threshold | 5 kills | 3–8 kills | TIER_1 reachable with n=2 in Wave 1 — too easy, undermines coupling with formation size | Requires near-perfect kill efficiency even at n=8; feels unattainable |
| Tier 2 threshold | 10 kills | 7–15 kills | Must be > Tier 1 threshold | TIER_2 never reached in a 13-wave run |
| Tier 3 threshold | 15 kills | 12–20 kills | Must be > Tier 2 threshold | TIER_3 never reached; system effectively has only 2 tiers |

### Cross-Knob Interactions

1. **`STREAK_WINDOW` × enemy kill rate**: Increase `STREAK_WINDOW` only if `ENEMY_SPEED` is reduced (enemies take longer to reach archer range) or `SHOOT_IVTL` is increased. These three constants determine whether streaks are buildable in practice.

2. **`STREAK_MULT_T3` × `PROJ_DAMAGE`**: At TIER_3 with n=8, `effective_damage = floor(8 × 1.50) = 12`. Wave 13 requires DPS = 52.8; n=8 + TIER_3 = 106.7. The headroom (2×) is intentional — TIER_3 should feel overwhelming. If `PROJ_DAMAGE` is decreased in balance, `STREAK_MULT_T3` may need to increase proportionally.

3. **`STREAK_GOLD_BONUS` × upkeep (economy.md)**: Gold bonuses from tier transitions partially offset Wave Upkeep costs (Sprint 5). Total bonus per wave cycle (all 3 tiers reached): 60g. At full formation (8 archers + 2 towers), upkeep = 40g. A player who reaches TIER_3 every wave earns 60g bonus on top of enemy drops — they can sustain the upkeep comfortably. This is the intended reward for sustained aggression.

## Visual/Audio Requirements

### Streak Tier — Visual

| Tier | Archer Modulate | HUD Indicator | Notes |
|------|----------------|---------------|-------|
| NONE | `Color(1.0, 1.0, 1.0)` | Counter hidden or grey | No visual change from baseline |
| TIER_1 | Subtle warm tint `Color(1.1, 1.05, 0.9)` — 0.2 s fade in | Counter amber, pulsing at 1 Hz | Barely visible — readable only if looking at HUD |
| TIER_2 | Brighter warm glow `Color(1.3, 1.1, 0.7)` — hold for duration | Counter orange, pulsing at 2 Hz | Noticeable at a glance |
| TIER_3 | Full gold overcharge `Color(1.8, 1.4, 0.4)` — held throughout | Counter red-gold, constant flash | Eye-catching — player should feel the power state |

Arrow projectiles inherit the archer modulate via shared `CanvasItemMaterial` — no per-arrow color update needed.

### Streak Decay — Visual

When `time_since_last_kill > STREAK_WINDOW - 0.5 s` (last 0.5 s of the window): flash the streak HUD counter at 4 Hz to warn the player. On reset: counter fades to 0 over 0.2 s.

### Tier Transition — Audio

| Transition | Sound | Character | Volume |
|---|---|---|---|
| NONE → TIER_1 | `sfx_streak_t1` | Short ascending chime, dry hit | −4 dB |
| TIER_1 → TIER_2 | `sfx_streak_t2` | Two-note ascending sting, more presence | −2 dB |
| TIER_2 → TIER_3 | `sfx_streak_t3` | Three-note triumph hit, low rumble tail | 0 dB |
| Streak reset | `sfx_streak_break` | Short descending tone, dry | −8 dB |

All sounds are non-positional (`AudioStreamPlayer` via AudioManager). Duration: 0.2–0.5 s each. Do not overlap with volley fire audio.

## Acceptance Criteria

**AC-MO-01 (Streak increments within window)**
**GIVEN** two enemies die at t = 0.0 s and t = 3.5 s (within STREAK_WINDOW = 4.0 s), **WHEN** both deaths are processed, **THEN** `kill_streak = 2` after the second kill.

**AC-MO-02 (Streak resets on window expiry)**
**GIVEN** `kill_streak = 7` and `time_since_last_kill = 4.1 s`, **WHEN** the next frame processes, **THEN** `kill_streak = 0`; tier transitions to NONE; `streak_tier_changed(0)` emitted.

**AC-MO-03 (TIER_1 threshold)**
**GIVEN** 4 kills made within STREAK_WINDOW (streak = 4), **WHEN** a 5th kill lands within 4.0 s, **THEN** `kill_streak = 5`; `streak_tier = TIER_1`; `streak_tier_changed(1)` emitted.

**AC-MO-04 (effective_damage at TIER_2)**
**GIVEN** `kill_streak = 10` (TIER_2), PROJ_DAMAGE = 8, **WHEN** a projectile hits an enemy with 100 HP, **THEN** enemy HP = 90 (delta = −10 = floor(8 × 1.30)); NOT 8 (base) or 12 (TIER_3).

**AC-MO-05 (effective_damage at TIER_3)**
**GIVEN** `kill_streak = 20` (TIER_3), PROJ_DAMAGE = 8, **WHEN** a projectile hits, **THEN** enemy HP decreases by exactly 12 (floor(8 × 1.50)).

**AC-MO-06 (PROJ_DAMAGE unmodified)**
**GIVEN** any streak tier, **WHEN** `PROJ_DAMAGE` constant is read from Archer Formation, **THEN** it equals the configured value (8 by default); it is never overwritten by the streak system.

**AC-MO-07 (Streak resets at wave end)**
**GIVEN** `kill_streak = 12` (TIER_2) at wave end, **WHEN** `wave_cleared` signal fires, **THEN** `kill_streak = 0`, `streak_tier = NONE` on that frame; no tier-transition gold bonus fires on reset.

**AC-MO-08 (Streak resets on session restart)**
**GIVEN** `kill_streak = 18` (TIER_3), **WHEN** `session_restart` fires, **THEN** `kill_streak = 0`, `streak_tier = NONE` on that frame.

**AC-MO-09 (Gold bonus on tier transition)**
**GIVEN** `kill_streak` goes from 4 to 5 (NONE → TIER_1), **WHEN** `streak_tier_changed(1)` fires, **THEN** Economy grants 10g immediately; `gold_changed` emitted with new balance; no coin spawns.

**AC-MO-10 (Gold bonus — TIER_3 transition only fires once)**
**GIVEN** `kill_streak` reaches 15 (TIER_2 → TIER_3), **WHEN** `kill_streak` continues to 20, **THEN** `streak_tier_changed(3)` was emitted exactly once (at k=15); no additional gold bonus fires for k = 16, 17, 18, 19, 20.

**AC-MO-11 (Streak not influenced by wave_cleared kill event)**
**GIVEN** the last enemy in a wave dies, `wave_cleared` fires in the same frame, **WHEN** the kill event and wave_cleared are processed, **THEN** `kill_streak` increments from the kill, THEN immediately resets to 0 from wave_cleared. Final state: `kill_streak = 0`. No tier transition gold bonus fires for the final kill (reset happens before tier_changed check).

**AC-MO-12 (Decay warning)**
**GIVEN** `kill_streak = 8` (TIER_1) and `time_since_last_kill = 3.6 s` (within last 0.5 s of window), **WHEN** this state persists for at least one frame, **THEN** the HUD streak counter is flashing at ≥ 4 Hz (verified by manual observation or test hook).

## Open Questions

1. **Streak carries between waves or resets**: Rule 4 specifies reset at wave end. An alternative is to carry the streak into the next wave (the inter-wave pause extends the window). This would reward uninterrupted play sessions but makes TIER_3 persistent — potentially trivializing Waves 6–13 once reached. Validate in first balance playtest. Owner: Balance/Gameplay. Target: Wave balance pass.

2. **Castle-damage penalty on streak**: A variant design would break the streak when the castle takes damage (enemies reach the castle = player was not aggressive enough). This makes Momentum a defensive metric as well as an offensive one. May feel punishing on mobile. Validate against "Tension sans panique" pillar. Owner: Design. Target: first playtest.

3. **Forge upgrade interactions with Momentum**: A "Streak Extender" Forge upgrade could increase STREAK_WINDOW (e.g., +1.0 s per purchase) or reduce tier thresholds. This is a natural Forge upgrade candidate — defer to Forge GDD authoring sprint. Owner: Forge design sprint. Target: Sprint 9.

4. **Streak across multiple simultaneous kills**: A full volley (8 archers × 1 shot) might kill 4 enemies in one frame if all projectiles land. Current rule: each kill increments streak by 1, even if simultaneous. `kill_streak` could advance 4 in one frame. Is this intended? It allows fast initial streak buildup in dense waves. Confirm this is acceptable behavior. Owner: Gameplay. Target: before implementation.
