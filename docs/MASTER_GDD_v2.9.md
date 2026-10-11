# CRUCIBLE OF ASH: MINIATURE BATTLER
## Master Game Design Document v2.9 (Asymmetric Rule-Breaking & Discrete Formation Specification)

**Engine / Runtime:** Fixed 30 Hz Deterministic Simulation Loop (Dart) decoupled from Flutter / Impeller presentation  
**Target Viewports:** Responsive 9:16 Mobile Portrait primary (390×844 logical px); 16:9 Landscape adaptable  
**Aesthetic Metaphor:** Dark Fantasy / Living Mineral Tabletop Miniature Wargame on physicalized kinetic plinths  

---

## 1. Executive Summary & Core Pillars
*Crucible of Ash: Miniature Battler* is a tactical roguelite battler combining deterministic spatial simulation, deep pre-battle sequence planning, and real-time alchemical card intervention.

- **The Arch-Sculptor & Living Mineral:** The player is an off-board alchemist commanding mineral constructs animated by pressurized Vitae and anchored to earth by kinetic plinth grounding seals.
- **Rule-Breaking Asymmetry (MtG Design Philosophy):** Baseline game rules (Focus pool, starting budget, fill rates, deck capacity, hand size) serve merely as defaults. Individual Commanders, Factions, and Cards explicitly bend, break, or invert these rules to create wildly distinct strategic identities.
- **Deterministic Column & Row Spatial Geometry:** Pre-battle placement across a 5-column, 2-row plane dictates combat flow. Targeting, synergy buffs, and guard mechanics resolve with mathematical predictability.
- **Pure Strategic Agency (Zero Quick-Time Events):** Combat outcomes depend strictly on preparation, composition, speed-tuning, and tactical card timing—without reflex-based tap or swipe prompts.
- **Low-Inflation Progression (Classic WoW Ethos):** Numbers remain compressed and human-readable. Upgrades, socketed chisels, and Crucible fusions yield tangible, calculated advantages rather than exponential power creep.

---

## 2. World Logic & Metaphysical Foundations

### 2.1 The Great Rupture & The White Rain
- **The Living Marrow:** Vitae was the imperial civilization's geological lifeblood—a conductive crimson fluid running through deep geological aquifers powering metallurgy, medicine, and deep-mantle golems.
- **The Cataclysm:** The rupture of The Undying Hearth superheated planetary aquifers, calcifying 99% of organic life into brittle stone husks whose soul-embers wander the ash plains.
- **The Sculptor's Curse:** Arch-Sculptors can channel pressurized Vitae to reanimate constructs, but doing so slowly petrifies their own vascular systems, driving an eternal search for fresh wellheads to stave off calcification.

### 2.2 Metaphysics of Combat & The Plinth Seal
- **Flesh of Stone:** Constructs are mineral fibers saturated with pressurized red Vitae that flex like petrified muscle. Shearing strikes cause Vitae leaks (Bleed), while porous osmotic weapons siphon pressurized fluid to lubricate seizing joints (Lifesteal).
- **The Plinth Seal:** Construct ash naturally disperses. The circular plinth is a downward radiant field of tension burned into the earth that binds the miniature to physical space.
- **Faction Seals:**
  - *Ash Legion:* Welded cold-iron bands on fortress flagstone.
  - *Crypt Stalkers:* Weeping arterial stone basins with black moss.
  - *Mire Coven:* Churned wet bog-mud with weeping shelf fungi.
  - *Calx Order:* Stark white compass ring with swirling miniature dust-devils.
  - *Corrupted Beasts:* Trampled black earth with bone shards and roots.

### 2.3 The Alchemical Apparatus: Catalyst Key & Tuning Slips
- **The Catalyst Gauntlet:** A brass, volcanic-glass, and clockwork apparatus worn by the Arch-Sculptor to channel Vitae into the battlefield.
- **Tuning Slips:** Tactical commands etched onto plates of slate-foil, horn, and gold leaf. Slotted into the Gauntlet rail, they alter battlefield laws.
- **The Burn Pit:** An under-rail exhaust slot where unwanted slips are incinerated for 0 Focus to vent heat and draw fresh tactical options.
- **Tactical Bullet-Time:** Dragging or inspecting a Tuning Slip slows simulation time by 30% to represent the Arch-Sculptor projecting their neural tether across the miasma.

---

## 3. Combat Engine & Spatial Formation Architecture

### 3.1 The 5v5 Dual-Row Grid
The battlefield consists of 5 dedicated spatial columns. Each slot can be independently assigned to the Frontline (Vanguard) or Backline (Arcanum):

```
[ ENEMY SQUAD ]
  Col 1 (Far L)   Col 2 (Mid L)   Col 3 (Center)   Col 4 (Mid R)   Col 5 (Far R)
════════════════════════════════ CLASH LINE ════════════════════════════════
  Col 1 (Far L)   Col 2 (Mid L)   Col 3 (Center)   Col 4 (Mid R)   Col 5 (Far R)
[ PLAYER SQUAD ]
```

- **Visual Offsets:**
  - *Frontline (Vanguard):* Stepped forward toward the clash line (+10px to +14px) with forward occlusion and prominent shadows.
  - *Backline (Arcanum):* Stepped back away from the clash line (-6px to -10px).
  - *Scale Integrity:* Units maintain 100% equal size regardless of lane assignment (no artificial shrinking).
- **Inherent Line Traits:**
  - *Frontline:* Grants $+10\%$ Stagger/Poise Resistance; generates $+15\%$ Action Point accumulation upon receiving direct hits. Frontline units absorb direct melee targeting.
  - *Backline:* Grants $+15\%$ Skill Range/Accuracy; gains the **Guarded** buff (takes $-20\%$ damage from direct single-target ranged strikes while at least 1 allied Frontline unit remains functional). If all Frontline allies fall, Guarded drops and Backline units receive full direct melee aggression.

### 3.2 Deterministic Column Targeting Rules
Units resolve basic actions and single-target skills according to rigid geometric priority:
1. **Direct Column Target:** Attacks fire directly across into the opposing unit occupying the same column index (Col 1 $\rightarrow$ Col 1).
2. **Line Precedence:** If the target column has a unit in the Frontline, the Frontline unit absorbs the attack. If that column's Frontline is empty, the attack penetrates directly into the column's Backline unit.
3. **Adjacency Fallback:** If an entire opposing column is empty, targeting cascades to the immediate adjacent columns (e.g., Column 1 checks Column 2, then Column 3; Column 3 checks Columns 2 & 4 evenly) rather than leaping across the battlefield.

### 3.3 Speed-Tuning & Organic Anti-Cleave Counter-Play
- **Action Value Engine (30 Hz):** Simulation advances at 30 ticks/second. Units accumulate Action Points ($AP$) each tick based on Speed:
  $$AP_{tick} = BaseSPD \times (1 + \sum Modifier_{SPD})$$
  When a unit reaches $10,000\text{ AP}$, its action executes.
- **Pre-Battle Initiative Ribbon:** The deployment screen and live vertical edge track display the exact sequential order of upcoming actions across both squads. Players adjust Speed stats to engineer deliberate combo chains (e.g., Support buffs $\rightarrow$ Assassin strikes $\rightarrow$ Juggernaut staggers).
- **Organic Anti-Cleave (No Artificial Blanket Rules):** Rather than arbitrary global damage caps, speed-cleave counter-play is achieved through:
  - *Pre-Battle Column Positioning:* Placing high-armor Juggernauts directly in the column facing dangerous enemy Assassins.
  - *Archetype Passives:* E.g., Iron Footman's *Shield Wall* (caps single-strike burst damage taken), Sanguine Vanguard's *Enduring Sinew* (survives lethal hit once with immediate AP counter).
  - *Fast Alchemical Reaction Slips:* Using starting Focus to cast defensive intercepts (*Aegis Shell*, *Disrupting Cleave*) before enemy burst resolves.

### 3.4 Damage & Mitigation Formulas
- **Effective Health (EHP):**
  $$EHP = HP \times \left(1 + \frac{ARMOR}{100}\right) \times \left(1 + \frac{RESIST}{100}\right)$$
- **Physical Damage Reduction (PRR):**
  $$PRR = \frac{ARMOR}{ARMOR + 100 + (10 \times ATTACKER\_LEVEL)}$$
- **Total Damage Dealt:**
  $$Damage = (BaseATK \times SkillCoeff) \times (1 - PRR) \times (1 + CRIT\_MULT) - FlatAbsorb$$

---

## 4. Commander Profiles & Asymmetric "Rule-Breaking"

### 4.1 Physical Commander Placement & Faction Asymmetry Matrix
The Commander occupies 1 of the 5 squad slots on the field. Each Commander breaks default game parameters to express their faction's unique philosophy:

| Commander | Faction | Deck Limit | Hand Size | Starting / Max Focus | Focus Fill Rate | Unique Rule-Breaker Trait |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Lord Vladislav** | Crypt Stalkers | 12 Slips | 3 Slips | 2 / 6 Focus | 1 per 30 ticks (1.0s) | **Sanguine Sacrifice:** Can cast Tuning Slips using construct HP if Focus is insufficient. |
| **Lady Valeria** | Ash Legion | 10 Slips | 3 Slips | 3 / 7 Focus | 1 per 40 ticks (1.33s) | **Cold-Iron Bastion:** Slower fill, but higher starting/max Focus; Frontline grants $+25$ Armor and initial stagger immunity. |
| **Morrigan** | Calx Order | **20 Slips** | **4 Slips** | 3 / 5 Focus | **1 per 20 ticks (0.66s)** | **Rapid Sky-Chymist:** Huge 20-card magazine, 4-card hand, rapid Focus regeneration, but constructs have $-10\%$ base HP. |
| **Malakor** | Mire Coven | 14 Slips | 3 Slips | 1 / 8 Focus | Ramping | **Alchemical Fermentation:** Starts at 1 Focus with slow generation; generation permanently accelerates for each active Poison stack on the battlefield. |

### 4.2 Positional Commander Stance Auras
A Commander's physical placement dictates active leadership bonuses:
- **Lord Vladislav:**
  - *Frontline Stance:* Grants adjacent Frontline allies $+15\%$ Lifesteal on kinetic strikes.
  - *Backline Stance:* Reduces the Focus cost of all Bleed Tuning Slips by 1 (minimum 1 Focus floor).
- **Lady Valeria:**
  - *Frontline Stance (Bastion of Cold Iron):* Grants all allied Frontline units $+25$ Armor and total immunity to initial stagger knockback.
  - *Backline Stance:* Grants Backline units $+20\%$ shield absorption potency.
- **Morrigan:**
  - *Frontline Stance:* Unstable rift pulses deal damage to both adjacent allies and enemies on hit.
  - *Backline Stance (Tapestry of Fate):* Increases Action Point accumulation of all Backline allies by $+15\%$.
- **Malakor:**
  - *Frontline Stance:* Melee strikes inflict 2 stacks of Caustic Rot.
  - *Backline Stance:* Detonating poison stacks refunds 1 Focus to the alchemical pool.

### 4.3 Downed State ("Severed Resonance")
- **Inert Vessel:** When a Commander or unit reaches 0 HP, their token transitions into a grey stone plinth.
- **Aura Extinguishment:** Commander leadership auras deactivate immediately upon entering the downed state.
- **Throttled Focus:** Focus generation drops by 50% (e.g. 1 Focus per 60 ticks instead of 30 ticks).
- **Continuous Agency:** Tuning Slips remain fully playable, allowing players to cast revives or execute last-ditch counterplays.

### 4.4 Infused Vitae Revive Mechanics
- Restored health scales from the caster's Attack stat and Generational tier:
  $$Revived\_HP = (Caster\_ATK \times SkillCoeff) \times (1 + Caster\_Gen \times 0.15)$$
- **Awakening State:** Revived units gain a 6-tick (0.2s) invulnerability window, cleansed status debuffs, and an AP gauge reset to 0.
- **Soul Fracture:** Each revive during an encounter incurs a stacking $-20\%$ Max HP penalty to prevent infinite stall loops.

---

## 5. Gauntlet Mechanics, Codex & Tuning Slips

### 5.1 Deck Structure & Natural Gating
- **Deck Magazine Sizing:** Tailored to the Commander (Lady Valeria = 10; Vladislav = 12; Malakor = 14; Morrigan = 20).
- **Magazine Composition:**
  - *1 Apex Rite:* Climax spell. **No artificial timer locks**—naturally gated by a high cost (5 or 6 Focus). Players who pool Focus and play efficiently can unleash their Apex Rite as early as ~12–15 seconds into combat.
  - *Sovereign Slips (2–4):* High-impact tactical tools (hard interrupts, revives, board clears); strictly 1 copy each.
  - *Core Slips (Balance):* Reliable foundational cards; maximum 2 copies per card.
- **The Rule of Minimum Cost:** No modification, relic, or aura can reduce a Tuning Slip's cost below 1 Focus (unless designed natively as a 0-Focus cantrip).

---

## 6. Status Effects & Bespoke Boss Encounters

### 6.1 Status Effect Matrix
| Status ID | Type | Stacking | Effect Mechanics | Cleansable |
| :--- | :--- | :--- | :--- | :---: |
| **BLEED** | DoT Physical | Intensity (Max 10) | Deals $0.15 \times ATK$ physical damage/sec per stack. Ignores 30% Armor. | Yes |
| **BURND** | DoT Fire | Duration (Max 12s) | Deals $0.22 \times ATK$ fire damage/sec. Spreads on expiry; suppresses 100% healing. | Yes |
| **POISON** | DoT Nature | Intensity (Max 15) | Deals true damage/sec; decays target Attack and Speed by 2% per stack. | Yes |
| **STUN** | Hard CC | Overwrite | Freezes AP accumulation; drains current AP gauge by 25%. | No |
| **HASTE** | Buff | Duration | Increases BaseSPD by 35%. | Yes |
| **AEGIS SHIELD**| Buff | Intensity | Absorbs incoming damage. Expiration pulses 50% remaining shield as AoE damage. | No |

### 6.2 Bespoke Boss Encounter Design (No Generic Cookie-Cutter HP Phases)
Every major boss operates as a unique tactical puzzle rather than a generic HP-sponge:
- **Gorgoroth the Flayed (Pyre Synod - Slag Behemoth):**
  - *The Puzzle (Molten Armor):* Starts with 90% passive damage reduction.
  - *Mechanic:* Charges telegraphed terminal channels (*Hearth Cataclysm*). Striking him with high-poise stagger skills or water/chalk slips shatters his slag plates piece by piece, exposing vulnerable molten cores for massive critical windows.
- **Malakor, Father of Rot (Mire Coven):**
  - *The Puzzle (Spore Cauldrons):* Spawns petrified fungal cauldrons on the enemy backline that passively regenerate his health.
  - *Mechanic:* Players must execute column-penetrating attacks or card interrupts to shatter cauldrons before they rupture into room-wide caustic miasma.
- **The Calcified Titan (World Boss):**
  - *The Puzzle (Segmented Destruction):* Features targetable anatomical segments (Left Aegis Arm, Molten Great-Cleaver, Core Hearth). Destroying the shield arm permanently eliminates his guard, while sundering the cleaver stops terminal sweep attacks.

### 6.3 The Ashen Reckoning (Universal Soft Enrage)
- Skirmishes enter Reckoning at 1:30 (2,700 ticks); hard adjudication at 2:00 (3,600 ticks).
- Boss encounters enter Reckoning at 3:00 (5,400 ticks); terminal enrage at 4:00 (7,200 ticks).
- Modifiers during Reckoning: Damage dealt $\times 2.0$, healing received $-50\%$. Completing boss puzzle objectives resets the phase timer to Tick 0.

---

## 7. Progression Economy & The 6-Generation Crucible

### 7.1 Currencies & Reagents
- **Unbound Ash:** Soft mass currency earned from combat and recycling; spent to level base stats and enhance physical gear (+1 to +10).
- **Distilled Vitae:** Reagent fuel harvested from springs; spent for Crucible fusions and trait awakening.
- **Anima Slag (Target-Farmed Boss Reagents):** Dedicated drops (*Molten Brim-Slag*, *Virulent Bile-Cores*, *Phase-Fractured Glass*) used to forge unique keystone traits.

### 7.2 Deterministic 6-Generation Crucible ($32\times\text{ G1} = 1\times\text{ G6}$)
- **G1 (Thrall):** Level cap 20; Base Skill; 0 Plinth Sockets.
- **G2 (Hardened):** Level cap 30; Signature Skill unlocked.
- **G3 (Veteran):** Level cap 40; Unlocks Plinth Trait Socket 1.
- **G4 (Dread):** Level cap 50; Ultimate Burst unlocked.
- **G5 (Ascended):** Level cap 60; Unlocks Plinth Trait Socket 2; Apex Visual Form.
- **G6 (Pureblood Sovereign):** Level cap 70; Unlocks Plinth Trait Socket 3; Cataclysm Link.

### 7.3 Player Time Respect: Instant Extraction
Achieving a 3-star Flawless Clear (no casualties) on any resource crypt permanently unlocks **Instant Sweep / Extraction**, letting players bypass daily resource grinding and focus playtime on unsolved roguelite descents and trials.
