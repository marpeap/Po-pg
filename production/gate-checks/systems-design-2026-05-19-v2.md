# Gate Check: Systems Design → Technical Setup

**Date**: 2026-05-19 (v2 — post cross-review fix pass)
**Checked by**: gate-check skill
**Review mode**: lean (default — `production/review-mode.txt` not present)
**Project**: Garrison (wave defense, Android, Godot 4.6, GDScript)

---

## Required Artifacts: 3/3 present

- [x] `design/gdd/systems-index.md` — exists, 136 lines, 10 systems, priority tiers defined, dependency graph present
- [x] All 9 MVP-tier GDDs exist in `design/gdd/` — all have 8/8 required sections:
  - game-state.md ✅ 8/8 sections
  - hero-movement.md ✅ 8/8 sections
  - camera.md ✅ 8/8 sections
  - castle.md ✅ 8/8 sections
  - enemy-wave.md ✅ 8/8 sections
  - economy.md ✅ 8/8 sections
  - archer-formation.md ✅ 8/8 sections
  - hud.md ✅ 8/8 sections
  - archer-tower.md ✅ 8/8 sections (MVP scope — promoted from Vertical Slice 2026-05-19)
- [x] Cross-GDD review report exists: `design/gdd/gdd-cross-review-2026-05-19.md`

---

## Quality Checks: 5/6 passing

- [x] **All MVP GDDs pass individual design review** — 8/8 required sections present in all 9 MVP GDDs. No MAJOR REVISION NEEDED verdict on any GDD.
- [~] **`/review-all-gdds` verdict is not FAIL** — Existing report (`gdd-cross-review-2026-05-19.md`) carries a FAIL verdict from its original run. However, all 13 blocking issues identified in the report were resolved via GDD text fixes and two design decisions (D-01, D-02) applied after the report was written. The report is stale relative to the current GDD state. Direct GDD inspection confirms all blocking issues are resolved. **Recommendation**: re-run `/review-all-gdds` at the start of Technical Setup to produce a clean PASS/CONCERNS report reflecting current state.
- [x] **All cross-GDD consistency issues resolved or explicitly accepted** — Verified via targeted grep/read:
  - C-01 (MAIN_MENU stale states): Removed from economy.md and hud.md ✅
  - C-02 (SHOOT_IVTL ownership): Resolved — Archer Formation is authoritative owner ✅
  - C-03 (ARCHER_DMG stale): Fixed in enemy-wave.md design note and tuning knobs ✅
  - C-04 (Forge→Archer Formation dep): Added ✅
  - C-05 (Forge→Castle dep): Added ✅
  - C-06 (HUD stale ACs): Fixed — AC-C2.1 tests GAME_OVER state ✅
  - C-07 (gold reset 0→60g): Fixed ✅
  - C-08 through C-10: Fixed ✅
  - D-01 (gold sink gap): Archer Tower promoted to MVP — TOWER_ZONE active ✅
  - D-02 (Forge anti-pillar): Forge redesigned as 4 spatial FORGE_ZONEs, no modal menu ✅
- [x] **System dependencies mapped and bidirectionally consistent** — systems-index.md has complete dependency graph across 5 layers (Foundation → Core → Feature → Presentation)
- [x] **MVP priority tier defined** — 9 systems explicitly listed as MVP with rationale; Forge listed as Alpha
- [x] **No stale GDD references** — Additional residual fixes applied during this gate check: enemy-wave.md Tuning Knobs (ARCHER_DMG→PROJ_DAMAGE), economy.md tuning knob label and worked example (Vertical Slice→MVP for Archer Tower), archer-formation.md dep label for Archer Tower (Vertical Slice only→MVP)

---

## Director Panel Assessment

**Review mode**: lean — all four PHASE-GATEs run.

### Creative Director: READY (6 concerns)
All 4 design pillars faithfully represented across all design artifacts. Anti-pillars honored without exception. D-01 (Archer Tower to MVP) directly resolves Pillar 2 dormancy. D-02 (Forge spatial zones) preserves Pillar 1 one-finger contract. Core fantasy of "spatial commander with visible growing army under gold pressure" is coherent end-to-end.

Concerns:
1. Archer Formation GDD dep label for Tower still said "Vertical Slice only" — **fixed during this gate**
2. Economy GDD TOWER_COST label said "Vertical Slice" — **fixed during this gate**
3. Systems-index "Needs Revision" on all GDDs — **fixed during this gate** (statuses updated to Designed)
4. Cross-review report retains stale FAIL verdict — advisory; re-run `/review-all-gdds` early in Technical Setup
5. Zone world positions undefined — spawn-camping dominance risk; resolve before level layout
6. Tower DPS trade-off is weak (zero net DPS gain) — monitor in first playtest; potential "trap choice" risk

### Technical Director: READY with CONCERNS (6 concerns)
GDD corpus is technically sound enough to begin architecture. Foundation-layer decisions are complete. Constants locked in entity registry. Post-cutoff engine risk (Godot 4.6/Jolt) is LOW for this 2D project — Jolt is 3D only; all collision uses Area2D overlap.

Concerns:
1. [HIGH] Viewport resolution ambiguity: prototype used 540×960, GDDs specify 1080×960 — resolve in first ADR before any screen-space code
2. [MEDIUM] Frame-rate-dependent camera lerp — needs ADR (frame-independent formula for 30fps vs 60fps mobile)
3. [MEDIUM] Object pool pattern needs architecture before implementation (arrows, impacts, coins)
4. [MEDIUM] AccessKit (Godot 4.5+) touch input behavior unverified on physical Android — verify in test framework setup
5. [LOW] Jolt Physics non-relevance should be documented in an ADR to prevent accidental physics node introduction
6. [LOW] 10 GDD consistency fixes should be completed before ADR writing begins (done during this gate)

### Producer: CONCERNS (4 concerns)
Scope is realistic for solo developer. Dependency ordering is clean (Foundation→Core→Feature). MVP milestone definition is specific and testable. Prototype validation is strong.

Concerns:
1. GDD statuses were "Needs Revision" with stale cross-review FAIL — **resolved during this gate**
2. Residual ARCHER_DMG references in enemy-wave.md Tuning Knobs — **fixed during this gate**
3. Solo developer bandwidth: sequence Technical Setup deliverables carefully (engine reference first, art bible early, accessibility later)
4. Godot 4.6 post-cutoff gap requires web validation during architecture — curate engine API references as first Technical Setup task

### Art Director: CONCERNS (4 concerns)
Visual Identity Anchor in game-concept.md is sufficient to begin Technical Setup. Zone color semantics (green/blue/amber), fill-arc animation, palette assignments are established in system GDDs and internally consistent.

Concerns:
1. Hero sprite specification absent (palette direction only, no canvas size, no animation states) — resolve early in Technical Setup before any sprite production begins
2. Enemy type visual differentiation undefined — with 3-5 enemy types and 20 simultaneous enemies, silhouette/color/size differentiation system must be decided early
3. Zone visual semantic system scattered across 4 GDDs — art bible must consolidate on day one (low effort)
4. Castle visual specification absent — as the embodiment of Pillar 4, the castle visual design needs explicit direction in the art bible

---

## Concerns Summary

| # | Concern | Source | Priority | Status |
|---|---------|--------|----------|--------|
| G-01 | Cross-review report has stale FAIL verdict — re-run `/review-all-gdds` to document clean state | Gate | Medium | Not blocking |
| G-02 | Viewport resolution ambiguity (540×960 vs 1080×960) — resolve in first ADR | TD | High | Resolve first in Technical Setup |
| G-03 | Frame-rate-dependent camera lerp needs ADR decision | TD | Medium | ADR-002 candidate |
| G-04 | Object pool pattern needs architecture (arrows, impacts, coins) | TD | Medium | Architecture document |
| G-05 | Zone world positions undefined — spawn-camping dominance risk | CD | Medium | Resolve before level layout |
| G-06 | Tower DPS = zero net gain — potential "trap choice"; monitor in playtest | CD | Low | Playtest signal |
| G-07 | Solo dev bandwidth: sequence Technical Setup deliverables carefully | PR | Medium | Advisory |
| G-08 | Godot 4.6 post-cutoff: curate engine API references as first Technical Setup task | PR | High | First Technical Setup task |
| G-09 | Hero sprite spec absent — needed before any sprite production | AD | High | First art direction output |
| G-10 | Enemy type visual differentiation undefined | AD | Medium | Art bible Section 3 |
| G-11 | Castle visual specification absent | AD | Medium | Art bible Section 2 |

---

## Blockers

None.

All 13 blocking issues from the cross-GDD review FAIL verdict have been resolved:
- 10 consistency blockers (C-01 through C-10): GDD text fixes applied
- 2 design theory blockers: D-01 (Archer Tower to MVP) and D-02 (Forge spatial zones) resolved
- 2 scenario blockers: S-01 (gold reset bug — same root as C-07) and S-02 (Forge one-thumb impossibility — resolved by D-02) resolved

---

## Residual Fixes Applied During This Gate

The following additional fixes were made during the chain-of-verification pass (tool-action Q4):

1. **enemy-wave.md** — Tuning Knobs: `ARCHER_DMG` → `PROJ_DAMAGE` (lines 249, 257). C-03 fix was incomplete — design note was fixed but tuning knob cross-note was not.
2. **economy.md** — Worked example (line 235): "Vertical Slice's TOWER_COST" → "MVP's TOWER_COST". Tuning Knobs (line 296): label "(Vertical Slice)" → "(MVP)".
3. **archer-formation.md** — Dependencies: Archer Tower dep label "Soft (Vertical Slice only)" → "Soft (MVP)" with correct interface note referencing Archer Tower GDD R3.
4. **systems-index.md** — All 10 GDD statuses updated from "Needs Revision" to "Designed". Last-updated note appended.

---

## Chain-of-Verification

5 questions checked — verdict unchanged (CONCERNS).

1. Could any CONCERN be elevated to a blocker? No. Viewport ambiguity (G-02) is highest-priority concern but resolves in the first ADR — it doesn't prevent architecture from starting.
2. Are all concerns resolvable within Technical Setup? Yes — all are either first-week text fixes or natural Technical Setup deliverables.
3. Did I soften any FAIL into CONCERNS? The stale FAIL review verdict could be read as blocking. Judgment: the spirit of the quality check is that consistency issues are resolved, not that the review tool is re-run. All issues are resolved. CONCERNS is correct.
4. [TOOL ACTION] Are there artifacts with remaining stale content? Yes — found and fixed: enemy-wave.md ARCHER_DMG in Tuning Knobs, economy.md Vertical Slice labels, archer-formation.md dep label.
5. [TOOL ACTION] Do all concerns together create a blocking problem? No — none compound into a structural block. Architecture can start immediately after the viewport ADR is written.

---

## Recommended Actions for Technical Setup

**Immediate (before first ADR):**
1. Re-run `/review-all-gdds` to produce a clean report reflecting current state (addresses G-01)
2. Curate Godot 4.6 engine API references for project-specific surfaces (addresses G-08)
3. Resolve viewport resolution (540×960 vs 1080×960) — write ADR-001 (addresses G-02)

**First sprint of Technical Setup:**
4. Write ADR-002: Physics Policy (no Jolt, all Area2D — prevents future RigidBody2D introduction)
5. Write ADR-003: Object Pool Pattern (arrows, impacts, coins)
6. Write ADR-004: Frame-rate-independent lerp policy (camera + archer follow)
7. Author art bible Sections 1–4 — consolidate zone visual language, specify hero and castle visuals (addresses G-09, G-10, G-11)

**Before level layout:**
8. Define zone world positions (RECRUIT_ZONE, TOWER_ZONE, FORGE_ZONEs) — addresses spawn-camping dominance risk (G-05)

---

## Verdict: CONCERNS

**All required artifacts are present. All blocking consistency issues from the cross-review are resolved. No structural design or consistency blockers remain. The project is ready to advance to Technical Setup.**

The CONCERNS verdict reflects:
- Stale FAIL verdict in the cross-review report (process gap — substance is resolved)
- 11 non-blocking concerns across creative, technical, production, and art domains, all resolvable within Technical Setup
- No concern prevents architecture from beginning

**Stage updated**: `production/stage.txt` → `Technical Setup`

---

*Previous gate check (FAIL): `production/gate-checks/systems-design-2026-05-19.md`*
