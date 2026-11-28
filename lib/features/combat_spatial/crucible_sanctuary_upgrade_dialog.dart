import 'package:flutter/material.dart';
import 'crucible_skill_tree_dialog.dart';
import 'spatial_combat_engine.dart';

/// Legacy entry-point preserved for compatibility: routes directly into the single
/// unified Crucible Grimoire & Warband Upgrades hub on the Unit Upgrades tab.
class CrucibleSanctuaryUpgradeDialog extends StatelessWidget {
  final SpatialCombatEngine engine;

  const CrucibleSanctuaryUpgradeDialog({
    super.key,
    required this.engine,
  });

  static Future<void> show(BuildContext context, SpatialCombatEngine engine) {
    return CrucibleSkillTreeDialog.show(
      context,
      engine,
      initialTab: CrucibleHubTab.unitUpgrades,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CrucibleSkillTreeDialog(
      engine: engine,
      initialTab: CrucibleHubTab.unitUpgrades,
    );
  }
}
