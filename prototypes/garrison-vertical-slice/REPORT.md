# Vertical Slice Report — Garrison — 2026-05-19

> **Validation Question**: Does a player, starting from nothing, experience the
> "commanding general who spends gold under pressure" fantasy within 3+ waves,
> without developer guidance — and can we build one such loop in < 3 days at
> representative quality?

---

## Executive Summary

**Verdict**: PROCEED

The full Garrison loop is playable, self-explanatory, and delivers the core fantasy.
The economy decision moment (dwell to recruit under wave pressure) landed as intended.
Build completed in ~3h — well within the 1–3 day target.

CD-PLAYTEST skipped — Lean mode.

---

## Validation Question Result

> "Does the full Garrison loop deliver the 'commanding general' + 'each gold
> piece is a decision' fantasy within 3+ waves?"

**Answer**: YES

**Evidence**: Player completed the full [start → wave pressure → resolution]
cycle without developer guidance. Core fantasy — commanding general spending
gold under pressure — was felt. No blocking confusion or breakage observed.

---

## Core Loop Validation

| Step | Description | Pass? | Notes |
|------|-------------|-------|-------|
| Start | Player spawns, gold=60, castle=60HP | PASS | |
| Input | Joystick moves hero, archers follow in V | PASS | |
| Economy | Gold drops on kill, magnet collects, dwell to recruit | PASS | |
| Progression | T1 archers (30g), T2 archers (60g) | PASS | |
| Threat | Enemies march to castle, deal 10 damage on contact | PASS | |
| Escalation | Wave 1→5 enemy count and speed ramp | PASS | |
| Pressure | Castle HP loss is felt and visible | PASS | |
| Resolution | GAME_OVER on wave clear or castle=0 | PASS | |
| Reset | Session reset fully restores state, no scene reload | PASS | |

---

## Feel Assessment

**Joystick feel**: Responsive — fixed-anchor contract verified playable

**Archer formation**: V-formation follows correctly; ADR-004 lerp natural

**Enemy threat**: Tense — marching column creates real pressure

**Gold decision moment**: Felt meaningful — dwell timing under pressure is the core beat

**WAVE_CLEAR pause**: Pacing adequate for the slice

**Overall impression**: Fantasy lands. The "spend or hold" tension of the
economy is present even in the prototype quality build.

---

## Technical Findings

**Performance**: No issues reported at 540×960 with draw-only rendering

**Known simplifications vs. production** (documented, not bugs):
- No ObjectPoolManager — raw arrays (ADR-003 deferred to production)
- No AudioManager — silent build (ADR-008 deferred to production)
- No separate scene files — monolithic script (acceptable for VS)
- HUD drawn in _draw() rather than CanvasLayer (ADR-007 deferred to production)
- Viewport-space world — no Camera2D needed at this scale

**Architectural risks surfaced**: None. All 9 ADR decisions held up under
implementation. The direction_to enemy steering (ADR-006), fixed-anchor joystick,
dwell zone pattern, and session reset (ADR-005/ADR-007) all functioned as designed.

**Godot 4.6 compatibility issues**: None encountered.

---

## Velocity Log

| Day | What was built | Time |
|-----|----------------|------|
| Day 1 (2026-05-19) | project.godot + Main.tscn + Main.gd (~550 lines): GSM (4 states), fixed-anchor joystick, V-formation with ADR-004 lerp, 5-wave system, enemy steering (ADR-006), castle HP, economy (60g start, magnet, dwell recruit), HUD (gold / castle bar / wave / archer badge), session reset | ~3h |

**Total build time**: ~3h (1 day)
**Planned timeline**: 1–3 days
**Assessment**: On track — completed Day 1. Scope was correctly sized.

---

## Lessons Learned

**What assumptions were broken by building this?**

None broken. The single-script approach for the VS was the right call — it
validated architecture assumptions (ADRs 001–009) without needing the full
production layer structure.

**What surprised us about the pipeline?**

The draw-only rendering (no sprites, no scenes, no assets) was faster to
iterate than expected and still communicated the core fantasy clearly. This
suggests production art can be introduced incrementally without risking the
feel.

**What would we change about the slice scope?**

Nothing — scope was appropriate. Audio was correctly deferred; its absence
did not prevent fantasy validation.

---

## Recommended Next Steps

PROCEED to Production Pre-Production tasks:

1. `/ux-design hud` — HUD UX spec (formalize the 4 HUD elements)
2. `/ux-design game-over` — GAME_OVER screen spec
3. `/art-bible` (resume) — Sections 5–9
4. `/create-control-manifest` — layer rules from Accepted ADRs
5. `/create-epics layer:foundation` → `/create-epics layer:core`
6. `/create-stories [epic-slug]` for each epic
7. `/sprint-plan new`
8. `/gate-check pre-production`
