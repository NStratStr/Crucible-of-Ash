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
        return 'Clear Ashen Outpost solo to earn +1 Sigil (Summon) & +1★ Skill Point';
      case FtueStage.encounter2:
        return 'Summon your 1st Companion, unlock Slot 2 Skill, and clear Sunken Trench';
      case FtueStage.crucibleFusion:
        return 'Conquer Stage 1-3: Siphon Threshold to push toward the Elite Trial';
      case FtueStage.encounter3:
        return 'Challenge the Abyssal Juggernaut Elite with your expanded squad';
      case FtueStage.completed:
        return 'Conquer Chapter 1, forge Relics, and unlock Apex Crucible skills';
    }
  }

  String get tacticalAdvice {
    switch (this) {
      case FtueStage.awakening:
        return 'Your Discipline sets your starting Slot 1 Cinder generator. You will unlock Slots 2–5 and higher ranks by earning Skill Points from campaign victories.';
      case FtueStage.encounter1:
        return 'Drag your Ash Sculptor between Frontline, Midline, and Backline lanes to intercept or flank. Winning 1-1 awards +1 Sigil to Summon an ally & +1★ Skill Point.';
      case FtueStage.encounter2:
        return 'Use your Sigil at the Summoning Altar to summon a companion, then unlock a Slot 2 skill in the Crucible Skill Tree and clear Stage 1-2.';
      case FtueStage.crucibleFusion:
        return 'Use Cinders from basic strikes to unleash heavy skills, stagger armored foes, and clear Stage 1-3.';
      case FtueStage.encounter3:
        return 'Upgrade Hospice Gates Tier II to field a 3-unit squad, then exploit flanking trajectories and passives to break the Abyssal Juggernaut and claim a Rare Relic.';
      case FtueStage.completed:
        return 'Expand your roster at the Summoning Altar & Blood Altar, equip Relics from the Forge, and push toward the Chapter 1 Boss.';
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
