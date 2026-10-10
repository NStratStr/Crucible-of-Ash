# CRUCIBLE OF ASH: MINIATURE BATTLER
## Master Game Design Document v2.7 (Unified Production & World Logic Specification)

**Platform:** Mobile-First Hybrid (Flutter / Dart / Impeller; responsive 9:16 Portrait & 16:9 Landscape)  
**Simulation Engine:** Deterministic Fixed 30 Hz Speed-Tick Loop (Decoupled from Render Frames)  
**Aesthetic:** Dark Fantasy Grimdark / Living Mineral Tabletop Miniature Wargame  

---

## 1. Executive Summary & Core Pillars
*Crucible of Ash: Miniature Battler* is a dark fantasy, tactical autobattler designed for high-density strategic play across Mobile, Web, and Desktop runtimes. Players take the role of an Ash-Veined Sculptor, commanding squads of living-mineral tabletop miniatures within a physicalized 2.5D arena.

### Core Pillars
- **Flesh of Stone (Tabletop Metaphysics):** Units are not clunky steampunk robots or brittle cemetery statues; they are flexible, living mineral fibers saturated with pressurized, conductive Vitae. The circular plinth is their kinetic grounding seal burned into the earth.
- **Deterministic Spatial Simulation:** Combat resolves on continuous geometric physics planes using a fixed 30-ticks/sec timeline, explicit line-of-sight (LoS), dynamic bounding radii, and deterministic vector propagation.
- **Emergent Dynamic Fusion:** A 6-generation binary inheritance system (32× G1 = 1× G6) allows players to breed stats and graft socketable traits into bespoke hybrid miniatures with zero bricking risk.
- **Target-Farmed Progression & Ascensions:** An economy built on universal resources (Unbound Ash and Distilled Vitae) coupled with target-farmable boss reagents and a granular A1–A10 Ascension modifier stack.

---

## 2. World Cosmology & Metaphysical Foundations

### 2.1 The Great Rupture & The White Rain
- **The Living Marrow:** Vitae was the foundation of civilization—a hyper-conductive, crimson geological aquifer fluid powering imperial metallurgy, medical rejuvenation, and subterranean excavation golems.
- **The Rupture:** An alchemical accident intended to spark an artificial subterranean sun (the Undying Hearth) breached the mantle, superheating planetary Vitae reservoirs and calcifying bedrock into the stratosphere.
- **The White Rain:** The fallout condensed as caustic ash that swept the planet. 99% of humanity suffered instant pulmonary calcification—their internal fluids hardened into brittle, hollow stone husks whose trapped soul-embers wander the dust.
- **The Ash-Veined & The Sculptor's Curse:** A tiny fraction of miners and refinery alchemists bonded with the particulate. Their blood thickened into dark crimson Vitae. However, whenever an Ash-Veined Commander channels constructs, their own vascular tissue calcifies slightly. Commanders wage war in a desperate loop: securing deep-earth Vitae wells to power their apparatus and stave off complete petrification.

### 2.2 Metaphysics of Combat & Physicalized Plinths
- **Living Mineral Sinew:** Construct bodies flex and contract like petrified muscle.
- **Bleed & Lifesteal Logic:** "Bleeding" occurs when kinetic trauma shears a unit's outer mineral glaze, causing pressurized red Vitae to spray from internal vascular channels. Sanguine units ("Vampires") utilize porous, osmotic blades that draw fluid out of opposing chassis to lubricate their own seizing stone sinews.
- **Desiccated Ghouls:** Ghouls are abandoned constructs whose internal Vitae reservoirs have drained dry. Their mineral sinews have warped and seized like dried jerky, driving them into a predatory frenzy to crack open living units and scrape out congealed fluid.
- **The Plinth as Kinetic Grounding Seal:** Raw ash constructs naturally dissipate into dust. The circular plinth is a radiant boundary seal of downward Vitae tension burned into the dirt that grounds the construct’s mass into physical reality.

#### Faction Grounding Inscriptions:
- **Ash Legion:** Welded cold-iron rims on weathered fortress flagstone.
- **Crypt Stalkers:** Weeping arterial stone basins with creeping black moss.
- **Corrupted Beasts:** Trampled black earth with broken bone chips and toxic roots.
- **Occult Void Cult:** Obsidian discs etched with hovering, rift-glass violet runes.

### 2.3 The Commander’s Apparatus: Catalyst Key & Tuning Slips
- **The Alchemical Gauntlet & Catalyst Key:** Commanders do not haul multi-ton cauldrons. They wear an alchemical gauntlet housing the Catalyst Key—a clockwork spindle of volcanic glass, brass gears, and an imperial Vitae chamber. Pointing the Key into the ground causes ambient ash to violently condense around the plinth seal, manifesting a combat-ready construct in seconds.
- **Tuning Slips (The "Cards"):** Tactical commands are inscribed on thin plates of slate-foil, horn, or gold leaf etched with micro-runic circuits. Loading a slip into the gauntlet rail channels pressurized Vitae across the circuit into the unit's grounding seal.
- **Under-Rail Burn Pit:** Ejected, spent plates drop into the gauntlet’s under-rail Discard Pit to vent heat and cycle back into the draw feed.
- **Tactical Bullet-Time:** Dragging a Tuning Slip slows local simulation by 30% because the Commander is focusing their psychic tether through the aerial miasma to surgically direct their constructs.

---

## 3. Combat Engine Formulas & Targeting Hierarchy

### 3.1 Core Damage & Defense Formulas
- **Effective Health Calculation (EHP):**
  $$EHP = HP \times \left(1 + \frac{ARMOR}{100}\right) \times \left(1 + \frac{RESIST}{100}\right)$$
- **Physical Damage Reduction (PRR):**
  $$PRR = \frac{ARMOR}{ARMOR + 100 + (10 \times ATTACKER\_LEVEL)}$$
- **Elemental Resistance Reduction (ERR):**
  $$ERR = \frac{RESIST}{RESIST + 120}$$
- **Total Damage Output:**
  $$Damage = (BaseATK \times SkillCoeff) \times (1 - PRR) \times (1 + CRIT\_MULT) - FlatAbsorb$$

### 3.2 Action Speed & Turn Order
Turn execution utilizes an Action Value (AV) Accumulator Engine. Units accumulate Action Points (AP) each frame until reaching the Action Threshold ($AT = 10000$):
- $$AP_{tick} = BaseSPD \times (1 + \sum Modifier_{SPD})$$
- $$TicksToTurn = \frac{10000 - AP_{current}}{AP_{tick}}$$

### 3.3 Dynamic Targeting Hierarchy
When an action triggers, units evaluate targets based on an explicit 4-step filter:
1. **Hard Constraints:** Taunt/Provoke state override $\to$ Line-of-Sight Check (Raycast against static geometry) $\to$ Max Range Check ($Distance \le SkillRange + Radius_{target}$).
2. **Primary Priority Flag:** Selected via unit tactic setting (`Lowest_EHP_Absolute`, `Highest_Threat_Score`, `Cluster_Density_Max`, `Role_Class_Priority`: Healer > Mage > DPS > Tank).
3. **Tie-Breaker Metric:** Closeness to unit center mass ($Vector3.Distance$).
4. **Fallback:** Nearest valid enemy unit.

### 3.4 Mid-Battle Downed State & Revive Lifecycle ("Inert Vessel")
- **Inert Vessel State:** When HP reaches 0, the unit does not despawn. The miniature converts into an inert, desaturated grey stone plinth anchored to its slot. AP accumulation freezes to 0. It ceases to block line-of-sight for normal melee targets (enemies strike the Arcanum behind them), but remains an interactable spatial target for Necromancy, Corpse Detonation, or Revives.
- **Infused Vitae Revive Formula:** Restored health scales directly from the caster's Attack stat and Generational tier (G1–G6):
  $$Revived\_HP = (Caster\_ATK \times SkillCoeff) \times (1 + Caster\_Gen \times 0.15)$$
  Capped at target Max HP. Overflow vitality converts into a temporary golden Aegis Shield Ring equal to 50% of the excess.
- **Awakening State:** Revived units gain a 6-tick (0.2s) invulnerability grace window to prevent instant recleaving, have all previous debuffs cleansed, and reset their AP gauge to 0.
- **Soul Fracture Penalty:** Each time an individual unit is revived within a battle or descent run, it receives a stacking -20% Max HP penalty, preventing endless revive cycling.

---

## 4. Status Effect Matrix & In-Engine Compositing Stack
Status effects process in a deterministic order: Pre-Tick $\to$ Main Action $\to$ Post-Tick. Multipliers are additive within the same layer, multiplicative across layers.

| Status ID | Type | Stacking Type | Effect Mechanics | Cleansable |
| :--- | :--- | :--- | :--- | :--- |
| **BLEED** | DoT Physical | Intensity (Max 10) | Deals $0.15 \times ATK$ physical damage per second per stack. Shears mineral glaze, ignoring 30% Armor. | Yes |
| **BURN** | DoT Fire | Duration (Max 12s) | Deals $0.22 \times ATK$ fire damage per second. Spreads to units within 1.5m on expire. Suppresses 100% healing/reviving. | Yes |
| **FREEZE** | Hard CC | None | Unit cannot act. Physical hits shatter for 15% max HP bonus damage and end freeze. | Yes |
| **STUN** | Hard CC | Overwrite | Pauses AP Accumulation. Resets current AP frame by 25%. | No |
| **VULNERABLE** | Debuff | Refresh | Increases all incoming damage taken by 25%. | Yes |
| **HASTE** | Buff | Duration | Increases BaseSPD by 35%. | Yes |
| **SHIELD** | Buff | Intensity | Absorbs incoming damage. Expiration triggers AoE pulse dealing 50% remaining shield. | No |

### Procedural Compositing Rules (Zero Baked Assets)
- **Clean Master Sprites:** Miniatures are single neutral PNGs (character dominates 85% vertical space on circular plinth base).
- **Plinth Rim Pips:** Left arc renders Bleed notches; right arc renders Poison/Blight pips via Canvas `CustomPainter`.
- **Aegis Barrier:** Concentric gold radial ring tracks shield integrity.
- **Material Shaders:** Grayscale matrix for Stagger/Downed/Petrify; 45% opacity for Stealth.

---

## 5. Economy & The Crucible Progression Engine

### 5.1 Universal Economy (Two Currency Pillars)
- **Unbound Ash (Soft Currency / Mass):** Harvested from combat and scrapping; spent to level up base stats and forge/enhance physical Armature Relics.
- **Distilled Vitae (Reagent / Hydraulic Life-Pressure):** Harvested from subterranean wellheads; spent to power Crucible fusions, awaken Calcified Relics, and cast high-tier rites.

### 5.2 Summoning: Unsealing Calcified Relics
- **No Abstract Gacha Rarity:** All units enter the game at Generation 1 (G1) with zero baseline stat rarity gates. Every recruit has a viable trajectory toward becoming a G6 Sovereign.
- **The Discovery Loop:** Players unearth Calcified Relics and Sealed Memory Slips from crypts, nodes, and boss drops.
- **The Awakening Rite:** Inserting an unidentified relic into the Catalyst Key and pulsing it with Vitae strips away the calcified shell, reading the ancient combat frequency and flash-condensing the unit on the spot.

### 5.3 Deterministic 6-Generation Fusion Tree
Fusion combines duplicate units ($2^n$ binary tree, $32 \times G1 = 1 \times G6\ Sovereign$):
- `[ G1: Thrall / Feral ]` $\to$ Level Cap 20; Base Skill; 0 Plinth Sockets *(Requires 2x G1)*
- `[ G2: Hardened ]` $\to$ Level Cap 30; Signature Skill Unlocked *(Requires 2x G2)*
- `[ G3: Veteran ]` $\to$ Level Cap 40; Unlocks Plinth Socket 1 *(Requires 2x G3)*
- `[ G4: Dread ]` $\to$ Level Cap 50; Ultimate / Cooldown Burst Unlocked *(Requires 2x G4)*
- `[ G5: Ascended ]` $\to$ Level Cap 60; Unlocks Plinth Socket 2; Apex Sovereign Visual Form *(Requires 2x G5 + 1x Titan Basalt Core)*
- `[ G6: Pureblood Sovereign ]` $\to$ Level Cap 70; Unlocks Plinth Socket 3; Commander Cataclysm Link

**Zero Brick Risk:** Fusions never roll random baseline stats or overwrite traits with bad RNG. A G6 unit has an absolute, guaranteed stat ceiling.  
**Exponential Fusion Tax:**
$$Cost_{Ash} = 1000 \times (1.85)^{Generation}$$

**Auto-Synthesis & Trait Safety Locks:** A single-tap action in the Crucible rolls unlocked duplicate G1s and G2s into G3 veterans. Units dropping with rare bloodline traits receive a golden lock icon and are automatically excluded from auto-synthesis.

---

## 6. The Endgame Chase: Traits, Boss Slag & Armature Gear

### 6.1 Plinth Sockets & Trait Chiseling
- **Socket Progression:** Units unlock 1 to 3 trait sockets along their grounding ring as their Generation rank climbs (at G3, G5, and G6).
- **Trait Crafting & Upgrades:** Traits (e.g., Vampiric Sinew, Iron Thorns) are extracted by sacrificing donor units or refining boss materials into Inscribed Soul-Chisels. Traits start at Tier 1 and upgrade deterministically at camp using Ash and Vitae.
- **Modular Sockets with Friction:**
  - Socketing a trait: Free.
  - Overwriting/Destroying a trait: Free.
  - Clean Extraction: Removing a socketed trait to preserve it in inventory costs an alchemical solvent (Vitriol Salve) purchased from the Wandering Cartomancer, or an escalating Unbound Ash fee.

### 6.2 Target-Farmed Boss Reagents ("Anima Slag")
Bosses drop dedicated crafting reagents scaling with Ascension tiers (A1–A10):
- **Gorgoroth the Flayed:** Yields *Molten Brim-Slag* $\to$ Crafts Vanguard armor hardening, thorns reflection, and fire bursts.
- **Valok the Colossus:** Yields *Virulent Bile-Cores* $\to$ Crafts corrosion, contagion spread, and healing suppression traits.
- **Lady Valeria (Defiled):** Yields *Sun-Scorched Filigree* $\to$ Crafts Aegis shield bursts, cleanses, and revive accelerators.
- **Void Rift Sentinels:** Yields *Phase-Fractured Glass* $\to$ Crafts armor penetration, AP siphon, and critical cascades.

### 6.3 Physical Armature Relics (3 Gear Slots)
In addition to plinth trait sockets, constructs equip three physical items anchored to their mineral frame:
- **Weapon Edge / Catalyst Tip:** Enhances Base ATK and Critical Multipliers.
- **Core Plating / Harness:** Enhances Armor, Resistance, and Max HP.
- **Kinetic Gyro / Piston Joint:** Enhances Speed and Action Point accumulation rate.  
Gear is forged from campaign salvage and enhanced from +1 to +10 using Unbound Ash.

---

## 7. Operational Dynamics & "The Ashen Reckoning"

### 7.1 Encounter Pacing & Enrage Engine
| Encounter Tier | Standard Phase | Warning Chime | Ashen Reckoning (2.0× Dmg, -50% Heals) | Terminal Collapse (Escalating Dmg, No Revives) | Hard Cap / Wipe |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Skirmish / Arena** | 0:00 – 1:15 | 1:15 (2,250 ticks) | 1:30 (2,700 ticks) | 1:45 (3,150 ticks) | 2:00 (3,600 ticks) — Highest HP Wins |
| **Elite / Mini-Boss** | 0:00 – 1:45 | 1:45 (3,150 ticks) | 2:00 (3,600 ticks) | 2:15 (4,050 ticks) | 2:30 (4,500 ticks) — Highest HP Wins |
| **Boss / World Titan** | 0:00 – 2:30 | 2:30 (4,500 ticks) | 3:00 (5,400 ticks) | 3:30 (6,300 ticks) | 4:00 (7,200 ticks) — Titan Enrage Wipe |

### 7.2 Multi-Phase Boss Timer Resets
Crossing a major boss phase threshold (e.g., 66% HP, 33% HP) completely resets the phase clock to Tick 0 and clears active Reckoning damage/healing penalties. This ensures players are not penalized during early phases for playing defensively.

### 7.3 Mobile Ergonomics & Technical Guardrails
- **Hitbox Inflation:** Miniatures have an invisible +25% touch boundary padding around their plinth discs to eliminate drag-and-drop misfires.
- **Thumb Reach Optimization:** All primary interactive elements (Tuning Slips Carousel, Burn Pit, Focus Bar) are strictly anchored within the bottom 35% of the mobile screen.
- **Target Failsafe:** If a target dies while hovering a card during bullet-time, the card snaps safely back to hand with 0 Focus consumed.
- **Deterministic Replay Serialization:** Match inputs are recorded into compact 20-byte action blobs for 2 KB server validation, anti-cheat, and instant mid-battle crash recovery.
- **Offline Determinism:** Matches run entirely locally without requiring network connectivity; results sync lazily upon reconnection.

---

## 8. The Minimum Viable Product (MVP) Specification
The MVP proves the core thesis: *Does a 30-tick deterministic living-mineral autobattler with real-time Tuning Slip agency feel compelling on mobile?*

### 8.1 MVP Feature Boundary
- **Engine Core:** Fixed 30-Tick deterministic runner, 5v5 isometric plane (3 Vanguard, 2 Arcanum), hyperbolic armor mitigation, Downed/Revive lifecycle, and the Ashen Reckoning sudden death clock.
- **Miniature Roster (10 Units Only):**
  - **Ash Legion (Player):** Iron Footman (Juggernaut), Grave Duelist (Assassin), Iron Arbalest (Marksman), Sun-Scorched Cleric (Occultist), Field Medicus (Support).
  - **Crypt Stalkers (Enemy):** Rotting Husk (Juggernaut), Grave Ghoul (Assassin), Bone Archer (Marksman), Blight Necromancer (Occultist), Blood Alchemist (Support).
- **Commander & Grimoire (Lord Vladislav Only):** 6 Tuning Slips (Rend Flesh, Iron Bulwark, Exsanguinating Strike, Sanguine Revival, Disrupting Cleave, Blood Boil). Max 6 Focus pool.
- **Crucible Micro-Loop:** Local SQLite database supporting duplicate fusion up to G3 (G1 $\to$ G2 $\to$ G3). G4–G6 and trait grafting deferred.
- **Encounter Slice:** Single 3-wave skirmish map proving initiative ticks, card drags, bullet-time, and stagger interrupts.

---

## 9. Post-MVP Expansion Recipe

### Recipe 1 — Lineage & Crucible Altar Expansion:
- Unlock G4 Dread, G5 Ascended, and G6 Pureblood Sovereign tiers.
- Implement Trait Chiseling Altar (socketing donor passives into G3, G5, and G6 plinth rings).
- Implement Auto-Synthesis button and Rare Bloodline Trait safety locks.

### Recipe 2 — Faction & Commander Roster:
- Introduce Faction 3: Corrupted Beasts (Predator bleed & enrage passives).
- Introduce Faction 4: Occult Void Cult (Phase warp & gravity pulls).
- Add 5 Neutral Mercenary units.
- Implement Commanders Lady Valeria, Malakor, and Morrigan with full 30-slip Grimoire pools.

### Recipe 3 — Roguelite Descent & Armature Gear:
- Branching DAG map crawler (Encounter, Elite, Thrall Pen, Altar, Merchant).
- 3 Armature Relic gear slots (Weapon Edge, Core Plating, Kinetic Gyro) with +1 to +10 enhancement.
- The 10-level Ascension Matrix (A1–A10 Ordeals of the Ash).

### Recipe 4 — Competitive & Social Modes:
- Asynchronous Brigade Arena (PvP Option A) with weighted Defensive AI and 30-tick human reaction delays.
- World Titan communal sieges (Gorgoroth, Valok, Lady Valeria with multi-phase timer resets).
- Headless server validation of 20-byte/action binary replay logs.

---

## 10. Two-Year Live-Ops & World Strata Roadmap (2026 – 2028)
```
2026                          2027                                2028
Q4 ──────────► Q1 ──────────► Q2 ──────────► Q3 ──────────► Q4 ───► Q1 ──────────► Q2
[MVP & Alpha]  [Launch v1.0]  [Season 1]     [Season 2]     [Exp 1] [Season 4]     [Exp 2]
               40 Units       Corrupted      Void Rift      Abyssal New Factions   Guild Wars
               Campaign Ch 1-3 Beasts        Siege Titan    Depths  & Co-Op Raid   & Tourneys
```

### 10.1 Four-Layer World Strata Architecture
1. **The Aether-Vault (Sky):** Anti-gravity floating islands unaffected by the White Rain. (Aesthetic: feather, cloud-quartz, celestial brass).
2. **The Ash Basin (Surface):** The current theater of war (Ash Legion, Crypt Stalkers, Corrupted Beasts, Void Cult).
3. **The Sunken Trenches (Subterranean):** Underground oceans and flooded cathedrals beneath the crust. (Aesthetic: coral, drowned stone, abyssal brine).
4. **The World Forge (Mantle):** Superheated planetary core where the Hearth ruptured. (Aesthetic: molten constructs, basalt automatons, liquid slag).

### 10.2 Production Schedule
- **Q4 2026 (MVP Alpha & Closed Beta):** Playable 10-unit slice (Ash Legion vs. Crypt Stalkers, Lord Vladislav, 6 Tuning Slips). SQLite persistence, haptics, TestFlight / Android track (50 players). Target: >85% match completion in 45–75s.
- **Q1 2027 (Commercial Launch v1.0):** Full 40 player miniatures across all 4 Great Factions. 4 Commanders with complete decks. Full 6-Gen Crucible fusion & trait grafting. Campaign Chapters 1–3, Ascensions A1–A5. Battle Pass: Tithe of the Fallen.
- **Q2 2027 (Season 1: Rise of the Gore-Tusk):** Corrupted Beasts master questline. 3 Primal Mercenaries. World Titan: Valok the Carrion Colossus with phase resets. Launch Asynchronous Brigade Arena (PvP Option A). Ascensions A6–A8.
- **Q3 2027 (Season 2: Void Incursion):** Commander Release: The Architect of the Rift. 4 Void Cult specialists. Ascensions A9–A10 (Sovereign's Gaze). Guild contribution damage tracks for World Titan sieges.
- **Q4 2027 (Major Expansion 1: Sunken Crypts of Acheron v2.0):** Faction 5: The Abyssal Tide (10 new miniatures in the Sunken Trenches). Multi-tile Titan: Leviathan of the Deep Plinth. Permanent Commander relic crafting. Replay player for 20-byte logs.
- **Q1 2028 (Season 3: The Iron Crusade):** Ash Legion sub-lineage (Sunfire Templars). Commander: Grand Inquisitor Faust. Synchronous Friendly Duels via deterministic rollback engine.
- **Q2 2028 (Season 4: Eldritch Eclipse):** Co-Op Raid Nodes (two players command 3 units each on an ultra-wide battlefield). 5 Eldritch Mercenaries. Custom Plinth Forge cosmetic crafting system.
- **Q3 2028 (Major Expansion 2: Cataclysm Sovereign v3.0):** Faction 6: The Infernus Dominion (10 miniatures in the World Forge). Infinite seasonal delve mode (Ascensions A11–A15). Global Championship Arena with draft/ban phases.
