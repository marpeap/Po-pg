# Architecture Review Report — Garrison

> **Date**: 2026-05-19
> **Review Run**: Post ADR-001–009 completion
> **Engine**: Godot 4.6
> **Reviewer**: architecture-review skill (Technical Setup phase)
> **Verdict**: APPROVED

---

## Scope

This review covers:
- `docs/architecture/architecture.md` v1.0 (updated 2026-05-19 — traceability gaps resolved)
- ADR-001 through ADR-009 (all Accepted)
- `docs/architecture/requirements-traceability.md` v1.1
- Engine reference: `docs/engine-reference/godot/`

---

## 1. Requirements Traceability Coverage

**Result: PASS — 26/26 requirements traced, 0 Foundation layer gaps**

| Layer | Requirements | Traced | Gaps |
|-------|-------------|--------|------|
| Foundation | 3 | 3 | **0** ✅ |
| Core | 15 | 15 | 0 ✅ |
| Feature | 8 | 8 | 0 ✅ |
| Presentation | 4 | 4 | 0 ✅ |

Prior gaps (TR-gsm-001, TR-wave-002, TR-hud-001, TR-persist-001) are now resolved
by ADR-005, ADR-006, ADR-007, and ADR-009 respectively.

See `docs/architecture/requirements-traceability.md` for full matrix.

---

## 2. ADR Quality Audit

### Engine Compatibility Sections

**Result: PASS — All 9 ADRs have Engine Compatibility sections**

| ADR | Engine Compatibility | Version Stamped | Knowledge Risk |
|-----|---------------------|-----------------|---------------|
| ADR-001 | ✅ | Godot 4.6 | MEDIUM |
| ADR-002 | ✅ | Godot 4.6 | MEDIUM |
| ADR-003 | ✅ | Godot 4.6 | LOW |
| ADR-004 | ✅ | Godot 4.6 | LOW |
| ADR-005 | ✅ | Godot 4.6 | HIGH (Autoload post-cutoff) |
| ADR-006 | ✅ | Godot 4.6 | LOW |
| ADR-007 | ✅ | Godot 4.6 | HIGH (AnimationPlayer StringName) |
| ADR-008 | ✅ | Godot 4.6 | MEDIUM |
| ADR-009 | ✅ | Godot 4.6 | MEDIUM (FileAccess 4.4 changes) |

### GDD Requirements Addressed Sections

**Result: PASS — All 9 ADRs have GDD Requirements Addressed sections**

Every ADR links back to the specific GDD requirement(s) it satisfies. No ADR is
floating without a stated design origin.

### ADR Dependencies

**Result: PASS — No circular dependencies detected**

Dependency graph:
```
ADR-009 → (none)
ADR-008 → (none)
ADR-006 → ADR-003 (pool pattern extends to enemy pool)
ADR-005 → (none)
ADR-007 → ADR-001 (viewport), ADR-005 (GSM signal for HUD state)
ADR-004 → ADR-001 (viewport bounds for camera lerp)
ADR-003 → (none)
ADR-002 → ADR-001 (collision layer in context of 540×960 world)
ADR-001 → (none)
```

No cycles. Foundation ADRs (ADR-001 through ADR-005) have no mutual dependencies.

---

## 3. Deprecated API Audit

**Result: PASS — No deprecated APIs used**

Checked against `docs/engine-reference/godot/deprecated-apis.md`. No ADR specifies
use of any deprecated API. Specific mitigations noted:

| Risk | ADR Mitigation |
|------|----------------|
| `AnimationPlayer.method_call_mode` / `playback_active` (deprecated 4.3) | ADR-007 forbids AnimationPlayer on HUD CanvasLayer entirely — use Tween |
| `position_smoothing_enabled` (frame-rate-dependent) | ADR-004 mandates manual lerp; `position_smoothing_enabled = false` required in Camera2D |
| `FileAccess.open()` in MVP | ADR-009 defers all FileAccess to post-MVP — not forbidden globally, just deferred |
| `NavigationAgent2D` | ADR-006 defers to post-MVP; `direction_to` steering used instead |
| `RigidBody2D` / `CharacterBody2D` | ADR-002 explicitly forbids all physics bodies; Area2D overlap only |

---

## 4. HIGH RISK Engine Domain Coverage

Domains rated HIGH RISK in `docs/engine-reference/godot/VERSION.md` (Godot 4.5–4.6):

| Domain | Risk | Coverage |
|--------|------|---------|
| Jolt physics (now default in 4.6 for 3D) | HIGH | ADR-002: Area2D overlap only; Jolt is 3D-only, does not affect 2D. MITIGATED. |
| AnimationPlayer StringName changes (4.5) | HIGH | ADR-007: Tween mandated for HUD; AnimationPlayer forbidden on CanvasLayer. MITIGATED. |
| Autoload initialization order (4.5–4.6) | HIGH | ADR-005: Explicit autoload load order documented (GSM → ObjectPoolManager → AudioManager). MITIGATED. |
| Glow rework / D3D12 default (4.6) | HIGH | Compatibility renderer selected (ADR-001 context); glow rework does not affect Compatibility renderer. NOT A RISK for this project. |
| FileAccess return type changes (4.4) | MEDIUM | ADR-009: No FileAccess in MVP. Post-MVP implementation must reference `docs/engine-reference/godot/breaking-changes.md`. DEFERRED. |
| AccessKit / accessibility events (4.5) | MEDIUM | No screen-reader dependency in Garrison MVP. NOT A RISK for this project. |

**Result: PASS — All applicable HIGH RISK domains are mitigated or not applicable**

---

## 5. Architecture Principle Consistency

The master architecture document defines 4 architecture principles. Audit:

**Principle 1: One authoritative owner per data item**
✅ — Each tuning knob, state variable, and signal is owned by exactly one module.
No ownership conflicts remain after cross-GDD review B-01 fix (tower_purchased added to archer-formation.md).

**Principle 2: Foundation layer has no upstream dependencies**
✅ — GSM (ADR-005), AudioManager (ADR-008), ObjectPoolManager (ADR-003), and
persistence (ADR-009) all have zero upstream game-system dependencies. GSM only
broadcasts; never reads from Core or Feature layers.

**Principle 3: No frame-rate-dependent lerp or movement**
✅ — ADR-004 mandates `1.0 - pow(1.0 - F, delta × 60.0)` pattern. `position_smoothing_enabled`
is forbidden. All moving entities (camera factor 0.10, archer follow factor 0.12)
use this pattern.

**Principle 4: Pool before instantiate**
✅ — ADR-003 defines 24 arrows + 8 impacts + 16 coins. ADR-006 adds 30 enemy nodes.
ObjectPoolManager autoload owns all pools. `Node.instantiate()` per-frame is
forbidden (in `.claude/docs/technical-preferences.md` Forbidden Patterns).

---

## 6. Open Questions Status

| ID | Summary | ADR Resolution | Status |
|----|---------|----------------|--------|
| QQ-01 | Enemy pool 30 nodes — validate against profiling | ADR-006: 30 defined; validate at first perf profile | Open (acceptable) |
| QQ-02 | Tower arrow pool — ADR-003 covers formation only | ADR-006 note: update ADR-003 at tower implementation | Open (deferred, acceptable) |
| QQ-03 | AnimationPlayer StringName HUD risk | ADR-007: Tween mandated; risk fully mitigated | ✅ Resolved |
| QQ-04 | GPUParticles2D behavior in 4.6 | No VFX system in MVP scope; validate at first engine run | Open (deferred) |

All open questions are either resolved or acceptably deferred to implementation.
None block the Technical Setup → Pre-Production gate.

---

## 7. Verdict

**APPROVED**

All gate criteria for Technical Setup → Pre-Production are satisfied by the
architecture artifacts:

- ✅ 9 ADRs covering all Foundation and Core layer decisions — all Accepted
- ✅ 26/26 requirements traced — 0 Foundation layer gaps
- ✅ All ADRs have Engine Compatibility sections with version stamp
- ✅ All ADRs have GDD Requirements Addressed sections
- ✅ No deprecated APIs referenced
- ✅ All HIGH RISK engine domains mitigated or not applicable
- ✅ No circular ADR dependencies
- ✅ Architecture principles consistently applied across all ADRs

### Remaining Pre-Production Gaps (not blocking Technical Setup gate)

These are noted for tracking; none block the gate:

1. **Art bible Sections 5–9** — Sections 1–4 complete; sections 5–9 required before
   Pre-Production gate. Run `/art-bible` (no argument) to resume.

2. **HUD UX spec** — `design/ux/interaction-patterns.md` and `design/accessibility-requirements.md`
   are complete. A dedicated `/ux-design hud` spec is required before Pre-Production gate.

3. **GAME_OVER screen UX** — No spec exists. Required before Pre-Production gate.

4. **Control manifest** — `docs/architecture/control-manifest.md` not yet created.
   Required for Pre-Production gate. Run `/create-control-manifest` after Technical
   Setup gate passes.

5. **TR registry** — `docs/architecture/tr-registry.yaml` is scaffolded but not populated
   with live entries. Populate when running `/create-stories` (stories embed TR-IDs).

---

*Architecture review complete: 2026-05-19*
*Next review: after Pre-Production epics + stories are created, or when a GDD is significantly revised*
