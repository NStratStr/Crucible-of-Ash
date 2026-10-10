# CRUCIBLE OF ASH: MINIATURE BATTLER
## Master Game Design Document v2.8 (Unified Implementation Specification)

**Engine / Runtime:** Fixed 30 Hz Deterministic Simulation Loop (Dart) decoupled from Flutter / Impeller presentation  
**Target Viewports:** Responsive 9:16 Mobile Portrait primary (390×844 logical px); 16:9 Landscape adaptable  
**Aesthetic Metaphor:** Dark Fantasy / Living Mineral Tabletop Miniature Wargame on physicalized kinetic plinths  

---

## 1. Executive Summary & Core Pillars
*Crucible of Ash: Miniature Battler* is a tactical roguelite autobattler bridging deterministic spatial simulation with real-time card command agency.

- **The Arch-Sculptor & The Living Mineral:** The player is an off-board Ash-Veined Arch-Sculptor commanding living mineral constructs bound to physical reality by kinetic plinth grounding seals.
- **30-Tick Mathematical Determinism:** Combat resolves on continuous geometric physics planes using explicit line-of-sight (LoS), dynamic bounding radii, and deterministic vector propagation at 30 ticks/sec.
- **Emergent Dynamic Fusion:** A 6-generation binary inheritance system ($32 \times \text{G1} = 1 \times \text{G6}$) allows players to breed stats and graft socketable traits with zero RNG bricking risk.
- **Target-Farmed Progression & Ascensions:** Progression centers on universal currencies (Unbound Ash and Distilled Vitae) coupled with target-farmable boss reagents and a granular A1–A10 Ascension modifier stack.

---

## 2. World Logic & Metaphysical Foundations

### 2.1 The Great Rupture & The White Rain
- **The Living Marrow:** Vitae was the foundation of imperial civilization—a hyper-conductive, crimson geological aquifer fluid powering metallurgy, medicine, and deep-mantle golems.
- **The Cataclysm:** An attempt to ignite an artificial subterranean sun (The Undying Hearth) ruptured the mantle, superheating planetary Vitae aquifers and calcifying bedrock into the upper atmosphere.
- **The White Rain:** The fallout condensed as caustic ash, instantly calcifying 99% of humanity into brittle stone husks whose soul-embers wander the wasteland.
- **The Ash-Veined & The Sculptor's Curse:** A tiny fraction of refinery alchemists and miners bonded with the fallout, their blood thickening into conductive dark crimson Vitae. However, channeling constructs calcifies their own vascular lining over time, locking commanders into a survival loop of securing fresh Vitae wells to stave off petrification.

### 2.2 Metaphysics of Combat & The Plinth Seal
- **Flesh of Stone:** Constructs are mineral fibers saturated with pressurized Vitae that flex and contract like petrified muscle.
- **Bleed & Lifesteal Logic:** Kinetic strikes shear outer mineral glaze, causing pressurized red Vitae to leak from internal vascular channels (Bleed). Sanguine units ("vampires") wield porous osmotic blades siphoning pressurized fluid on hit to lubricate their own seizing stone sinews.
- **Desiccated Ghouls:** Abandoned constructs whose internal Vitae reservoirs ran dry, warping their mineral sinews like dried jerky and driving them into a predatory frenzy to scrape congealed fluid from fallen units.
- **The Plinth as Kinetic Grounding Seal:** Construct ash naturally wants to dissipate back to dust. The circular plinth is a downward radiant field of pressurized Vitae and tension burned into the earth that anchors the construct into physical space.

#### Faction Grounding Inscriptions:
- **Ash Legion:** Welded cold-iron bands on fortress flagstone.
- **Crypt Stalkers:** Weeping arterial stone basins with black moss.
- **Corrupted Beasts:** Trampled black earth with bone shards and roots.
- **Occult Void Cult:** Hovering rift-glass obsidian with violet runes.

### 2.3 The Commander’s Apparatus: Catalyst Key & Tuning Slips
- **The Alchemical Gauntlet:** The Arch-Sculptor wears an alchemical gauntlet housing the Catalyst Key—a clockwork spindle of volcanic glass, brass gears, and an imperial Vitae chamber. Pointing the key into the dirt condenses ambient ash around a plinth seal into a combat-ready construct in seconds.
- **Tuning Slips (The "Cards"):** Tactical commands are inscribed on thin plates of slate-foil, horn, or gold leaf etched with micro-circuits. Inserting a slip into the gauntlet rail channels pressurized Vitae into a construct's grounding seal.
- **Under-Rail Burn Pit:** Spent slips are ejected into the gauntlet’s under-rail Burn Pit to vent heat and recycle into the draw feed.
- **Tactical Bullet-Time:** Dragging a Tuning Slip slows local simulation by 30% as the Arch-Sculptor focuses their psychic tether across the miasma.

---

## 3. Combat Engine Formulas & Formation Systems

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
Turn execution utilizes an Action Value (AV) Accumulator Engine. Units accumulate Action Points ($AP$) each frame until reaching the Action Threshold ($AT = 10000$):
- $$AP_{tick} = BaseSPD \times (1 + \sum Modifier_{SPD})$$
- $$TicksToTurn = \frac{10000 - AP_{current}}{AP_{tick}}$$

### 3.3 Dynamic Targeting Hierarchy
When an action triggers, units evaluate targets based on an explicit 4-step filter:
1. **Hard Constraints:** Taunt/Provoke override $\to$ Line-of-Sight Check (Raycast against static geometry) $\to$ Max Range Check ($Distance \le SkillRange + Radius_{target}$).
2. **Primary Priority Flag:** Selected via unit tactic setting (`Lowest_EHP_Absolute`, `Highest_Threat_Score`, `Cluster_Density_Max`, `Role_Class_Priority`: Healer > Mage > DPS > Tank).
3. **Tie-Breaker Metric:** Closeness to unit center mass ($Vector3.Distance$).
4. **Fallback:** Nearest valid enemy unit.

### 3.4 Formation Customization & Positional Modifiers
Squads consist of 5 physical units on the board: 1 Commander + 4 Construct Squad Mates. Players have full tactical freedom to place each unit into the Frontline or Backline:
- **Visual Offset:** Frontline units render pushed forward (+35 logical px toward the clash line) with larger drop shadows; Backline units render stepped back (-35 logical px).
- **Frontline Slot Modifiers:** Grants $+10\%$ Stagger Resistance and $+15\%$ Action Point accumulation upon taking direct hits. Frontline units absorb melee aggro by default.
- **Backline Slot Modifiers:** Grants $+15\%$ Skill Range/Accuracy and the **Guarded** buff (takes $-20\%$ damage from direct ranged single-target attacks as long as at least 1 allied Frontline unit remains standing). If no Frontline units are active, Backline units lose Guarded and take full direct melee aggression.

### 3.5 Physical Commander, Leadership Auras & Downed Resonance
- **The Commander as a Board Unit:** The Commander occupies 1 of the 5 squad slots, acting on their own initiative gauge while radiating an inherent Leadership Aura and providing the 10 Tuning Slips loaded into the Gauntlet.
- **Specific Aura Lane Requirements:** Leadership auras possess hard-coded lane requirements:
  - **Front-Locked Auras (e.g., Lady Valeria - "Bastion of Cold Iron"):** Active only when stationed in the Frontline ($+25$ Armor to frontline allies and immunity to initial stagger knockback). Deactivates if moved to the Backline.
  - **Back-Locked Auras (e.g., Morrigan - "Tapestry of Fate"):** Active only when stationed in the Backline ($+15\%$ AP accumulation rate to backline allies). Deactivates if pushed to the Frontline.
  - **Positional Vector Auras (e.g., Lord Vladislav - "Vampiric Conduit"):** Frontline placement grants adjacent frontline allies $+15\%$ Lifesteal; Backline placement reduces the Focus cost of all Bleed Tuning Slips by 1 (minimum 1).
- **Commander Downed State ("Severed Resonance"):**
  - When the Commander reaches 0 HP, their token transitions into an Inert Vessel (grey stone plinth).
  - Their Leadership Aura extinguishes immediately.
  - Focus generation drops by 50% (1 Focus per 60 ticks instead of 30 ticks).
  - **No Hard Lockout:** Tuning Slips remain accessible, giving the Arch-Sculptor the choice to pool Focus for an emergency revive order or execute a final burst attack.

### 3.6 Downed State & Revive Lifecycle ("Inert Vessel")
- **Inert Vessel State:** When a unit's HP reaches 0, it does not despawn. The miniature converts into an inert, desaturated grey stone plinth anchored to its slot. AP accumulation freezes to 0. It ceases to block line-of-sight for normal melee targets (enemies strike the unit behind them), but remains an interactable spatial target for Necromancy, Corpse Detonation, or Revives.
- **Infused Vitae Revive Formula:** Restored health scales directly from the caster's Attack stat and Generational tier (G1–G6):
  $$Revived\_HP = (Caster\_ATK \times SkillCoeff) \times (1 + Caster\_Gen \times 0.15)$$
  Capped at target Max HP. Overflow vitality converts into an Aegis Shield Ring equal to 50% of the excess.
- **Awakening State:** Revived units gain a 6-tick (0.2s) invulnerability grace window to prevent instant recleaving, have all previous debuffs cleansed, and reset their AP gauge to 0.
- **Soul Fracture Penalty:** Each time an individual unit is revived within a battle or descent run, it receives a stacking -20% Max HP penalty, preventing endless revive cycling.

---

## 4. Status Effect Matrix & In-Engine Compositing Stack
Status effects process in deterministic order: Pre-Tick $\to$ Main Action $\to$ Post-Tick. Multipliers are additive within the same layer, multiplicative across layers.

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
- **Plinth Rim Pips:** Left arc renders Bleed notches; right arc renders Poison pips via Canvas `CustomPainter`.
- **Aegis Barrier:** Concentric gold radial ring tracks shield integrity.
- **Material Shaders:** Grayscale matrix for Stagger/Downed/Petrify; 45% opacity for Stealth.

---

## 5. Gauntlet Mechanics & Tuning Slips
- **Focus Engine:** The Gauntlet holds a base pool of 6 Focus. Focus generates at 1 point per 30 global logic ticks (reduced to 1 point per 60 ticks if the Commander is downed).
- **Hand Capacity & Burn Pit:** Hand capacity is fixed at 3 active Tuning Slips. Dragging an unwanted slip to the bottom-right Burn Pit costs 0 Focus and draws a replacement after a 6-tick (0.2s) safety cooldown.
- **Deck Reshuffle:** When the slip deck empties, the discard pile recycles instantly with zero resource penalty.
- **Target Failsafe:** If a target unit dies while hovering a card during bullet-time, the card snaps safely back to hand with 0 Focus consumed.

---

## 6. Economy & The Crucible Progression Engine

### 6.1 Universal Economy (Two Currency Pillars)
- **Unbound Ash (Soft Currency / Mass):** Harvested from combat and scrapping; spent to level up base stats and forge/enhance physical Armature Relics.
- **Distilled Vitae (Reagent / Hydraulic Life-Pressure):** Harvested from subterranean wellheads; spent to power Crucible fusions, awaken Calcified Relics, and cast high-tier rites.

### 6.2 Deterministic 6-Generation Fusion Tree
Fusion combines duplicate units ($2^n$ binary tree, $32 \times \text{G1} = 1 \times \text{G6 Sovereign}$):
```
[ G1: Thrall / Feral ] ────► Level Cap 20; Base Skill; 0 Plinth Sockets
       │ (Requires 2x G1)
[ G2: Hardened ] ──────────► Level Cap 30; Signature Skill Unlocked
       │ (Requires 2x G2)
[ G3: Veteran ] ───────────► Level Cap 40; Unlocks Plinth Socket 1
       │ (Requires 2x G3)
[ G4: Dread ] ─────────────► Level Cap 50; Ultimate / Cooldown Burst Unlocked
       │ (Requires 2x G4)
[ G5: Ascended ] ──────────► Level Cap 60; Unlocks Plinth Socket 2; Apex Sovereign Visual Form
       │ (Requires 2x G5 + 1x Titan Basalt Core)
[ G6: Pureblood Sovereign ]► Level Cap 70; Unlocks Plinth Socket 3; Commander Cataclysm Link
```
- **Zero Brick Risk:** Fusions never roll random baseline stats or overwrite traits with bad RNG. A G6 unit has an absolute, guaranteed stat ceiling.
- **Exponential Fusion Tax:**
  $$Cost_{Ash} = 1000 \times (1.85)^{Generation}$$
- **Auto-Synthesis & Trait Safety Locks:** Single-tap action in the Crucible rolls unlocked duplicate G1s and G2s into G3 veterans. Units with rare bloodline traits receive a golden lock icon and are automatically excluded from auto-synthesis.

---

## 7. The Endgame Chase: Traits, Boss Slag & Armature Gear

### 7.1 Plinth Sockets & Trait Chiseling
- **Socket Progression:** Units unlock 1 to 3 trait sockets along their grounding ring as their Generation rank climbs (at G3, G5, and G6).
- **Trait Crafting:** Traits (e.g., Vampiric Sinew, Iron Thorns) are extracted by sacrificing donor units or refining boss materials into Inscribed Soul-Chisels.
- **Modular Friction:** Socketing and overwriting traits is free. Clean extraction (preserving the trait item in inventory) requires Vitriol Salve from the Wandering Cartomancer or an escalating Ash fee.

### 7.2 Target-Farmed Boss Reagents ("Anima Slag")
- **Gorgoroth the Flayed:** Yields *Molten Brim-Slag* $\to$ Crafts Vanguard armor hardening, thorns reflection, and fire bursts.
- **Valok the Colossus:** Yields *Virulent Bile-Cores* $\to$ Crafts corrosion, contagion spread, and healing suppression traits.
- **Lady Valeria (Defiled):** Yields *Sun-Scorched Filigree* $\to$ Crafts Aegis shield bursts, cleanses, and revive accelerators.
- **Void Rift Sentinels:** Yields *Phase-Fractured Glass* $\to$ Crafts armor penetration, AP siphon, and critical cascades.

### 7.3 Physical Armature Relics (3 Gear Slots)
In addition to plinth trait sockets, constructs equip three physical items anchored to their mineral frame:
- **Weapon Edge / Catalyst Tip:** Enhances Base ATK and Critical Multipliers.
- **Core Plating / Harness:** Enhances Armor, Resistance, and Max HP.
- **Kinetic Gyro / Piston Joint:** Enhances Speed and Action Point accumulation rate.  
Gear is forged from campaign salvage and enhanced from +1 to +10 using Unbound Ash.

---

## 8. Operational Dynamics & "The Ashen Reckoning"

### 8.1 Encounter Pacing & Enrage Engine
| Encounter Tier | Standard Phase | Warning Chime | Ashen Reckoning (2.0× Dmg, -50% Heals) | Terminal Collapse (Escalating Dmg, No Revives) | Hard Cap / Wipe |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Skirmish / Arena** | 0:00 – 1:15 | 1:15 (2,250 ticks) | 1:30 (2,700 ticks) | 1:45 (3,150 ticks) | 2:00 (3,600 ticks) — Highest HP Wins |
| **Elite / Mini-Boss** | 0:00 – 1:45 | 1:45 (3,150 ticks) | 2:00 (3,600 ticks) | 2:15 (4,050 ticks) | 2:30 (4,500 ticks) — Highest HP Wins |
| **Boss / World Titan** | 0:00 – 2:30 | 2:30 (4,500 ticks) | 3:00 (5,400 ticks) | 3:30 (6,300 ticks) | 4:00 (7,200 ticks) — Titan Enrage Wipe |

### 8.2 Multi-Phase Boss Timer Resets
Crossing a major boss phase threshold (e.g., 66% HP, 33% HP) completely resets the phase clock to Tick 0 and clears active Reckoning damage/healing penalties. This ensures players are not penalized during early phases for playing defensively.

### 8.3 Mobile Ergonomics & Technical Guardrails
- **Hitbox Inflation:** Miniatures have an invisible +25% touch boundary padding around their plinth discs to eliminate drag-and-drop misfires.
- **Thumb Reach Optimization:** All primary interactive elements (Tuning Slips Carousel, Burn Pit, Focus Bar) are strictly anchored within the bottom 35% of the mobile screen.
- **Deterministic Replay Serialization:** Match inputs are recorded into compact 20-byte action blobs for 2 KB server validation, anti-cheat, and instant mid-battle crash recovery.
- **Offline Determinism:** Matches run entirely locally without requiring network connectivity; results sync lazily upon reconnection.

---

## 9. The Minimum Viable Product (MVP) Specification
The MVP validates that the 30-tick deterministic living-mineral autobattler with real-time Tuning Slip agency feels responsive and strategically compelling on mobile.

### 9.1 In-Scope for MVP
- **Deterministic Engine:** Fixed 30 Hz simulation runner (`simulation_runner.dart`), hyperbolic armor mitigation, Downing/Revive lifecycle (Infused Vitae), and Ashen Reckoning match timer.
- **Plinth Visuals & Depth Offset:** Flutter presentation layer with procedural `CustomPainter` plinth boundary rings, greyscale downed shaders, and dynamic Frontline/Backline depth offset (+35px / -35px).
- **Squad Composition (10 Miniatures Total):**
  - **Ash Legion:** Lord Vladislav (Commander, Frontline Lifesteal / Backline Bleed Cost Aura), Iron Footman (Juggernaut), Grave Duelist (Assassin), Iron Arbalest (Marksman), Field Medicus (Support).
  - **Crypt Stalkers (Enemy Encounter):** Rotting Husk (Juggernaut), Grave Ghoul (Assassin), Bone Archer (Marksman), Blight Necromancer (Occultist), Blood Alchemist (Support).
- **Gauntlet Deck:** 6 Vladislav Tuning Slips (Rend Flesh, Iron Bulwark, Exsanguinating Strike, Sanguine Revival, Disrupting Cleave, Blood Boil), 3-slip carousel, 30% Bullet-Time, and 0-Focus Burn Pit.
- **Micro-Crucible:** SQLite persistence supporting duplicate fusions up to G3 (G1 $\to$ G2 $\to$ G3).
- **Encounter Slice:** 3-wave skirmish demonstrating speed ticks, stagger interrupts, line positioning, and boss pacing.

### 9.2 Deferred to Post-MVP Recipes
- 3-Slot Armature Relic gear system (Weapon, Core, Gyro).
- Plinth Trait Chiseling & Solvent extraction fees.
- Boss Anima Slag crafting materials.
- G4 to G6 Sovereign forms and full 63-unit roster.
- Asynchronous Brigade Arena and communal World Titan sieges.

---

## 10. Post-MVP Expansion Recipe
- **Recipe 1 — Lineage & Crucible Altar Expansion:** Unlock G4–G6 tiers, Trait Chiseling Altar, and Auto-Synthesis with Trait Locks.
- **Recipe 2 — Faction & Commander Roster:** Add Corrupted Beasts, Occult Void Cult, 5 Mercenaries, and Commanders Lady Valeria, Malakor, and Morrigan.
- **Recipe 3 — Roguelite Descent & Armature Gear:** Branching DAG map crawler, 3 Armature Relic gear slots, and A1–A10 Ascension Matrix.
- **Recipe 4 — Competitive & Social Modes:** Asynchronous Brigade Arena (PvP Option A) with weighted Defensive AI, World Titan communal sieges with phase resets, and headless replay validation.

---

## 11. Two-Year Live-Ops & World Strata Roadmap (2026 – 2028)

### 11.1 Four-Layer World Strata
- **The Aether-Vault (Sky):** Anti-gravity floating islands unaffected by the White Rain. (Feather, cloud-quartz, celestial brass).
- **The Ash Basin (Surface):** The current theater of war (Ash Legion, Crypt Stalkers, Corrupted Beasts, Void Cult).
- **The Sunken Trenches (Subterranean):** Flooded cathedrals beneath the crust. (Coral, drowned stone, abyssal brine).
- **The World Forge (Mantle):** Superheated planetary core where the Hearth ruptured. (Molten constructs, basalt automatons, liquid slag).

### 11.2 Milestone Schedule
- **Q4 2026 (MVP Alpha & Closed Beta):** Playable 10-unit slice (Ash Legion vs. Crypt Stalkers, Lord Vladislav, 6 Slips). SQLite persistence, haptics, TestFlight / Android track (50 players).
- **Q1 2027 (Commercial Launch v1.0):** Full 40 player miniatures across 4 Factions. 4 Commanders. Full 6-Gen Crucible fusion & trait grafting. Campaign Chapters 1–3, Ascensions A1–A5. Battle Pass: Tithe of the Fallen.
- **Q2 2027 (Season 1: Rise of the Gore-Tusk):** Corrupted Beasts questline. 3 Mercenaries. World Titan: Valok the Colossus. Asynchronous Brigade Arena (PvP Option A). Ascensions A6–A8.
- **Q3 2027 (Season 2: Void Incursion):** Commander: The Architect of the Rift. 4 Void Cult units. Ascensions A9–A10. Guild Titan contribution tracks.
- **Q4 2027 (Major Expansion 1: Sunken Crypts of Acheron v2.0):** Faction 5: The Abyssal Tide (10 units). Multi-tile Titan: Leviathan of the Deep Plinth. Permanent relic crafting. Replay player.
- **Q1 2028 (Season 3: The Iron Crusade):** Ash Legion Sunfire Templars. Commander: Grand Inquisitor Faust. Synchronous Friendly Duels via deterministic rollback engine.
- **Q2 2028 (Season 4: Eldritch Eclipse):** Co-Op Raid Nodes (two players command 3 units each). 5 Eldritch Mercenaries. Custom Plinth Forge.
- **Q3 2028 (Major Expansion 2: Cataclysm Sovereign v3.0):** Faction 6: The Infernus Dominion (10 units). Infinite delve mode (Ascensions A11–A15). Global Championship Arena.

---

## 12. Complete 63-Miniature Roster Manifest

### 12.1 Ash Legion (Player Faction - Cold Iron & Sunfire)
- **Iron Footman $\to$ Lord Justiciar (Juggernaut):** Frontline bulwark; Shield Slam deals physical damage equal to $150\%$ current Armor and inflicts +15 Stagger.
- **Grave Duelist $\to$ Ashen Inquisitor (Assassin):** High-speed duelist; Riposte enters parry stance for 10 ticks, countering incoming physical strikes for $200\%$ critical damage.
- **Iron Arbalest $\to$ Siege Arbalest Prime (Marksman):** Column sniper; Piercing Quarrel hits primary target and penetrates for $60\%$ damage to the unit directly behind.
- **Sun-Scorched Cleric $\to$ Solar Hierophant (Occultist):** Area debuffer; Purifying Censer bathes the target row in searing ash, stripping $30\%$ Armor for 20 ticks.
- **Field Medicus $\to$ Sunlight Banneret (Support):** Combat reviver; Triage Rebirth heals or revives an allied Inert Vessel using the Infused Vitae formula.

### 12.2 Crypt Stalkers (Player Faction - Obsidian & Vampiric Blood)
- **Rotting Husk $\to$ Grave Titan (Juggernaut):** Desiccated tank; Tombstone Slam deals blunt kinetic damage and applies a 15-tick Slow ($-30\%$ Speed).
- **Grave Ghoul $\to$ Ashen Strigoi Lord (Assassin):** Sanguine skirmisher; Flesh Tear applies 2 Bleed stacks and leeches $50\%$ of damage dealt as health.
- **Bone Archer $\to$ Wraith Sniper (Marksman):** Long-range sniper; Splinter Arrow hits a single target and splinters bone shards to adjacent allies.
- **Blight Necromancer $\to$ Lich Dominus (Occultist):** Attrition caster; Life Leech channels for 15 ticks, draining 50 HP per tick to distribute across damaged allies.
- **Blood Alchemist $\to$ Sanguine Priestess (Support):** Vitae catalyst; Sanguine Transfusion sacrifices 10% current HP to grant a 300 HP Aegis Shield to the lowest-health ally.

### 12.3 Corrupted Beasts (Player Faction - Bone & Wild Decay)
- **Dread Boar $\to$ Gore-Tusk Colossus (Juggernaut):** Unstoppable charger; Gore Charge rushes across the lane, knocking back the front target and ignoring initial collision.
- **Feral Hound $\to$ Ashen Cerberus (Assassin):** Pack hunter; gains $+20\%$ Attack Speed for every unit suffering from Bleed on the opposing board.
- **Quill Spitter $\to$ Venom-Spine Basilisk (Marksman):** Ranged pest; fires spine volleys applying non-cleansable neurotoxin ($-15\%$ AP accumulation).
- **Carrion Shaman $\to$ Brood Defiler (Occultist):** Miasma caller; converts ground beneath target row into rot-mire, dealing nature damage per tick.
- **Pack Alpha $\to$ Primal Patriarch (Support):** Roaring commander; Primal Howl cleanses crowd control from beast allies and grants $+25\%$ Speed for 15 ticks.

### 12.4 Occult Void Cult (Player Faction - Runes & Arcane Rifts)
- **Void-Bound Thrall $\to$ Obsidian Sentinel (Juggernaut):** Rift guardian; converts $20\%$ of incoming damage into an arcane shockwave pulsed back to attackers.
- **Shadow Flayer $\to$ Void Ripper (Assassin):** Phase stalker; blinks behind the enemy with the lowest EHP, striking from stealth with $+40\%$ critical chance.
- **Acolyte Slinger $\to$ Void Ray Stalker (Marksman):** Energy gunner; fires continuous void beams that ramp in damage by $+10\%$ per consecutive second on the same target.
- **Cultist Apprentice $\to$ Blight Arch-Warlock (Occultist):** Gravity manipulator; summons a singularity pulling all targets in a 3m radius into a concentrated cluster.
- **Chanter of the Void $\to$ Herald of the Dark Gate (Support):** Dimensional anchor; anchors the lowest AP ally, instantly filling their turn meter by $+3,000$ AP.

### 12.5 Neutral Mercenaries (5 Units)
- **Dwarf Ironbreaker (Juggernaut):** Immovable tank; immune to dynamic knockbacks and takes $-30\%$ damage from area attacks.
- **Bounty Hunter (Assassin):** Opportunist; marks highest-threat target; securing the kill instantly grants 2 Focus to the Gauntlet.
- **Ashen Trapper (Marksman):** Caltrop deployer; drops traps along the front line that root advancing enemies for 20 ticks.
- **Rogue Pyromancer (Occultist):** Wildfire caster; throws volatile flasks inflicting rapid Burn stacks that explode on expiration.
- **Wandering Cartomancer (Support):** Slip cyclist; basic attacks reduce the redrawing cooldown of the Gauntlet Burn Pit by 50%.

### 12.6 Campaign Enemy Swarms (15 Units)
- **The Carrion Swarm (5):** Bloated Abomination (self-destructs on death), Plague Leaper (bypasses vanguard), Blight Spitter (acid pools), Swarm Caller (summons larvae), Noxious Censer-Bearer (aura suppresses healing).
- **The Infernus Brood (5):** Molten Brute (armor hardening), Fire Drake Stalker (breath line), Ash Slinger (blind debuff), Hellfire Invoker (rain of fire channel), Ignited Zealot (frenzy at low HP).
- **The Defiled Dominion (5):** Fallen Templar (shield wall), Penitent Flagellant (damage ramps with lost HP), Heresy Hunter (silence strike), Defiled Bishop (mass shielding), Chained Reliquary (explodes into soul-embers).

### 12.7 World Titans / Boss Sovereigns (3 Units)
- **Gorgoroth the Flayed:** Dual-blade magma brute; telegraphs screen-wide Flaying Cleave (45 ticks to interrupt via Stagger break).
- **Valok the Carrion Colossus:** Weeping marble titan; radiates toxic sludge that corrupts ground tiles and pulses contagion damage.
- **Lady Valeria (Defiled Justiciar):** Corrupted holy sovereign; summons floating sword rings that execute targets below $20\%$ HP.
