# CRUCIBLE OF ASH: TECHNICAL ARCHITECTURE & ASSET PIPELINE SPECIFICATION
## Engineering Manual, Rendering Pipelines & Asset Integration Guide (v3.0)

---

## 1. Executive System Overview

*Crucible of Ash* is a dark fantasy, tabletop-style tactical battler built in **Flutter (Dart)** running a **30 Hz deterministic simulation loop** decoupled from the UI rendering layer.

```
┌─────────────────────────────────────────────────────────────┐
│                 CRUCIBLE OF ASH RUNTIME                     │
├──────────────────────────────┬──────────────────────────────┤
│    DETERMINISTIC SIMULATION  │     PRESENTATION LAYER       │
│  - InitiativeTickManager     │  - BattleScreen              │
│  - 30 Hz Action Point ticks  │  - Kinetic 3D Plinth Shading │
│  - Column/Lane Spatial Rules │  - Card Drag & Bullet-Time   │
│  - CombatResolutionService   │  - Canvas Painters & VFX     │
│  - GeneralCommandService     │  - LivingAtmosphereEngine    │
└──────────────────────────────┴──────────────────────────────┘
```

---

## 2. Animation & Asset Architecture: How Visuals Work

### 2.1 The Two-Layer Paradigm: Do We Need a Separate Effects File?
**Direct Answer:** **NO separate effect image file is required for base unit animations.** 

In *Crucible of Ash*, unit animations and combat visual effects are split between **Clean Character Cutouts** and **Procedural Shader/Canvas VFX Layers**:

```
┌─────────────────────────────────────────────────────────────┐
│                    UNIT CARD RENDER STACK                   │
├─────────────────────────────────────────────────────────────┤
│ LAYER 4: Floating Combat Pops & Damage Numbers (Local Stack)│
├─────────────────────────────────────────────────────────────┤
│ LAYER 3: Target Reticles, Intent Badges, Health/Shield Bar  │
├─────────────────────────────────────────────────────────────┤
│ LAYER 2.5: Procedural VFX (Slash/Pierce/Crit/Shockwave)     │
├─────────────────────────────────────────────────────────────┤
│ LAYER 1B: Character Cutout PNG (Clean Transparent Model)    │
│           - Rendered with transform matrices (lunge, tilt)  │
│           - Dynamic ColorFilter (Red hit-flash, Grey-death) │
├─────────────────────────────────────────────────────────────┤
│ LAYER 1A: 3D Ground Plinth (Faction Radial Canvas & Shadow) │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Why Separate Effect Images Aren't Needed on the Character PNG:
1. **Procedural Kinetic Animation:** 
   - Attack lunges, staggered hit recoil, crits, and death falls are driven by Flutter matrix transforms (`Matrix4.translationValues`, `rotateZ`, `scale`) applied dynamically in real time.
2. **Dynamic Color Filtering & Hit Stops:** 
   - When a unit takes damage, `BlendMode.srcATop` flashes the model crimson (`0xFFFF1744`), triggers a 180ms screen shake, and applies a procedural strike slash over the model.
3. **Procedural Directional VFX:**
   - Slashing blades, piercing tracer lines, crush shockwaves, arcane runes, and boss impacts are rendered by Flutter `CustomPainter` vector shapes and radial gradients directly over the unit.
4. **Reusability & Palette Cleanliness:**
   - If an effect (e.g. fire, blood spray, lightning) were baked directly into the unit PNG, it would freeze in mid-air when the character is idling, breathing, or taking damage. 
   - **Rule:** Keep the character asset 100% clean of transient visual effects (no static blood splatters, no frozen muzzle flashes, no drawn slash trails).

---

## 3. Asset Specifications for Gemini Generation

When generating art in Gemini or image tools, follow these exact format, dimension, and compositional rules:

### 3.1 Unit Miniatures / Character Cutouts
- **Format:** `PNG` with **100% transparent alpha background** (Zero halos, clean contours).
- **Resolution:** 1024×1024 px or 768×1024 px.
- **Framing:** Full-body portrait standing firmly grounded. The bottom 5–8% of the canvas should align with the character's feet/hooves/claws to rest directly on the 3D ground plinth.
- **Lighting & Palette:** High-contrast gothic grimdark, rim-lit with amber/crimson/pallid moonlight. Deep cast shadows beneath feet.
- **Style:** Detailed physical tabletop miniature, living stone, hardened mineral sinew, cold wrought iron, or bone-and-porcelain.
- **Naming Convention:** `[Faction]_[Archetype]_[Name]_G[1-6].png`  
  *(e.g., `ash_legion_vanguard_iron_footman_g1.png`)*

### 3.2 Faction Plinths & Ground Contact
Units sit on procedural faction plinths rendered in-engine:
- **Ash Legion:** Welded cold-iron bands on charcoal flagstone.
- **Crypt Stalkers:** Weeping arterial stone basins with black lichen.
- **Mire Coven:** Churned wet bog-mud with shelf fungi.
- **Calx Order:** Stark white compass ring with swirling chalk dust.
- **Corrupted Beasts:** Trampled black loam with shattered bone shards.

### 3.3 Tactical Tuning Slips (Spell / Order Cards)
- **Format:** `PNG` or `JPG` with high-contrast borders (16:9 vertical card ratio, e.g., 600×900 px).
- **Framing:** Dark fantasy wargaming slate-foil, engraved stone plate, or brass clockwork plate with an illuminated central rune or figurative spell scene.
- **Content:** The art should depict the alchemical rite in action (e.g., *Siphon Vitality* = crimson threads flowing from an iron husk to a kneeling warrior).

### 3.4 Battlefield Environments
- **Format:** `JPG` (1920×1080 px or 1080×1920 px vertical orientation).
- **Style:** Deep atmospheric perspective, desaturated dark fantasy backgrounds (gothic arches, volcanic chasms, salt flats, ashen woods) designed to support the `LivingAtmosphereBackground` breathing and ember particle engine.

---

## 4. Current Combat Mechanics & Engine Operation

### 4.1 5v5 Dual-Row Grid (Vanguard & Arcanum)
- **Vanguard (Frontline):** Stepped forward toward the central Ashen Front clash line. Takes direct melee hits, grants +10% Poise/Stagger resistance, and generates +15% Action Points when struck.
- **Arcanum (Backline):** Stepped back. Gains **Guarded** buff (-20% damage from single-target ranged strikes while at least one Vanguard ally lives). If all Vanguard allies fall, Arcanum receives full melee pressure.

### 4.2 Initiative & Action Point (AP) Tick Engine
- Ticking occurs at **30 Hz**. Each tick, units accumulate AP based on Speed:
  $$AP_{\text{tick}} = BaseSPD \times (1 + \text{Mod}_{SPD})$$
- When a unit reaches 10,000 AP (100% Turn Meter), the simulation pauses, and the unit executes its designated skill or basic action.
- The upcoming action order is dynamically displayed in real time on the vertical Initiative Ribbon on the screen's left edge.

### 4.3 Alchemical Focus & Tactical Bullet-Time
- **Focus / Vitae Generation:** Focus accumulates passively over time (1 per 30 global logic ticks, or 60 ticks if the Commander is downed). Additionally, **Micro-Vitae** (+0.25 Focus charge progress) is generated whenever an allied construct completes a basic attack or mitigates a hit.
- **Tactical Bullet-Time:** Dragging any Tuning Slip card slows game speed to **30% (0.30x speed)**.
- **Targeting Ghost Bars:**
  - Dragging a damage card (*Siphon Vitality*, *Rend Flesh*) over an enemy tints the targeted health bar chunk in flashing amber/red.
  - Dragging a defensive card (*Sanguine Ward*, *Iron Bulwark*) over an ally displays a proportional white overlay indicating the shield buffer.
  - Hovering *Siphon Vitality* draws a glowing bezier energy tether from the target enemy to the frontline recipient.
- **On-Tempo Vitae Rebate:** Casting a defensive ward or interrupt spell during the final 0.5s of an enemy intent bar refunds +1 instant Vitae ("PERFECT TIMING!").
- **The Burn Pit (Ash Pyre):** Dragging an unwanted card to the incinerator brazier exhausts it for 0 Focus, cycles a new card, and grants +1 instant Focus with an 8-tick redraw cooldown.

---

## 5. Summary Checklist for Creating Assets with Gemini

| Asset Type | File Extension | Background | Size / Aspect | Crucial Visual Rule |
|:---|:---:|:---:|:---:|:---|
| **Unit Miniature** | `.png` | **Transparent (Alpha)** | ~1024×1024 | Clean silhouette, feet aligned to bottom edge, no baked slash or fire effects. |
| **Boss Titan** | `.png` | **Transparent (Alpha)** | ~1024×1024 | Colossal mass, intimidating posture, dramatic rim lighting. |
| **Spell / Order Art** | `.jpg` / `.png` | Opaque / Framed | ~600×900 (2:3) | Central focal action, high contrast, readable in compact cards. |
| **Battlefield Background** | `.jpg` | Opaque | 1080×1920 / 1920×1080 | Desaturated, atmospheric, depth-focused, minimal clutter in lower half. |
| **UI Crest / Icon** | `.png` | **Transparent (Alpha)** | 256×256 / 512×512 | Carved iron, brass, or obsidian with high contrast edge bevels. |
