# Game State Machine

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-19
> **Implements Pillar**: Pillar 4 — Tension sans panique | Pillar 1 — Un seul doigt, zéro friction

## Overview

The Game State Machine is the session coordinator for Garrison. It defines the three phases of every run — **Playing**, **Game Over**, and **Resetting** — and acts as the single authority that all other systems query to know whether they should process. It owns no gameplay data itself; it signals state transitions so that movement, spawning, economy, and combat systems can start, pause, and reset cleanly.

From the player's perspective, the state machine is invisible during play. It becomes felt at two moments: when the castle falls (Game Over — screen darkens, session halts) and when the player chooses to restart (all systems reset to initial conditions, new run begins instantly with no menu). This design serves Pillar 4 ("Tension sans panique") by making the Game Over moment clear and deliberate, and Pillar 1 ("Un seul doigt, zéro friction") by ensuring the restart path is one action, no friction.

## Player Fantasy

The Game State Machine has no direct player fantasy — players never interact with it consciously. Its purpose is to make two player-facing moments land correctly:

- **Game Over**: The instant the castle HP reaches zero, the world freezes. The player understands immediately that the run is over. No ambiguity, no grace period, no last-second recovery. The tension built over the run — watching the HP bar drop — resolves cleanly. This serves Pillar 4: "Tension sans panique."
- **Restart**: One tap resets everything. No menu navigation, no loading screen, no confirmation dialog. The next run begins immediately. This serves Pillar 1: "Un seul doigt, zéro friction."

The game state machine succeeds when players never think about it — only about what it enables them to feel.

## Detailed Design

### Core Rules

1. The game has exactly **3 states**: `PLAYING`, `GAME_OVER`, and `RESETTING`.
2. Only one state is active at a time. No parallel states, no substates for MVP.
3. All gameplay systems check the current state before processing. When not `PLAYING`, they halt all logic (no movement, no spawning, no shooting, no economy).
4. The state machine owns no gameplay data. It coordinates other systems via signals; it does not store HP, gold, or unit counts.
5. The game launches directly into `PLAYING` — no main menu for MVP.
6. Restart requires no confirmation. One tap on the Game Over overlay triggers `RESETTING` → `PLAYING` immediately.

---

### States and Transitions

| State | Description | Systems active |
|-------|-------------|----------------|
| `PLAYING` | Active gameplay — hero moves, enemies spawn, economy runs | All systems |
| `GAME_OVER` | Castle HP reached 0 — world frozen, overlay shown, waiting for restart tap | None (display only) |
| `RESETTING` | Synchronous full reset of all systems — completes in one frame | None during reset |

| Transition | Trigger | Action |
|-----------|---------|--------|
| `PLAYING → GAME_OVER` | Castle HP reaches 0 (Castle system emits `castle_fell`) | Halt all systems; display Game Over overlay |
| `GAME_OVER → RESETTING` | Player taps anywhere on screen | Hide overlay; begin full reset |
| `RESETTING → PLAYING` | Reset complete (synchronous, same frame) | Resume all systems |

---

### Interactions with Other Systems

| System | Interaction |
|--------|-------------|
| **Castle** | Emits `castle_fell` signal when HP = 0. State machine listens and transitions to `GAME_OVER`. |
| **Hero Movement** | Reads game state; halts joystick processing and movement when not `PLAYING`. |
| **Enemy Wave** | Reads game state; halts spawning and enemy movement when not `PLAYING`. |
| **Economy** | Reads game state; halts dwell timer and gold collection when not `PLAYING`. |
| **Archer Formation** | Reads game state; halts archer movement and shooting when not `PLAYING`. |
| **Camera** | Halts lerp updates when not `PLAYING`; remains on last position during `GAME_OVER`. |
| **HUD** | Always renders (displays final state on `GAME_OVER` overlay). |
| **All systems — on RESETTING** | State machine emits `session_reset` signal. Each system resets to its initial values (see Reset Scope below). |

**Reset Scope (full reset on every restart):**

| Value | Reset to |
|-------|----------|
| Castle HP | 200 (CASTLE_MAX_HP) |
| Gold | 60 (starting gold) |
| Archer count | 2 (starting archers) |
| All enemies | Cleared |
| All projectiles | Cleared |
| All gold coins | Cleared |
| Spawn timer | 2.0s (SPAWN_IVTL) |
| Zone dwell timer | 0 |
| Camera position | Hero start position |
| Hero position | World start position (540, 1700) |

## Formulas

The Game State Machine contains no mathematical formulas. State transitions are triggered by discrete events (signals), not calculated values.

**Transition predicates:**

| Transition | Condition |
|-----------|-----------|
| `PLAYING → GAME_OVER` | `castle.hp <= 0` (evaluated by Castle system; state machine listens for `castle_fell` signal) |
| `GAME_OVER → RESETTING` | `input.any_touch_pressed == true` while state is `GAME_OVER` |
| `RESETTING → PLAYING` | Reset sequence complete (synchronous — no timer needed) |

The only numeric value owned by this system is the **Game Over display duration**: zero — the overlay persists until the player taps, with no auto-dismiss timer.

## Edge Cases

- **If the player taps during `RESETTING`**: Ignore. Input is only processed in `GAME_OVER`. The `RESETTING` state is synchronous and completes in one frame — the window is too short to cause issues in practice.
- **If `castle_fell` fires while already in `GAME_OVER`**: Ignore duplicate signals. The state machine only acts on `castle_fell` when in `PLAYING`.
- **If `castle_fell` fires during `RESETTING`**: Impossible — Castle HP is reset to full before any system resumes. Castle cannot deal damage during `RESETTING`. No guard needed, but document the assumption.
- **If an enemy reduces castle HP to 0 in the same frame as another enemy**: Both contacts apply; HP clamps to 0. Only one `castle_fell` signal fires (HP ≤ 0 check, not HP == 0). State machine transitions once.
- **If the reset takes longer than one frame**: Not expected in MVP (all data is Arrays cleared in O(n)). If performance issues arise, `RESETTING` can become a multi-frame state — flag as an open question for post-MVP.
- **If the player force-quits during `PLAYING`**: No save state in MVP — next session starts fresh in `PLAYING`. No recovery needed.

## Dependencies

**Upstream dependencies (systems this GDD depends on):** None — Layer 0 Foundation.

**Downstream dependents (systems that depend on this GDD):**

| System | What they need from Game State Machine |
|--------|----------------------------------------|
| Castle | Emit `castle_fell` signal to trigger `GAME_OVER` |
| Hero Movement | Read current state to halt processing when not `PLAYING` |
| Enemy Wave | Read current state to halt spawning and movement |
| Economy | Read current state to halt dwell timer and gold collection |
| Archer Formation | Read current state to halt movement and shooting |
| Camera | Read current state to halt lerp updates |
| HUD | Subscribe to `GAME_OVER` to show overlay; subscribe to `session_reset` to hide it |

All systems listen for the `session_reset` signal to reinitialise their data to starting values.

## Tuning Knobs

The Game State Machine has minimal tuning surface — state transitions are event-driven, not time-based.

| Knob | Default | Safe Range | Effect if changed |
|------|---------|------------|-------------------|
| `HERO_START_POS` | `(540, 1700)` | Anywhere in world bounds | Starting distance from castle and zone. Affects first-seconds orientation. |

> **Note**: `STARTING_GOLD` is defined and owned by the Economy GDD (see `economy.md`). `STARTING_ARCHERS` is defined and owned by the Archer Formation GDD (see `archer-formation.md`). `CASTLE_MAX_HP` is defined in the Castle GDD. `SPAWN_IVTL` is defined in Enemy Wave GDD. All are listed in the Reset Scope table above for completeness; tune them in their respective GDDs.

## Acceptance Criteria

- **GIVEN** the game launches, **WHEN** the first frame renders, **THEN** the game is in `PLAYING` state with hero at `(540, 1700)`, 2 archers, 60g gold, and castle at full HP — no menu shown.
- **GIVEN** the game is in `PLAYING`, **WHEN** castle HP reaches 0, **THEN** all systems halt within the same frame, a Game Over overlay appears, and the game enters `GAME_OVER` state.
- **GIVEN** the game is in `GAME_OVER`, **WHEN** the player taps anywhere on screen, **THEN** the overlay disappears and the game enters `RESETTING` then `PLAYING` within one frame.
- **GIVEN** a restart, **WHEN** `PLAYING` resumes, **THEN** castle HP = 200, gold = 60, archers = 2, all enemies cleared, all projectiles cleared, all gold coins cleared, hero at `(540, 1700)`.
- **GIVEN** the game is in `GAME_OVER`, **WHEN** a second `castle_fell` signal fires, **THEN** the state does not change and no duplicate reset is triggered.
- **GIVEN** the game is in `PLAYING`, **WHEN** two enemies contact the castle in the same frame reducing HP to 0, **THEN** exactly one `castle_fell` signal fires and the game transitions to `GAME_OVER` once.
- **GIVEN** the game is in `PLAYING`, **WHEN** the player taps on the bottom half of the screen, **THEN** the joystick activates normally — no state change.

## Open Questions

- **Post-MVP: Main Menu** — Should a main menu state be added for the shippable build? If yes, the state machine gains a `MENU` state and the `MENU → PLAYING` transition. Owner: design lead. Target: Vertical Slice planning.
- **Post-MVP: Multi-frame RESETTING** — If reset performance is an issue on low-end devices, `RESETTING` may need to spread across 2-3 frames with a brief loading flash. Owner: programmer. Target: first performance profiling session.
- **Post-MVP: Pause state** — Is a `PAUSED` state needed? Currently not in scope (Pillar 1 favours simplicity). If added, all systems must respect it identically to `GAME_OVER`. Owner: design lead. Target: Alpha scope review.
