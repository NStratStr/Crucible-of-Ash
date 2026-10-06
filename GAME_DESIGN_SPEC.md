# TECHNICAL & GAME DESIGN SPECIFICATION: PROJECT ASHEN CRUCIBLE
**A Modern Dark Fantasy Generational Brigade Battler**  
*Target Platforms: Flutter (iOS / Android / Web CanvasKit)*  
*Architecture: Clean Architecture / Reactive Modular Engine*

---

## 1. Executive Summary & Creative Vision

### 1.1 Core Hook: Compounding Generational Lineage
Unlike standard hero collectors where low-rarity summons are discarded as useless fodder, **Project Ashen Crucible** centers progression around **The Crucible of Blood**. Players cultivate, breed, and sacrifice monsters across generations. Inheriting 10% of parental stats at maximum level and grafting signature passive traits allows humble common thralls to compound into bespoke "Pureblood" champions over generations.

### 1.2 Influences & Synthesis
- **Blood Brothers**: Dark, grotesque fantasy aesthetics; brigade formation slots; generational sacrifice/evolution (*Crucible of Blood*).
- **Raid: Shadow Legends**: Continuous Speed/Turn-Meter initiative; asymptotic defense mitigation; buff/debuff hierarchies; high-stakes boss survivability puzzles.
- **Brave Exvius**: Precision tactical execution windows; Limit Bursts; micro-timing synergy.
- **Pox Nora**: Global resource management (Essence/Focus); tactical battlefield triggers.
- **Slay the Spire**: Directed Acyclic Graph (DAG) campaign traversal; risk-reward routing.

### 1.3 Art Direction
Grim, high-contrast dark fantasy (weathered iron, cracked obsidian, blood-sigil engravings, muted sepia parchment interfaces, crimson accents).

---

## 2. Core Game Loops

```
====================================================================================
1. TACTICAL CRAWL (Micro-Loop: 10–15 Minutes)
   - Traverse a Directed Acyclic Graph (DAG) campaign trail without backtracking.
   - 5-slot squad engagements (3 Vanguard, 2 Arcanum) with persistent attrition.
   - Resolve combat via a Speed-Tuned Tick Engine and 6-Role Hexagonal Wheel.
   - Deploy General Orders via battlefield Focus.
   -> Yields: Cursed Ore, Bloodline Sigils, Captured Thralls.
====================================================================================
                                      │
                                      ▼
====================================================================================
2. THE STRONGHOLD & CRUCIBLE (Meso-Loop: Strategic Metagame)
   - The Crucible of Blood: Fuse duplicate thralls; compound generational stats.
   - Trait Grafting: Transfer one passive perk from a sacrifice to the successor.
   - Relic Forge: Assemble 2-piece and 4-piece equipment sets from elite materials.
   - General Phylactery: Spend Anointed Bloodstones to unlock new Commander skills.
   -> Unlocks: Deeper campaign tiers, specialized faction dungeons.
====================================================================================
                                      │
                                      ▼
====================================================================================
3. THE ENDGAME GAUNTLET (Macro-Loop: Mastery & Retention)
   - The World Titan: Daily siege survival encounter requiring survivability tuning.
   - Lineage Crypts: Strict unit-type restricted trials (e.g., Undead / Beasts only).
   - Abyssal Descents: Tiered difficulty modifiers altering baseline enemy affinities.
====================================================================================
```

---

## 3. The 6-Role Hexagonal Affinity Wheel

To eliminate rigid rock-paper-scissors dead-ends in a 5-unit squad, the game uses a **6-node directional wheel**.

```
                          [ 0: JUGGERNAUT ]
                           (Tanks / Brutes)
                           /              \
                          /                \
        [ 5: OCCULTIST ]                     [ 1: ASSASSIN ]
      (Mages / Blight)                      (Rogues / Duelists)
             |                                      |
             |                                      |
        [ 4: SUPPORT ]                       [ 2: MARKSMAN ]
      (Healers / Bards)                     (Snipers / Artillery)
                          \                /
                           \              /
                            [ 3: SKIRMISHER ]
                           (Flyers / Beasts)
```

### 3.1 Archetype Profiles & Matchup Logic
1. **Juggernaut (Tanks / Colossi / Golems)**: High Armor, damage absorption, frontline anchors.
   - *Prey (+1 Clockwise)*: Assassin (Heavy armor and counters crush frail duelists).
   - *Predator (-1 Counter-Clockwise)*: Occultist (Magic and rot bypass physical armor).
2. **Assassin (Stalkers / Dual-Blades)**: Armor penetration, high Speed burst.
   - *Prey*: Marksman (Closes gaps rapidly to gut long-range artillery before they aim).
   - *Predator*: Juggernaut (Blades glance off heavy armor plating).
3. **Marksman (Archers / Cannoneers)**: Backline physical DPS, true-strike targeting.
   - *Prey*: Skirmisher (Flyer) (Ranged tracking shoots down aerial beasts).
   - *Predator*: Assassin (Flankers close distance before ranged volleys discharge).
4. **Skirmisher (Flyers / Prowling Beasts)**: High Evasion, line-ignoring mobility, backline diving.
   - *Prey*: Support (Swoops over frontlines to pick off fragile healers).
   - *Predator*: Marksman (Vulnerable in open airspace to direct archery fire).
5. **Support (Healers / Alchemists / Totemists)**: Sustain, dispels, Turn-Meter acceleration.
   - *Prey*: Occultist (Purification and wards negate damage-over-time blight).
   - *Predator*: Skirmisher (Flyer) (Squishy casters fall to sudden aerial dives).
6. **Occultist (Warlocks / Necromancers)**: AoE sorcery, blight stacks, armor dissolution.
   - *Prey*: Juggernaut (Corrosive blight rots heavy physical defenders).
   - *Predator*: Support (Magical cleansing and burst restoration counteract hexes).

### 3.2 Relationship Multiplier Matrix
| Attacker \ Defender | Juggernaut (0) | Assassin (1) | Marksman (2) | Skirmisher (3) | Support (4) | Occultist (5) |
|---|---|---|---|---|---|---|
| **Juggernaut (0)** | Neutral (1.00) | **STRONG (1.30)** | Neutral (1.00) | Neutral (1.00) | Neutral (1.00) | *WEAK (0.75)* |
| **Assassin (1)** | *WEAK (0.75)* | Neutral (1.00) | **STRONG (1.30)** | Neutral (1.00) | Neutral (1.00) | Neutral (1.00) |
| **Marksman (2)** | Neutral (1.00) | *WEAK (0.75)* | Neutral (1.00) | **STRONG (1.30)** | Neutral (1.00) | Neutral (1.00) |
| **Skirmisher (3)** | Neutral (1.00) | Neutral (1.00) | *WEAK (0.75)* | Neutral (1.00) | **STRONG (1.30)** | Neutral (1.00) |
| **Support (4)** | Neutral (1.00) | Neutral (1.00) | Neutral (1.00) | *WEAK (0.75)* | Neutral (1.00) | **STRONG (1.30)** |
| **Occultist (5)** | **STRONG (1.30)** | Neutral (1.00) | Neutral (1.00) | Neutral (1.00) | *WEAK (0.75)* | Neutral (1.00) |

*Rule:*
$$\text{delta} = (\text{defender.index} - \text{attacker.index}) \pmod 6$$
- $\text{delta} = 1$: **Strong** ($\times 1.30$)
- $\text{delta} = 5$: **Weak** ($\times 0.75$)
- Otherwise: **Neutral** ($\times 1.00$)

---

## 4. Mathematical Combat Engine

### 4.1 Damage & Mitigation Curves
To prevent defense stats from causing hard invulnerability thresholds, damage uses an asymptotic mitigation curve:

$$\text{Mitigation Multiplier} = \frac{1000}{1000 + (3.5 \times \text{Defender Defense})}$$

$$\text{Base Damage} = \text{Attacker Attack} \times \text{Skill Coefficient} \times \text{Mitigation Multiplier}$$

$$\text{Final Damage} = \text{Base Damage} \times \text{Affinity Multiplier} \times \text{Crit Multiplier} \times \text{Variance}[0.95, 1.05]$$

#### Glancing Blow Mechanic
When attacking at an Affinity Disadvantage ($\times 0.75$), the attack incurs a **25% Glancing Blow chance**:
- Damage is reduced by an additional $30\%$ ($\times 0.70$, compounding).
- Cannot score a Critical Hit.
- Negative status effects (Blight, Stun, Armor break) fail to apply.

### 4.2 Initiative Tick Engine
The combat loop operates on discrete internal increments called **Ticks**:
$$\Delta \text{TM} = \left(\frac{\text{Speed}}{100}\right) \times 10$$
- When any unit reaches $\ge 100.0\text{ TM}$, the tick engine pauses into `CombatPhase.awaitingAction`.
- **Tie-Breaking**:
  1. Highest raw TM overflow.
  2. Highest base Speed stat.
  3. Player side (Allies) priority.

---

## 5. The Crucible of Blood (Generational Breeding)

```
       [ Progenitor A (Lv. 30 Max) ]            [ Progenitor B (Lv. 30 Max) ]
            Base ATK: 200                             Base ATK: 180
                     \                                       /
                      \                                     /
                       v                                   v
                  +---------------------------------------------+
                  |            THE CRUCIBLE OF BLOOD            |
                  +----------------------+----------------------+
                                         |
                                         v
                         [ Lineage Descendant (Gen 2) ]
                  Species Baseline ATK:  150
                  Inherited Bonus:       (200 * 0.10) + (180 * 0.10) = +38 ATK
                  Final Base ATK:        150 + 38 = 188 ATK
                  Grafted Trait:         Transfers 1 Passive Trait from Parent A or B
```

### 5.1 Generational Progression Rules
- **Generational Scale**: $\text{Gen 1} \to \text{Gen 2} \to \text{Gen 3} \to \text{Pureblood (Gen 4)}$.
- **Inheritance Efficiency**:
  - Max Level: Transfers **10%** of parents' final attributes.
  - Premature (Below Max Level): Transfers **5%** of current attributes.
- **Formula**:
  $$\text{Child Stat} = \text{Species Base} + (\text{Parent}_A \times \text{Ratio}_A) + (\text{Parent}_B \times \text{Ratio}_B)$$
- **Trait Grafting**: Units have 1 Native Trait and 1 Graft Socket. Upon fusion, 1 passive trait from either progenitor is locked into the descendant's socket.

---

## 6. Generals (Commanders) & Battlefield Orders

Generals observe from the Command Platform behind the brigade, providing a permanent passive aura and deploying Orders funded by **Command Focus** (gained by dealing and receiving damage; 500 damage = 1 Focus point, max cap 3).

### 6.1 General Profiles
1. **Lord Vladislav (The Blood Sovereign)**
   - *Aura (Crimson Tithe)*: All allies gain +8% Lifesteal against Bleeding/wounded targets.
   - *Siphon Vitality (1 Focus)*: Drain 15% HP from a target enemy; distribute drained vitality across surviving frontline Vanguard allies.
   - *Sanguine Ward (2 Focus)*: Sacrifice 15% team HP to generate an Armor barrier equal to 200% of the sacrifice.
   - *Feast of Ruin (3 Focus)*: Execute an enemy below 20% max HP; surge all surviving allies with +50% Turn Meter.
2. **Lady Valeria (The Iron Justiciar)**
   - *Aura (Iron Aegis)*: Frontline Vanguard gains +25% Armor and reflects 15% physical damage.
   - *Stand Resolute (1 Focus)*: Fortify targeted ally with +40% Armor.
   - *Retributive Stride (2 Focus)*: All frontline allies trigger an instant counter-strike against their lane opponents.
   - *Smite the Wicked (3 Focus)*: High-impact single-target strike scaling with total squad Armor.
3. **Malakor (The Blight Father)**
   - *Aura (Carrion Miasma)*: When an ally falls, all enemies gain 2 stacks of Blight.
   - *Corpse Burst (1 Focus)*: Detonate a fallen unit for AoE poison damage.
   - *Virulent Cascade (2 Focus)*: Instantly trigger 50% of remaining DoT on blighted enemies.
   - *Rebind Flesh (3 Focus)*: Resurrect a fallen ally as a decaying thrall for 2 turns.
4. **Morrigan (The Ashen Oracle)**
   - *Aura (Temporal Threads)*: Squad gains +10% Speed; crits grant +5% Turn-Meter.
   - *Quicken (1 Focus)*: Immediately grant target ally 100% TM.
   - *Unravel Hex (2 Focus)*: Strip enemy buffs and reduce Armor by 30%.
   - *Echoing Hourglass (3 Focus)*: Backline Arcanum repeats their last action for free.

---

## 7. Campaign Crawl & Map Generation (DAG Engine)

Progression is represented as a Directed Acyclic Graph (DAG) across 12 to 15 vertical tiers without backtracking:
- **Skirmish**: Standard 5-man brigade encounter. Awards base gold, XP, and common thralls.
- **Elite Fiend**: High-damage encounter with guaranteed equipment drops and rare Bloodline Sigils.
- **Watchtower (Scout)**: Clears Fog of War across upcoming tiers; reveals enemy affinity compositions.
- **Blood Altar**: High-stakes trade node (e.g. sacrifice 25% squad HP for permanent run buffs).
- **Defiled Crypt**: Narrative choice event with risk-reward outcomes.
- **Rest Haven**: Recover 40% squad HP or upgrade an equipped relic.
- **World Titan**: Chapter-capping boss encounter.

---

## 8. First-Time User Experience (FTUE) Script
- **Screen 1**: Awakening — Choose General (Vladislav or Valeria) and receive starter brigade.
- **Screen 2**: Encounter 1 — Tutorial skirmish teaching Speed ticks, Vanguard/Arcanum layout.
- **Screen 3**: Encounter 2 — Affinity check teaching the Hex Wheel and Commander Focus.
- **Screen 4**: The Crucible of Blood — Fuse duplicate hounds into Generation 2 Cerberus Spawn.
- **Screen 5**: Encounter 3 — Gatekeeper boss defeated by the newly evolved Gen 2 powerhouse.
