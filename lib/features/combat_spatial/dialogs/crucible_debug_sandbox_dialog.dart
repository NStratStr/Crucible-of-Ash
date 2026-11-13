import 'package:flutter/material.dart';
import '../models/crucible_skill_tree_models.dart';
import '../spatial_combat_engine.dart';

class CrucibleDebugSandboxDialog extends StatefulWidget {
  final SpatialCombatEngine engine;
  final VoidCallback onStateChanged;
  final VoidCallback? onUnlockAllUnits;

  const CrucibleDebugSandboxDialog({
    super.key,
    required this.engine,
    required this.onStateChanged,
    this.onUnlockAllUnits,
  });

  static Future<void> show(
    BuildContext context, {
    required SpatialCombatEngine engine,
    required VoidCallback onStateChanged,
    VoidCallback? onUnlockAllUnits,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CrucibleDebugSandboxDialog(
        engine: engine,
        onStateChanged: onStateChanged,
        onUnlockAllUnits: onUnlockAllUnits,
      ),
    );
  }

  @override
  State<CrucibleDebugSandboxDialog> createState() => _CrucibleDebugSandboxDialogState();
}

class _CrucibleDebugSandboxDialogState extends State<CrucibleDebugSandboxDialog> {
  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final sculptor = engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull;

    return Dialog(
      backgroundColor: const Color(0xFF0C0E14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF161A24),
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.build_circle, color: Color(0xFFFFD54F), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CRUCIBLE DEV SANDBOX & SKILL TESTER',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'Live testing environment: instant buildcraft, zero cooldowns & damage testing',
                          style: TextStyle(color: Colors.white54, fontSize: 9.0),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 2. Body controls
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Active Status Strip
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12141C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusStat('CINDERS', '${sculptor?.crucibleCinders ?? 0}/100', const Color(0xFFFF9100)),
                        _buildStatusStat('SKILL POINTS', '${engine.skillTreeState.availableSkillPoints}', const Color(0xFFFFD54F)),
                        _buildStatusStat('GOD MODE', engine.isDebugGodModeEnabled ? 'ACTIVE' : 'OFF', engine.isDebugGodModeEnabled ? const Color(0xFF69F0AE) : Colors.white38),
                        _buildStatusStat('INF CINDERS', engine.isDebugInfiniteCinders ? 'ACTIVE' : 'OFF', engine.isDebugInfiniteCinders ? const Color(0xFF69F0AE) : Colors.white38),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section A: God Mode & Infinite Cinders Toggles
                  const Text(
                    'SANDBOX PASSIVES & TOGGLES:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToggleCard(
                          title: '🛡️ GOD MODE',
                          subtitle: 'Squad takes 0 damage',
                          isActive: engine.isDebugGodModeEnabled,
                          activeColor: const Color(0xFF00E676),
                          onTap: () {
                            setState(() => engine.debugToggleGodMode());
                            widget.onStateChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildToggleCard(
                          title: '🔥 INFINITE CINDERS',
                          subtitle: 'Lock cinders at 100/100',
                          isActive: engine.isDebugInfiniteCinders,
                          activeColor: const Color(0xFFFF9100),
                          onTap: () {
                            setState(() => engine.debugToggleInfiniteCinders());
                            widget.onStateChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section B: Instant Resource Grants
                  const Text(
                    'INSTANT RESOURCE GRANTS:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildActionBtn(
                        label: '⚡ +10 SKILL POINTS',
                        color: const Color(0xFFFFD54F),
                        icon: Icons.stars,
                        onTap: () {
                          setState(() => engine.debugAddSkillPoints(10));
                          widget.onStateChanged();
                        },
                      ),
                      _buildActionBtn(
                        label: '🔥 FILL CINDERS (100)',
                        color: const Color(0xFFFF7043),
                        icon: Icons.whatshot,
                        onTap: () {
                          setState(() => engine.debugFillCinders());
                          widget.onStateChanged();
                        },
                      ),
                      _buildActionBtn(
                        label: '⏱️ RESET ALL COOLDOWNS',
                        color: const Color(0xFF00E5FF),
                        icon: Icons.timer_off,
                        onTap: () {
                          setState(() => engine.debugResetCooldowns());
                          widget.onStateChanged();
                        },
                      ),
                      _buildActionBtn(
                        label: '👑 UNLOCK ALL SKILLS (MAX RANK)',
                        color: const Color(0xFFB388FF),
                        icon: Icons.workspace_premium,
                        onTap: () {
                          setState(() => engine.debugUnlockAllSkills());
                          widget.onStateChanged();
                        },
                      ),
                      if (widget.onUnlockAllUnits != null)
                        _buildActionBtn(
                          label: '👥 UNLOCK ALL RETINUE UNITS',
                          color: const Color(0xFF40C4FF),
                          icon: Icons.groups,
                          onTap: () {
                            widget.onUnlockAllUnits?.call();
                            setState(() {});
                            widget.onStateChanged();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section C: Combat & Target Controls
                  const Text(
                    'COMBAT & TARGET CONTROL:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildActionBtn(
                        label: '🎯 SPAWN 25,000 HP TRAINING DUMMY',
                        color: const Color(0xFF69F0AE),
                        icon: Icons.track_changes,
                        onTap: () {
                          setState(() => engine.debugSpawnTrainingDummy());
                          widget.onStateChanged();
                        },
                      ),
                      _buildActionBtn(
                        label: '⚡ FILL ALL ALLIES AP (INSTANT TURNS)',
                        color: const Color(0xFFFFD54F),
                        icon: Icons.flash_on,
                        onTap: () {
                          setState(() => engine.debugFillAlliesAp());
                          widget.onStateChanged();
                        },
                      ),
                      _buildActionBtn(
                        label: '💥 SLAY ALL ENEMIES (ADVANCE WAVE)',
                        color: const Color(0xFFFF5252),
                        icon: Icons.auto_delete,
                        onTap: () {
                          setState(() => engine.debugKillAllEnemies());
                          widget.onStateChanged();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section D: 1-Click Archetype Loadout Presets
                  const Text(
                    '1-CLICK ARCHETYPE PRESET LOADOUTS:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildArchetypeBtn('🔥 PURE WRATH (ATTACK)', const Color(0xFFE53935), CrucibleSkillBranch.wrath),
                      _buildArchetypeBtn('🛡️ PURE BASTION (DEFENSE)', const Color(0xFF00BFA5), CrucibleSkillBranch.bastion),
                      _buildArchetypeBtn('🩸 PURE RESONANCE (HYBRID)', const Color(0xFFBA68C8), CrucibleSkillBranch.resonance),
                      _buildArchetypeBtn('✨ PURE VITAE (HEALING)', const Color(0xFF69F0AE), CrucibleSkillBranch.vitae),
                      _buildArchetypeBtn('🌋 PURE CALAMITY (AOE)', const Color(0xFFFF9100), CrucibleSkillBranch.calamity),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF141720),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF69F0AE), size: 14),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'All changes take effect immediately in the current encounter.',
                      style: TextStyle(fontSize: 8.5, color: Colors.white60),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('RESUME BATTLE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.15) : const Color(0xFF161922),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? activeColor : Colors.white12,
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isActive ? activeColor : Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w900)),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 8.0)),
                ],
              ),
            ),
            Switch(
              value: isActive,
              activeColor: activeColor,
              onChanged: (_) => onTap(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: color.withValues(alpha: 0.7), width: 1.0),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 13, color: color),
      label: Text(label, style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: color)),
      onPressed: onTap,
    );
  }

  Widget _buildArchetypeBtn(String label, Color color, CrucibleSkillBranch branch) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.18),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: color.withValues(alpha: 0.7), width: 1.0),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color)),
      onPressed: () {
        setState(() {
          widget.engine.debugEquipArchetypeLoadout(branch);
        });
        widget.onStateChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Equipped $label loadout!'),
            duration: const Duration(seconds: 1),
            backgroundColor: color.withValues(alpha: 0.8),
          ),
        );
      },
    );
  }
}
