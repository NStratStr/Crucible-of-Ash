import 'package:flutter/material.dart';

enum FtueStage {
  awakening,       // Screen 1: Awakening — Choose General (Vladislav or Valeria)
  encounter1,      // Screen 2: Encounter 1 — Speed ticks & Vanguard/Arcanum layout
  encounter2,      // Screen 3: Encounter 2 — Hex Wheel affinities & Commander Focus
  crucibleFusion,  // Screen 4: Crucible of Blood — Fuse duplicate hounds into Gen 2 Cerberus Spawn
  encounter3,      // Screen 5: Encounter 3 — Gatekeeper boss defeated by Gen 2 powerhouse
  completed,       // Free play
}

extension FtueStageMeta on FtueStage {
  int get stepNumber {
    switch (this) {
      case FtueStage.awakening:
        return 1;
      case FtueStage.encounter1:
        return 2;
      case FtueStage.encounter2:
        return 3;
      case FtueStage.crucibleFusion:
        return 4;
      case FtueStage.encounter3:
        return 5;
      case FtueStage.completed:
        return 6;
    }
  }

  String get title {
    switch (this) {
      case FtueStage.awakening:
        return 'SCREEN 1: THE AWAKENING';
      case FtueStage.encounter1:
        return 'SCREEN 2: INITIATIVE TICKS';
      case FtueStage.encounter2:
        return 'SCREEN 3: THE HEX WHEEL & FOCUS';
      case FtueStage.crucibleFusion:
        return 'SCREEN 4: CRUCIBLE TRANSMUTATION';
      case FtueStage.encounter3:
        return 'SCREEN 5: GATEKEEPER PURGE';
      case FtueStage.completed:
        return 'CAMPAIGN UNLEASHED';
    }
  }

  String get shortObjective {
    switch (this) {
      case FtueStage.awakening:
        return 'Bind your Progenitor General covenant';
      case FtueStage.encounter1:
        return 'Win skirmish; observe Speed ticks & Vanguard shields';
      case FtueStage.encounter2:
        return 'Exploit Hex affinities and deploy Commander Focus Orders';
      case FtueStage.crucibleFusion:
        return 'Transmute duplicate War-Hounds into Gen 2 Cerberus Spawn';
      case FtueStage.encounter3:
        return 'Vanquish the Ashen Gatekeeper Colossus with your Gen 2 Champion';
      case FtueStage.completed:
        return 'Traverse the Ashen Campaign DAG and challenge the Endgame Gauntlet';
    }
  }

  String get tacticalAdvice {
    switch (this) {
      case FtueStage.awakening:
        return 'Lord Vladislav offers +8% Lifesteal against bleeding targets, while Lady Valeria grants frontline Vanguard +25% Armor and Retaliation.';
      case FtueStage.encounter1:
        return 'The initiative engine ticks Turn Meters toward 100 based on Speed. Frontline Vanguard absorbs melee strikes while backline Arcanum casts safely.';
      case FtueStage.encounter2:
        return 'Clockwise matchups deal +30% damage, counter-clockwise deal 0.75x with 25% Glancing blows. Dealing & taking 500 damage yields 1 Focus point.';
      case FtueStage.crucibleFusion:
        return 'Max-level progenitors transfer 10% of their final stats, plus one grafted passive trait. The resulting Gen 2 beast gains increased level caps and base power.';
      case FtueStage.encounter3:
        return 'The Gatekeeper Colossus possesses immense Armor. Deploy your newly forged Gen 2 Cerberus with Rend Flesh and Commander Focus to breach its defenses.';
      case FtueStage.completed:
        return 'You have mastered the foundational mechanics of Project Ashen Crucible. Forge relics, breed Pureblood Gen 4 titans, and conquer the World Titan.';
    }
  }

  IconData get icon {
    switch (this) {
      case FtueStage.awakening:
        return Icons.auto_awesome;
      case FtueStage.encounter1:
        return Icons.speed;
      case FtueStage.encounter2:
        return Icons.change_circle;
      case FtueStage.crucibleFusion:
        return Icons.local_fire_department;
      case FtueStage.encounter3:
        return Icons.dangerous;
      case FtueStage.completed:
        return Icons.workspace_premium;
    }
  }
}
