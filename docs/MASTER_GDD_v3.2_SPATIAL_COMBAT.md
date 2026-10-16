# MASTER GAME DESIGN DOCUMENT v3.2
## Spatial Node Combat System & Tabletop Miniature Architecture
**Crucible of Ash: Dark Fantasy Roguelike Auto-Battler**
*Document Version: 3.2.0 | Supersedes: MASTER_GDD_v2.9.md & Legacy 2D Lane Combat*

---

## 1. Executive Summary & Design Vision

*Crucible of Ash* is a dark-fantasy tactical tabletop auto-battler for mobile and PC.
Version 3.2 formally replaces the legacy 2-row horizontal lane system with the **2.5D Isometric Spatial Node Battlefield**. 

### Core Pillars
1. **Physical Tabletop Presence:** Units are rendered as upright dark fantasy miniatures grounded on angled isometric contact plinths (embossed with runic borders and contact shadows).
2. **True Spatial Tactics (The 5x7 Node Arena):**
   * 5 columns $\times$ 3 rows of Player Depth (Frontline, Midline, Backline).
   * 1 Central Dynamic Clash Line.
   * 5 columns $\times$ 3 rows of Hostile Territory with multi-tile Behemoth Boss footprints (e.g., Gorgoroth the Flayed taking a 2x2 Colossus footprint).
3. **Adaptive Posture System (No Dead Turns):** Displacement and knockbacks dynamically alter a unit's attack style rather than freezing or passing turns.
4. **Unit Combat Triad:**
   * **Automated Basic Action:** Fires automatically on AP accumulation (10,000 AP tick threshold).
   * **Stance Mastery (Passive):** Positional conditions grant runic plinth auras and powerful combat effects.
   * **Manual Ultimate Burst:** High-impact, player-targeted skills with tactical bullet-time slowdown.
5. **Inert Vessel Downed State & Severed Resonance:** Fallen units remain as physical inert vessels blocking movement until revived via Infused Vitae.

---

## 2. Battlefield Geometry & Perspective

### 2.1 The Coordinate Matrix
* **Columns:** $0 \dots 4$ (Col 1 to Col 5).
* **Global Rows ($gRow$):** $0 \dots 6$
  * $gRow \in [0, 2]$: Hostile Territory ($gRow = 2$: Front, $gRow = 1$: Mid, $gRow = 0$: Back).
  * $gRow = 3$: Neutral Dynamic Clash Line.
  * $gRow \in [4, 6]$: Allied Regiment ($gRow = 4$: Front, $gRow = 5$: Mid, $gRow = 6$: Back).

### 2.2 Depth-Sorting Layer Architecture (The Z-Index Rule)
In 2.5D isometric projection:
$$\text{Depth} = gRow + \text{column}$$
* **Background Elements:** Render first ($gRow \in [0, 2]$).
* **Foreground Elements (Player Squad):** Render last on top ($gRow \in [4, 6]$).
* **Layer Order in Flutter Stack:**
  1. Floor Terrain Layer (35 diamond tiles, grid borders, drop-target zones).
  2. Miniature Token Layer (all 1x1 units and multi-node colossi sorted ascending by Contact Depth).
  3. Tactical Overlay Layer (translucent basic attack trajectory vectors, telegraph countdowns, AOE splash rings).
  4. Kinetic Combat VFX Layer (slash trails, piercing beams, ground shockwaves).

---

## 3. The Unit Combat Triad

```
┌───────────────────────────────────────────────────────────────┐
│                      UNIT COMBAT TRIAD                        │
├───────────────────────────────┬───────────────────────────────┤
│ 1. Basic Action (Automated)   │ Standard attack on full AP    │
│ 2. Stance Mastery (Passive)   │ Positional condition -> Buff  │
│ 3. Ultimate Burst (Manual)    │ Full meter -> Drag mini-slate │
└───────────────────────────────┴───────────────────────────────┘
```

### 3.1 Automated Basic Action (10,000 AP Threshold)
Units accumulate Action Points based on their `speed` stat each simulation tick:
$$\Delta\text{AP} = \text{speed} \times 1.25$$
Upon reaching 10,000 AP, the unit fires its current depth-adapted basic action down its designated column or target.

### 3.2 Stance Mastery (Archetype Positional Traits)
* **Vanguard / Juggernaut — "Hold the Line":**
  * *Trigger:* Remains stationary in the Frontline ($gRow = 4$) for 2 consecutive attack cycles.
  * *Visual Cue:* Outer iron rim of plinth ignites with an amber/gold glowing rune ring.
  * *Effect:* Gains +30% Armor (PRR) and Stagger Immunity. Basic attack becomes an Earth-Shattering Bash cleaving laterally across adjacent frontline tiles, resetting 1,500 AP on targets hit.
* **Skirmisher / Assassin — "Flanking Momentum":**
  * *Trigger:* Attacks a target with active Bleed or repositioned during combat.
  * *Visual Cue:* Crimson wind trail circling the plinth base.
  * *Effect:* Next basic strike gains +40% Critical Strike Chance and inflicts 2 Bleed stacks; refunds 3,000 AP (initiates next attack 30% faster).
* **Arcanum / Mage — "Aetheric Alignment":**
  * *Trigger:* Casts basic attack from Backline ($gRow = 6$) under Guarded status.
  * *Visual Cue:* Cyan geometric runic circle pulsing beneath the plinth.
  * *Effect:* Attack pierces straight down the full column; generates +1 Global Focus.
* **Support / Healer — "Sanctified Hearth":**
  * *Trigger:* Allied units occupy both nodes immediately adjacent to the Support unit.
  * *Visual Cue:* Emerald runic aura expanding outward to touch neighbor plinths.
  * *Effect:* Regenerates 3% Max HP per second to neighbors and dispels 1 crowd-control stack.

### 3.3 Manual Ultimate Burst
* Charges via basic attacks (+15% per strike) and taking kinetic damage (+10% on heavy hits).
* Dragging the glowing runic portrait engages **30% tactical bullet-time**.
* Drop directly onto targeted nodes or enemy colossi to execute unblockable tactical bursts.

---

## 4. The Adaptive Posture System

When a unit is displaced by knockback, pull, or tactical swapping, its action adapts to its row:

### 4.1 Vanguard / Melee
* **Frontline ($gRow = 4$): [Brawl Stance]** Full 100% melee impact, lateral cleaves, absorbs hits.
* **Midline ($gRow = 5$): [Advancing Tremor]** Slams shield into earth for a kinetic shockwave straight down the column (60% base damage + 15 stagger). Automatically advances forward if front tile is vacant.
* **Backline ($gRow = 6$): [Braced Bulwark]** 0 kinetic damage. Slams shield into ground, granting +25 Armor to allies ahead in that column and charging 20% Ultimate gauge.

### 4.2 Caster / Healer
* **Backline ($gRow = 6$): [Aetheric Focus]** Full ranged range, Guarded status (-20% ranged damage taken).
* **Midline ($gRow = 5$): [Arcane Volley]** Standard spellcasting cadence.
* **Frontline ($gRow = 4$): [Point-Blank Vulnerability]** Loses Guarded status; taking heavy hits delays AP by 25%. Basic spell converts to an immediate radial Panic Discharge with knockback.

---

## 5. Downed State & Encounter Economy

### 5.1 Inert Vessel State
* Units reduced to 0 HP do not vanish or leave the board.
* The miniature desaturates to a cold stone grey plinth, remaining on the grid as an obstacle.
* AP accumulation freezes at 0.

### 5.2 Severed Resonance
* If Commander (Lady Valeria) enters Downed State, party Focus accumulation is throttled by 50%.

### 5.3 Infused Vitae Revive
* Casting *Infused Vitae* (or dedicated revival card) restores 40% Max HP.
* Grants 6 ticks of invulnerability (ethereal gold shield).
* Applies *Soul Fracture* (-15% max HP for remainder of encounter).

---

## 6. Status Effect Matrix

| Status | Type | Mechanic |
| :--- | :--- | :--- |
| **Bleed** | DoT | Kinetic ticks on AP accumulation; detonated by Skirmisher crits. |
| **Poison** | Decay | True damage per tick; reduces target Attack and Speed by 2% per stack. |
| **Freeze** | Control | Freezes AP gauge completely; physical melee hits shatter for +15% Max HP bonus damage. |
| **Vulnerable** | Debuff | Amplifies all incoming kinetic and radiant damage by +25%. |
| **Haste** | Buff | Accelerates AP accumulation rate by +30%. |

---

## 7. Art & Asset Pipeline Specification

1. **Character Cutouts:** Upright 2D transparent PNG cutouts rendered with bottom-center alignment.
2. **Contact Plinths:** Angled isometric ellipses ($W \times H$ matching tile aspect ratio $2:1$).
   * 1x1 Standard Units: $W \approx 88\text{px}, H \approx 20\text{px}$.
   * 2x2 Behemoth Bosses: $W \approx 180\text{px}, H \approx 44\text{px}$.
3. **Plinth Alignment Anchor:** Bottom vertex of character miniature aligns directly with the center of its assigned diamond tile.

---
*Crucible of Ash — Engineered for Deep Mobile & PC Tabletop Tactics.*
