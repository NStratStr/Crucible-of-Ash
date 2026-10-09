# CRUCIBLE OF ASH: MINIATURE BATTLER
## Master Game Design Document v2.6 (Production & MVP Architecture)
**Platform:** Mobile-First Hybrid (Flutter / Dart / Impeller; responsive 9:16 Portrait & 16:9 Landscape)
**Simulation Engine:** Deterministic Fixed 30 Hz Speed-Tick Loop (Decoupled from Render Frames)
**Aesthetic:** Dark Fantasy Grimdark / Gothic Tabletop Miniature Wargame

---

### 1. EXECUTIVE SUMMARY & CORE PILLARS
*Crucible of Ash: Miniature Battler* is a dark fantasy, turn-based/initiative tactical autobattler designed for high-density strategic play across Mobile, Web, and Desktop runtimes. Players curate, fuse, and command squads of collectible tabletop-style miniatures within a physicalized 2.5D arena.

#### Core Pillars
* **Tactical Depth via Miniature Crafting:** Units are physical miniatures defined by modular bases, plinth materials, and socketable soul-cores/traits.
* **Spatial & Initiative Determinism:** Combat resolves on continuous geometric physics and a fixed 30-ticks/sec timeline using explicit line-of-sight (LoS), dynamic bounding radii, and deterministic vector propagation.
* **Emergent Dynamic Fusion:** A 6-generation inheritance system allows players to breed stats, abilities, and status affinities into bespoke hybrid miniatures.
* **Ascension-Driven Replayability:** A steep, granular A1–A10 Ascension modifier stack demands deep system comprehension and zero-error execution.

---

### 2. CORE GAME LOOPS

```
[ Collection / Recruits / Fusion ] ───► [ Squad Assembly & Loadout ]
         ▲                                           │
         │                                           ▼
[ Meta Rewards & Ash ] ◄──────────── [ Tactical Combat Arena Loop ]
```

#### Core Loop Mechanics
1. **Assembly Phase:** Player selects 5 Active Miniatures (3 Vanguard, 2 Arcanum) and equips Commander Grimoires.
2. **Deployment Phase:** Placement of units onto the tactical plane using radial collision bounding.
3. **Real-Time Tactical Loop:** Action resolution proceeds dynamically based on Action Speed ticks. Units execute deterministic AI logic trees (Targeting → Movement → Action → Status Resolution).
4. **Post-Match Extraction:** Defeated units yield Ember Shards and raw Unbound Ash. Victorious runs grant Crucible Keys to unlock higher Ascension tiers.

---

### 3. COMBAT ENGINE FORMULAS & TARGETING HIERARCHY

#### 3.1 Core Damage & Defense Formulas
* **Effective Health Calculation (EHP):**
  $$EHP = HP \times \left(1 + \frac{ARMOR}{100}\right) \times \left(1 + \frac{RESIST}{100}\right)$$
* **Physical Damage Reduction (Diminishing Returns):**
  $$PRR = \frac{ARMOR}{ARMOR + 100 + (10 \times ATTACKER\_LEVEL)}$$
* **Elemental Resistance Reduction:**
  $$ERR = \frac{RESIST}{RESIST + 120}$$
* **Total Damage Output:**
  $$Damage = (BaseATK \times SkillCoeff) \times (1 - PRR) \times (1 + CRIT\_MULT) - FlatAbsorb$$

#### 3.2 Action Speed & Turn Order
Turn execution utilizes an Action Value (AV) Accumulator Engine. Units accumulate Action Points ($AP$) each frame until reaching the Action Threshold ($AT = 10000$):
$$AP_{tick} = BaseSPD \times (1 + \sum Modifier_{SPD})$$
$$TicksToTurn = \frac{10000 - AP_{current}}{AP_{tick}}$$

#### 3.3 Dynamic Targeting Hierarchy
When an action triggers, units evaluate targets based on an explicit 4-step filter:
1. **Hard Constraints:** Taunt/Provoke state override → Line-of-Sight Check (Raycast against static geometry) → Max Range Check ($Distance \le SkillRange + Radius_{target}$).
2. **Primary Priority Flag:** Selected via unit tactic setting (Lowest_EHP_Absolute, Highest_Threat_Score, Cluster_Density_Max, Role_Class_Priority: Healer > Mage > DPS > Tank).
3. **Tie-Breaker Metric:** Closeness to unit center mass ($Vector3.Distance$).
4. **Fallback:** Nearest valid enemy unit.

#### 3.4 Mid-Battle Downed State & Revive Lifecycle ("Inert Vessel")
* **Inert Vessel State:** When a unit's HP reaches 0, it does not despawn. The miniature converts into an inert, desaturated grey stone plinth anchored to its slot. AP accumulation freezes to 0. It ceases to block line-of-sight for normal melee targets (enemies strike the Arcanum behind them), but remains an interactable spatial target for Necromancy, Corpse Detonation, or Revives.
* **Infused Vitae Revive Formula:** Restored health scales directly from the caster's Attack stat and Generational tier (G1–G6):
  $$Revived\_HP = (Caster\_ATK \times SkillCoeff) \times (1 + Caster\_Gen \times 0.15)$$
  *Capped at target Max HP. Overflow converts into an Aegis Shield Ring equal to 50% of the excess.*
* **Awakening State:** Revived units gain a **6-tick (0.2s) invulnerability grace window** to prevent instant recleaving, have all previous debuffs cleansed, and reset their AP gauge to 0.
* **Soul Fracture Penalty:** Each time an individual unit is revived within a battle or descent run, it receives a stacking **-20% Max HP** penalty, preventing endless revive cycling.

---

### 4. STATUS EFFECT MATRIX & IN-ENGINE COMPOSITING STACK

Status effects process in a deterministic order: **Pre-Tick → Main Action → Post-Tick**. Multipliers are additive within the same layer, multiplicative across layers.

| Status ID | Type | Stacking Type | Effect Mechanics | Cleansable |
| :--- | :--- | :--- | :--- | :--- |
| **BLEED** | DoT Physical | Intensity (Max 10) | Deals $0.15 \times ATK$ physical damage per second per stack. Ignores 30% Armor. | Yes |
| **BURN** | DoT Fire | Duration (Max 12s) | Deals $0.22 \times ATK$ fire damage per second. Spreads to units within 1.5m on expire. Suppresses 100% healing. | Yes |
| **FREEZE** | Hard CC | None | Unit cannot act. Physical hits shatter for 15% max HP bonus damage and end freeze. | Yes |
| **STUN** | Hard CC | Overwrite | Pauses AP Accumulation. Resets current AP frame by 25%. | No |
| **VULNERABLE** | Debuff | Refresh | Increases all incoming damage taken by 25%. | Yes |
| **HASTE** | Buff | Duration | Increases BaseSPD by 35%. | Yes |
| **SHIELD** | Buff | Intensity | Absorbs incoming damage. Expiration triggers AoE pulse dealing 50% remaining shield. | No |

#### Procedural Compositing Rules
* **Clean Master Sprites:** No status visuals baked into PNG art assets.
* **Plinth Rim Pips:** Left arc renders Bleed notches; right arc renders Poison pips via Canvas `CustomPainter`.
* **Aegis Barrier:** Concentric gold radial ring tracks shield integrity.
* **Material Modifiers:** Grayscale matrix for Stagger/Petrify/Downed; 45% opacity for Stealth.

---

### 5. GRIMOIRE SYSTEM & HAND MANAGEMENT
Generals do not use turn timers; they command a 10-card tactical Grimoire using Focus. Hand capacity is fixed at 3 cards.
* **Burn Pit:** Dragging an unwanted card to the Discard Pit costs 0 Focus and draws a fresh card after a 6-tick (0.2s) safety cooldown.
* **Deck Reshuffle:** When the Grimoire empties, the discard pile instantly recycles with zero resource penalty.
* **Bullet-Time:** Dragging a card slows game simulation to 30% speed.
* **Target Failsafe:** If a hovered target dies before touch release, the dragged card snaps safely back to hand with **0 Focus consumed**.

---

### 6. MINIATURE MANIFEST (63 LAUNCH MINIATURES)

#### Player Factions (40 Miniatures: 4 Factions × 5 Archetypes × 2 Tiers)
* **Ash Legion:**
  * Juggernaut: G1 Iron Footman → G6 Lord Justiciar
  * Assassin: G1 Grave Duelist → G6 Ashen Inquisitor
  * Marksman: G1 Iron Arbalest → G6 Siege Arbalest Prime
  * Occultist: G1 Sun-Scorched Cleric → G6 Solar Hierophant
  * Support: G1 Field Medicus → G6 Sunlight Banneret
* **Corrupted Beasts:**
  * Juggernaut: G1 Dread Boar → G6 Gore-Tusk Colossus
  * Assassin: G1 Feral Hound → G6 Ashen Cerberus
  * Marksman: G1 Quill Spitter → G6 Venom-Spine Basilisk
  * Occultist: G1 Carrion Shaman → G6 Brood Defiler
  * Support: G1 Pack Alpha → G6 Primal Patriarch
* **Crypt Stalkers:**
  * Juggernaut: G1 Rotting Husk → G6 Grave Titan
  * Assassin: G1 Grave Ghoul → G6 Ashen Strigoi Lord
  * Marksman: G1 Bone Archer → G6 Wraith Sniper
  * Occultist: G1 Blight Necromancer → G6 Lich Dominus
  * Support: G1 Blood Alchemist → G6 Sanguine Priestess
* **Occult Void Cult:**
  * Juggernaut: G1 Void-Bound Thrall → G6 Obsidian Sentinel
  * Assassin: G1 Shadow Flayer → G6 Void Ripper
  * Marksman: G1 Acolyte Slinger → G6 Void Ray Stalker
  * Occultist: G1 Cultist Apprentice → G6 Blight Arch-Warlock
  * Support: G1 Chanter of the Void → G6 Herald of the Dark Gate

#### Neutral / Mercenary Pool (5 Miniatures)
* Dwarf Ironbreaker, Bounty Hunter, Ashen Trapper, Rogue Pyromancer, Wandering Cartomancer.

#### Campaign Enemy Swarms (15 Miniatures)
* **The Carrion Swarm (5):** Bloated Abomination, Plague Leaper, Blight Spitter, Swarm Caller, Noxious Censer-Bearer.
* **The Infernus Brood (5):** Molten Brute, Fire Drake Stalker, Ash Slinger, Hellfire Invoker, Ignited Zealot.
* **The Defiled Dominion (5):** Fallen Templar, Penitent Flagellant, Heresy Hunter, Defiled Bishop, Chained Reliquary.

#### World Titans / Boss Sovereigns (3 Oversized Miniatures)
* Gorgoroth the Flayed, Valok the Carrion Colossus, Lady Valeria Defiled Justiciar.

---

### 7. SIX-GENERATION FUSION MATH & GENETICS
Fusion follows a strict binary progression tree (32x G1 = 1x G6 Sovereign). Base stat calculations use Gaussian blending with mutation variance ($\sigma = 0.05$):
$$BaseStat_{Child} = \left( \frac{BaseStat_{P1} + BaseStat_{P2}}{2} \right) \times \left(1 + Generation \times 0.03\right) \times \mathcal{N}(1, 0.05)$$

* Gen 0 (Base Pulls) + Gen 0 → Gen 1 (+3% Stat Ceiling, 1 Passive Slot)
* Gen 1 + Gen 1 → Gen 2 (+6% Stat Ceiling, 2 Passive Slots)
* Gen 2 + Gen 2 → Gen 3 (+9% Stat Ceiling, Cross-Archetype Ability)
* Gen 3 + Gen 3 → Gen 4 (+12% Stat Ceiling, Mutation Slot)
* Gen 4 + Gen 4 → Gen 5 (+15% Stat Ceiling, Prismatic Aura Slot)
* Gen 5 + Gen 5 → Gen 6 (Apex Sovereign Tier, Max Stat Ceiling +20%)

* **Auto-Synthesis:** Single-tap action in the Crucible rolls duplicate G1s and G2s into G3 veterans.
* **Trait Safety Lock:** Units dropping with rare bloodline traits are automatically locked from auto-synthesis.

---

### 8. ASCENSION TIER STACK (A1 – A10)
1. **A01 - Aggressive Instincts:** Enemy ATK +15% (+20% Bloodstones).
2. **A02 - Thickened Hides:** Enemy Armor & Resist +20% (+40% Bloodstones).
3. **A03 - Depleted Reserves:** Player starting Mana/Focus reduced by 50% (+65% Bloodstones).
4. **A04 - Sovereign Spikes:** Elites/Bosses reflect 15% physical damage (+90% Bloodstones).
5. **A05 - Grimoire Tax:** Hand size reduced from 3 to 2 cards (+120% Bloodstones).
6. **A06 - Callous Flesh:** Bleed and Poison on allies deal 50% more damage (+155% Bloodstones).
7. **A07 - Hardened Will:** Enemy Stagger Gauges require +40% more impact (+195% Bloodstones).
8. **A08 - Unstable Ground:** Volcanic Ash hazard nodes appear on map (+240% Bloodstones).
9. **A09 - Severed Lineage:** Focus generation slowed by 25% (+290% Bloodstones).
10. **A10 - Crucible of Ash / Sovereign's Gaze:** Bosses gain random affixes (Vampiric, Shielded, Swiftcast). Guaranteed Legendary Relic (+350% Bloodstones).

---

### 9. UI / UX SYSTEM & VIEWPORT LAYOUTS
Fully responsive architecture supporting **Mobile Portrait (9:16 - 390×844 logical px)** and **Desktop/Tablet Landscape (16:9 - 1920×1080 logical px)**.
* **Mobile Portrait:** Top header (44px), Boss Intent Bar (50px), 2.5D Isometric Clash Arena (380px), Focus Ribbon (36px), Lower Card Tray (170px), Burn Pit at bottom-right (48×48px).
* **Desktop Landscape:** Left Commander Dock (280px), Central Clash Arena (1360px), Right Target/Boss Dock (280px), Lower Command Tray (240px).
* **Inspect Tap Modal:** Tapping any miniature pauses simulation and opens a dark slate side-drawer with precise stat breakdowns and status durations.

---

### 10. TECHNICAL ARCHITECTURE & PERFORMANCE BUDGETS
* **Fixed 30-Tick Determinism:** Simulation is decoupled from render frames using an internal accumulator.
* **Binary Replay Serialization:** Action inputs packed into 20-byte blobs per action for 2 KB anti-cheat validation and crash-recovery state replay.
* **Audio Voice Concurrency:** Voice stealing priority queue (Tier 1: Boss Ultimates/Cataclysms → Tier 2: Player Cards → Tier 3: Basic Attacks). Mobile capped at 24 concurrent voices; Desktop at 64.
* **Asset Memory Budgets:** 512×512 master PNGs for standard units; 1024×1024 for Titans. Only active 10 combatants loaded into GPU VRAM during encounters.

---

### 11. ASYNCHRONOUS BRIGADE ARENA (PVP OPTION A)
Players snapshot a defensive formation of 5 miniatures and a 10-card Grimoire. The Defensive AI evaluates plays using a weighted tree:
1. **Emergency Preservation:** Cast heal/shield if allied Vanguard < 25% HP.
2. **Telegraph Disruption:** Cast stun/slow if attacker is within 10 ticks of burst.
3. **Combo Execution:** Cast execute card if target has 3+ Bleed stacks.
4. **Proactive Pressure:** Play lowest-cost order if Focus $\ge$ 5/6.
5. **Simulated Reaction Delay:** AI incurs a 30-tick (1.0s) delay to preserve attacker agency.

---

### 12. ECONOMY VALVES & METAGAME TUNING
* **Currencies:** Ash (soft currency for leveling/fusions), Ember Shards (hard currency for cosmetic bases/reset tokens), Crypt Keys (pacing mechanism).
* **Patience or Prestige:** Zero hard paywalls or exclusive power gates. Players pay for time convenience (reagent bundles, trait chisels) and cosmetic prestige.
* **Exponential Fusion Tax:**
  $$Cost_{Ash} = 1000 \times (1.85)^{Generation}$$

---

### 13. OPERATIONAL & PLAYER EXPERIENCE FACTORS

#### 13.1 Encounter Pacing & "The Ashen Reckoning" (Enrage Mechanics)

| Encounter Tier | Standard Combat | Warning Chime | Phase 1: Ashen Reckoning (2.0× Dmg, -50% Heals) | Phase 2: Terminal Collapse (Escalating Dmg, No Revives) | Hard Adjudication / Wipe |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Standard Skirmish / Arena** | 0:00 – 1:15 | **1:15** (2,250 ticks) | **1:30** (2,700 ticks) | **1:45** (3,150 ticks) | **2:00** (3,600 ticks) — Highest HP Wins |
| **Elite / Mini-Boss** | 0:00 – 1:45 | **1:45** (3,150 ticks) | **2:00** (3,600 ticks) | **2:15** (4,050 ticks) | **2:30** (4,500 ticks) — Highest HP Wins |
| **Boss / World Titan** | 0:00 – 2:30 | **2:30** (4,500 ticks) | **3:00** (5,400 ticks) | **3:30** (6,300 ticks) | **4:00** (7,200 ticks) — Titan Enrage Wipe |

#### 13.2 Multi-Phase Boss Timer Resets
Crossing a major boss phase threshold (e.g., 66% HP, 33% HP) **completely resets the phase clock to Tick 0** and clears active Reckoning damage/healing penalties. This ensures players are not penalized during early phases for playing defensively.

#### 13.3 Mobile Ergonomics & Touch Boundaries (Fitts's Law)
* **Hitbox Inflation:** Miniatures on screen have an invisible **+25% touch boundary padding** around their plinth discs to eliminate drag-and-drop misfires on high-DPI displays.
* **Thumb Reach Optimization:** All primary interactive elements (Card Hand Carousel, Burn Pit, Focus Indicator) are strictly anchored within the **bottom 35% of the mobile screen**. The upper 65% remains dedicated to combat visualization.

#### 13.4 Energy Philosophy & Resource Gating
* **Unrestricted Campaign Access:** The core Campaign Descent and Ascension ladder feature **zero hard energy or stamina gates**. Players can play, draft, and experiment without artificial play-blockers.
* **Targeted Crypt Lockouts:** Specific resource grinding dungeons (Lineage Crypts) utilize daily allotment keys (3 free Crypt Keys/day) to pace duplicate fodder acquisition without penalizing casual play.

#### 13.5 First-Time User Experience (FTUE) & Progressive Disclosure
* **Encounter 1:** 3 Vanguards only; autonomous initiative attacks (teaches turn meters, armor mitigation, and HP).
* **Encounter 2:** Introduces Commander Focus and the first Order Card (*Rend Flesh*).
* **Encounter 3:** Introduces enemy Boss Intent telegraph countdowns and Stagger break cards.
* **Crucible Unlock:** The Crucible altar remains sealed until completing Chapter 1, introducing duplicate fusion and trait grafting only after base recruits are earned.

#### 13.6 Offline Determinism & Network Tolerance
* **Zero-Latency Offline Execution:** Combat runs entirely locally without requiring an active connection during match execution.
* **Lazy Synchronization:** If connection is interrupted, the game stores the serialized 20-byte/action binary log and seamlessly syncs results with the game server once connectivity is re-established.

---

### 14. THE MINIMUM VIABLE PRODUCT (MVP) SPECIFICATION

#### 14.1 MVP Boundary & Scope Pruning
* **Engine Core:** Fixed 30-Tick deterministic runner, 5v5 isometric plane (3 Vanguard, 2 Arcanum), hyperbolic armor mitigation, Downing/Revive lifecycle, and the Ashen Reckoning sudden death clock.
* **Miniature Roster (10 Units Only):**
  * *Ash Legion (Player):* Iron Footman (Juggernaut), Grave Duelist (Assassin), Iron Arbalest (Marksman), Sun-Scorched Cleric (Occultist), Field Medicus (Support).
  * *Crypt Stalkers (Enemy):* Rotting Husk (Juggernaut), Grave Ghoul (Assassin), Bone Archer (Marksman), Blight Necromancer (Occultist), Blood Alchemist (Support).
* **Commander & Grimoire (Lord Vladislav Only):** 6 Core Cards (Rend Flesh, Iron Bulwark, Exsanguinating Strike, Sanguine Revival, Disrupting Cleave, Blood Boil). Max 6 Focus pool.
* **Crucible Micro-Loop:** Local SQLite database supporting duplicate fusion up to G3 (G1 → G2 → G3). G4–G6 and trait grafting deferred.
* **Encounter Format:** Single 3-wave skirmish map proving initiative ticks, card drags, bullet-time, and stagger interrupts.

---

### 15. POST-MVP EXPANSION RECIPE

Following successful validation of the MVP vertical slice, systems are added in four sequential recipes:

1. **Recipe 1 — Lineage & Altar Expansion:**
   * Unlock G4 Dread, G5 Ascended, and G6 Pureblood Sovereign tiers.
   * Implement Trait Grafting altar (socketing donor passives into G3/G5 slots).
   * Implement Auto-Synthesis button and Rare Bloodline Trait safety locks.
2. **Recipe 2 — Faction & Commander Roster:**
   * Introduce Faction 3: Corrupted Beasts (Predator bleed & enrage passives).
   * Introduce Faction 4: Occult Void Cult (Phase warp & gravity pulls).
   * Add 5 Neutral Mercenary units.
   * Implement Commanders Lady Valeria, Malakor, and Morrigan with 30-card pools.
3. **Recipe 3 — Roguelite Descent & Ascensions:**
   * Branching DAG map generator (Encounter, Elite, Thrall Pen, Altar, Merchant).
   * In-run currency (Ashen Cinders) and 3-slot temporary run relics.
   * The 10-level Ascension Matrix (A1–A10 Ordeals of the Ash).
4. **Recipe 4 — Competitive & Social Modes:**
   * Asynchronous Brigade Arena (PvP Option A) with weighted Defensive AI.
   * World Titan communal sieges (Gorgoroth, Valok, Lady Valeria with multi-phase timer resets).
   * Headless server validation of 20-byte/action binary replay logs.

---

### 16. TWO-YEAR PRODUCTION & LIVE-OPS ROADMAP (2026 – 2028)

| Timeline | Milestone / Season | Core Deliverables & Live-Ops Content |
| :--- | :--- | :--- |
| **Q4 2026** | MVP Alpha & Closed Beta | Playable 10-unit slice (Ash Legion vs. Crypt Stalkers, Lord Vladislav, 6 cards). SQLite persistence, haptics, TestFlight / Android track (50 players). Target: >85% match completion in 45–75s. |
| **Q1 2027** | Commercial Launch v1.0 | Full 40 player miniatures across all 4 Great Factions. 4 Commanders with complete decks. Full 6-Gen Crucible fusion & trait grafting. Campaign Chapters 1–3, Ascensions A1–A5. Battle Pass: *Tithe of the Fallen*. |
| **Q2 2027** | Season 1: *Rise of the Gore-Tusk* | Corrupted Beasts master questline. 3 Primal Mercenaries. World Titan: *Valok the Carrion Colossus* with phase resets. Launch Asynchronous Brigade Arena (PvP Option A). Ascensions A6–A8. |
| **Q3 2027** | Season 2: *Void Incursion* | Commander Release: *The Architect of the Rift*. 4 Void Cult specialists. Ascensions A9–A10 (Sovereign's Gaze). Guild contribution damage tracks for World Titan sieges. |
| **Q4 2027** | Major Expansion 1: *Sunken Crypts of Acheron* (v2.0) | Faction 5: **The Abyssal Tide** (10 new miniatures). 3 underwater cathedral biomes. Multi-tile Titan: *Leviathan of the Deep Plinth*. Permanent Commander relic crafting. Replay player for 20-byte logs. |
| **Q1 2028** | Season 3: *The Iron Crusade* | Ash Legion sub-lineage (Sunfire Templars). Commander: *Grand Inquisitor Faust*. Synchronous Friendly Duels via deterministic rollback engine. |
| **Q2 2028** | Season 4: *Eldritch Eclipse* | Co-Op Raid Nodes (two players command 3 units each on ultra-wide battlefield). 5 Eldritch Mercenaries. Custom Plinth Forge cosmetic crafting system. |
| **Q3 2028** | Major Expansion 2: *Cataclysm Sovereign* (v3.0) | Faction 6: **The Infernus Dominion** (10 miniatures). Infinite seasonal delve mode (Ascensions A11–A15). Global Championship Arena with draft/ban phases. |

---

### 17. WORLD BUILDING & NARRATIVE ARCHITECTURE

#### 17.1 The Mythos: The Cataclysm of Ash
Centuries ago, the high-fantasy empire of the Shattered Epoch collapsed in an alchemical cataclysm that reduced the physical world to smoldering ash. Organic bodies were vaporized in seconds. The few surviving masters of the occult—known as **Ash Sculptors** or **Pyrebinders**—learned to bind wandering remnant souls into fired-clay tokens, stone effigies, and obsidian gaming plinths.

*The Tabletop Justification:* Units stand on circular plinths because without their physical stone base, their souls dissolve into the ash winds. When a unit is defeated, their vessel cracks and turns cold grey stone ("Inert Vessel"). Only an infusion of *Infused Vitae* can reignite the soul-ember within.

#### 17.2 The Four Great Factions
* **The Ash Legion (Cold Iron & Sunfire):** Remnants of the old imperial guard who worship a dying sun. They encase their soul-vessels in welded cold-iron bands and fortress flagstones, prioritizing defensive walls, armor stacking, and unyielding order.
* **The Corrupted Beasts (Bone & Wild Decay):** Fauna that adapted to the fallout by devouring blighted earth and fusing with dead predators. Bound by pack instinct, feral scent, and bleeding frenzy; their plinths are made of churned black earth, roots, and bone fragments.
* **The Crypt Stalkers (Obsidian & Vampiric Blood):** Ancient noble houses who barricaded themselves inside ancestral mausoleums. They preserve their consciousness through dark vitae distillation and necromancy, fighting from cracked cemetery stone plinths with life leech and shadow stealth.
* **The Occult Void Cult (Runes & Arcane Rifts):** Heretical scholars who actively tore open dimensional fractures to harvest eldritch energy from the abyssal void. Mounted on obsidian plinths etched with glowing violet runes; masters of gravity manipulation, phase teleports, and reality shearing.

#### 17.3 The Ritual of the Crucible (In-World Fusion)
Why do 32 G1 Thralls combine into 1 G6 Sovereign? Raw recruits are shattered soul-shards with fragmented memories and flickering will. Fusing them at the subterranean Crucible Altar burns away psychic impurities, condensing dozens of flickering sparks into a single, lucid **Pureblood Sovereign** with transcendent combat power.

#### 17.4 The Commanders
* **Lord Vladislav (The Sanguine King):** A melancholic monarch who traded his mortal kingdom for eternal vampiric vitae. Sacrifices health for battlefield momentum; commands the Grimoire with devastating bleed executions.
* **Lady Valeria (The Iron Justiciar):** A zealot who forswore passive healing, welding herself into blessed steel. Believes pain is the only true shield; punishes aggressors with holy stagger breaks and retribution damage.
* **Malakor (The Plague Father):** A physician who witnessed the cataclysm and concluded that rot is the only path to renewal. Commands miasmas of blight, corpse bursts, and irreversible decay.
* **Morrigan (The Raven Oracle):** A seer who perceives the battlefield as strings on a cosmic loom. Stretches and cuts time, stealing enemy turn meters and executing instant cooldown resets.

#### 17.5 The Roguelite Descent & World Titans
Squads dive deep into the **Ashen Trench** to harvest Basalt Cores and ancient relics from shattered cathedrals. Wandering these wastes are the **World Titans**: colossal entities like *Gorgoroth the Flayed*—a forgotten forge-god condemned to wander the basalt wastes—and *Valok the Carrion Colossus*, whose weeping marble base corrupts the very earth it crushes.
