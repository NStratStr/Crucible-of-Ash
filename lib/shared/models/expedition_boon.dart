import 'package:flutter/material.dart';

enum ExpeditionBoon {
  sanguineCovenant,   // +15% Squad Attack & +15% Crit DMG
  obsidianAegis,      // +20% Squad Defense
  vitalityWellspring, // +15% Lifesteal
}

extension ExpeditionBoonExtension on ExpeditionBoon {
  String get displayName {
    switch (this) {
      case ExpeditionBoon.sanguineCovenant:
        return 'Sanguine Covenant (+15% ATK/CRIT)';
      case ExpeditionBoon.obsidianAegis:
        return 'Obsidian Aegis (+20% DEF)';
      case ExpeditionBoon.vitalityWellspring:
        return 'Vitality Wellspring (+15% Lifesteal)';
    }
  }

  String get description {
    switch (this) {
      case ExpeditionBoon.sanguineCovenant:
        return '+15% Squad Attack and +15% Critical Damage amplification.';
      case ExpeditionBoon.obsidianAegis:
        return '+20% Squad Defense mitigation against enemy strikes.';
      case ExpeditionBoon.vitalityWellspring:
        return '+15% Lifesteal vitality recovery on all physical & magical strikes.';
    }
  }

  Color get color {
    switch (this) {
      case ExpeditionBoon.sanguineCovenant:
        return const Color(0xFFFF7043);
      case ExpeditionBoon.obsidianAegis:
        return const Color(0xFF78909C);
      case ExpeditionBoon.vitalityWellspring:
        return const Color(0xFFE91E63);
    }
  }

  IconData get icon {
    switch (this) {
      case ExpeditionBoon.sanguineCovenant:
        return Icons.whatshot;
      case ExpeditionBoon.obsidianAegis:
        return Icons.shield;
      case ExpeditionBoon.vitalityWellspring:
        return Icons.water_drop;
    }
  }
}
