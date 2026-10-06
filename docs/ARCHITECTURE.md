# PROJECT ARCHITECTURE & DEVELOPER GUIDE
**Project Ashen Crucible**  
*Flutter / Dart Codebase*

---

## 1. Directory Structure

```
lib/
├── core/
│   ├── combat_math.dart              # Hexagonal affinity wheel, mitigation, damage formula
│   └── theme/
│       └── ashen_theme.dart          # Gothic dark fantasy UI tokens, colors, gradients
├── features/
│   ├── combat/
│   │   ├── battle_screen.dart        # 5v5 battle view with active turn highlight and orders HUD
│   │   ├── combat_resolution_service.dart # Basic attack resolution, lifesteal, damage commit
│   │   └── initiative_tick_manager.dart   # Turn-meter tick engine, tie-breaking, pause loop
│   ├── crucible/
│   │   ├── crucible_screen.dart      # Generational fusion altar, preview calculation, rituals
│   │   └── crucible_service.dart     # Pure stat inheritance math, trait grafting logic
│   └── generals/
│       └── general_command_service.dart # Focus accumulation, Vladislav / Valeria Orders
├── shared/
│   ├── data/
│   │   └── starter_brigades.dart     # Mock rosters, starter hounds, tutorial enemies, boss
│   ├── models/
│   │   └── unit_entity.dart          # Immutable unit models, formation slots, stats
│   └── widgets/
│       └── app_shell.dart            # Main navigation shell (Battle, Crucible, Lore/Roster)
└── main.dart                         # Flutter entrypoint
```

---

## 2. Testing Strategy & Test Suites

The codebase is built test-first with decoupled pure services:

| Test File | Target Service | Coverage |
|---|---|---|
| `test/core/combat_math_test.dart` | `CombatMath` | 6-role hex wheel (+1 strong, +5 weak, neutrals), defense mitigation curve, glancing blows |
| `test/features/combat/initiative_tick_manager_test.dart` | `InitiativeTickManager` | Speed tick increments, 100 TM action pause, overflow tie-breaking, speed tie-breaking, alive filtering |
| `test/features/combat/combat_resolution_service_test.dart` | `CombatResolutionService` | Action resolution, damage scaling, lifesteal healing, target defeat, turn consumption |
| `test/features/crucible/crucible_service_test.dart` | `CrucibleService` | 10% max-level transfer, 5% premature transfer, 3-gen compounding, trait grafting |
| `test/features/generals/general_command_service_test.dart` | `GeneralCommandService` | Focus buildup (500 dmg threshold), Siphon Vitality, Sanguine Ward, Feast of Ruin |

To run the complete test suite:
```bash
flutter test
```

---

## 3. Key Conventions for Multi-Prompt Expansion

When prompting Antigravity to build subsequent phases:
1. **Never break immutable entity patterns**: `UnitEntity` uses `copyWith` and returns new immutable copies.
2. **Keep the engine decoupled from UI**: The `InitiativeTickManager` can be tested purely headless in Dart without widgets.
3. **Use the 6-Role Hexagon**: Always evaluate archetype relations using `CombatMath.getAffinityMultiplier`.
4. **Follow the Generational Cap**: Ensure generations compound up to Generation 4 (`Pureblood`).
