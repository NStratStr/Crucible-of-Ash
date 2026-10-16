import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import 'campaign_node.dart';

class LinearCampaignStage {
  final int stageNumber;
  final String stageCode; // e.g. "1-1"
  final String name;
  final String description;
  final String environmentTitle;
  final CampaignNodeType type;
  final int rewardIchor;
  final int rewardOre;
  final int rewardSigils;
  final List<Archetype> enemyAffinities;
  final CampaignHazardType hazard;
  final String backgroundAsset;
  final String thumbnailAsset;
  final bool isBoss;

  const LinearCampaignStage({
    required this.stageNumber,
    required this.stageCode,
    required this.name,
    required this.description,
    required this.environmentTitle,
    required this.type,
    required this.rewardIchor,
    required this.rewardOre,
    this.rewardSigils = 0,
    required this.enemyAffinities,
    this.hazard = CampaignHazardType.none,
    required this.backgroundAsset,
    required this.thumbnailAsset,
    this.isBoss = false,
  });

  static List<LinearCampaignStage> getStagesForChapter(int chapter) {
    switch (chapter) {
      case 2:
        return _chapter2Stages;
      case 3:
        return _chapter3Stages;
      case 1:
      default:
        return _chapter1Stages;
    }
  }

  static const List<LinearCampaignStage> _chapter1Stages = [
    LinearCampaignStage(
      stageNumber: 1,
      stageCode: '1-1',
      name: 'Ashen Outpost',
      description: 'First defensive line breached under scorching ember winds.',
      environmentTitle: 'Perimeter Boundary • Depth 1',
      type: CampaignNodeType.skirmish,
      rewardIchor: 150,
      rewardOre: 20,
      enemyAffinities: [Archetype.juggernaut, Archetype.marksman],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/ashen_trail_desolation.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 2,
      stageCode: '1-2',
      name: 'Sunken Trench',
      description: 'Feral war-hounds prowling through the mud and calcified bones.',
      environmentTitle: 'Trench Ruins • Depth 2',
      type: CampaignNodeType.skirmish,
      rewardIchor: 180,
      rewardOre: 25,
      enemyAffinities: [Archetype.skirmisher, Archetype.occultist],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/feral_warhound.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 3,
      stageCode: '1-3',
      name: 'Siphon Threshold',
      description: 'Ancient bloodline conduit radiating dark alchemical energy.',
      environmentTitle: 'Altar Grounds • Depth 3',
      type: CampaignNodeType.altar,
      rewardIchor: 220,
      rewardOre: 30,
      rewardSigils: 1,
      enemyAffinities: [Archetype.occultist, Archetype.support],
      hazard: CampaignHazardType.none,
      backgroundAsset: 'assets/images/blood_altar_sigil.jpg',
      thumbnailAsset: 'assets/images/blood_altar_sigil.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 4,
      stageCode: '1-4',
      name: 'The Scorched Bridge',
      description: 'Armored vanguard patrols blocking the passage across the volcanic ravine.',
      environmentTitle: 'Basalt Viaduct • Depth 4',
      type: CampaignNodeType.skirmish,
      rewardIchor: 250,
      rewardOre: 35,
      enemyAffinities: [Archetype.juggernaut, Archetype.assassin],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/volcanic_chasm_battlefield.jpg',
      thumbnailAsset: 'assets/images/volcanic_chasm_battlefield.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 5,
      stageCode: '1-5',
      name: 'Abyssal Juggernaut',
      description: 'Elite heavy guardian wielding an iron slab in the storm eye.',
      environmentTitle: 'Chamber of Iron • Midpoint Elite',
      type: CampaignNodeType.elite,
      rewardIchor: 350,
      rewardOre: 50,
      rewardSigils: 1,
      enemyAffinities: [Archetype.juggernaut, Archetype.occultist, Archetype.marksman],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ironclad_dreadnought.jpg',
      thumbnailAsset: 'assets/images/ironclad_dreadnought.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 6,
      stageCode: '1-6',
      name: 'Smoldering Haven',
      description: 'Sanctuary fires burning with soul embers. Bind wounds and rearm.',
      environmentTitle: 'Rest Haven • Depth 6',
      type: CampaignNodeType.restHaven,
      rewardIchor: 150,
      rewardOre: 20,
      enemyAffinities: [],
      hazard: CampaignHazardType.none,
      backgroundAsset: 'assets/images/bone_campfire.jpg',
      thumbnailAsset: 'assets/images/bone_campfire.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 7,
      stageCode: '1-7',
      name: 'Ravenwood Thicket',
      description: 'Winged crypt stalkers ambushing from the blackened branches.',
      environmentTitle: 'Blighted Forest • Depth 7',
      type: CampaignNodeType.skirmish,
      rewardIchor: 280,
      rewardOre: 40,
      enemyAffinities: [Archetype.skirmisher, Archetype.marksman],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/ashen_trail_desolation.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 8,
      stageCode: '1-8',
      name: 'Obsidian Spire',
      description: 'High watchtower overlooking the Ashen Rift and the Titan lair.',
      environmentTitle: 'Observation Spire • Depth 8',
      type: CampaignNodeType.watchtower,
      rewardIchor: 200,
      rewardOre: 45,
      enemyAffinities: [],
      hazard: CampaignHazardType.none,
      backgroundAsset: 'assets/images/realm_overworld_map.jpg',
      thumbnailAsset: 'assets/images/realm_overworld_map.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 9,
      stageCode: '1-9',
      name: 'Chained Sarcophagus',
      description: 'Ancient lineage crypt holding sealed progenitor blood.',
      environmentTitle: 'Defiled Crypt • Depth 9',
      type: CampaignNodeType.crypt,
      rewardIchor: 300,
      rewardOre: 50,
      rewardSigils: 1,
      enemyAffinities: [Archetype.occultist, Archetype.assassin],
      hazard: CampaignHazardType.none,
      backgroundAsset: 'assets/images/gothic_arch_battlefield.jpg',
      thumbnailAsset: 'assets/images/gothic_arch_battlefield.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 10,
      stageCode: '1-10',
      name: 'Gorgoroth the Flayed',
      description: 'The Chapter World Titan towering over the Ashen Rift in a raging fire vortex.',
      environmentTitle: 'Titan Throne • CHAPTER I CLIMAX',
      type: CampaignNodeType.boss,
      rewardIchor: 1000,
      rewardOre: 100,
      rewardSigils: 2,
      enemyAffinities: [Archetype.juggernaut, Archetype.occultist, Archetype.assassin, Archetype.marksman],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/flayed_butcher.jpg',
      thumbnailAsset: 'assets/images/flayed_butcher.jpg',
      isBoss: true,
    ),
  ];

  static const List<LinearCampaignStage> _chapter2Stages = [
    LinearCampaignStage(
      stageNumber: 1,
      stageCode: '2-1',
      name: 'Sunken Crypt Entrance',
      description: 'Mire vapors choke the flooded necropolis arches.',
      environmentTitle: 'Submerged Tombs • Depth 1',
      type: CampaignNodeType.skirmish,
      rewardIchor: 250,
      rewardOre: 35,
      enemyAffinities: [Archetype.skirmisher, Archetype.occultist],
      hazard: CampaignHazardType.miasmaMire,
      backgroundAsset: 'assets/images/gothic_arch_battlefield.jpg',
      thumbnailAsset: 'assets/images/gothic_arch_battlefield.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 5,
      stageCode: '2-5',
      name: 'Plague Alchemist Coven',
      description: 'Corrosive alchemists distilling necrotic plague cauldrons.',
      environmentTitle: 'Alchemical Sanctum • Depth 5',
      type: CampaignNodeType.elite,
      rewardIchor: 500,
      rewardOre: 70,
      rewardSigils: 1,
      enemyAffinities: [Archetype.occultist, Archetype.juggernaut],
      hazard: CampaignHazardType.miasmaMire,
      backgroundAsset: 'assets/images/plague_occultist.jpg',
      thumbnailAsset: 'assets/images/plague_occultist.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 10,
      stageCode: '2-10',
      name: 'Malakor the Carrion Father',
      description: 'Ancient necromancer commanding decaying legions from the sunken mire.',
      environmentTitle: 'Carrion Cathedral • CHAPTER II CLIMAX',
      type: CampaignNodeType.boss,
      rewardIchor: 1500,
      rewardOre: 150,
      rewardSigils: 3,
      enemyAffinities: [Archetype.occultist, Archetype.juggernaut, Archetype.skirmisher],
      hazard: CampaignHazardType.miasmaMire,
      backgroundAsset: 'assets/images/plague_occultist.jpg',
      thumbnailAsset: 'assets/images/plague_occultist.jpg',
      isBoss: true,
    ),
  ];

  static const List<LinearCampaignStage> _chapter3Stages = [
    LinearCampaignStage(
      stageNumber: 1,
      stageCode: '3-1',
      name: 'Abyssal Void Rift',
      description: 'Gravity fluctuates as reality cracks into the void.',
      environmentTitle: 'Fractured Realm • Depth 1',
      type: CampaignNodeType.skirmish,
      rewardIchor: 400,
      rewardOre: 60,
      enemyAffinities: [Archetype.assassin, Archetype.marksman],
      hazard: CampaignHazardType.voidDistortion,
      backgroundAsset: 'assets/images/realm_overworld_map.jpg',
      thumbnailAsset: 'assets/images/realm_overworld_map.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 10,
      stageCode: '3-10',
      name: 'The Void Sovereign Colossus',
      description: 'The ancient titan that ruptured the Undying Hearth.',
      environmentTitle: 'Core Hearth • FINAL ASCENSION',
      type: CampaignNodeType.boss,
      rewardIchor: 3000,
      rewardOre: 250,
      rewardSigils: 5,
      enemyAffinities: [Archetype.juggernaut, Archetype.occultist, Archetype.assassin, Archetype.marksman, Archetype.support],
      hazard: CampaignHazardType.voidDistortion,
      backgroundAsset: 'assets/images/realm_overworld_map.jpg',
      thumbnailAsset: 'assets/images/realm_overworld_map.jpg',
      isBoss: true,
    ),
  ];
}
