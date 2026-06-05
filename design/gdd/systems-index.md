# Systems Index — Garrison

*Last updated: 2026-05-20 (Sprint 5 design expansion — Targeting Priority, Tactical Formations, Gold Maintenance added to existing GDDs; Momentum added as new system)*

Design order: Foundation → Core → Feature → Presentation → Polish

---

## Progress Tracker

| # | System | File | Status | Priority | Layer | Dependencies |
|---|--------|------|--------|----------|-------|--------------|
| — | Game Concept | `game-concept.md` | **Approved** | — | — | — |
| 1 | Game State Machine | `game-state.md` | **Designed** | MVP | Foundation | — |
| 2 | Hero Movement | `hero-movement.md` | **Designed** | MVP | Foundation | — |
| 3 | Camera | `camera.md` | **Designed** | MVP | Foundation | Hero Movement |
| 4 | Castle | `castle.md` | **Designed** | MVP | Foundation | Game State Machine |
| 5 | Enemy Wave | `enemy-wave.md` | **Designed** | MVP | Foundation | Castle |
| 6 | Economy | `economy.md` | **Designed** | MVP | Core | Hero Movement, Enemy Wave |
| 7 | Archer Formation | `archer-formation.md` | **Designed** | MVP | Core | Hero Movement, Enemy Wave |
| 8 | HUD | `hud.md` | **Designed** | MVP | Presentation | Economy, Castle, Enemy Wave |
| 9 | Archer Tower | `archer-tower.md` | **Designed** | MVP | Feature | Archer Formation, Economy |
| 10 | Forge | `forge.md` | **Designed** | Alpha | Feature | Economy, Game State Machine |
| 11 | Momentum | `momentum.md` | **Designed** | Sprint 5 | Core | Archer Formation, Enemy Wave, Game State Machine |

---

## Dependency Graph

```
Layer 0 — Foundation (no dependencies)
  ├── Game State Machine
  └── Hero Movement

Layer 1 — Foundation (depend on L0)
  ├── Camera            → Hero Movement
  └── Castle            → Game State Machine

Layer 2 — Foundation (depend on L1)
  └── Enemy Wave        → Castle

Layer 3 — Core (depend on L0 + L2)
  ├── Economy           → Hero Movement, Enemy Wave
  └── Archer Formation  → Hero Movement, Enemy Wave

Layer 4 — Feature (depend on L3)
  ├── Archer Tower      → Archer Formation, Economy
  └── Forge             → Economy, Game State Machine

Layer 3b — Core (Sprint 5 expansion, depend on L0 + L2 + L3)
  └── Momentum          → Archer Formation, Enemy Wave, Game State Machine

Layer 3 extensions (Sprint 5)
  ├── Archer Formation  → +Targeting Priority (Forge-gated), +Tactical Formations (Forge-gated)
  └── Economy           → +Gold Maintenance (wave upkeep), +TARGETING_ZONE, +FORMATION_ZONE

Layer 5 — Presentation (depend on L2 + L3)
  └── HUD               → Economy, Castle, Enemy Wave
```

### Bottleneck Systems (high dependency count — design and build first)

- **Hero Movement** — 4 systems depend on it (Camera, Economy, Archer Formation, indirectly all)
- **Enemy Wave** — 3 systems depend on it (Economy, Archer Formation, HUD)

### Absorbed Sub-Systems (covered inside their parent GDD)

- **Virtual Joystick / Input** — absorbed into Hero Movement GDD
- **Projectile / Auto-Shoot** — absorbed into Archer Formation GDD (hero + archers = one firing unit per Pillar 1: "Un seul doigt, zéro friction")
- **Gold Magnet / Collectible** — absorbed into Economy GDD (magnet radius = 170px validated in prototype 1)
- **Dwell Zone Interaction** — absorbed into Economy GDD (0.8s trigger validated in prototype 2)

---

## Priority Tiers

### MVP (must ship for core loop to function)

| System | Why |
|--------|-----|
| Game State Machine | Defines play / game-over / restart — every system calls into it |
| Hero Movement | The joystick is the only player input — nothing functions without it |
| Camera | World is 2× viewport — MVP-mandatory (validated in prototype 1 debrief) |
| Castle | Pillar 4 "Tension sans panique" requires castle HP as the threat |
| Enemy Wave | No enemies = no pressure, no gold, no decisions |
| Economy | Dwell trigger + gold = the spatial tension mechanic validated in prototype 2 |
| Archer Formation | Primary power expression — Pillar 3 "L'armée se voit grandir" |
| HUD | Gold counter + castle HP bar required for economic decisions to be readable |
| Archer Tower | Resolves gold sink gap: once all 8 archers are recruited, TOWER_COST = 100g provides an ongoing spending decision that sustains Pillar 2 ("Chaque pièce d'or est une décision") past Wave 3. Moved from Vertical Slice to MVP per /review-all-gdds 2026-05-19 D-01 resolution. |

### Vertical Slice

| System | Why |
|--------|-----|
| *(no systems at this tier — Archer Tower promoted to MVP)* | — |

### Alpha

| System | Why |
|--------|-----|
| Forge | Global upgrade layer; only balanced once archer and tower systems are tuned |

### Sprint 5 (feature expansion — no new ADR required unless noted)

| System | GDD location | Type | Notes |
|--------|-------------|------|-------|
| Targeting Priority | `archer-formation.md` §Rules 11–13 | Extension | NEAREST always active; FIRST/STRONGEST/WEAKEST Forge-gated. `_find_nearest_enemy()` → `targeting_select(mode, pool)`. No new ADR. |
| Tactical Formations | `archer-formation.md` §Rules 14–17 | Extension | V always active; LINE/ARC Forge-gated. New formulas D-8, D-9. No new ADR. |
| Gold Maintenance | `economy.md` §Rules 13–18 | Extension | Wave upkeep deducted at wave end. Requires `wave_cleared` signal from Enemy Wave. No new ADR. |
| Momentum | `momentum.md` | New GDD | Kill streak → DPS multiplier + gold bonus. Sub-component of Archer Formation. No new ADR. |

---

## Design Order (recommended authoring sequence)

GDDs should be authored in dependency order — never write a system GDD before the
GDDs for its dependencies exist.

1. **Game State Machine** — `game-state.md` — no dependencies
2. **Hero Movement** — `hero-movement.md` — no dependencies
3. **Camera** — `camera.md` — depends on Hero Movement
4. **Castle** — `castle.md` — depends on Game State Machine
5. **Enemy Wave** — `enemy-wave.md` — depends on Castle
6. **Economy** — `economy.md` — depends on Hero Movement, Enemy Wave
7. **Archer Formation** — `archer-formation.md` — depends on Hero Movement, Enemy Wave
8. **HUD** — `hud.md` — depends on Economy, Castle, Enemy Wave
9. **Archer Tower** — `archer-tower.md` — depends on Archer Formation, Economy
10. **Forge** — `forge.md` — depends on Economy

---

## Prototype Learnings (inform GDD Tuning Knobs)

Validated values from `prototypes/garrison-concept/REPORT.md` and
`prototypes/economy-spatial-concept/REPORT.md`:

| Value | Validated | Used in GDD |
|-------|-----------|-------------|
| Joystick fixed anchor: bottom-left `(135, 800)` | Yes | Hero Movement |
| Joystick radius: 80px | Yes | Hero Movement |
| Hero speed: 200px/s | Yes | Hero Movement |
| Camera lerp factor: 0.10 | Yes | Camera |
| World size: 1080×1920 | Yes | Camera |
| Archer V-formation: 8 slots, validated readable | Yes | Archer Formation |
| Archer follow lerp: 0.12 | Yes | Archer Formation |
| Gold magnet radius: 170px | Yes | Economy |
| Dwell trigger: 0.8s | Yes | Economy |
| Archer recruit cost: 30g | Yes | Economy |
| Gold drop per enemy: 15g | Provisional | Economy |
| Enemy speed: 70px/s | Provisional | Enemy Wave |
| Castle damage per contact: 8 HP | Provisional | Castle |
| Castle max HP: 200 | Provisional | Castle |
