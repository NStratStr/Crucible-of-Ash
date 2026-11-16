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
        return 'ACT I: THE AWAKENING';
      case FtueStage.encounter1:
        return 'STAGE 1-1: ASHEN OUTPOST';
      case FtueStage.encounter2:
        return 'STAGE 1-2: SUNKEN TRENCH';
      case FtueStage.crucibleFusion:
        return 'STAGE 1-3: SIPHON THRESHOLD';
      case FtueStage.encounter3:
        return 'STAGE 1-5: ABYSSAL JUGGERNAUT';
      case FtueStage.completed:
        return 'CAMPAIGN UNLEASHED';
    }
  }

  String get shortObjective {
    switch (this) {
      case FtueStage.awakening:
        return 'Choose your Ash Sculptor Crucible Discipline';
      case FtueStage.encounter1:
        return 'Clear Ashen Outpost solo to rescue your Vanguard Husk & earn +1★ Skill Point';
      case FtueStage.encounter2:
        return 'Unlock Slot 2 in the Skill Tree and defeat the Sunken Trench pack';
      case FtueStage.crucibleFusion:
        return 'Conquer Siphon Threshold to recruit your 2nd Retinue companion';
      case FtueStage.encounter3:
        return 'Challenge the Abyssal Juggernaut Elite with your 3-unit squad';
      case FtueStage.completed:
        return 'Conquer Chapter 1, forge Relics, and unlock Apex Crucible skills';
    }
  }

  String get tacticalAdvice {
    switch (this) {
      case FtueStage.awakening:
        return 'Your Discipline sets your starting Slot 1 Cinder generator. You will unlock Slots 2–5 and higher ranks by earning Skill Points from campaign victories.';
      case FtueStage.encounter1:
        return 'Drag your Ash Sculptor between Frontline, Midline, and Backline lanes to intercept or flank. Winning 1-1 rescues a Vanguard Husk and grants +1★ Skill Point.';
      case FtueStage.encounter2:
        return 'Open the Crucible Skill Tree (top HUD or Citadel Home) to spend your ★ Skill Point on a Slot 2 Cinder spender, then deploy your Vanguard Husk in front.';
      case FtueStage.crucibleFusion:
        return 'Use Cinders from basic strikes to unleash heavy skills and stagger armored foes. Clearing 1-3 recruits a Grave Duelist into your 3rd squad slot.';
      case FtueStage.encounter3:
        return 'With a 3-unit squad and 3+ Skill Points invested, exploit flanking trajectories and Retinue passives to break the Abyssal Juggernaut and claim your first Rare Relic.';
      case FtueStage.completed:
        return 'Expand your roster in the Retinue Squad & Crucible Altar, equip Relics from the Forge, and push toward the Chapter 1 Boss.';
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
