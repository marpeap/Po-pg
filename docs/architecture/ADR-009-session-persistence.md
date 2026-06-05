# ADR-009: Session Persistence — No Save in MVP

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

Garrison MVP has **no file persistence**. All game state (gold, archer count, castle HP,
wave index) is session-only and resets on session restart. Score (waves survived) is
displayed at game over but not written to disk. `FileAccess` is deferred to post-MVP.
This prevents scope creep and avoids Godot 4.4 `FileAccess` return-type changes.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | MEDIUM — `FileAccess` return type changed in Godot 4.4 (post-cutoff). Deferring `FileAccess` entirely eliminates this risk for MVP. |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — `FileAccess` is explicitly deferred |
| **Verification Required** | None for MVP. When save is added post-MVP: verify `FileAccess.open()` return type in Godot 4.6 (changed to nullable in 4.4). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Clarifies scope — prevents any system from implementing save prematurely |
| **Blocks** | Nothing (this ADR removes scope, not adds it) |
| **Ordering Note** | Communicate to all programmers before any feature work begins |

## Context

### Problem Statement

Without an explicit "no save" decision, a programmer implementing Economy or EnemyWave
may add `FileAccess` calls to persist high scores or gold. In Godot 4.4, `FileAccess.open()`
changed return type (now returns `null` on failure instead of raising an error). Code written
against 4.3 patterns will silently fail. Deferring `FileAccess` entirely eliminates this
risk category for MVP.

### Constraints

- `FileAccess` return type changed in Godot 4.4 (MEDIUM risk, post-cutoff)
- Game concept explicitly defers long-term progression: "Hors scope MVP"
- Solo developer — no time budget for save/load in MVP

### Requirements

- No `FileAccess` calls anywhere in MVP codebase
- Score (waves survived) displayed on game over screen — transient, not persisted
- All gameplay state resets identically on every session start
- When save is added post-MVP, it must use the Godot 4.4+ FileAccess pattern

## Decision

**No persistence in MVP.** All state is in-memory only.

**Score display**: Wave count shown on GameOverOverlay as a `Label`. Not stored to disk.
Value is held in `GameStateMachine._waves_survived: int`, reset to 0 on `session_restart`.

**Forbidden in MVP codebase**:
- `FileAccess.open()`
- `FileAccess.file_exists()`
- Any `ConfigFile` read/write
- Any `JSON.stringify` / `JSON.parse` on persistent data

**Post-MVP save pattern** (for when save is added — documented here to prevent 4.3-era mistakes):

```gdscript
# Godot 4.4+ pattern (NOT for MVP — reference only)
var file := FileAccess.open("user://save.dat", FileAccess.WRITE)
if file == null:
    push_error("FileAccess failed: " + FileAccess.get_open_error())
    return
file.store_string(JSON.stringify(save_data))
# Note: file closes automatically when it goes out of scope in 4.4+
```

**High score logic (post-MVP)**: Compare `_waves_survived` against stored record at game over.
This is 3 lines of code + 1 file write — defer until post-MVP polish.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/game-concept.md` | Game Concept | "Long-term progression: hors scope MVP" | Confirms no persistence; score display is transient only |

## Related

- `docs/engine-reference/godot/breaking-changes.md` — FileAccess return type change (4.4)
- ADR-005 — GSM holds `_waves_survived` counter (session-scoped)
