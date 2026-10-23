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

  /// Returns 10 stages for any given mission (1 to 10)
  static List<LinearCampaignStage> getStagesForChapter(int missionNumber) {
    switch (missionNumber) {
      case 2:
        return _mission2Stages;
      case 3:
        return _mission3Stages;
      case 4:
        return _mission4Stages;
      case 5:
        return _mission5Stages;
      case 6:
        return _mission6Stages;
      case 7:
        return _mission7Stages;
      case 8:
        return _mission8Stages;
      case 9:
        return _mission9Stages;
      case 10:
        return _mission10Stages;
      case 1:
      default:
        return _mission1Stages;
    }
  }

  // =========================================================================
  // MISSION 1: THE OUTSKIRT WRECKAGE (1-1 to 1-10) • Act I
  // =========================================================================
  static const List<LinearCampaignStage> _mission1Stages = [
    LinearCampaignStage(
      stageNumber: 1,
      stageCode: '1-1',
      name: 'Ashen Outpost',
      description: 'First defensive line breached under scorching ember winds. Subdue and salvage a captive vanguard husk.',
      environmentTitle: 'Perimeter Boundary • Depth 1',
      type: CampaignNodeType.skirmish,
      rewardIchor: 60,
      rewardOre: 10,
      enemyAffinities: [Archetype.juggernaut],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/rotting_husk_g1.png',
    ),
    LinearCampaignStage(
      stageNumber: 2,
      stageCode: '1-2',
      name: 'Sunken Trench',
      description: 'Feral pyrehounds prowling through mud and calcified bones.',
      environmentTitle: 'Trench Ruins • Depth 2',
      type: CampaignNodeType.skirmish,
      rewardIchor: 80,
      rewardOre: 15,
      enemyAffinities: [Archetype.skirmisher],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/feral_warhound.png',
    ),
    LinearCampaignStage(
      stageNumber: 3,
      stageCode: '1-3',
      name: 'Siphon Threshold',
      description: 'Ancient bloodline conduit radiating dark alchemical energy and blood chanters. Conquering this awards your first full summon.',
      environmentTitle: 'Altar Grounds • Depth 3',
      type: CampaignNodeType.skirmish,
      rewardIchor: 100,
      rewardOre: 20,
      enemyAffinities: [Archetype.occultist, Archetype.support],
      hazard: CampaignHazardType.none,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/blood_altar_sigil.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 4,
      stageCode: '1-4',
      name: 'The Scorched Bridge',
      description: 'Lava-infused colossi and fiery vanguard guards blocking the basalt viaduct.',
      environmentTitle: 'Basalt Viaduct • Depth 4',
      type: CampaignNodeType.skirmish,
      rewardIchor: 120,
      rewardOre: 25,
      enemyAffinities: [Archetype.juggernaut, Archetype.skirmisher],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/magma_golem.png',
    ),
    LinearCampaignStage(
      stageNumber: 5,
      stageCode: '1-5',
      name: 'Abyssal Juggernaut',
      description: 'Heavy Dreadnought Colossus clad in wrought iron, crushing intruders.',
      environmentTitle: 'Chamber of Iron • Midpoint Elite',
      type: CampaignNodeType.elite,
      rewardIchor: 160,
      rewardOre: 35,
      enemyAffinities: [Archetype.juggernaut, Archetype.marksman],
      hazard: CampaignHazardType.none,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/ironclad_dreadnought.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 6,
      stageCode: '1-6',
      name: 'Smoldering Haven',
      description: 'Soulfire embers provide refuge, guarded by fallen sentinel remnants.',
      environmentTitle: 'Rest Haven • Depth 6',
      type: CampaignNodeType.skirmish,
      rewardIchor: 140,
      rewardOre: 20,
      enemyAffinities: [Archetype.support, Archetype.skirmisher],
      hazard: CampaignHazardType.none,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/bone_campfire.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 7,
      stageCode: '1-7',
      name: 'Ravenwood Thicket',
      description: 'Winged crypt stalkers and feral beasts ambushing from petrified groves.',
      environmentTitle: 'Blighted Forest • Depth 7',
      type: CampaignNodeType.skirmish,
      rewardIchor: 180,
      rewardOre: 30,
      enemyAffinities: [Archetype.assassin, Archetype.skirmisher],
      hazard: CampaignHazardType.miasmaMire,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/cerberus_pureblood.png',
    ),
    LinearCampaignStage(
      stageNumber: 8,
      stageCode: '1-8',
      name: 'Plague Altar of the Flayed',
      description: 'Corrupted zealots offering calcified marrow to the flayed titans.',
      environmentTitle: 'Desecrated Crypt • Depth 8',
      type: CampaignNodeType.skirmish,
      rewardIchor: 200,
      rewardOre: 35,
      enemyAffinities: [Archetype.occultist, Archetype.juggernaut],
      hazard: CampaignHazardType.miasmaMire,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/plague_occultist.jpg',
    ),
    LinearCampaignStage(
      stageNumber: 9,
      stageCode: '1-9',
      name: 'Spire of the Fallen Sentinels',
      description: 'Ancient watchtower teeming with sharpshooters and void balistas.',
      environmentTitle: 'Obsidian Spire • Depth 9',
      type: CampaignNodeType.elite,
      rewardIchor: 250,
      rewardOre: 45,
      enemyAffinities: [Archetype.marksman, Archetype.assassin],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
      thumbnailAsset: 'assets/images/ballista_pureblood.png',
    ),
    LinearCampaignStage(
      stageNumber: 10,
      stageCode: '1-10',
      name: 'Gorgoroth the Flayed',
      description: 'The Chapter World Titan towering over the Ashen Rift in a raging fire vortex.',
      environmentTitle: 'Titan Throne • CHAPTER I CLIMAX',
      type: CampaignNodeType.boss,
      rewardIchor: 500,
      rewardOre: 80,
      rewardSigils: 1,
      enemyAffinities: [Archetype.juggernaut, Archetype.occultist, Archetype.assassin, Archetype.marksman],
      hazard: CampaignHazardType.ashenEmberStorm,
      backgroundAsset: 'assets/images/volcanic_chasm_battlefield.jpg',
      thumbnailAsset: 'assets/images/flayed_butcher.png',
      isBoss: true,
    ),
  ];

  // Helper factory to generate generic regional stages
  static List<LinearCampaignStage> _buildGenericStages(int mission, String zoneName, String bgAsset, String bossName, String bossAsset) {
    return List.generate(10, (i) {
      final stageNum = i + 1;
      final isBoss = stageNum == 10;
      final isElite = stageNum == 5 || stageNum == 9;
      return LinearCampaignStage(
        stageNumber: stageNum,
        stageCode: '$mission-$stageNum',
        name: isBoss ? bossName : (isElite ? '$zoneName Vanguard Elite' : '$zoneName Sector $stageNum'),
        description: isBoss
            ? 'The apex guardian of the $zoneName. Defeat it to secure the regional catalyst!'
            : 'Clear enemy scouting battalions holding defensive fortifications in $zoneName.',
        environmentTitle: '$zoneName • Stage $stageNum',
        type: isBoss ? CampaignNodeType.boss : (isElite ? CampaignNodeType.elite : CampaignNodeType.skirmish),
        rewardIchor: isBoss ? 1200 + mission * 150 : 200 + stageNum * 20,
        rewardOre: isBoss ? 120 + mission * 15 : 25 + stageNum * 4,
        rewardSigils: isBoss ? 2 + (mission ~/ 3) : (isElite ? 1 : 0),
        enemyAffinities: [
          Archetype.values[stageNum % Archetype.values.length],
          Archetype.values[(stageNum + 2) % Archetype.values.length],
        ],
        hazard: mission % 2 == 0 ? CampaignHazardType.miasmaMire : CampaignHazardType.ashenEmberStorm,
        backgroundAsset: bgAsset,
        thumbnailAsset: isBoss ? bossAsset : (isElite ? 'assets/images/ironclad_dreadnought.jpg' : bgAsset),
        isBoss: isBoss,
      );
    });
  }

  static final List<LinearCampaignStage> _mission2Stages = _buildGenericStages(2, 'Smoldering Barricade', 'assets/images/ashen_trail_desolation.jpg', 'Slag-Carapace Sentinel', 'assets/images/magma_golem.png');
  static final List<LinearCampaignStage> _mission3Stages = _buildGenericStages(3, 'Resonance Beacon Perimeter', 'assets/images/ashen_trail_desolation.jpg', 'Ash-Storm Colossus', 'assets/images/flayed_butcher.png');
  static final List<LinearCampaignStage> _mission4Stages = _buildGenericStages(4, 'Forge-Master\'s Gate', 'assets/images/volcanic_chasm_battlefield.jpg', 'Dreadnought Forge-Master', 'assets/images/ironclad_dreadnought.jpg');
  static final List<LinearCampaignStage> _mission5Stages = _buildGenericStages(5, 'The Molten Caldera', 'assets/images/volcanic_chasm_battlefield.jpg', 'Pyre Drake Gorgoroth', 'assets/images/flayed_butcher.png');
  static final List<LinearCampaignStage> _mission6Stages = _buildGenericStages(6, 'The Glass Scriptorium', 'assets/images/gothic_arch_battlefield.jpg', 'Arch-Lich Malakor', 'assets/images/plague_occultist.jpg');
  static final List<LinearCampaignStage> _mission7Stages = _buildGenericStages(7, 'The Petrified Bog-Lands', 'assets/images/gothic_arch_battlefield.jpg', 'Mother Morrigan\'s Avatar', 'assets/images/cerberus_pureblood.png');
  static final List<LinearCampaignStage> _mission8Stages = _buildGenericStages(8, 'The Obsidian Sepulcher', 'assets/images/gothic_arch_battlefield.jpg', 'Strigoi Blood-Lord', 'assets/images/strigoi_lord_g6.png');
  static final List<LinearCampaignStage> _mission9Stages = _buildGenericStages(9, 'The Tectonic Trench', 'assets/images/volcanic_chasm_battlefield.jpg', 'Tectonic Engine Juggernaut', 'assets/images/magma_golem.png');
  static final List<LinearCampaignStage> _mission10Stages = _buildGenericStages(10, 'Siege of the Ash-Spire', 'assets/images/realm_overworld_map.jpg', 'Grand Inquisitor of the Pyre', 'assets/images/lord_justicar_g6.png');
}
