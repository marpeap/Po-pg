# Cross-GDD Review Report
Date: 2026-05-19
GDDs Reviewed: 10 system GDDs + game-concept.md + systems-index.md
Systems Covered: Game State, Hero Movement, Camera, Castle, Enemy Wave, Economy, Archer Formation, HUD, Archer Tower, Forge
Entity Registry: design/registry/entities.yaml (401 lines, 4 entities, 9 formulas, 28 constants)
Engine: Godot 4.6, GDScript

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

---

**C-01 — Stale State References: MAIN_MENU / LOADING / WIN do not exist in MVP Game State Machine**

Economy GDD (lines 52, 70) defines a state-gating table that includes `MAIN_MENU | No — frozen`. HUD GDD (line 34) lists visibility rules for `LOADING`, `WIN`, and `MAIN_MENU` states. HUD acceptance criterion AC-C2.1 tests `MAIN_MENU` state.

Game State Machine GDD defines exactly 3 states: `PLAYING`, `GAME_OVER`, `RESETTING`. There is no `MAIN_MENU`, `LOADING`, or `WIN` state in MVP.

GDDs affected: economy.md (state table), hud.md (visibility rules + AC-C2.1)
Action required: Remove MAIN_MENU, LOADING, and WIN from Economy's state table and HUD's visibility rules. Update AC-C2.1 to test against actual states (GAME_OVER, RESETTING).

---

**C-02 — SHOOT_IVTL ownership conflict: three GDDs claim or attribute ownership differently**

- hero-movement.md Tuning Knobs: claims ownership of SHOOT_IVTL (0.9s, safe range 0.4–2.0s)
- archer-formation.md Cross-Knob section: defers ownership to Hero Movement
- forge.md (line 102): states SHOOT_IVTL is "owned by Archer Formation"
- entities.yaml: `source: archer-formation`

Three conflicting claims. Implementers cannot determine which system initializes, owns, and exposes SHOOT_IVTL for tuning. Since SHOOT_IVTL controls the fire rate of the entire formation (hero auto-shoot + archers + towers), and Forge modifies it at runtime, ownership must be assigned unambiguously.

GDDs affected: hero-movement.md (Tuning Knobs), archer-formation.md (Cross-Knobs), forge.md
Recommended resolution: Archer Formation owns SHOOT_IVTL. Hero Movement references it as a cross-knob. Forge documents that it modifies Archer Formation's SHOOT_IVTL value at runtime.

---

**C-03 — Stale ARCHER_DMG reference in enemy-wave.md**

Enemy Wave GDD (line 137) states: "At an assumed ARCHER_DMG ~= 10 HP/hit, enemies require ceil(57/10) = 6 hits at Wave 10."

Actual value: PROJ_DAMAGE = 8 HP (archer-formation.md, entities.yaml). At PROJ_DAMAGE = 8, Wave 10 enemies (57 HP) require ceil(57/8) = 8 hits, not 6. The balance reasoning in the design note is built on incorrect data.

GDDs affected: enemy-wave.md (design note line 137)
Action required: Replace ARCHER_DMG = 10 with PROJ_DAMAGE = 8. Recalculate: ceil(57/8) = 8 hits at Wave 10 — at the upper boundary of the stated 3–8 hit target range. Update all derived kill-time calculations in the same section.

---

**C-04 — Forge → Archer Formation: missing bidirectional dependency**

Forge GDD (line 219) explicitly states: "Bidirectional note for Archer Formation GDD: Update during /design-review to list Forge as a downstream system that modifies PROJ_DAMAGE and SHOOT_IVTL at runtime."

Archer Formation GDD does not list Forge anywhere in its Dependencies section. At runtime, Forge writes to PROJ_DAMAGE and SHOOT_IVTL — values that Archer Formation uses every fire cycle. The receiving system has no documented awareness of this write.

GDDs affected: archer-formation.md (Dependencies section)
Action required: Add Forge as a downstream dependent in archer-formation.md with note: "Forge (Alpha) may modify PROJ_DAMAGE and SHOOT_IVTL at runtime via upgrade purchases."

---

**C-05 — Forge → Castle: missing bidirectional dependency**

Forge GDD (line 221) states: "Bidirectional note for Castle GDD: Update during /design-review to list Forge as a downstream system that modifies CASTLE_MAX_HP at runtime."

Castle GDD does not list Forge anywhere. Forge's CASTLE_MAX_HP_UP upgrade directly modifies Castle's primary tuning knob at runtime.

GDDs affected: castle.md (Dependencies section)
Action required: Add Forge as a downstream dependent in castle.md with note: "Forge (Alpha) may increase CASTLE_MAX_HP at runtime. Does not heal current HP."

---

**C-06 — HUD references non-existent states in Acceptance Criteria**

HUD AC-C2.1: "GIVEN GameStateManager is in MAIN_MENU state, WHEN the scene is rendered, THEN the HUD CanvasLayer.visible property is false."

This acceptance criterion references a state that does not exist in the Game State Machine. A QA tester cannot pass or fail this criterion — the state it tests is unreachable.

GDDs affected: hud.md (AC-C2.1)
Action required: Replace MAIN_MENU with GAME_OVER and RESETTING. Verify that HUD visibility behaviour for these two valid states is fully specified.

---

**C-07 — Economy gold reset on session_reset: internal contradiction**

Economy GDD Core Rule 1 (line 32): gold resets to STARTING_GOLD = 60g on session reset.
Economy GDD Acceptance Criteria H-1 (line 310): "gold equals exactly 60."
Economy GDD Interactions table (line 82): "session_reset | Resets gold to 0."

The Interactions table directly contradicts the Core Rules and AC. An implementer reading the Interactions table will initialize gold to 0 on restart, breaking the game from wave 1.

GDDs affected: economy.md (Interactions table, line 82)
Action required: Change "Resets gold to 0" to "Resets gold to STARTING_GOLD (60g)."

---

**C-08 — STARTING_GOLD note in game-state.md contains factual error**

Game State Machine GDD (line 131) notes: "STARTING_GOLD is defined in the Castle GDD." STARTING_GOLD is defined in Economy, not Castle. Castle does not define or reference STARTING_GOLD.

GDDs affected: game-state.md (line 131)
Action required: Correct note to reference economy.md as the source of STARTING_GOLD.

---

**C-09 — facing_angle reset value conflict: Archer Formation expects pi, Hero Movement resets to 0**

Archer Formation Edge Case (line 271): "facing_angle is initialized to face up (pi) at session start."
Archer Formation AC-EC-04 (line 611): "facing_angle defaults to pi at session start."
Hero Movement GDD (line 38): "facing angle resets to 0" on session_reset.

If the implementer follows Hero Movement's session_reset handler (resets angle to 0), the archer formation will point in the wrong direction at every run start. The two systems disagree on the same shared state variable.

GDDs affected: hero-movement.md (reset section) OR archer-formation.md (EC + AC-EC-04)
Action required: Align both GDDs to the same value. The formation's visual correctness depends on this. Recommend: facing_angle resets to pi (pointing toward castle), and hero-movement.md acknowledges this.

---

**C-10 — STARTING_GOLD and STARTING_ARCHERS dual ownership**

game-state.md lists both STARTING_GOLD = 60g and STARTING_ARCHERS = 2 in its Tuning Knobs section. Economy GDD also owns STARTING_GOLD; Archer Formation GDD also owns STARTING_ARCHERS. Entity Registry identifies economy as source for STARTING_GOLD and archer-formation as source for STARTING_ARCHERS.

Two GDDs each claim tuning authority for the same constant. While values agree today, divergence after tuning is likely.

GDDs affected: game-state.md (Tuning Knobs section)
Action required: Remove STARTING_GOLD and STARTING_ARCHERS from game-state.md's Tuning Knobs. Add cross-references: "see economy.md" and "see archer-formation.md." Game State Machine reads these values; it does not own them.

---

### Warnings (should resolve, but won't block)

**W-C-01 — Signal name mismatch: GSM emits `game_state_changed` but HUD notes may use different name**
HUD Dependencies section documents the GSM signal as `game_state_changed(new_state)`. GSM GDD downstream table references "subscribe to GAME_OVER" without specifying the signal name explicitly. Confirm signal name is consistent across both documents and matches the eventual implementation.

**W-C-02 — Archer Tower ↔ Archer Formation dependency gap**
Archer Tower GDD (R3) specifies Formation must respond to `tower_purchased` by releasing 2 slots. Archer Formation lists Tower as a "Soft (Vertical Slice only)" dep with "No interface defined in MVP — deferred to Archer Tower GDD." Archer Tower GDD Open Question OQ-4 flags this. Before Vertical Slice implementation, both GDDs must be updated with the agreed slot-release interface.

**W-C-03 — Systems Index understates Forge dependency graph**
Systems Index lists Forge dependencies as "Economy" only. Forge GDD also has a hard upstream dependency on Game State Machine (`game_over` signal resets all deltas) and soft downstream dependencies on Archer Formation and Castle. The systems index dependency graph is incomplete for Forge.

**W-C-04 — Forge dwell timer pause not documented in Economy**
Forge GDD UI Requirements state that dwell timers for RECRUIT_ZONE and TOWER_ZONE are suppressed while the Forge upgrade menu is open. Economy GDD has no mention of this cross-system pause. Economy must implement this behaviour without any specification in its own GDD.

**W-C-05 — Game Concept pause duration stale**
Game Concept (line 94): "Pause inter-vague: 5s est un point de depart." Enemy Wave GDD: INTER_WAVE_PAUSE = 10s. The 2x discrepancy may confuse future contributors reading the concept doc.

**W-C-06 — Game Concept ZONE_RADIUS stale**
Game Concept (line 79): "Zone radius: ~60px (a valider en prototype)." Economy GDD: ZONE_RADIUS = 90px (validated). Concept doc references a superseded provisional value.

**W-C-07 — Forge PROJ_DAMAGE upgrade has no ceiling**
Forge F1 formula: `upgraded_proj_damage(k) = 8 + k*2`. No maximum k is defined. At k=10 (theoreticaly purchasable), PROJ_DAMAGE = 28 HP and a full-formation volley = 224 HP, enough to one-shot Wave 10 enemies with a single archer. Enemy HP scaling (+3/wave) does not cap, but neither does the upgrade. An explicit ceiling on k (e.g., k_max = 5) would prevent degenerate outcomes.

**W-C-08 — Tower engagement_time fragile to ENEMY_SPEED tuning**
Tower DPS design note: "Tower can solo-kill until ~Wave 55" assumes ENEMY_SPEED = 70 px/s. If tuned to 150 px/s (within Enemy Wave's stated safe range), engagement_time drops from 11.43s to 5.33s and the solo-kill ceiling drops to ~Wave 10. This cross-knob fragility is not documented in either GDD's tuning section.

---

## Game Design Issues

### Blocking

---

**D-01 — Pillar 2 goes dormant after Wave 2–3 in MVP: confirmed by the math**

Economy's own progression table (Formula D-6) shows all 8 archer slots can be filled by the end of Wave 2 with near-optimal play:

- STARTING_GOLD = 60g → 2 free archers
- Wave 1 max gold = 75g → 2 more Tier-1 archers (60g) + 15g saved
- Wave 2 max gold = 105g → 15g + 105g = 120g → 2 Tier-2 archers (120g) exactly

Result: 8/8 archers by end of Wave 2, gold count = 0g, no gold sink remains for the rest of the MVP run.

From Wave 3 onward, gold accumulates with no purpose. The gold counter becomes a meaningless number. Pillar 2 ("Chaque piece d'or est une decision") is inert for the majority of the play session.

This issue affects: economy.md, game-concept.md (pillar definition), archer-formation.md (cap rule)

Design options (not a prescription — user decides):
A. Add a recurring gold sink in MVP scope (e.g., ammo system, castle repair — requires new GDD)
B. Remove the hard archer cap or add a 9th+ slot at high cost to extend the spending curve
C. Accept Pillar 2 as a "waves 1–3 only" pillar and reframe it in game-concept.md accordingly
D. Move Archer Tower into MVP scope to provide a post-recruitment gold sink (100g)

---

**D-02 — Forge upgrade menu violates Anti-Pillars and breaks the one-finger design**

Forge GDD introduces a modal overlay panel with 3 selectable upgrade cards. The player must:
1. Read text descriptions of 3 upgrades
2. Evaluate trade-offs (damage vs. fire rate vs. magnet range)
3. Tap a specific UI card to confirm selection

This is the only system in the entire design that introduces a second input modality (tap on UI element) beyond the joystick. Hero movement remains active during menu display.

Anti-Pillar violations:
- "PAS de menus complexes mid-combat" — the Forge is a menu mid-combat
- "PAS de boutons / taps mid-combat" — card selection requires a tap
- Pillar 1 ("Un seul doigt, zero friction") — the joystick occupies the thumb; tapping a card simultaneously is physically impossible on a phone with one hand

Additionally, the modal adds a 5th concurrent attention demand (combat + gold + castle + HUD + menu), exceeding the 4-system comfort limit identified in the attention budget check.

Recommended design alternative (not a prescription): Replace the modal menu with 3 separate spatial ForgeZones — one per upgrade type — placed at fixed map positions. The player selects an upgrade by dwelling on the corresponding zone, exactly like recruit zones. This preserves one-finger play and the spatial commander identity.

---

### Warnings

**W-D-01 — Dominant positioning strategy: spawn-camping is risk-free and always optimal**
Enemies ignore the hero (Core Rule 9, enemy-wave.md) and march straight to the castle. The hero's only strategic purpose is positioning for gold collection and DPS. Staying near the bottom edge (y ≈ 1860, near enemy spawn) maximises intercept time and gold proximity. No mechanic punishes or creates a trade-off for this positioning. If dwell zones are placed near the castle, they create a forced choice; if zones are placed near spawn, the strategy is reinforced. Zone placement (undefined — Economy Open Question 1) must account for this.

**W-D-02 — Archer recruitment is always-optimal early spend: no competing gold sink creates a non-decision**
In MVP waves 1–3, the correct action is always "buy the next archer as soon as affordable." Pillar 2's "decision" is reduced to mechanical optimisation with no real alternative. Tiered costs (30g / 60g) add pacing variation but not genuine choice. The decision space opens only after wave 3 when gold becomes idle (D-01), at which point there is no decision at all.

**W-D-03 — Archer Tower provides zero net DPS gain; practical play favours keeping all archers mobile**
Tower GDD Formula F4 proves `system_dps` is unchanged by tower purchases when enemies pass through both tower range and formation range. Combined with the spawn-camping strategy (W-D-01), which positions the hero and formation in the primary intercept zone, towers only add coverage for enemies that slip past — a fallback, not a strategic alternative. The "mobile vs. fixed DPS" trade-off is theoretically present but practically moot.

**W-D-04 — Unchecked positive feedback loop: more archers -> more kills -> more gold -> more archers**
Pre-cap, each archer increases kill rate, which increases gold income, which accelerates the next recruit. No dampener exists. The loop resolves only because the 8-archer cap is hit rapidly. This is acceptable for the MVP scope but should be considered if the archer cap is raised.

**W-D-05 — No catch-up mechanic for players taking early castle damage**
Castle HP never regenerates (Core Rule 7, castle.md). Gold income is proportional to kill rate (which requires DPS). A formation that is weak earns less gold, recruits slower, and leaks more enemies. The STARTING_GOLD = 60g guarantee provides 2 archers per run as a floor, but no mechanic reduces the accumulated damage disadvantage of a bad early wave.

**W-D-06 — Difficulty plateau at Wave 9: enemy count caps while HP scaling rate is gentle**
Enemy count caps at 20 from Wave 9 onward. Post-cap difficulty scales by HP only (+3/wave). With formation DPS fixed at 71.11 HP/s (n=8), each additional 3 HP adds only 0.84s of clearing time per wave — a barely perceptible slope after the steep count-based ramp of Waves 1–8. The "tightening noose" of Pillar 4 may feel stalled at mid-game.

**W-D-07 — Forge DPS upgrades may push session length far beyond the 5–20 minute design target**
Enemy Wave GDD targets Wave 10–15 as the designed run length. Forge F5: maximum formation DPS after upgrades = `(8 * (8 + k*2)) / (0.9 - j*0.1)` with SHOOT_IVTL_FLOOR = 0.4s. At PROJ_DAMAGE = 28 and SHOOT_IVTL = 0.4, formation DPS = 560 HP/s. This trivialises all enemy HP values for dozens of additional waves and extends sessions far beyond the design target. The Forge GDD does not analyse this interaction.

**W-D-08 — Forge fantasy drifts from spatial commander identity toward RPG stat-upgrade**
All system Player Fantasies converge on "mobile commander building a growing army under pressure." Forge's stated fantasy is "becoming unstoppable; gold transmuted to power" — a personal power fantasy. While the stats apply to the formation, the interaction pattern (read text, evaluate stats, tap card) is a personal RPG moment inserted into a spatial strategy game. This is a minor identity drift, not a blocker.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. Enemy kill → gold → magnet → recruit zone → archer recruit
2. Castle HP = 0 → game over → session_reset
3. Wave end → inter-wave pause → new wave
4. Forge upgrade selection during active wave (Alpha)
5. SHOOT_IVTL modified mid-wave with tower and formation both active

### Blockers

**S-01 — Session Reset: Economy resets gold to 0 instead of 60g**
Scenario: Castle HP = 0 → game over → player taps restart → session_reset fires

Step where failure occurs: Economy's session_reset handler, per the Interactions table (line 82), resets gold to 0. The rest of the Economy GDD (Core Rules, AC) specifies reset to STARTING_GOLD = 60g. An implementer following the Interactions table ships a broken restart — the player begins every new run broke with no way to recruit archers.

Systems involved: economy.md (internal contradiction), game-state.md (fires session_reset)
Resolution: Fix Economy Interactions table (covered by C-07 above).

**S-02 — Forge upgrade selection requires simultaneous joystick control and UI tap (one-thumb impossibility)**
Scenario: Player walks to FORGE_ZONE, dwells 0.8s, Forge modal opens, enemies continue advancing

Step where failure occurs: The player's thumb is on the joystick to avoid lost castle HP during the modal. The upgrade selection requires tapping a card displayed on screen. On a single-thumb mobile device, both actions cannot occur simultaneously. The player must release the joystick (hero stops, formation stops, DPS stops), read the cards, tap a selection, and then resume movement. During this pause, castle HP takes damage.

Systems involved: forge.md (UI design), hero-movement.md (movement continues during modal), castle.md (damage continues), economy.md (dwell timer interaction)
Resolution: Covered by D-02. Spatial zone selection eliminates the tap requirement.

### Warnings

**S-03 — SHOOT_IVTL runtime modification: Tower and Formation timers may not update simultaneously**
Scenario: Forge upgrades SHOOT_IVTL mid-wave. Both Archer Tower and Archer Formation use SHOOT_IVTL to drive their fire timers.

Issue: If each system initialises its own Godot `Timer` node with SHOOT_IVTL at scene creation, a runtime change to the constant does not automatically update active timers. The Forge GDD documents that SHOOT_IVTL_DOWN modifies SHOOT_IVTL globally, but does not specify how active timers in other systems are notified of the change. The result may be that the formation updates immediately (if it reads SHOOT_IVTL each cycle) while the tower continues on its old cadence (if it set its `Timer.wait_time` once at creation).

Systems involved: forge.md, archer-formation.md, archer-tower.md
This is an implementation concern rather than a GDD contradiction — but the architecture must define the notification pattern before the Archer Tower system is built.

**S-04 — Mid-wave archer recruitment creates undefined interaction with formation firing cycle**
Scenario: Player recruits an archer during an active wave. The new archer spawns into the next available slot while the formation is actively firing.

Issue: None of the GDDs specifies whether a newly-recruited archer fires on the same cycle as existing archers or waits for the next volley cycle. If archers synchronise on a shared timer, the new archer joins the next volley. If each archer has its own timer, the new archer fires immediately, slightly desynchronising the formation. The HUD archer counter must update at the correct moment. The behaviour is not undefined in a blocking sense — it degrades gracefully — but it is unspecified.

Systems involved: archer-formation.md, economy.md (recruit_purchased signal), hud.md

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| economy.md | Remove MAIN_MENU from state table; fix gold reset (0 → 60g) | Consistency | Blocking |
| hud.md | Remove MAIN_MENU/LOADING/WIN from visibility rules; fix AC-C2.1 | Consistency | Blocking |
| enemy-wave.md | Replace ARCHER_DMG = 10 with PROJ_DAMAGE = 8; recalculate hits-to-kill | Consistency | Blocking |
| archer-formation.md | Add Forge as downstream dep; align facing_angle reset value | Consistency | Blocking |
| castle.md | Add Forge as downstream dep | Consistency | Blocking |
| hero-movement.md | Resolve SHOOT_IVTL ownership (remove from Tuning Knobs or clarify cross-ref); align facing_angle reset | Consistency | Blocking |
| game-state.md | Fix STARTING_GOLD note (Castle → Economy); remove STARTING_GOLD/ARCHERS from Tuning Knobs | Consistency | Blocking |
| forge.md | Align SHOOT_IVTL ownership statement; add runtime timer notification pattern note; add PROJ_DAMAGE upgrade ceiling | Consistency + Design | Blocking |
| game-concept.md | Update Pillar 2 framing to reflect MVP dormancy; update zone radius (60px → 90px); update inter-wave pause (5s → 10s) | Design | Warning |
| archer-tower.md | Document slot-release interface for Archer Formation (resolve OQ-4) | Consistency | Warning |
| systems-index.md | Expand Forge dependency listing to include Game State and Formation/Castle soft deps | Consistency | Warning |

---

## Chain-of-Verification

Five challenge questions checked before finalising verdict:

1. **[TOOL ACTION — Phase 2 agent re-read all GDDs]** Did I verify state references by actually reading the files, not inferring? Yes — Economy line 52/70 and HUD line 34 were explicitly cited with line numbers from full reads.

2. **[TOOL ACTION — entities.yaml read in full]** Does SHOOT_IVTL ownership conflict exist in the registry, or only in GDD text? Confirmed: entities.yaml says `source: archer-formation` with a note that hero-movement.md also uses it — a documented inconsistency in the registry itself.

3. **Is the gold sink issue a FAIL or a CONCERNS?** The math proves Pillar 2 is inert for the majority of the MVP run. Architecture built on this GDD set will produce a game that fails to express its second design pillar. This is blocking for architecture — systems will be designed assuming gold tension throughout, when it only exists for 2–3 waves. Verdict: FAIL.

4. **Are Forge issues blocking if Forge is Alpha scope?** The Forge GDD exists and will influence architecture. The SHOOT_IVTL ownership conflict spans MVP systems (Hero Movement, Archer Formation) and is not Alpha-scoped — it must be resolved before any architecture. The anti-pillar violation must be resolved before the Forge GDD is considered approved input for architecture. Verdict: FAIL on both counts.

5. **Am I overstating any blocker?** The facing_angle conflict (C-09) and gold reset (C-07) are implementation blockers that would ship as bugs if unresolved. SHOOT_IVTL (C-02) is a blocker because three systems will be architected around a constant with no agreed owner — the first ADR touching fire rate will be built on ambiguous ground. Verdict: all ten consistency blockers are correctly classified.

Chain-of-Verification: 5 questions checked — verdict unchanged (FAIL).

---

## Verdict: FAIL

**Blocking issues preventing architecture from beginning: 13**
- Consistency blockers: 10 (C-01 through C-10)
- Design theory blockers: 2 (D-01 gold sink, D-02 Forge anti-pillar)
- Scenario blockers: 2 (S-01 gold reset implementation bug, S-02 Forge one-thumb impossibility)
  *(S-01 and C-07 address the same root cause — counted once in the totals)*

**Warning issues (address before production): 18**

---

## Required actions before re-running /review-all-gdds

The following changes are required. All are GDD text edits except item 5 which requires a design decision.

**Tier 1 — Text fixes (each ≤ 15 minutes):**
1. economy.md: Remove MAIN_MENU from state table; change "Resets gold to 0" → "Resets gold to STARTING_GOLD (60g)" in Interactions table
2. hud.md: Remove MAIN_MENU, LOADING, WIN from visibility rules; rewrite AC-C2.1 to test GAME_OVER and RESETTING states
3. enemy-wave.md: Replace "ARCHER_DMG ~= 10 HP/hit" with PROJ_DAMAGE = 8 HP; update kill calculations (Wave 10: 8 hits, not 6)
4. game-state.md: Fix STARTING_GOLD source note (Castle → Economy); remove STARTING_GOLD and STARTING_ARCHERS from Tuning Knobs (add cross-refs)
5. castle.md: Add Forge as downstream dep in Dependencies section
6. archer-formation.md: Add Forge as downstream dep; align facing_angle reset value to pi
7. hero-movement.md: Either (a) remove SHOOT_IVTL from Tuning Knobs and add a cross-ref to archer-formation.md, or (b) explicitly state it is the owner and update all other GDDs to defer to it; align facing_angle reset value to match archer-formation.md
8. forge.md: Align SHOOT_IVTL ownership statement to match the resolution from item 7

**Tier 2 — Design decision required:**
9. gold sink in MVP (D-01): Choose one of the four options listed in D-01 and update game-concept.md and economy.md accordingly. If Option D (move Tower into MVP), update systems-index.md priority tier.

**Tier 3 — Design decision required (Alpha scope):**
10. Forge interaction design (D-02): Replace modal card selection with spatial zone selection or another one-finger-compatible alternative; update forge.md UI Requirements accordingly.
