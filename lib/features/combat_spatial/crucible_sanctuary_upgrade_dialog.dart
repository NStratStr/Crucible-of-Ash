import 'dart:math';
import 'package:flutter/material.dart';
import 'models/crucible_skill_tree_models.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';

class CrucibleSanctuaryUpgradeDialog extends StatefulWidget {
  final SpatialCombatEngine engine;

  const CrucibleSanctuaryUpgradeDialog({
    super.key,
    required this.engine,
  });

  static Future<void> show(BuildContext context, SpatialCombatEngine engine) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CrucibleSanctuaryUpgradeDialog(engine: engine),
    );
  }

  @override
  State<CrucibleSanctuaryUpgradeDialog> createState() => _CrucibleSanctuaryUpgradeDialogState();
}

class _CrucibleSanctuaryUpgradeDialogState extends State<CrucibleSanctuaryUpgradeDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final minions = engine.playerUnits.where((u) => !u.isAshSculptor && u.id != 'ash_sculptor').toList();
    final sculptor = engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 720,
        height: 600,
        decoration: BoxDecoration(
          color: const Color(0xFF13111A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            const BoxShadow(color: Colors.black87, blurRadius: 20),
          ],
        ),
        child: Column(
          children: [
            // Header Bar: Title + Crypt Currencies + Close
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1926),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'CRUCIBLE FORGE SANCTUARY',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),

                  // Currencies / Drops Counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0A12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFB0BEC5).withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.blur_on, size: 12, color: Color(0xFFB0BEC5)),
                        const SizedBox(width: 3),
                        Text(
                          '${engine.unboundAshWallet} ASH',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0A12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.opacity, size: 12, color: Color(0xFFFF5252)),
                        const SizedBox(width: 3),
                        Text(
                          '${engine.distilledVitaeWallet} VITAE',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFFF8A80)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0A12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF80D8FF).withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.foundation, size: 12, color: Color(0xFF80D8FF)),
                        const SizedBox(width: 3),
                        Text(
                          '${engine.petrifiedPlinthsWallet} PLINTHS',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF80D8FF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: const Color(0xFF14121C),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFFD54F),
                indicatorWeight: 2.5,
                labelColor: const Color(0xFFFFD54F),
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                tabs: const [
                  Tab(icon: Icon(Icons.shield, size: 14), text: 'RETINUE MINIONS'),
                  Tab(icon: Icon(Icons.local_fire_department, size: 14), text: 'ASH SCULPTOR & SKILLS'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Retinue Minions
                  _buildMinionsTab(minions),

                  // Tab 2: Ash Sculptor
                  _buildSculptorTab(sculptor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinionsTab(List<CombatUnitState> minions) {
    if (minions.isEmpty) {
      return const Center(
        child: Text(
          'No living retinue companions deployed in current formation.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: minions.map((minion) => _buildMinionCard(minion)).toList(),
    );
  }

  Widget _buildMinionCard(CombatUnitState minion) {
    final String key = '${minion.id.toLowerCase()}_${minion.templateId.toLowerCase()}';
    final bool isFootman = key.contains('footman');
    final bool isDuelist = key.contains('duelist');
    final bool isReaver = key.contains('reaver');
    final bool isSentinel = key.contains('sentinel');
    final bool isScribe = key.contains('scribe');
    final bool isChanter = key.contains('chanter');
    final bool isMedicus = key.contains('medicus') || key.contains('cleric');
    final bool isArbalest = key.contains('arbalest') || key.contains('mortar');

    final String basicTitle = isFootman ? 'Shieldbash Cleave'
        : (isDuelist ? 'Flensing Twin-Thrust'
        : (isReaver ? 'Molten Execution'
        : (isSentinel ? 'Tectonic Impact'
        : (isScribe ? 'Arterial Siphon'
        : (isChanter ? 'Curse of Inertia'
        : (isMedicus ? 'Mending Luminescence'
        : (isArbalest ? 'Piercing Volley' : 'Skirmish Thrust')))))));

    final String basicDesc = isFootman
        ? 'Strikes foe for 115% ATK, permanently shreds -12 Armor & grants +15 Aegis Barrier to self.'
        : (isDuelist
            ? 'Strikes foe for 120% ATK + 2 Bleeds. Deals +30% CRIT & refunds +1,500 AP on bleeding foes.'
            : (isReaver
                ? 'Heavy slash dealing 130% ATK (+35% bonus execution damage against targets below 50% HP).'
                : (isSentinel
                    ? '125% ATK heavy slam. Stuns target if target has >= 30 Armor and shreds -15 Armor.'
                    : (isScribe
                        ? 'Drains 110% ATK from target, converting 25% of damage dealt into team healing.'
                        : (isChanter
                            ? 'Applies Slow hex, reducing target Action Gauge accumulation rate by -25%.'
                            : (isMedicus
                                ? 'Strikes foe for 95% ATK and restores +45 HP (+15% Max HP) to lowest ally.'
                                : (isArbalest
                                    ? 'Fires armor-piercing projectile penetrating through the target entire column.'
                                    : 'Basic strike against frontline enemies.')))))));

    final String sigTitle = isFootman ? "Bastion's Aegis"
        : (isDuelist ? 'Phantom Ambush'
        : (isReaver ? 'Rending Decapitation'
        : (isSentinel ? 'Tectonic Fortress'
        : (isScribe ? 'Sanguine Wellspring'
        : (isChanter ? 'Chronos Miasma'
        : (isMedicus ? 'Purifying Bloom'
        : (isArbalest ? 'Cluster Mortar' : minion.signatureSkillName)))))));

    final String sigDesc = isFootman
        ? "Auto-triggers every 3 turns: Slams greatshield, granting +40 Aegis Barrier to BOTH self AND the Ash Sculptor + staggers foes by -2,000 AP."
        : (isDuelist
            ? "Auto-triggers every 3 turns: Blinks behind target for 185% ATK CRIT (+3 Bleeds) and channels +12 Cinders directly into the Sculptor."
            : (isReaver
                ? "Auto-triggers every 3 turns: Unleashes 240% True DMG execute on lowest HP foe + grants +15 Cinders on kill."
                : (isSentinel
                    ? "Auto-triggers every 3 turns: Grants +35 Aegis Barrier to all allies & intercepts 50% damage directed at Sculptor."
                    : (isScribe
                        ? "Auto-triggers every 3 turns: Heals all allies for 25% Max HP & channels +8 Cinders directly to the Sculptor."
                        : (isChanter
                            ? "Auto-triggers every 3 turns: Halts enemy AP gauges by -3,000 AP & grants 3s Haste to all allies."
                            : (isMedicus
                                ? "Auto-triggers every 3 turns: Cleanses all debuffs across the squad and heals all allies for 35% Max HP."
                                : (isArbalest
                                    ? "Auto-triggers every 3 turns: Blankets all 3 enemy columns with fire, dealing 160% AoE DMG."
                                    : "Auto-triggers signature skill every 3 actions.")))))));

    final String passiveTitle = isFootman ? 'Bulwark Oath'
        : (isDuelist ? "Stalker's Keen Edge"
        : (isReaver ? "Reaver's Ferocity"
        : (isSentinel ? 'Grave Carapace'
        : (isScribe ? 'Vitae Bond'
        : (isChanter ? 'Temporal Weft'
        : (isMedicus ? 'Aura of Vitality'
        : (isArbalest ? 'Siege Resonator' : 'Retinue Bond')))))));

    final String passiveDesc = isFootman
        ? 'While Iron Footman is alive: The Ash Sculptor gains +25 Armor and takes 15% reduced damage from all sources.'
        : (isDuelist
            ? 'While Grave Duelist is alive: The Ash Sculptor gains +15% Critical Chance and generates +4 bonus Cinders on critical strikes.'
            : (isReaver
                ? 'While Pyre Reaver is alive: The Ash Sculptor gains +20% Attack Multiplier and +8 Cinders on enemy takedowns.'
                : (isSentinel
                    ? 'While Stone Sentinel is alive: The Ash Sculptor gains +35% Barrier Capacity and Stagger Immunity.'
                    : (isScribe
                        ? 'While Blood Scribe is alive: The Ash Sculptor gains +18% Lifesteal and +2 Cinders on bleed ticks.'
                        : (isChanter
                            ? 'While Miasma Chanter is alive: The Ash Sculptor gains -20% Skill Cooldowns and +2,000 AP tempo.'
                            : (isMedicus
                                ? 'While Sanctified Medicus is alive: The Ash Sculptor gains +25% Healing Power and +3% Max HP regen per tick.'
                                : (isArbalest
                                    ? 'While Cinder Arbalest is alive: The Ash Sculptor gains +25% AoE Damage and +1 AoE splash radius.'
                                    : 'Passively empowers commander.')))))));

    final int upgradeCost = 120;
    final bool canUpgrade = widget.engine.unboundAshWallet >= upgradeCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181622),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Minion Header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  minion.assetPath,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        minion.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'LV. ${minion.level}',
                          style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 8.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HP ${minion.hp}/${minion.maxHp}  •  ATK ${minion.attack}  •  ARM ${minion.armor}  •  SPD ${minion.speed}',
                    style: const TextStyle(color: Color(0xFF80D8FF), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.upgrade, size: 13),
                label: Text(
                  'REFORGE ($upgradeCost ASH)',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canUpgrade ? const Color(0xFFFF6D00) : const Color(0xFF2E241E),
                  foregroundColor: canUpgrade ? Colors.white : Colors.white38,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: canUpgrade
                    ? () {
                        setState(() {
                          widget.engine.upgradeMinion(minion.id);
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Unique Basic Attack Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF263238),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('BASIC', style: TextStyle(color: Color(0xFF90CAF9), fontSize: 7.5, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      basicTitle,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    Text(basicDesc, style: const TextStyle(color: Colors.white70, fontSize: 8.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 3-Turn Signature Skill Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E2723),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('SIGNATURE', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 7.5, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sigTitle (Every 3 Turns)',
                      style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    Text(sigDesc, style: const TextStyle(color: Colors.white70, fontSize: 8.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Passive Given to the Sculptor
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('PASSIVE AURA', style: TextStyle(color: Color(0xFF69F0AE), fontSize: 7.5, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$passiveTitle ➔ Given to Ash Sculptor',
                      style: const TextStyle(color: Color(0xFF69F0AE), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    Text(passiveDesc, style: const TextStyle(color: Colors.white70, fontSize: 8.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSculptorTab(CombatUnitState? sculptor) {
    if (sculptor == null) {
      return const Center(child: Text('Sculptor unit not found.', style: TextStyle(color: Colors.white)));
    }

    final engine = widget.engine;
    final bool canAscend = engine.unboundAshWallet >= 200 && engine.distilledVitaeWallet >= 20;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Sculptor Furnace Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1622),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFF6D00), width: 1.2),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  sculptor.assetPath,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Color(0xFFFF6D00), size: 32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THE ASH SCULPTOR (COMMANDER)',
                      style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'HP ${sculptor.hp}/${sculptor.maxHp}  •  ATK ${sculptor.attack}  •  ARM ${sculptor.armor}  •  CINDERS ${sculptor.crucibleCinders}/100',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (engine.isBulwarkOathActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(3)),
                            child: const Text('🛡️ BULWARK (+25 ARM, -15% DMG)', style: TextStyle(color: Color(0xFFB9F6CA), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        if (engine.isStalkerKeenEdgeActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFFB71C1C), borderRadius: BorderRadius.circular(3)),
                            child: const Text('🗡️ STALKER (+15% CRIT, +4🔥)', style: TextStyle(color: Color(0xFFFF8A80), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        if (engine.isReaverFerocityActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFFE65100), borderRadius: BorderRadius.circular(3)),
                            child: const Text('🔥 REAVER (+20% ATK, +8🔥 ON KILL)', style: TextStyle(color: Color(0xFFFFE0B2), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        if (engine.isGraveCarapaceActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFF006064), borderRadius: BorderRadius.circular(3)),
                            child: const Text('🗿 SENTINEL (+35% AEGIS, STAGGER IMMUNE)', style: TextStyle(color: Color(0xFF80DEEA), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        if (engine.isVitaeBondActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFF4A148C), borderRadius: BorderRadius.circular(3)),
                            child: const Text('🩸 VITAE (+18% LIFESTEAL, +2🔥 BLEED)', style: TextStyle(color: Color(0xFFE1BEE7), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        if (engine.isTemporalWeftActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(3)),
                            child: const Text('⏳ TEMPORAL (-20% CDR, +2,000 AP)', style: TextStyle(color: Color(0xFFC5CAE9), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        if (engine.isAuraOfVitalityActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFF004D40), borderRadius: BorderRadius.circular(3)),
                            child: const Text('✨ MEDICUS (+25% HEAL, +3% REGEN)', style: TextStyle(color: Color(0xFFA7FFEB), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        if (engine.isSiegeResonatorActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFFBF360C), borderRadius: BorderRadius.circular(3)),
                            child: const Text('🎯 ARBALEST (+25% AOE DMG, +1 RADIUS)', style: TextStyle(color: Color(0xFFFFCCBC), fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.whatshot, size: 14),
                label: const Text('ASCEND\n(200 ASH, 20 VIT)', textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAscend ? const Color(0xFFFF6D00) : const Color(0xFF2E241E),
                  foregroundColor: canAscend ? Colors.white : Colors.white38,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: canAscend
                    ? () {
                        setState(() {
                          engine.upgradeSculptorFurnace();
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section Title: 5 Equipped Commander Skills
        const Text(
          'EQUIPPED COMMANDER SKILLS (COOLDOWNS & RANKS)',
          style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),

        // List 5 Equipped Skills
        ...List.generate(5, (slotIdx) {
          final skill = engine.skillTreeState.getSkillInSlot(slotIdx);
          if (skill == null) return const SizedBox.shrink();

          final bool canUpgradeSkill = engine.distilledVitaeWallet >= 15 && skill.canUpgrade;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF181622),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: skill.borderColor.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Row(
              children: [
                Icon(skill.icon, color: skill.primaryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            skill.name.toUpperCase(),
                            style: TextStyle(color: skill.primaryColor, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF232538),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'RANK ${skill.rank}/${skill.maxRank}',
                              style: const TextStyle(color: Colors.white, fontSize: 8.0, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '⏳ ${skill.effectiveCooldownSeconds.toStringAsFixed(1)}s CD  •  ${skill.cinderCost}🔥',
                            style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        skill.currentRankDescription,
                        style: const TextStyle(color: Colors.white70, fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canUpgradeSkill ? const Color(0xFFB71C1C) : const Color(0xFF261A1D),
                    foregroundColor: canUpgradeSkill ? Colors.white : Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: canUpgradeSkill
                      ? () {
                          setState(() {
                            engine.upgradeCommanderSkill(skill.id);
                          });
                        }
                      : null,
                  child: Text(
                    skill.canUpgrade ? 'RANK UP (15 VIT)' : 'MAX RANK',
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
