import 'dart:math';
import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/widgets/gothic_header_bar.dart';
import '../relics/relic_service.dart';
import 'delve_models.dart';
import 'delve_service.dart';

/// Interactive Procedural Catacomb Delve Screen (Stygian Expeditions)
class CatacombDelveScreen extends StatefulWidget {
  final DelveService delveService;
  final List<UnitEntity> brigadeSquad;
  final RelicService? relicService;
  final void Function(DelveRoom room, List<UnitEntity> squadWithHp) onLaunchCombat;
  final void Function({
    required int ichor,
    required int ore,
    required int sigils,
    required int plinthShards,
  }) onExtractionConfirmed;
  final VoidCallback onClose;

  const CatacombDelveScreen({
    super.key,
    required this.delveService,
    required this.brigadeSquad,
    this.relicService,
    required this.onLaunchCombat,
    required this.onExtractionConfirmed,
    required this.onClose,
  });

  @override
  State<CatacombDelveScreen> createState() => _CatacombDelveScreenState();
}

class _CatacombDelveScreenState extends State<CatacombDelveScreen> {
  DelveService get _service => widget.delveService;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);

    // If no run is active, initiate a fresh expedition
    if (!_service.isRunActive) {
      _service.startNewRun(widget.brigadeSquad);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  List<UnitEntity> _getSquadWithCurrentHp() {
    return widget.brigadeSquad.map((unit) {
      final hp = _service.getUnitHp(unit);
      return unit.copyWith(currentHp: hp);
    }).toList();
  }

  void _handleRoomSelected(DelveRoom room) {
    if (!room.isAvailable && !room.isCleared) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This subterranean corridor is sealed. Clear preceding chambers first!'),
          backgroundColor: Color(0xFF37474F),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (room.isCleared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${room.title} has already been conquered.'),
          backgroundColor: const Color(0xFF263238),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // Enter room & drain torchlight
    _service.enterRoom(room.id);

    // Open appropriate room dialog
    switch (room.type) {
      case DelveRoomType.skirmish:
      case DelveRoomType.wanderingElite:
      case DelveRoomType.catacombArchon:
        _showCombatPreparationModal(room);
        break;
      case DelveRoomType.restingShrine:
        _showRestingShrineModal(room);
        break;
      case DelveRoomType.vaultChest:
        _showVaultChestModal(room);
        break;
      case DelveRoomType.extractionStone:
        _showExtractionRunestoneModal(room);
        break;
    }
  }

  // --------------------------------------------------------------------------
  // ROOM MODALS
  // --------------------------------------------------------------------------

  void _showCombatPreparationModal(DelveRoom room) {
    final bool isElite = room.type == DelveRoomType.wanderingElite;
    final bool isBoss = room.type == DelveRoomType.catacombArchon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1017),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: isBoss
                  ? const Color(0xFFD500F9)
                  : isElite
                      ? const Color(0xFFFF1744)
                      : const Color(0xFFFF7043),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(room.icon, color: room.color, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: room.color,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          room.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFECEFF1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                room.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF90A4AE)),
              ),
              if (room.eliteAffix != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: room.eliteAffix!.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: room.eliteAffix!.color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(room.eliteAffix!.icon, color: room.eliteAffix!.color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ELITE AFFIX: ${room.eliteAffix!.name.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: room.eliteAffix!.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              room.eliteAffix!.description,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFCFD8DC)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Spoils preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSpoilPreviewItem('ICHOR', '+${room.rewardIchor}', const Color(0xFFE91E63)),
                    _buildSpoilPreviewItem('ORE', '+${room.rewardOre}', const Color(0xFFFF9800)),
                    _buildSpoilPreviewItem('SIGILS', '+${room.rewardSigils}', const Color(0xFFFFD54F)),
                    _buildSpoilPreviewItem(
                      'PLINTHS',
                      '+${_service.isGloomActive ? room.rewardPlinthShards * 2 : room.rewardPlinthShards}',
                      const Color(0xFF00E5FF),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF90A4AE),
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('RETREAT TO CORRIDOR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: room.color,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.flash_on, size: 20),
                      label: const Text('ENGAGE FOE', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        widget.onLaunchCombat(room, _getSquadWithCurrentHp());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRestingShrineModal(DelveRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final squad = widget.brigadeSquad;
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1017),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: const Color(0xFF69F0AE), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.healing, color: Color(0xFF69F0AE), size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLOOD SANCTUARY & RESTING SHRINE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF69F0AE),
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'Commune with the Basalt Altar',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'An ancient blood font wells up from the subterranean stone. Choose one boon before the magic dissipates:',
                    style: TextStyle(fontSize: 13, color: Color(0xFFB0BEC5)),
                  ),
                  const SizedBox(height: 16),
                  // Option 1: Mend Squad
                  _buildShrineOptionCard(
                    title: 'MEND SQUAD VITAE',
                    subtitle: 'Restore 35% Max HP to all living allies & revive fallen allies with 30% HP.',
                    icon: Icons.favorite,
                    accentColor: const Color(0xFF69F0AE),
                    onTap: () {
                      _service.restAtShrine(
                        healSquad: true,
                        stokeTorch: false,
                        takeBoon: false,
                        squad: squad,
                      );
                      _service.completeRoom(room.id);
                      Navigator.of(ctx).pop();
                      _showSnackBar('Squad Vitae restored by 35%!');
                    },
                  ),
                  const SizedBox(height: 10),
                  // Option 2: Kindle Torch
                  _buildShrineOptionCard(
                    title: 'STOKE THE TORCHLIGHT',
                    subtitle: 'Add +45 Torchlight to push back the lethal Stygian Gloom.',
                    icon: Icons.local_fire_department,
                    accentColor: const Color(0xFFFFD54F),
                    onTap: () {
                      _service.restAtShrine(
                        healSquad: false,
                        stokeTorch: true,
                        takeBoon: false,
                        squad: squad,
                      );
                      _service.completeRoom(room.id);
                      Navigator.of(ctx).pop();
                      _showSnackBar('Torchlight kindled (+45 Torchlight)!');
                    },
                  ),
                  const SizedBox(height: 10),
                  // Option 3: Blood Sacrifice for Boon
                  _buildShrineOptionCard(
                    title: 'BLOOD SACRIFICE FOR BOON',
                    subtitle: 'Sacrifice 20% Squad HP to receive a permanent Delve Boon.',
                    icon: Icons.auto_awesome,
                    accentColor: const Color(0xFFE040FB),
                    onTap: () {
                      final availableBoons = DelveBoon.pool
                          .where((b) => !_service.activeBoons.any((ab) => ab.id == b.id))
                          .toList();
                      final chosen = availableBoons.isNotEmpty
                          ? availableBoons[Random().nextInt(availableBoons.length)]
                          : DelveBoon.pool.first;

                      _service.restAtShrine(
                        healSquad: false,
                        stokeTorch: false,
                        takeBoon: true,
                        chosenBoon: chosen,
                        squad: squad,
                      );
                      _service.completeRoom(room.id);
                      Navigator.of(ctx).pop();
                      _showSnackBar('Sacrifice accepted! Acquired boon: ${chosen.name}');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVaultChestModal(DelveRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1017),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: Color(0xFFFFD54F), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VAULT OF ANTIQUITIES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD54F),
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          room.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'A heavy iron-reinforced sarcophagus sits before you. You can unlock it cleanly using a Crypt Key or attempt to pick/force the lock at the risk of springing a deadly needle trap.',
                style: TextStyle(fontSize: 13, color: Color(0xFFCFD8DC)),
              ),
              const SizedBox(height: 18),
              // Option 1: Use Crypt Key
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.vpn_key, size: 20),
                label: Text(
                  'UNLOCK WITH CRYPT KEY (${_service.cryptKeys} REMAINING)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _service.cryptKeys > 0
                    ? () {
                        final res = _service.openVault(useKey: true, squad: widget.brigadeSquad);
                        _service.completeRoom(room.id);
                        Navigator.of(ctx).pop();
                        _showResultDialog('VAULT UNLOCKED', res['message'] as String, isSuccess: true);
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              // Option 2: Force Lock
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7043),
                  side: const BorderSide(color: Color(0xFFFF7043)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.warning, size: 20),
                label: const Text('FORCE THE LOCK (70% SUCCESS / 30% TRAP)'),
                onPressed: () {
                  final res = _service.openVault(useKey: false, squad: widget.brigadeSquad);
                  _service.completeRoom(room.id);
                  Navigator.of(ctx).pop();
                  final bool success = res['success'] as bool;
                  _showResultDialog(
                    success ? 'LOCK FORCED' : 'TRAP TRIGGERED',
                    res['message'] as String,
                    isSuccess: success,
                  );
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('LEAVE UNTOUCHED', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExtractionRunestoneModal(DelveRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final nextFloor = _service.currentFloor + 1;
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1017),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: const Color(0xFF00E5FF), width: 1.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.vpn_key, color: Color(0xFF00E5FF), size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STYGIAN EXTRACTION RUNESTONE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Threshold of the Deep',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'The runestone hums with ancient spatial teleportation sorcery. You stand at the boundary between safety and glory.',
                style: TextStyle(fontSize: 13, color: Color(0xFFB0BEC5)),
              ),
              const SizedBox(height: 16),
              // Current Loot Sack
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCUMULATED DELVE LOOT SACK:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF80D8FF)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSpoilPreviewItem('ICHOR', '${_service.accumulatedIchor}', const Color(0xFFE91E63)),
                        _buildSpoilPreviewItem('ORE', '${_service.accumulatedOre}', const Color(0xFFFF9800)),
                        _buildSpoilPreviewItem('SIGILS', '${_service.accumulatedSigils}', const Color(0xFFFFD54F)),
                        _buildSpoilPreviewItem(
                          'PLINTHS',
                          '${_service.accumulatedPlinthShards}',
                          const Color(0xFF00E5FF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Choice 1: Safe Extraction
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.shield, size: 20),
                label: const Text(
                  'EXTRACT TO CITADEL (100% LOOT BANKED)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _performSafeExtraction();
                },
              ),
              const SizedBox(height: 12),
              // Choice 2: Descend Deeper
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5252),
                  side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.arrow_downward, size: 20),
                label: Text(
                  'DESCEND TO FLOOR $nextFloor (+45% SPOILS SCALE)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _service.completeRoom(room.id);
                  _service.descendNextFloor();
                  Navigator.of(ctx).pop();
                  _showSnackBar('Descended to Floor $nextFloor! Beware of growing gloom.');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _performSafeExtraction() {
    final spoils = _service.extractRun();
    widget.onExtractionConfirmed(
      ichor: spoils['ichor'] ?? 0,
      ore: spoils['ore'] ?? 0,
      sigils: spoils['sigils'] ?? 0,
      plinthShards: spoils['plinths'] ?? 0,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 28),
              SizedBox(width: 10),
              Text('EXPEDITION EXTRACTED', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your squad emerged from the Stygian Catacombs intact! All spoils have been deposited into your Citadel vaults.',
                style: TextStyle(color: Color(0xFFCFD8DC), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1017),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildExtractSummaryRow('Raw Ash & Ichor', '+${spoils['ichor']}', const Color(0xFFE91E63)),
                    _buildExtractSummaryRow('Cursed Ore', '+${spoils['ore']}', const Color(0xFFFF9800)),
                    _buildExtractSummaryRow('Bloodline Sigils', '+${spoils['sigils']}', const Color(0xFFFFD54F)),
                    _buildExtractSummaryRow('Petrified Plinth Shards', '+${spoils['plinths']}', const Color(0xFF00E5FF)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onClose();
              },
              child: const Text('RETURN TO CITADEL', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showResultDialog(String title, String message, {required bool isSuccess}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSuccess ? const Color(0xFFFFD54F) : const Color(0xFFFF5252)),
          ),
          title: Row(
            children: [
              Icon(isSuccess ? Icons.stars : Icons.dangerous, color: isSuccess ? const Color(0xFFFFD54F) : const Color(0xFFFF5252)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Text(message, style: const TextStyle(color: Color(0xFFCFD8DC), fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CONTINUE DELVE', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A2634),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // UI BUILD
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final floor = _service.currentFloorData;

    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Atmospheric Radial Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 1.4,
                  colors: _service.isGloomActive
                      ? const [
                          Color(0xFF260A0D),
                          Color(0xFF120507),
                          Color(0xFF080203),
                        ]
                      : const [
                          Color(0xFF0F1B2B),
                          Color(0xFF0A0F17),
                          Color(0xFF06080C),
                        ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Top Header Bar
                GothicHeaderBar(
                  title: 'CATACOMB DELVES',
                  categoryTag: 'STYGIAN EXPEDITION',
                  actions: [
                    // Crypt Keys Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B26),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key, size: 14, color: Color(0xFFFFD54F)),
                          const SizedBox(width: 4),
                          Text(
                            'KEYS: ${_service.cryptKeys}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFFE082)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () {
                        if (_service.isRunActive) {
                          _showAbandonConfirmDialog();
                        } else {
                          widget.onClose();
                        }
                      },
                    ),
                  ],
                ),

                // 2. Torchlight & Gloom Status Ribbon
                _buildTorchlightRibbon(),

                // 3. Stygian Gloom Warning Banner (if active)
                if (_service.isGloomActive) _buildGloomAlertBanner(),

                // 4. Floor Title & Boons Row
                _buildFloorInfoRow(floor),

                // 5. Interactive Procedural Map Canvas
                Expanded(
                  child: floor != null ? _buildDungeonMap(floor) : const Center(child: CircularProgressIndicator()),
                ),

                // 6. Persistent Squad Vitae Status Bar
                _buildSquadStatusTray(),

                // 7. Accumulated Loot Sack Summary Bar
                _buildLootSackBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTorchlightRibbon() {
    final torchVal = _service.torchlight;
    final Color torchColor = torchVal > 60
        ? const Color(0xFFFF9800)
        : torchVal > 30
            ? const Color(0xFFFFB74D)
            : const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF0A0F16),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, size: 16, color: torchColor),
          const SizedBox(width: 6),
          Text(
            'TORCHLIGHT: $torchVal%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: torchColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: torchVal / 100.0,
                backgroundColor: const Color(0xFF1E2630),
                valueColor: AlwaysStoppedAnimation<Color>(torchColor),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            torchVal > 30 ? 'ILLUMINATED' : 'STYGIAN GLOOM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: torchVal > 30 ? const Color(0xFF90A4AE) : const Color(0xFFFF5252),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGloomAlertBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      color: const Color(0xFFB71C1C),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'STYGIAN GLOOM: Enemies have +25% Crit • Petrified Plinth Shard drops DOUBLED (2x)!',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorInfoRow(DelveFloor? floor) {
    if (floor == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  floor.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  floor.subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF78909C)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_service.activeBoons.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(
              children: _service.activeBoons.map((boon) {
                return Tooltip(
                  message: '${boon.name}: ${boon.description}',
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: boon.color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: boon.color, width: 1.0),
                    ),
                    child: Icon(boon.icon, size: 14, color: boon.color),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDungeonMap(DelveFloor floor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(floor.columns.length, (colIdx) {
              final colRoomIds = floor.columns[colIdx];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: colRoomIds.map((roomId) {
                    final room = floor.rooms[roomId]!;
                    return _buildRoomNodeCard(room);
                  }).toList(),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildRoomNodeCard(DelveRoom room) {
    final bool isAvailable = room.isAvailable;
    final bool isCleared = room.isCleared;

    final Color borderColor = isCleared
        ? Colors.white24
        : isAvailable
            ? room.color
            : const Color(0xFF263238);

    final Color bgColor = isCleared
        ? const Color(0xFF0A0E14)
        : isAvailable
            ? const Color(0xFF131C28)
            : const Color(0xFF070A0E);

    return InkWell(
      onTap: () => _handleRoomSelected(room),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isAvailable ? 1.8 : 1.0),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: room.color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCleared ? Icons.check_circle : room.icon,
                  size: 18,
                  color: isCleared ? const Color(0xFF69F0AE) : borderColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    room.typeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isCleared ? const Color(0xFF90A4AE) : borderColor,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              room.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCleared ? const Color(0xFF78909C) : Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (room.eliteAffix != null && !isCleared) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: room.eliteAffix!.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  room.eliteAffix!.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: room.eliteAffix!.color,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '+${room.rewardIchor} Ash',
                  style: const TextStyle(fontSize: 9, color: Color(0xFFE91E63)),
                ),
                if (room.rewardPlinthShards > 0)
                  Text(
                    '+${room.rewardPlinthShards} Plinths',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF00E5FF)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquadStatusTray() {
    final squad = widget.brigadeSquad;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0B1017),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPEDITION SQUAD VITAE (PERSISTENT ATTRITION):',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF78909C)),
          ),
          const SizedBox(height: 6),
          Row(
            children: squad.map((unit) {
              final currentHp = _service.getUnitHp(unit);
              final maxHp = unit.maxHp;
              final double ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
              final bool isDead = currentHp <= 0;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDead ? const Color(0xFF1E0B0E) : const Color(0xFF121922),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDead ? const Color(0xFFFF5252).withValues(alpha: 0.5) : Colors.white12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDead ? Icons.dangerous : Icons.shield,
                            size: 11,
                            color: isDead ? const Color(0xFFFF5252) : const Color(0xFF80D8FF),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              unit.name,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDead ? const Color(0xFFFF5252) : Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ratio > 0.5
                                ? const Color(0xFF69F0AE)
                                : ratio > 0.2
                                    ? const Color(0xFFFFD54F)
                                    : const Color(0xFFFF5252),
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDead ? 'FALLEN' : '$currentHp/$maxHp',
                        style: TextStyle(
                          fontSize: 8,
                          color: isDead ? const Color(0xFFFF5252) : const Color(0xFF90A4AE),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLootSackBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF070B10),
        border: Border(top: BorderSide(color: Colors.white12, width: 1.0)),
      ),
      child: Row(
        children: [
          // Loot Sack summary
          Expanded(
            child: Row(
              children: [
                _buildLootPill(Icons.opacity, '${_service.accumulatedIchor}', const Color(0xFFE91E63)),
                const SizedBox(width: 8),
                _buildLootPill(Icons.diamond, '${_service.accumulatedOre}', const Color(0xFFFF9800)),
                const SizedBox(width: 8),
                _buildLootPill(Icons.auto_awesome, '${_service.accumulatedSigils}', const Color(0xFFFFD54F)),
                const SizedBox(width: 8),
                _buildLootPill(Icons.foundation, '${_service.accumulatedPlinthShards}', const Color(0xFF00E5FF)),
              ],
            ),
          ),
          // Quick Extract Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.vpn_key, size: 14),
            label: const Text('EXTRACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => _performSafeExtraction(),
          ),
        ],
      ),
    );
  }

  Widget _buildLootPill(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSpoilPreviewItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF78909C))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildShrineOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131B26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAbandonConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFF5252)),
          ),
          title: const Text('ABANDON EXPEDITION?', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const Text(
            'Fleeing the catacombs now without activating an Extraction Runestone will result in a 50% consolation wipe salvage. Are you certain?',
            style: TextStyle(color: Color(0xFFCFD8DC), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('STAY IN CATACOMBS', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final consolation = _service.wipeRun();
                widget.onExtractionConfirmed(
                  ichor: consolation['ichor'] ?? 0,
                  ore: consolation['ore'] ?? 0,
                  sigils: consolation['sigils'] ?? 0,
                  plinthShards: consolation['plinths'] ?? 0,
                );
                Navigator.of(ctx).pop();
                widget.onClose();
              },
              child: const Text('FLEE (50% SALVAGE)'),
            ),
          ],
        );
      },
    );
  }
}
