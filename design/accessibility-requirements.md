# Accessibility Requirements — Garrison

> **Status**: Committed
> **Author**: ux-designer
> **Last Updated**: 2026-05-19
> **Stage**: Technical Setup
> **Applies To**: All screens and game systems

---

## Committed Accessibility Tier

**Tier: BASIC-MOBILE**

Garrison targets Android mobile with touch-only input. The accessibility tier
commits to the following baseline: every player who can hold a phone and place one
finger on the screen can complete a full play session without encountering an
accessibility barrier that prevents progress.

This is not a full WCAG AA commitment (Garrison is a real-time action game, not
a web document), but it incorporates the mobile-applicable subset of WCAG 2.1 AA
and the Google Android accessibility guidelines as the governing standard.

**Summary of tier obligations:**
- Touch targets meet minimum size requirements
- No information is conveyed by color alone
- All player-facing text meets minimum contrast and size requirements
- The game is operable by one hand with one touch point at all times
- Audio provides independent confirmation of key game events
- No harmful flashing patterns

---

## 1. Input Accessibility

### 1.1 Single-Touch Contract

**Requirement**: The entire game must be playable with exactly one simultaneous
touch point. No multi-touch gesture (pinch, two-finger swipe, etc.) is required
or assumed.

**Rationale**: Pillar 1 ("Un seul doigt, zéro friction") aligns with single-touch
accessibility. Players with motor impairments affecting one hand, or players using
adaptive switches, must be able to play without modification.

**Implementation**: The Fixed-Anchor Virtual Joystick (Pattern 1) and Zone Dwell
Trigger (Pattern 2) are the only input mechanisms. Both operate with one touch point.
Validated in `design/gdd/hero-movement.md` and `design/ux/interaction-patterns.md`.

### 1.2 Touch Target Minimum Size

**Requirement**: No interactive touch target may be smaller than 44×44 logical pixels
(Android Material Design minimum; equivalent to ~7mm physical at standard DPI).

**Application to Garrison**:
- Virtual joystick touch area: entire bottom half of the screen (~540×480px). PASSES.
- Dwell zones: ZONE_RADIUS = 90px in world space. At 540×960 logical viewport,
  this maps to approximately 45px at 1:1 — passes minimum but should be monitored
  if the world-to-viewport mapping changes.
- No HUD elements are interactive in MVP. If interactive HUD elements are added
  in later milestones, they must meet this requirement.

### 1.3 One-Handed Operation

**Requirement**: All gameplay and navigation actions must be reachable with the
dominant thumb, phone held in one hand in portrait orientation.

**Rationale**: The joystick anchor at `(135, 800)` in 540×960 viewport is
positioned for the bottom-left thumb grip — the standard mobile hold for portrait
play. Zones in the world are reached by movement, not by direct tap — the player
does not need to tap anywhere except the joystick area.

---

## 2. Visual Accessibility

### 2.1 Text Contrast

**Requirement**: All player-facing text must meet a contrast ratio of at least 4.5:1
against its background (WCAG 2.1 AA — Normal Text).

**Minimum rendered text sizes**:
- HUD counters and labels: minimum 16px rendered at 540×960 logical resolution
- Zone labels (Forge, Alpha): minimum 14px rendered
- GAME_OVER text: minimum 20px rendered

**Implementation note**: HUD elements are placed on a semi-transparent dark strip
(design/gdd/hud.md). The strip background must achieve the required contrast ratio.
Exact color values to be defined in Art Bible Section 3 (Color Palette).

### 2.2 Color Independence

**Requirement**: No information critical to gameplay may be conveyed by color alone.
A player who cannot distinguish colors must receive the same information via shape,
text, icon, or audio.

**Application to Garrison**:

| Element | Color Used | Non-Color Fallback Required |
|---------|-----------|----------------------------|
| Castle HP bar | Green → red gradient on low HP | Numeric HP value displayed alongside bar |
| Gold counter | Yellow gold icon | Numeric count displayed |
| Archer badge | Formation icon | Numeric count displayed (e.g., "2/8") |
| Wave label | — | Text label ("Wave 3" or "Wave Clear") |
| Dwell progress bar | Fill color changes on complete | Fill length + completion feedback (sound) |
| FORGE_ZONE_DMG vs FORGE_ZONE_SPD | Different zone colors | Distinct icon/label per zone type (Alpha) |

**CRITICAL GAP**: Castle HP bar color gradient (green → red) must NOT be the
only signal that the castle is under threat. The numeric HP value must always be
visible, or a distinct low-HP audio/visual warning must accompany the color change.
Resolve in `/ux-design hud`.

### 2.3 Text Scaling

**Requirement**: The game does not need to support Android system font scaling
for the MVP release. Player-facing text sizes are fixed in the HUD spec.

**Rationale**: Garrison is a real-time action game with a fixed viewport. Dynamic
text scaling would require reflowing HUD elements — this is out of scope for MVP.
If post-MVP accessibility feedback identifies text size as a barrier, a manual
in-game text size toggle (S/M/L) should be added as the resolution path.

### 2.4 Safe Area Insets

**Requirement**: No HUD element may be positioned in the OS-reported unsafe area
(Android status bar, navigation bar, camera notch).

**Implementation**: All HUD elements must be inside the OS-reported safe rect.
In Godot 4.6, use `DisplayServer.get_display_safe_area()` to query safe rect at
runtime and offset HUD anchors accordingly.

**Priority**: HIGH — must be implemented before any public playtest on physical
Android devices.

---

## 3. Audio Accessibility

### 3.1 Audio as Redundant Confirmation

**Requirement**: Audio must provide independent confirmation of the following events
(player must be able to confirm the event occurred without looking at the screen):

| Event | Required Audio Cue | Status |
|-------|--------------------|--------|
| Volley fire | Bow/arrow sound | Defined in ADR-008 |
| Archer recruited | Recruitment sound | To define in Audio GDD |
| Gold collected (batch) | Coin collect sound | To define in Audio GDD |
| Castle taking damage | Impact sound | To define in Audio GDD |
| Dwell trigger complete | Completion chime | To define in Audio GDD |
| Game Over | Distinct loss stinger | To define in Audio GDD |

**Gap**: Audio GDD does not yet exist. Create before Pre-Production gate.
Audio cues are REQUIRED for BASIC-MOBILE tier — silent events create a barrier
for players who cannot see the visual feedback in low-light conditions or with
display accessibility overlays active.

### 3.2 No Information in Audio Alone

**Requirement**: No critical gameplay information may be conveyed by audio alone.
All audio cues must have a corresponding visual indicator.

**Rationale**: Players with hearing impairments or in a silent environment (public
transit, muted phone) must receive all information through visual channels.

### 3.3 Volume Controls

**Requirement**: The game must respect the Android system volume setting. No
game-internal volume normalization may override the system master volume.

**Implementation**: AudioManager autoload (ADR-008) uses non-positional
`AudioStreamPlayer` nodes. All audio routes through the Android system volume
stack by default — no additional implementation required.

---

## 4. Motion and Flicker

### 4.1 No Harmful Flashing

**Requirement**: No element in the game may flash at 3–50 Hz (the range associated
with photosensitive seizure risk, per WCAG 2.1 — Guideline 2.3).

**Application to Garrison**:
- Volley fire effects: single-frame impact VFX are acceptable (1 frame at 60fps = 16ms,
  far below the 333ms threshold for the 3Hz minimum).
- Castle HP low-health warning pulse: if implemented, must pulse at < 3 Hz
  (one pulse per 333ms+). A slow, calm pulse (e.g., one beat per second) is acceptable.
- GAME_OVER screen: no rapid flash transition. Cross-fade or instant cut preferred.

### 4.2 Reduced Motion

**Requirement**: There is no Android system-level reduced-motion flag accessible
via Godot 4.6 GDScript (unlike iOS UIAccessibility). A manual in-game toggle
for reduced motion effects is NOT required at the BASIC-MOBILE tier.

**Deferral condition**: If a post-MVP accessibility audit identifies motion as a
barrier for any player, add a manual in-game toggle. Until then, ensure all
animations have calm, non-jarring defaults (no rapid shake, no rapid position
flicker on HUD elements).

---

## 5. Cognitive Accessibility

### 5.1 First-Time Legibility

**Requirement**: A player who has never seen Garrison must understand what to do
within 90 seconds of their first session, without reading a tutorial screen.

**Implementation path**: Joystick affordance (visual indicator of where to touch),
zone labels visible in world space, and enemy movement toward the castle all
communicate the game goal spatially. Validate in first playtest session.

### 5.2 No Time-Limited Menus

**Requirement**: No menu, prompt, or dialog that requires player input may have
an auto-dismiss timer during MVP. All non-gameplay UI must persist until the player
acts on it.

**Rationale**: Time-limited prompts create a barrier for players who read slowly
or need more time to make decisions. In Garrison, the only timed element is the
Zone Dwell Trigger — which is an intentional gameplay mechanic, not a menu.

---

## 6. Acceptance Criteria

- [ ] All HUD text renders at ≥ 16px on a physical Android device at target DPI
- [ ] Castle HP bar displays numeric HP value alongside the bar fill — color is not
  the sole indicator of castle health
- [ ] No interactive touch target in MVP is smaller than 44×44 logical pixels
- [ ] All gameplay is completable in a single play session using one touch point only
- [ ] HUD elements do not overlap Android system status bar or navigation bar on
  a test device with a camera notch
- [ ] No UI element flashes at 3–50 Hz — verified by visual inspection on device
- [ ] Audio cues fire for: volley fire, dwell trigger complete, gold collect, game over
- [ ] Game respects Android system volume (muted phone = silent game)

---

## 7. Known Gaps (resolve before Pre-Production gate)

| Gap | Impact | Resolution Path |
|-----|--------|-----------------|
| Audio GDD missing — audio cues not fully specified | Medium | Create Audio GDD before Pre-Production |
| Castle HP color-only warning — numeric fallback not yet in HUD spec | High | Resolve in `/ux-design hud` |
| GAME_OVER dismiss mechanism not defined | Medium | Resolve in `/ux-design game-over` |
| FORGE_ZONE icon/label language not defined | Medium | Art bible + `/ux-design forge-zones` (Alpha) |
| Reduced-motion Android detection investigation | Low | Investigate before Polish gate |

---

*Accessibility tier committed: BASIC-MOBILE*
*Next review: Pre-Production gate — verify all BASIC-MOBILE criteria are addressed in UX specs*
