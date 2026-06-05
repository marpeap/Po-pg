# ADR-001: Viewport Resolution — 960×540 Landscape with Canvas Stretch

## Status

Accepted

## Date

2026-05-19

## Last Updated

2026-05-23 — Landscape refactor (Sprint 7): orientation flipped to landscape,
viewport changed from 540×960 to 960×540, world from 1080×1920 to 1920×1080.
All zone-based interaction replaced by HUD buttons. Joystick moved to bottom-left.

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6); Landscape refactor (Sonnet 4.6)

## Summary

Sprint 7 landscape refactor: the game was switched from portrait (540×960 / world 1080×1920)
to **landscape (960×540 / world 1920×1080)** to improve ergonomics. The joystick stays in
the bottom-left quadrant while action buttons occupy the bottom-right. We retain Godot's
`canvas_items` / `keep` stretch so the game scales 2× to fill a 1080p landscape Android screen.
This halves the pixel fill rate relative to a 1920×1080 native viewport.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / UI |
| **Knowledge Risk** | MEDIUM — stretch modes and canvas-item rendering are stable from 4.3, but verify against Godot 4.6 release notes for any mobile stretch changes |
| **References Consulted** | `docs/engine-reference/godot/modules/camera2d.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — `ProjectSettings` stretch mode and `Camera2D` limits have been stable since 4.0 |
| **Verification Required** | Run on target Android device and confirm: (1) viewport fills screen with correct aspect ratio, (2) Camera2D limits constrain scroll correctly, (3) safe area insets do not cut into playable area |

> **Note**: Knowledge Risk MEDIUM — re-validate if upgrading past Godot 4.6.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-004 (Camera2D lerp bounds depend on viewport size), all GDDs that reference pixel coordinates |
| **Blocks** | Camera implementation, HUD layout, zone placement, any code that references screen or world coordinates |
| **Ordering Note** | Must be Accepted before any code referencing `get_viewport_rect()`, `get_visible_rect()`, or pixel-space coordinate is written |

## Context

### Problem Statement

`camera.md` specifies "World: 1080×1920. Viewport: TBD in ADR-001." All zone placement
values (JOYSTICK_ANCHOR, zone radiuses), sprite sizes, and camera limit calculations
depend on knowing the viewport. Without a decision, no code can use screen coordinates.

### Current State

No viewport is configured. Project Settings → Display → Window size is at Godot default.

### Constraints

- **Target hardware**: Android phones, typically 1080×1920 to 2400×1080 physical pixels
- **Rendering**: Compatibility renderer (required for broadest Android support — GDD constraint)
- **Performance budget**: ≤150 draw calls, 60fps at 16.6ms frame budget
- **Asset design**: Archer sprites are 32×32 px, hero sprites sized for the world grid
- **Portrait orientation**: fixed, no landscape

### Requirements

- Viewport must use a 9:16 aspect ratio matching the 1080×1920 world
- Camera2D limits (0-1080, 0-1920) must produce correct scroll boundaries
- Touch input coordinates (joystick anchor at 135, 800) must align with visible content
- Scaling must not produce sub-pixel artifacts on sprites (pixel art safety)
- Safe area insets (Android notch, navigation bar) must not overlap game controls

## Decision

**Viewport size**: 540×960 px (9:16 ratio, exactly half the world dimensions)

**Stretch settings** (Project Settings → Display → Window → Stretch):
```
Mode:   canvas_items
Aspect: keep
Scale:  2.0 (automatic — engine computes scale from window vs viewport)
```

With these settings, Godot renders the game at 540×960 and upscales 2× to fill any
16:9 or taller Android screen. On a 1080×1920 physical screen: exact 2× upscale,
pixel-perfect. On a taller screen (e.g. 1080×2340): pillarboxed with black bars top/bottom
or letterboxed depending on `keep` behavior — game area remains 540×960 logical pixels.

**Camera2D limit math with this viewport**:
- Viewport half-size: 270×480 px
- Camera center scroll range X: 270 to (1080 − 270) = 270 to 810 px
- Camera center scroll range Y: 480 to (1920 − 480) = 480 to 1440 px
- Camera2D limits remain: `left=0, right=1080, top=0, bottom=1920`
  (Godot applies limits to viewport EDGES, not center — these values are correct)

**Zoom**: `Camera2D.zoom = Vector2(1.0, 1.0)` — no zoom applied in code. The viewport-to-world
scaling is handled entirely by the stretch mode.

**Safe area**: Apply `DisplayServer.get_display_safe_area()` to offset the joystick anchor
and any HUD elements that sit near screen edges. The 540×960 logical coordinate system
means safe area values must be divided by the current scale factor when converting.
Practical approach: place all interactive UI at least 40 logical pixels from any edge
(covers most Android safe areas at 2× scale).

### Architecture

```
Physical Android screen (e.g. 1080×1920)
        │ Godot stretch: canvas_items / keep / 2×
        ▼
Godot Viewport: 540×960 logical px
        │
        ├─ Camera2D (follows hero, limits 0-1080 / 0-1920)
        │       └─ shows 540×960 region of world
        │
        └─ World space: 1080×1920 px total
                ├─ Hero sprites (32px radius)
                ├─ Archer formation (V shape, 200×138px bounding box)
                ├─ Zones (radius 90px)
                ├─ Enemies (spawn at y≈1860, march to y≈100)
                └─ Castle (at top, y≈0)
```

### Key Interfaces

```gdscript
# Project Settings (project.godot) — set once, not in code
# display/window/size/viewport_width  = 540
# display/window/size/viewport_height = 960
# display/window/stretch/mode = "canvas_items"
# display/window/stretch/aspect = "keep"

# In Camera2D script — applied in _ready()
func _ready() -> void:
    limit_left   = 0
    limit_right  = 1080
    limit_top    = 0
    limit_bottom = 1920
    position_smoothing_enabled = false  # Manual lerp per ADR-004

# Touch input — JOYSTICK_ANCHOR is in logical 540×960 coordinates
# (135, 800) is lower-left region of the 540×960 viewport
const JOYSTICK_ANCHOR: Vector2 = Vector2(135.0, 800.0)
```

### Implementation Guidelines

1. Set viewport in **Project Settings**, not in code — code should never override viewport size.
2. All hard-coded pixel values in GDDs (zone radii, joystick anchor, sprite sizes) are in
   **world / logical-viewport coordinates**. Do not multiply or divide by 2 in code — the
   stretch mode handles the physical scaling.
3. When reading safe area insets via `DisplayServer.get_display_safe_area()`, the returned
   Rect2i is in **physical pixels**. Convert to logical coordinates:
   `logical_inset = physical_inset / DisplayServer.screen_get_scale()`. If `screen_get_scale()`
   returns 0 or is unavailable (emulator), default to 1.0.
4. If testing on desktop (mouse emulation), set window size to 540×960 for 1:1 testing,
   or 1080×1920 for 2:1 upscale simulation.

## Alternatives Considered

### Alternative 1: 1080×1920 native viewport

- **Description**: Match viewport to world exactly — 1 viewport px = 1 world px. No upscaling.
- **Pros**: Crispest possible rendering. No stretch complexity. Exact coordinate mapping.
- **Cons**: Fills entire pixel budget (1080×1920 = ~2M pixels) at every frame. On low-end
  Android (Mali-G51, Adreno 505), 60fps at 2M pixels + particle effects is at risk.
  Sprite textures at 32px would appear very small on a physical 1080p screen.
- **Estimated Effort**: Same implementation effort
- **Rejection Reason**: Performance risk on target low-end Android. Sprites too small for
  comfortable mobile visibility at physical 32px with no upscale.

### Alternative 2: 1080×960 (half-height) viewport

- **Description**: Match world width exactly (1080px) but use half the world height (960px).
- **Pros**: No horizontal stretching. World width = viewport width.
- **Cons**: Camera must scroll only vertically, not horizontally. Camera2D limit_right = 1080
  with viewport width = 1080 means no horizontal scroll at all — hero is always horizontally
  centered. This breaks the design if the hero moves off-center horizontally. Also 1080×960
  is not a standard phone ratio; letterboxing on 9:16 screens wastes screen area.
- **Rejection Reason**: Non-standard aspect ratio. Eliminates horizontal camera freedom.

### Alternative 3: 270×480 (quarter-resolution) viewport

- **Description**: 4× upscale from a very low-res viewport.
- **Pros**: Minimal pixel fill. Strong "pixel art" aesthetic.
- **Cons**: 32×32 sprites become 8×8 logical pixels — not readable. Zones (radius 90px
  logical) become 22.5 logical px — too small for reliable touch. Rejected immediately.
- **Rejection Reason**: Readability and touch target size fail at this resolution.

## Consequences

### Positive

- 2× upscale = 4× fewer pixels to fill = significant GPU headroom on mobile
- 32×32 sprite art displays as 64×64 physical pixels on 1080p screens — comfortable
  mobile visibility
- All coordinate arithmetic in code matches GDD values exactly (no scale factors in code)
- Stretch mode handles physical screen variation automatically

### Negative

- Sub-pixel rendering at non-2× scale factors (e.g. on a 1440p phone) — Godot's
  `canvas_items` stretch with non-integer scale produces filtered upscaling. For pixel art,
  enable "Filter" off on sprite textures (use `TEXTURE_FILTER_NEAREST`).
- Black bars appear on screens taller than 9:16 (e.g. 19.5:9 phones)

### Neutral

- Camera2D limit math: the limits in GDDs (0, 1080, 0, 1920) remain unchanged — they
  refer to world coordinates, and Godot's Camera2D applies limits correctly regardless
  of viewport size.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Sprite texture filtering produces blur at non-2× scales | Medium | Low (visual only) | Set `TEXTURE_FILTER_NEAREST` on all sprite imports |
| Safe area insets overlap joystick on notched phones | Low | Medium | Enforce 40px logical edge margin; test on a physical device with notch |
| Godot 4.6 stretch mode behavior changed post-cutoff | Low | High | Verify on first Godot 4.6 run; check against breaking-changes.md |

## Performance Implications

| Metric | 1080×1920 viewport | 540×960 viewport (chosen) | Budget |
|--------|-------------------|--------------------------|--------|
| Pixel fill rate | ~2.07M px/frame | ~518K px/frame | — |
| Draw calls | No change | No change | ≤150 |
| Memory (framebuffer) | ~8MB (RGBA8) | ~2MB (RGBA8) | ≤512MB total |

4× reduction in framebuffer size and pixel fill — significant headroom for particles
and overdraw on mobile.

## Migration Plan

No existing code to migrate — this is the initial configuration.

1. Open Project Settings → Display → Window
2. Set Viewport Width = 540, Viewport Height = 960
3. Set Stretch Mode = `canvas_items`, Aspect = `keep`
4. Run on desktop with window resized to 540×960 and verify coordinate alignment
5. Run on Android device and verify safe area margins

**Rollback plan**: Change viewport to 1080×1920 and remove stretch settings. All world
coordinates remain valid (they are world-space, not viewport-space).

## Validation Criteria

- [ ] Desktop run: all zones (radius 90px) appear correctly sized relative to hero (32px radius)
- [ ] Desktop run: joystick anchor at (135, 800) is in the lower-left quarter of the screen
- [ ] Android device: game fills screen without black bars (or bars are symmetric / acceptable)
- [ ] Android device: no touch input offset — joystick responds where finger touches
- [ ] Camera scroll: hero can reach all 4 edges of the 1080×1920 world before camera hits limits
- [ ] Performance: 60fps on reference device (mid-range Android, ~2020)

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/camera.md` | Camera | "World: 1080×1920. Viewport: TBD in ADR-001." | Defines viewport as 540×960; Camera2D limits remain 0-1080 / 0-1920 world coordinates |
| `design/gdd/hero-movement.md` | Hero Movement | Touch input coordinates must align with visible content | JOYSTICK_ANCHOR (135, 800) is in 540×960 logical space — confirmed lower-left placement |
| `design/gdd/hud.md` | HUD | HUD elements must not overlap game controls | 40px logical edge margin + safe area inset handling |

## Related

- ADR-004 — Camera frame-rate-independent lerp (depends on this ADR for viewport bounds)
- `docs/engine-reference/godot/modules/camera2d.md` — Camera2D limit documentation
- `docs/engine-reference/godot/current-best-practices.md` — Android safe area guidance
