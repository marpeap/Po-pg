# Camera

> **Status**: Designed (pending /design-review)
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-18
> **Implements Pillar**: Pillar 1 — Un seul doigt, zéro friction | Pillar 3 — L'armée se voit grandir

## Overview

The Camera system is the viewport controller for Garrison. It follows the hero across a 1080×1920 world that is twice the size of the 540×960 viewport, keeping the hero centered using a smooth lerp. The camera applies world-boundary clamping so the viewport never shows space outside the world. When the hero is alive and moving, the camera tracks without input — the player never pans manually.

From a data perspective, the Camera reads `hero_pos` from Hero Movement each frame, computes a lerp target, clamps it to valid world bounds, and writes the resulting `camera_pos` to drive the viewport offset. It also reads game state to halt updates when not `PLAYING` and resets to the hero's start position on `session_reset`.

From the player's perspective, the camera is invisible — it succeeds when players think only about where to move, not about where the camera is. The 2× world means players must navigate to gold zones, castle, and enemy clusters across a map larger than the screen — the smooth follow is what makes this navigation feel natural on a one-thumb joystick. The off-screen indicator sub-system (directional arrows for the castle and dwell zone when they leave the viewport) ensures the player retains spatial orientation without ever taking their thumb off the joystick.

## Player Fantasy

The Camera has no direct player fantasy — players never interact with it consciously, and a well-implemented camera is noticed only when it fails. Its purpose is to make two other player-facing moments land correctly:

- **Seamless navigation**: When the player drags the joystick and the hero glides toward a gold zone on the far side of the map, the world scrolls smoothly behind them. The player feels freedom of movement across a large battlefield — not the constraint of a small screen. This serves Pillar 1: "Un seul doigt, zéro friction." No panning, no minimap interaction, no mental map maintenance required.
- **Spatial awareness**: When the castle or dwell zone is off-screen, a directional arrow at the viewport edge tells the player exactly where to look. The player always knows where the threat is and where the gold is — even while running toward enemies on the opposite side of the world. This serves Pillar 3: "L'armée se voit grandir" — the player must be able to read the battlefield to make strategic decisions about where to position their formation.

The camera succeeds when players never think about it. Its failure modes — lag that makes the hero slip out of frame, hard cuts on reset that are jarring, or off-screen arrows pointing the wrong way — break the illusion of seamless control.

## Detailed Design

### Core Rules

1. The viewport is 540×960 px. The world is 1080×1920 px. The world is exactly 2× the viewport in both axes.
2. The camera position (`cam_pos`) is the world-space coordinate at the center of the viewport.
3. Each frame during `PLAYING`, the camera lerps toward `hero_pos`: `cam_pos = cam_pos.lerp(hero_pos, CAM_LERP)`.
4. After the lerp, `cam_pos` is clamped to valid world bounds: `x ∈ [270, 810]`, `y ∈ [480, 1440]`. This ensures the viewport never shows space outside the world.
5. The camera processes lerp updates **only when Game State is `PLAYING`**. When not `PLAYING`, `cam_pos` is unchanged.
6. On `session_reset`, `cam_pos` teleports instantly (no lerp) to `HERO_START_POS = (540, 1700)`. The lerp resumes from this position when `PLAYING` begins.
7. The camera exposes `cam_pos: Vector2` each frame for any downstream system that needs to compute screen positions or viewport visibility.
8. The camera owns the **off-screen indicator** sub-system. For each tracked world point (castle, dwell zone), if the point falls outside the current viewport rect, a directional arrow is drawn at the viewport edge pointing toward that world point.
9. Off-screen indicators are drawn every frame regardless of game state (display-only — they do not block input or affect game logic).
10. The viewport rect at any frame is `Rect2(cam_pos − VIEWPORT/2, VIEWPORT)`.

---

### States and Transitions

| State | Condition | Camera behavior |
|-------|-----------|-----------------|
| Following | Game State = `PLAYING` | Lerps toward `hero_pos` each frame; clamped to world bounds; off-screen arrows drawn |
| Frozen | Game State ≠ `PLAYING` | `cam_pos` unchanged; off-screen arrows still drawn using last position |
| Resetting | `session_reset` received | `cam_pos` teleports to `(540, 1700)` in the same frame; transitions immediately to Following |

---

### Interactions with Other Systems

| System | Interface |
|--------|-----------|
| **Game State Machine** | Reads game state each frame; freezes lerp when not `PLAYING`. Listens for `session_reset` to teleport `cam_pos`. |
| **Hero Movement** *(upstream)* | Reads `hero_pos: Vector2` each frame as the lerp target. |
| **Economy** *(downstream, provisional)* | Reads `cam_pos: Vector2` to determine if dwell zone is off-screen. Provides dwell zone world position as input to off-screen indicator sub-system. *(Provisional — Economy GDD not yet written.)* |
| **Castle** *(downstream, provisional)* | Provides castle world position as input to off-screen indicator sub-system. *(Provisional — Castle GDD not yet written.)* |
| **HUD** *(downstream, provisional)* | Off-screen indicator arrows are rendered by the Camera layer, not the HUD. HUD reads `cam_pos` if it needs to place screen-space elements. *(Provisional — HUD GDD not yet written.)* |

## Formulas

### Camera Position Lerp

`cam_pos = cam_pos.lerp(hero_pos, CAM_LERP)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Camera position (current) | `cam_pos` | Vector2 | `(270, 480)` to `(810, 1440)` | World-space position at viewport center, before clamping |
| Hero position | `hero_pos` | Vector2 | `(18, 18)` to `(1062, 1902)` | Current hero world position (from Hero Movement) |
| Lerp factor | `CAM_LERP` | float | 0.05–0.20 | Interpolation weight per frame. Validated at 0.10. |

**Output Range:** `cam_pos` moves toward `hero_pos` by `CAM_LERP × distance` per frame. At 60fps and `CAM_LERP = 0.10`, lag behind hero is ~1.5 frames at full world-crossing speed (200 px/s → ~3.3px per frame lag).
**Example:** `cam_pos = (270, 480)`, `hero_pos = (540, 960)`. After lerp: `cam_pos = (297, 528)`. After clamping: unchanged (within bounds).

---

### Camera Position Clamp

`cam_pos = clamp(cam_pos, CAM_MIN, CAM_MAX)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Camera position (post-lerp) | `cam_pos` | Vector2 | unclamped | Result of the lerp step |
| Camera min bound | `CAM_MIN` | Vector2 | `(270, 480)` | `VIEWPORT / 2` — left-top limit so viewport doesn't show outside world |
| Camera max bound | `CAM_MAX` | Vector2 | `(810, 1440)` | `WORLD_SIZE − VIEWPORT / 2` — right-bottom limit |

**Derivation:** `CAM_MIN.x = VIEWPORT.x / 2 = 540 / 2 = 270`. `CAM_MAX.x = WORLD_SIZE.x − VIEWPORT.x / 2 = 1080 − 270 = 810`. Same logic for Y axis.
**Output Range:** `cam_pos.x ∈ [270, 810]`, `cam_pos.y ∈ [480, 1440]`.

---

### World-to-Screen Transform

`screen_pos = world_pos − cam_pos + VIEWPORT / 2`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| World position | `world_pos` | Vector2 | `(0, 0)` to `(1080, 1920)` | Any point in world space |
| Camera position | `cam_pos` | Vector2 | `(270, 480)` to `(810, 1440)` | Current viewport center in world space |
| Viewport size | `VIEWPORT` | Vector2 | `(540, 960)` | Fixed viewport dimensions |
| Screen position | `screen_pos` | Vector2 | viewport space | Resulting screen-space coordinate |

**Output Range:** A world point at exactly `cam_pos` maps to `VIEWPORT / 2 = (270, 480)` (screen center).
**Example:** `world_pos = (540, 120)` (castle), `cam_pos = (540, 960)`. `screen_pos = (540 − 540 + 270, 120 − 960 + 480) = (270, −360)` → off-screen (Y < 0).

---

### Off-Screen Arrow Position

For a tracked world point that is off-screen, compute the arrow's screen-space position at the viewport edge:

`arrow_pos = edge_clamp(normalize(screen_pos − VIEWPORT/2), VIEWPORT, ARROW_MARGIN)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Screen position of target | `screen_pos` | Vector2 | may be outside viewport | World-to-screen result for the tracked point |
| Viewport center | `VIEWPORT/2` | Vector2 | `(270, 480)` | Screen-space center |
| Viewport size | `VIEWPORT` | Vector2 | `(540, 960)` | Fixed viewport dimensions |
| Arrow margin | `ARROW_MARGIN` | float | 20px | Inset from viewport edge where arrow is drawn |

**Method:** Cast a ray from viewport center in the direction of `screen_pos − VIEWPORT/2`. Find the intersection with the viewport rectangle inset by `ARROW_MARGIN`. The intersection point is where the arrow is drawn.
**Example:** Castle is directly above viewport (screen_pos.y < 0). Ray direction = `(0, -1)`. Intersects top edge at `y = ARROW_MARGIN = 20`. Arrow drawn at `(270, 20)` pointing upward.

## Edge Cases

- **If the hero is at a world corner** (e.g., `hero_pos = (18, 18)`): The lerp target is at the world edge. After lerp, `cam_pos` would be pulled toward `(18, 18)`, but the clamp floors it at `(270, 480)`. The viewport shows the top-left corner of the world — world content only, no out-of-bounds. Hero appears near the top-left of the screen, not at center.
- **If the hero moves faster than the camera can follow** (hypothetical — hero speed 200 px/s, CAM_LERP 0.10 at 60fps): Camera lags by ~3.3 px/frame. At 200 px/s of sustained sprint the hero is always visible — the lag is imperceptible at validated values. If `HERO_SPEED` is tuned above ~350 px/s, the hero may reach the viewport edge before the camera catches up. Flag as a tuning dependency: `HERO_SPEED` changes must be re-validated against `CAM_LERP`.
- **If `CAM_LERP = 1.0`**: Camera snaps to hero each frame (no smoothing). Viewport follows hero rigidly. Not a crash — valid for debugging. Not intended for production.
- **If `CAM_LERP = 0.0`**: Camera never moves. Hero can walk off-screen. Invalid play state — treat as a configuration error. Minimum safe value: 0.03.
- **If `session_reset` fires while lerp is mid-travel**: `cam_pos` teleports instantly to `(540, 1700)`. No residual lerp from the previous position. The next frame begins lerping from `(540, 1700)`.
- **If game state transitions to `GAME_OVER` with camera mid-lerp**: Camera freezes at its current lerped position — not at `hero_pos`. The final frame shows wherever the camera was when the castle fell. This is correct: freezing creates a "snapshot" effect that reinforces the Game Over moment.
- **If a tracked world point (castle, zone) is exactly at viewport center**: `screen_pos − VIEWPORT/2 = (0, 0)`. Direction is zero-length — cannot normalize. No off-screen arrow is drawn (the point is on-screen). Guard: if `screen_pos` is inside viewport rect → skip indicator.
- **If two tracked points are both off-screen in the same direction**: Both arrows are drawn. If they overlap visually, the indicators remain distinct (different color or label). Visual disambiguation is a HUD/art concern — the Camera system draws both arrows regardless.
- **If the world size is changed** (future maps): `CAM_MIN` and `CAM_MAX` must be recomputed. They are derived constants, not hardcoded — any change to `WORLD_SIZE` or `VIEWPORT` must propagate to the clamp formula. Flag as a configuration dependency.

## Dependencies

**Upstream dependencies:**

| System | What Camera needs | Hard/Soft |
|--------|-------------------|-----------|
| Game State Machine | Current state (`PLAYING`/other); `session_reset` signal | Hard |
| Hero Movement | `hero_pos: Vector2` each frame — lerp target | Hard |

**Downstream dependents:**

| System | What they consume from Camera |
|--------|-------------------------------|
| Economy *(provisional)* | `cam_pos: Vector2` — viewport center, used to determine if dwell zone is off-screen for indicator display |
| Castle *(provisional)* | Provides its world position to Camera for off-screen indicator; reads nothing from Camera directly |
| HUD *(provisional)* | `cam_pos: Vector2` — needed to place screen-space HUD elements relative to viewport |

**Note:** Camera is a leaf node in the dependency graph — no MVP system is downstream in a blocking sense. The downstream relationships above are for coordinate and indicator data, not functional dependencies.

## Tuning Knobs

| Knob | Default | Safe Range | Effect if too low / too high |
|------|---------|------------|------------------------------|
| `CAM_LERP` | 0.10 | 0.03–0.25 | Too low: camera lags badly, hero near viewport edge during fast moves. Too high: camera snaps, loses smoothness, feels jittery on mobile. Validated at 0.10 in prototype 1. |
| `ARROW_MARGIN` | 20px | 10–40px | Too low: arrows clip into screen edge or overlap safe-area UI. Too large: arrows crowd toward screen center. |
| `WORLD_SIZE` | `(1080, 1920)` | Fixed for MVP | Changing this invalidates `CAM_MIN`, `CAM_MAX`, and all systems that assume world dimensions. Treat as fixed for MVP — a map size change is a major scope decision. |
| `VIEWPORT` | `(540, 960)` | Fixed for MVP | Changing viewport changes all screen-space calculations across every system. Fixed by target resolution. |

**Cross-knob interaction:** `CAM_LERP` and `HERO_SPEED` (Hero Movement GDD) interact. If `HERO_SPEED` is increased, `CAM_LERP` may need to increase proportionally to keep the hero within the viewport center region. Validate both together when either is changed.

## Acceptance Criteria

- **GIVEN** the game is in `PLAYING`, **WHEN** the hero moves away from the camera center, **THEN** the camera lerps toward `hero_pos` at `CAM_LERP = 0.10` per frame, producing visible smooth follow with no snapping.
- **GIVEN** the hero is at world position `(540, 960)` (center), **WHEN** the camera settles, **THEN** `cam_pos = (540, 960)` and the hero is at screen center `(270, 480)`.
- **GIVEN** the hero reaches a world corner (e.g., `hero_pos = (18, 18)`), **WHEN** the camera attempts to follow, **THEN** `cam_pos` clamps to `(270, 480)` and the viewport shows only world content — no black out-of-bounds area is visible.
- **GIVEN** the hero is at `hero_pos = (18, 1902)` (bottom-left corner), **WHEN** measured, **THEN** `cam_pos.x = 270` (clamped), `cam_pos.y = 1440` (clamped), hero appears in the lower-left quadrant of the screen.
- **GIVEN** the game transitions to `GAME_OVER`, **WHEN** the transition occurs, **THEN** `cam_pos` freezes at its current value within the same frame and does not lerp further.
- **GIVEN** `session_reset` fires, **WHEN** `PLAYING` resumes, **THEN** `cam_pos = (540, 1700)` on frame 1 (instantaneous — no lerp from previous position).
- **GIVEN** the castle is at world position `(540, 120)` and `cam_pos = (540, 960)`, **WHEN** the castle is off-screen (screen_pos.y = −360), **THEN** an arrow is drawn at the top viewport edge pointing upward toward the castle.
- **GIVEN** any tracked world point is inside the viewport rect, **WHEN** evaluated, **THEN** no off-screen arrow is drawn for that point.
- **GIVEN** two tracked points are both off-screen simultaneously, **WHEN** evaluated, **THEN** two separate arrows are drawn — one for each point.
- **GIVEN** `CAM_LERP = 0.10` and `HERO_SPEED = 200 px/s`, **WHEN** the hero moves at full speed for 2 seconds, **THEN** the hero remains within the center half of the viewport at all times (camera lag ≤ half-viewport width/height in sustained movement).
- **GIVEN** the game is in `GAME_OVER`, **WHEN** off-screen indicators are evaluated, **THEN** arrows are still drawn using the frozen `cam_pos` — indicators do not disappear on Game Over.

## Open Questions

- **Off-screen indicator ownership**: The GDD assigns off-screen arrow rendering to the Camera system. If the HUD GDD later takes responsibility for all screen-space overlays, this indicator must migrate to HUD. Owner: design lead. Target: HUD GDD authoring.
- **Delta-corrected lerp**: The current lerp formula `cam_pos.lerp(hero_pos, CAM_LERP)` is frame-rate dependent — at 30fps the camera will follow slower than at 60fps. A frame-rate-independent version uses `lerp(cam_pos, hero_pos, 1.0 - pow(1.0 - CAM_LERP, delta * 60.0))`. For MVP targeting 60fps this is not blocking. Owner: programmer. Target: architecture phase.
- **Safe area insets**: Android notch and navigation bar insets may clip the top and bottom edges of the viewport. `ARROW_MARGIN = 20px` may not be sufficient to clear all device-specific safe areas. Owner: design lead + programmer. Target: first device test session.
- **Castle position**: The off-screen indicator for the castle requires the castle's world position. This GDD assumes the castle is at a fixed world coordinate (provisionally `(540, 120)` based on prototype 2). Castle GDD must confirm this. Owner: Castle GDD authoring. Target: Castle GDD.
- **Additional tracked points**: Currently two tracked points — castle and dwell zone. If future systems add POIs (e.g., Forge location), the indicator system must be extended. Document as expandable at architecture time.
