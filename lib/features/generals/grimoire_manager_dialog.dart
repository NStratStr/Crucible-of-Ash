import 'package:flutter/material.dart';
import '../generals/general_command_service.dart';
import '../combat/wargaming_spell_card.dart';

/// Modal dialog allowing players to manage their Commander's Grimoire deck,
/// inspect card counts, add/remove orders from their active battle deck,
/// and level up / anoint their Commander's Phylactery rank.
class GrimoireManagerDialog extends StatefulWidget {
  final GeneralCommandService commandService;
  final int bloodlineSigils;
  final ValueChanged<int>? onSigilsChanged;
  final void Function(GeneralType type, int newRank)? onPhylacteryUpgraded;
  final VoidCallback? onGrimoireSaved;

  const GrimoireManagerDialog({
    super.key,
    required this.commandService,
    this.bloodlineSigils = 0,
    this.onSigilsChanged,
    this.onPhylacteryUpgraded,
    this.onGrimoireSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required GeneralCommandService commandService,
    int bloodlineSigils = 0,
    ValueChanged<int>? onSigilsChanged,
    void Function(GeneralType type, int newRank)? onPhylacteryUpgraded,
    VoidCallback? onGrimoireSaved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GrimoireManagerDialog(
        commandService: commandService,
        bloodlineSigils: bloodlineSigils,
        onSigilsChanged: onSigilsChanged,
        onPhylacteryUpgraded: onPhylacteryUpgraded,
        onGrimoireSaved: onGrimoireSaved,
      ),
    );
  }

  @override
  State<GrimoireManagerDialog> createState() => _GrimoireManagerDialogState();
}

class _GrimoireManagerDialogState extends State<GrimoireManagerDialog> {
  late GeneralType _activeGeneral;
  late List<String> _workingDeck; // Order IDs currently in the deck
  late int _currentSigils;

  @override
  void initState() {
    super.initState();
    _activeGeneral = widget.commandService.activeGeneralType;
    _currentSigils = widget.bloodlineSigils;
    _syncWorkingDeck();
  }

  void _syncWorkingDeck() {
    final customMap = widget.commandService.allCustomGrimoires;
    if (customMap.containsKey(_activeGeneral)) {
      _workingDeck = List<String>.from(customMap[_activeGeneral]!);
    } else {
      final defaultCards = GeneralCommandService.buildDefaultGrimoireForGeneral(_activeGeneral);
      _workingDeck = defaultCards.map((c) => c.id).toList();
    }
  }

  int get _requiredDeckSize {
    switch (_activeGeneral) {
      case GeneralType.valeria:
        return 10;
      case GeneralType.vladislav:
        return 12;
      case GeneralType.malakor:
        return 14;
      case GeneralType.morrigan:
        return 20;
    }
  }

  GeneralProfile get _profile => GeneralProfile.getByType(_activeGeneral);
  int get _rank => widget.commandService.getPhylacteryRank(_activeGeneral);

  void _addCardToDeck(GeneralOrderDefinition order) {
    if (_workingDeck.length >= _requiredDeckSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Grimoire capacity reached ($_requiredDeckSize/$_requiredDeckSize). Remove a card first!'),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(milliseconds: 1400),
        ),
      );
      return;
    }
    setState(() {
      _workingDeck.add(order.id);
    });
  }

  void _removeCardFromDeck(String orderId) {
    final idx = _workingDeck.indexOf(orderId);
    if (idx != -1) {
      setState(() {
        _workingDeck.removeAt(idx);
      });
    }
  }

  void _saveDeck() {
    if (_workingDeck.length != _requiredDeckSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Grimoire requires exactly $_requiredDeckSize cards! Currently has ${_workingDeck.length}.'),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(milliseconds: 1800),
        ),
      );
      return;
    }

    widget.commandService.saveCustomGrimoire(_activeGeneral, _workingDeck);
    widget.commandService.initializeGrimoire();
    widget.onGrimoireSaved?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_profile.name}\'s Grimoire sealed ($_requiredDeckSize cards)!'),
        backgroundColor: _profile.themeColor,
        duration: const Duration(milliseconds: 1600),
      ),
    );
    Navigator.of(context).pop();
  }

  void _resetToDefault() {
    final defaultCards = GeneralCommandService.buildDefaultGrimoireForGeneral(_activeGeneral);
    setState(() {
      _workingDeck = defaultCards.map((c) => c.id).toList();
    });
  }

  void _upgradePhylactery() {
    final sigilCost = _rank == 1 ? 1 : 2;
    if (_currentSigils < sigilCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient Sigils! Upgrade requires $sigilCost Bloodline Sigils.'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    final newSigils = _currentSigils - sigilCost;
    widget.commandService.upgradePhylactery(_activeGeneral);
    final newRank = widget.commandService.getPhylacteryRank(_activeGeneral);

    setState(() {
      _currentSigils = newSigils;
    });

    widget.onSigilsChanged?.call(newSigils);
    widget.onPhylacteryUpgraded?.call(_activeGeneral, newRank);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_profile.name}\'s Phylactery consecrated to Rank $newRank!'),
        backgroundColor: _profile.themeColor,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isMobile = screenWidth < 680;
    final availablePool = GeneralCommandService.getAvailableOrderPoolForGeneral(_activeGeneral);

    final deckCounts = <String, int>{};
    for (final id in _workingDeck) {
      deckCounts[id] = (deckCounts[id] ?? 0) + 1;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 980,
        height: isMobile ? screenHeight * 0.94 : 760,
        decoration: BoxDecoration(
          color: const Color(0xFF101017),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _profile.themeColor.withValues(alpha: 0.8), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.9),
              blurRadius: 24,
              spreadRadius: 6,
            ),
            BoxShadow(
              color: _profile.themeColor.withValues(alpha: 0.25),
              blurRadius: 18,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(isMobile),

            // General Selector Tabs
            _buildGeneralTabs(),

            // Main Editor Body
            Expanded(
              child: isMobile
                  ? _buildMobileTabbedLayout(availablePool, deckCounts)
                  : _buildDesktopSplitLayout(availablePool, deckCounts),
            ),

            // Bottom Action Footer
            _buildFooter(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final int sigilCost = _rank == 1 ? 1 : 2;
    final bool canUpgrade = _rank < 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: _profile.themeColor.withValues(alpha: 0.4), width: 1.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_stories, color: _profile.themeColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'GRIMOIRE ARCHIVES',
                        style: TextStyle(
                          color: _profile.themeColor,
                          fontSize: isMobile ? 12.0 : 14.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _profile.themeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: _profile.themeColor.withValues(alpha: 0.6), width: 0.8),
                      ),
                      child: Text(
                        'RANK $_rank/3',
                        style: TextStyle(
                          color: _profile.themeColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_profile.name} • ${_profile.title} (DECK: ${_workingDeck.length}/$_requiredDeckSize CARDS)',
                  style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ],
            ),
          ),
          if (canUpgrade) ...[
            GestureDetector(
              onTap: _upgradePhylactery,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _currentSigils >= sigilCost
                        ? const [Color(0xFF801515), Color(0xFF4A0A0A)]
                        : const [Color(0xFF33333E), Color(0xFF1E1E26)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _currentSigils >= sigilCost ? const Color(0xFFFF5252) : Colors.white24,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.upgrade, size: 13, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 4),
                    Text(
                      'ANOINT RANK ${_rank + 1} ($sigilCost 🩸)',
                      style: const TextStyle(color: Colors.white, fontSize: 9.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTabs() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C12),
        border: Border(bottom: BorderSide(color: Color(0xFF242434), width: 1)),
      ),
      child: Row(
        children: GeneralProfile.allGenerals.map((g) {
          final bool isSelected = g.type == _activeGeneral;
          final int rank = widget.commandService.getPhylacteryRank(g.type);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_activeGeneral == g.type) return;
                setState(() {
                  _activeGeneral = g.type;
                  _syncWorkingDeck();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? g.themeColor.withValues(alpha: 0.18) : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? g.themeColor : Colors.transparent,
                      width: 2.2,
                    ),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(g.icon, size: 14, color: isSelected ? g.themeColor : const Color(0xFF8E8EA0)),
                      const SizedBox(width: 5),
                      Text(
                        '${g.name.split(' ').last} (R$rank)',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF8E8EA0),
                          fontSize: 10.0,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDesktopSplitLayout(
    List<GeneralOrderDefinition> availablePool,
    Map<String, int> deckCounts,
  ) {
    return Row(
      children: [
        // Left Column: Active Grimoire Deck
        Expanded(
          flex: 5,
          child: _buildDeckPanel(deckCounts),
        ),
        Container(width: 1.5, color: const Color(0xFF242434)),
        // Right Column: Order Archives / Spell Library
        Expanded(
          flex: 6,
          child: _buildLibraryPanel(availablePool, deckCounts),
        ),
      ],
    );
  }

  Widget _buildMobileTabbedLayout(
    List<GeneralOrderDefinition> availablePool,
    Map<String, int> deckCounts,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF14141E),
            child: TabBar(
              indicatorColor: _profile.themeColor,
              labelColor: _profile.themeColor,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'ACTIVE DECK (${_workingDeck.length}/$_requiredDeckSize)'),
                const Tab(text: 'ORDER ARCHIVES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDeckPanel(deckCounts),
                _buildLibraryPanel(availablePool, deckCounts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckPanel(Map<String, int> deckCounts) {
    final bool isDeckFull = _workingDeck.length == _requiredDeckSize;

    return Container(
      color: const Color(0xFF0F0F16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subheader
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF151520),
              border: Border(bottom: BorderSide(color: Color(0xFF242434), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'EQUIPPED IN GRIMOIRE',
                    style: TextStyle(
                      color: _profile.themeColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDeckFull ? const Color(0xFF1B5E20) : const Color(0xFF801515),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDeckFull ? const Color(0xFF81C784) : const Color(0xFFFF5252),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isDeckFull ? 'COMPLETE' : '${_requiredDeckSize - _workingDeck.length} NEEDED',
                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Cards list
          Expanded(
            child: _workingDeck.isEmpty
                ? const Center(
                    child: Text(
                      'Grimoire is currently empty.\nAdd orders from the Archives!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: deckCounts.keys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, idx) {
                      final orderId = deckCounts.keys.elementAt(idx);
                      final count = deckCounts[orderId] ?? 0;
                      final order = GeneralCommandService.findOrderById(orderId);
                      if (order == null) return const SizedBox.shrink();

                      final bool isUnlocked = widget.commandService.isOrderUnlockedForGeneral(_activeGeneral, order);

                      return _buildEquippedCardRow(order, count, isUnlocked);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedCardRow(GeneralOrderDefinition order, int count, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isUnlocked ? const Color(0xFF38384E) : const Color(0xFF801515),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isUnlocked
                    ? [const Color(0xFF2A2634), const Color(0xFF15141D)]
                    : [const Color(0xFF1C1A22), const Color(0xFF100F15)],
              ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isUnlocked ? _profile.themeColor : const Color(0xFF424254),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  !isUnlocked ? Icons.lock : (order.icon ?? Icons.auto_awesome),
                  size: 16,
                  color: isUnlocked ? _profile.themeColor : Colors.white38,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    !isUnlocked ? 'R${order.requiredPhylacteryRank}' : '${order.focusCost}V',
                    style: TextStyle(
                      color: isUnlocked ? const Color(0xFFFFD54F) : const Color(0xFFFF5252),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        order.name,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${order.focusCost}V',
                        style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 7.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!isUnlocked) ...[
                      const SizedBox(width: 3),
                      const Text(
                        '(LOCKED)',
                        style: TextStyle(color: Color(0xFFFF5252), fontSize: 7.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  order.description,
                  style: const TextStyle(color: Colors.white60, fontSize: 8.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Count and Adjust Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFFF5252)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeCardFromDeck(order.id),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'x$count',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF00E676)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _addCardToDeck(order),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryPanel(
    List<GeneralOrderDefinition> availablePool,
    Map<String, int> deckCounts,
  ) {
    return Container(
      color: const Color(0xFF13131C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subheader
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF181826),
              border: Border(bottom: BorderSide(color: Color(0xFF242434), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'ORDER ARCHIVES',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'TAP TO EQUIP',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8.5),
                ),
              ],
            ),
          ),

          // Orders Grid / List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: availablePool.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final order = availablePool[idx];
                final int inDeck = deckCounts[order.id] ?? 0;
                final bool isUnlocked = widget.commandService.isOrderUnlockedForGeneral(_activeGeneral, order);

                return _buildLibraryOrderCard(order, inDeck, isUnlocked);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryOrderCard(GeneralOrderDefinition order, int inDeck, bool isUnlocked) {
    final bool isSignature = order.id != 'rend_flesh' &&
        order.id != 'iron_bulwark' &&
        order.id != 'exsanguinating_strike' &&
        order.id != 'sanguine_revival' &&
        order.id != 'disrupting_cleave' &&
        order.id != 'blood_boil';

    return GestureDetector(
      onTap: () {
        if (!isUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${order.name} requires Phylactery Rank ${order.requiredPhylacteryRank}! Anoint ${_profile.name} to unlock.'),
              backgroundColor: const Color(0xFFB3261E),
              duration: const Duration(milliseconds: 1400),
            ),
          );
          return;
        }
        _addCardToDeck(order);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked ? const Color(0xFF1A1A28) : const Color(0xFF121218),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isUnlocked
                ? (isSignature ? _profile.themeColor.withValues(alpha: 0.6) : const Color(0xFF38384E))
                : const Color(0xFF2B2B36),
            width: isSignature ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Miniature Spell Badge
            Container(
              width: 50,
              height: 64,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: isUnlocked
                      ? [const Color(0xFF282535), const Color(0xFF14131B)]
                      : [const Color(0xFF1B1A22), const Color(0xFF0F0E13)],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isUnlocked
                      ? (isSignature ? _profile.themeColor : const Color(0xFFD4AF37))
                      : const Color(0xFF424254),
                  width: isSignature ? 1.5 : 1.0,
                ),
                boxShadow: (isUnlocked && isSignature)
                    ? [
                        BoxShadow(
                          color: _profile.themeColor.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !isUnlocked ? Icons.lock : (order.icon ?? Icons.auto_awesome),
                    size: 20,
                    color: isUnlocked
                        ? (isSignature ? _profile.themeColor : const Color(0xFFD4AF37))
                        : Colors.white30,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      !isUnlocked ? 'RANK ${order.requiredPhylacteryRank}' : '${order.focusCost} VITAE',
                      style: TextStyle(
                        color: !isUnlocked ? const Color(0xFFFF5252) : const Color(0xFFFFD54F),
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.name,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isSignature)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: _profile.themeColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'SIGNATURE',
                            style: TextStyle(color: _profile.themeColor, fontSize: 7.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const Spacer(),
                      if (inDeck > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF00E676), width: 0.8),
                          ),
                          child: Text(
                            'IN DECK: x$inDeck',
                            style: const TextStyle(color: Color(0xFF00E676), fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.description,
                    style: TextStyle(
                      color: isUnlocked ? Colors.white70 : Colors.white30,
                      fontSize: 9.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isUnlocked ? Icons.lock_open : Icons.lock,
                        size: 10,
                        color: isUnlocked ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isUnlocked
                            ? 'Rank ${order.requiredPhylacteryRank} Unlocked'
                            : 'Requires Phylactery Rank ${order.requiredPhylacteryRank}',
                        style: TextStyle(
                          color: isUnlocked ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                          fontSize: 8.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    final bool isDeckFull = _workingDeck.length == _requiredDeckSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF14141E),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
        border: Border(top: BorderSide(color: Color(0xFF242434), width: 1.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Reset to Default button
          TextButton.icon(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFB0BEC5)),
            label: const Text(
              'RESET DEFAULT',
              style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
          ),

          // Save / Seal Grimoire Button
          ElevatedButton.icon(
            onPressed: _saveDeck,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDeckFull ? const Color(0xFF1B5E20) : const Color(0xFF33333E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: isDeckFull ? const Color(0xFF81C784) : Colors.white24,
                  width: 1.0,
                ),
              ),
            ),
            icon: Icon(Icons.check, size: 15, color: isDeckFull ? Colors.white : Colors.white38),
            label: Text(
              isDeckFull ? 'SEAL GRIMOIRE ($_requiredDeckSize CARDS)' : 'INCOMPLETE (${_workingDeck.length}/$_requiredDeckSize)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: isDeckFull ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
