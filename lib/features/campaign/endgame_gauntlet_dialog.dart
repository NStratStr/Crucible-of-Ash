import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';

enum EndgameTrialType {
  worldTitan,
  lineageCrypt,
  deathlessCrypt,
  abyssalDescent,
  abyssalDescentII,
  abyssalDescentIII,
}

class EndgameTrialDefinition {
  final EndgameTrialType type;
  final String title;
  final String subtitle;
  final String description;
  final String modifier;
  final String rewardsText;
  final IconData icon;
  final Color themeColor;

  const EndgameTrialDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.modifier,
    required this.rewardsText,
    required this.icon,
    required this.themeColor,
  });
}

class EndgameGauntletDialog extends StatelessWidget {
  final List<UnitEntity>? activeSquad;

  const EndgameGauntletDialog({super.key, this.activeSquad});

  static const List<EndgameTrialDefinition> trials = [
    EndgameTrialDefinition(
      type: EndgameTrialType.worldTitan,
      title: 'THE ASHEN WORLD TITAN',
      subtitle: 'Chapter-Capping Colossus Siege',
      description: 'Face the colossal Generation 4 Pureblood Titan with 4,500 HP, backed by Void Archons and Iron Harbingers.',
      modifier: 'TITANIC FURY: Boss attacks strike all frontline Vanguard units simultaneously.',
      rewardsText: 'Guaranteed Legendary Relic • +2,000 Ichor • +1,500 Brigade XP',
      icon: Icons.shield,
      themeColor: Color(0xFFD32F2F),
    ),
    EndgameTrialDefinition(
      type: EndgameTrialType.lineageCrypt,
      title: 'LINEAGE CRYPT: DEN OF FANGS',
      subtitle: 'Beastline Lineage Trial (2+ Beasts or Skirmishers Required)',
      description: 'A dark cavern teeming with Cerberus Alpha and stealth predators that inflict heavy bleed afflictions.',
      modifier: 'BLOOD MOON: All critical strike damage is amplified by +50%.',
      rewardsText: 'Pureblood War-Hound Thrall • +800 Ichor • +800 Brigade XP',
      icon: Icons.pets,
      themeColor: Color(0xFFFB8C00),
    ),
    EndgameTrialDefinition(
      type: EndgameTrialType.deathlessCrypt,
      title: 'LINEAGE CRYPT: TOMB OF THE DEATHLESS',
      subtitle: 'Undead & Occultist Trial (2+ Undead/Occultists Required)',
      description: 'Ancient sepulcher guarded by deathless sorcerers who wield soul-siphoning curses and necrotic rot.',
      modifier: 'GRAVE CHILL: Fallen enemies explode in frigid miasma; healing potency reduced by 25%.',
      rewardsText: 'Pureblood Lich Sovereign • +900 Ichor • +2 Bloodline Sigils',
      icon: Icons.brightness_3,
      themeColor: Color(0xFF7E57C2),
    ),
    EndgameTrialDefinition(
      type: EndgameTrialType.abyssalDescent,
      title: 'ABYSSAL DESCENT: TORMENT I',
      subtitle: 'Affinity Shift Trial',
      description: 'Descend into the dark abyss where Arch-Lich Malgok wields toxic miasma and resurrective thralls.',
      modifier: 'CORROSIVE MIASMA: Non-Occultist units suffer 30 poison damage at start of turn.',
      rewardsText: 'Epic Relic • +1,200 Ichor • +1,000 Brigade XP',
      icon: Icons.dark_mode,
      themeColor: Color(0xFF8E24AA),
    ),
    EndgameTrialDefinition(
      type: EndgameTrialType.abyssalDescentII,
      title: 'ABYSSAL DESCENT: TORMENT II',
      subtitle: 'Void Corruption Trial',
      description: 'Mutated abyss where void-warped champions deal heavy rot and occult strikes automatically blight.',
      modifier: 'VOID CORRUPTION: Non-Occultists take 45 poison at turn start; Occultist strikes apply Blight.',
      rewardsText: 'Epic/Legendary Relic • +1,600 Ichor • +2 Bloodline Sigils',
      icon: Icons.grain,
      themeColor: Color(0xFF5E35B1),
    ),
    EndgameTrialDefinition(
      type: EndgameTrialType.abyssalDescentIII,
      title: 'ABYSSAL DESCENT: TORMENT III',
      subtitle: 'Abyssal Eclipse Siege',
      description: 'Pinnacle abyssal nightmare where the Colossal Void Archon and Arch-Lich unleash dual catastrophic modifiers.',
      modifier: 'ABYSSAL ECLIPSE: Boss cleaves all frontline Vanguard units AND non-Occultists suffer 40 poison damage.',
      rewardsText: 'Guaranteed Legendary Relic • +2,500 Ichor • +3 Bloodline Sigils',
      icon: Icons.brightness_auto,
      themeColor: Color(0xFFB71C1C),
    ),
  ];

  static Future<EndgameTrialType?> show(BuildContext context, {List<UnitEntity>? activeSquad}) {
    return showModalBottomSheet<EndgameTrialType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EndgameGauntletDialog(activeSquad: activeSquad),
    );
  }

  int get _beastAndSkirmisherCount {
    if (activeSquad == null) return 2;
    return activeSquad!.where((u) {
      final isSkirm = u.archetype == Archetype.skirmisher;
      final isBeast = u.speciesId.contains('hound') ||
          u.speciesId.contains('cerberus') ||
          u.speciesId.contains('beast') ||
          u.speciesId.contains('bat') ||
          u.speciesId.contains('wolf');
      return isSkirm || isBeast;
    }).length;
  }

  int get _undeadAndOccultistCount {
    if (activeSquad == null) return 2;
    return activeSquad!.where((u) {
      final isOccultist = u.archetype == Archetype.occultist;
      final isUndead = u.speciesId.contains('ghoul') ||
          u.speciesId.contains('lich') ||
          u.speciesId.contains('skeleton') ||
          u.speciesId.contains('undead') ||
          u.speciesId.contains('vampire') ||
          u.speciesId.contains('necro') ||
          u.speciesId.contains('grave');
      return isOccultist || isUndead;
    }).length;
  }

  void _onEngageTrial(BuildContext context, EndgameTrialDefinition trial) {
    if (trial.type == EndgameTrialType.lineageCrypt) {
      final count = _beastAndSkirmisherCount;
      if (count < 2) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF14141A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFFB8C00), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock, color: Color(0xFFFB8C00), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'LINEAGE BARRIER SEALED',
                    style: TextStyle(
                      color: Color(0xFFFB8C00),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'The Den of Fangs strictly permits only feral beasts and skirmishers to tread its hallowed earth.\n\nYour active squad has $count / 2 required units. Please configure at least 2 Beast or Skirmisher units in your brigade.',
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('UNDERSTOOD', style: TextStyle(color: Color(0xFFFB8C00))),
              ),
            ],
          ),
        );
        return;
      }
    } else if (trial.type == EndgameTrialType.deathlessCrypt) {
      final count = _undeadAndOccultistCount;
      if (count < 2) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF14141A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF7E57C2), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock, color: Color(0xFF7E57C2), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SEPULCHRAL BARRIER SEALED',
                    style: TextStyle(
                      color: Color(0xFF7E57C2),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'The Tomb of the Deathless strictly permits only undead and occultist soul-binders to cross its threshold.\n\nYour active squad has $count / 2 required units. Please configure at least 2 Undead or Occultist units in your brigade.',
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('UNDERSTOOD', style: TextStyle(color: Color(0xFF7E57C2))),
              ),
            ],
          ),
        );
        return;
      }
    }

    Navigator.pop(context, trial.type);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFFB3261E), width: 1.5),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3261E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB3261E)),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Color(0xFFE5A93C), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE ENDGAME GAUNTLET',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Section 2.3 Macro-Loop: Mastery & Retention',
                        style: TextStyle(
                          color: Color(0xFF8E8EA0),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Trial Cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGauntletHeroBanner(),
                ...trials.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildTrialCard(context, t),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauntletHeroBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB3261E), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB3261E).withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/flayed_butcher.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B1B22)),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.90),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'THE MACRO TRIALS',
                    style: TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ENDGAME SIEGE & LINEAGE CRYPTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'High-stakes daily boss encounters with strict roster requirements and unique battle modifiers.',
                    style: TextStyle(color: Colors.white70, fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialCard(BuildContext context, EndgameTrialDefinition trial) {
    final bool isLineageCrypt = trial.type == EndgameTrialType.lineageCrypt;
    final bool isDeathlessCrypt = trial.type == EndgameTrialType.deathlessCrypt;
    final int beastCount = _beastAndSkirmisherCount;
    final int undeadCount = _undeadAndOccultistCount;
    final bool lineageRestricted = (isLineageCrypt && beastCount < 2) || (isDeathlessCrypt && undeadCount < 2);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: trial.themeColor.withValues(alpha: 0.7), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: trial.themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: trial.themeColor),
                  ),
                  child: Icon(trial.icon, color: trial.themeColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trial.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trial.subtitle,
                        style: TextStyle(
                          color: trial.themeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              trial.description,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
            ),
            const SizedBox(height: 8),

            // Lineage Restriction info badge if applicable
            if (isLineageCrypt) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: beastCount < 2
                      ? const Color(0xFF2E1010)
                      : const Color(0xFF102810),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: beastCount < 2 ? const Color(0xFFE53935) : const Color(0xFF43A047),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      beastCount < 2 ? Icons.lock : Icons.check_circle,
                      size: 13,
                      color: beastCount < 2 ? const Color(0xFFE53935) : const Color(0xFF43A047),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        beastCount < 2
                            ? 'RESTRICTION: 2+ Beasts/Skirmishers Required ($beastCount / 2 in squad)'
                            : 'RESTRICTION MET: $beastCount Beasts/Skirmishers Ready',
                        style: TextStyle(
                          color: beastCount < 2 ? const Color(0xFFE57373) : const Color(0xFF81C784),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (isDeathlessCrypt) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: undeadCount < 2
                      ? const Color(0xFF2E1010)
                      : const Color(0xFF102810),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: undeadCount < 2 ? const Color(0xFFE53935) : const Color(0xFF43A047),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      undeadCount < 2 ? Icons.lock : Icons.check_circle,
                      size: 13,
                      color: undeadCount < 2 ? const Color(0xFFE53935) : const Color(0xFF43A047),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        undeadCount < 2
                            ? 'RESTRICTION: 2+ Undead/Occultists Required ($undeadCount / 2 in squad)'
                            : 'RESTRICTION MET: $undeadCount Undead/Occultists Ready',
                        style: TextStyle(
                          color: undeadCount < 2 ? const Color(0xFFE57373) : const Color(0xFF81C784),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Modifier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: trial.themeColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: trial.themeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trial.modifier,
                      style: TextStyle(
                        color: trial.themeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Rewards
            Row(
              children: [
                const Icon(Icons.card_giftcard, size: 13, color: Color(0xFFE5A93C)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Yield: ${trial.rewardsText}',
                    style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(lineageRestricted ? Icons.lock_outline : Icons.sports_kabaddi, size: 16),
                label: Text(
                  lineageRestricted
                      ? (isDeathlessCrypt ? 'SEPULCHRE SEALED' : 'LINEAGE SEALED')
                      : 'ENGAGE TRIAL',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lineageRestricted ? const Color(0xFF424242) : trial.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _onEngageTrial(context, trial),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
