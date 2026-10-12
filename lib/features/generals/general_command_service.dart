import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../combat/initiative_tick_manager.dart';

enum GeneralType {
  vladislav,
  valeria,
  malakor,
  morrigan,
}

@immutable
class GeneralOrderDefinition {
  final String id;
  final String name;
  final int focusCost;
  final String description;
  final IconData icon;
  final bool requiresTargetEnemy;
  final bool requiresTargetAlly;
  final int requiredPhylacteryRank;

  const GeneralOrderDefinition({
    required this.id,
    required this.name,
    required this.focusCost,
    required this.description,
    required this.icon,
    this.requiresTargetEnemy = false,
    this.requiresTargetAlly = false,
    this.requiredPhylacteryRank = 1,
  });
}

@immutable
class GeneralProfile {
  final GeneralType type;
  final String id;
  final String name;
  final String title;
  final String auraName;
  final String auraDescription;
  final Color themeColor;
  final IconData icon;
  final List<GeneralOrderDefinition> orders;

  const GeneralProfile({
    required this.type,
    required this.id,
    required this.name,
    required this.title,
    required this.auraName,
    required this.auraDescription,
    required this.themeColor,
    required this.icon,
    required this.orders,
  });

  static const GeneralOrderDefinition rendFleshOrder = GeneralOrderDefinition(
    id: 'rend_flesh',
    name: 'REND FLESH',
    focusCost: 1,
    description: 'Strike target enemy with physical damage and inflict 2 stacks of Bleed.',
    icon: Icons.colorize,
    requiresTargetEnemy: true,
    requiredPhylacteryRank: 1,
  );

  static const GeneralOrderDefinition ironBulwarkOrder = GeneralOrderDefinition(
    id: 'iron_bulwark',
    name: 'IRON BULWARK',
    focusCost: 2,
    description: 'Fortify target ally with an Aegis Shield and +25 Armor.',
    icon: Icons.shield,
    requiresTargetAlly: true,
    requiredPhylacteryRank: 1,
  );

  static const GeneralOrderDefinition exsanguinatingStrikeOrder = GeneralOrderDefinition(
    id: 'exsanguinating_strike',
    name: 'EXSANGUINATE',
    focusCost: 3,
    description: 'Heavy strike dealing 2.5x damage against Bleeding targets or executing below 25% HP.',
    icon: Icons.dangerous,
    requiresTargetEnemy: true,
    requiredPhylacteryRank: 1,
  );

  static const GeneralOrderDefinition sanguineRevivalOrder = GeneralOrderDefinition(
    id: 'sanguine_revival',
    name: 'REVIVAL',
    focusCost: 4,
    description: 'Infuse Vitae into a fallen ally: revives with grace window and Aegis Shield overflow.',
    icon: Icons.healing,
    requiresTargetAlly: true,
    requiredPhylacteryRank: 1,
  );

  static const GeneralOrderDefinition disruptingCleaveOrder = GeneralOrderDefinition(
    id: 'disrupting_cleave',
    name: 'DISRUPT',
    focusCost: 2,
    description: 'Cleave enemy formation and reduce target AP / Turn Meter by 25%.',
    icon: Icons.flash_on,
    requiresTargetEnemy: true,
    requiredPhylacteryRank: 1,
  );

  static const GeneralOrderDefinition bloodBoilOrder = GeneralOrderDefinition(
    id: 'blood_boil',
    name: 'BLOOD BOIL',
    focusCost: 2,
    description: 'Grant target ally Haste (+35% Speed) at the cost of 5% current HP recoil.',
    icon: Icons.whatshot,
    requiresTargetAlly: true,
    requiredPhylacteryRank: 1,
  );

  static const List<GeneralProfile> allGenerals = [
    GeneralProfile(
      type: GeneralType.vladislav,
      id: 'vladislav_01',
      name: 'Lord Vladislav',
      title: 'The Blood Sovereign',
      auraName: 'Crimson Tithe',
      auraDescription: 'Squad gains +8% Lifesteal against wounded and Bleeding targets.',
      themeColor: Color(0xFFB3261E),
      icon: Icons.bloodtype,
      orders: [
        GeneralOrderDefinition(
          id: 'siphon_vitality',
          name: 'SIPHON',
          focusCost: 1,
          description: 'Drain 15% HP from target enemy; heal frontline Vanguard allies.',
          icon: Icons.water_drop,
          requiresTargetEnemy: true,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'sanguine_ward',
          name: 'WARD',
          focusCost: 2,
          description: 'Sacrifice 15% team HP to create an Armor barrier equal to 200% of sacrificed vitality.',
          icon: Icons.shield,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'feast_of_ruin',
          name: 'EXECUTE',
          focusCost: 3,
          description: 'Instantly execute enemy below 20% HP and surge squad with +50% Turn Meter.',
          icon: Icons.dangerous,
          requiresTargetEnemy: true,
          requiredPhylacteryRank: 3,
        ),
        rendFleshOrder,
        ironBulwarkOrder,
        exsanguinatingStrikeOrder,
        sanguineRevivalOrder,
        disruptingCleaveOrder,
        bloodBoilOrder,
      ],
    ),
    GeneralProfile(
      type: GeneralType.valeria,
      id: 'valeria_01',
      name: 'Lady Valeria',
      title: 'The Iron Justiciar',
      auraName: 'Iron Aegis',
      auraDescription: 'Frontline Vanguard gains +25% Armor and reflects 15% physical damage.',
      themeColor: Color(0xFFD4AF37),
      icon: Icons.shield_moon,
      orders: [
        GeneralOrderDefinition(
          id: 'stand_resolute',
          name: 'RESOLUTE',
          focusCost: 1,
          description: 'Fortify targeted ally with +40% Armor.',
          icon: Icons.security,
          requiresTargetAlly: true,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'retributive_stride',
          name: 'COUNTER',
          focusCost: 2,
          description: 'All Vanguard allies execute an immediate free counter-strike against enemies.',
          icon: Icons.flash_on,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'smite_the_wicked',
          name: 'SMITE',
          focusCost: 3,
          description: 'High-impact divine strike scaling with 80% of total squad Armor.',
          icon: Icons.bolt,
          requiresTargetEnemy: true,
          requiredPhylacteryRank: 3,
        ),
      ],
    ),
    GeneralProfile(
      type: GeneralType.malakor,
      id: 'malakor_01',
      name: 'Malakor',
      title: 'The Blight Father',
      auraName: 'Carrion Miasma',
      auraDescription: 'When an ally falls, all enemies gain 2 stacks of Blight.',
      themeColor: Color(0xFF2E7D32),
      icon: Icons.coronavirus,
      orders: [
        GeneralOrderDefinition(
          id: 'corpse_burst',
          name: 'BURST',
          focusCost: 1,
          description: 'Detonate necrotic miasma dealing 140 poison damage to all enemies and inflicting Blight.',
          icon: Icons.bubble_chart,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'virulent_cascade',
          name: 'CASCADE',
          focusCost: 2,
          description: 'Trigger 160 burst damage on all blighted foes and add a Blight stack.',
          icon: Icons.grain,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'rebind_flesh',
          name: 'REBIND',
          focusCost: 3,
          description: 'Resurrect a fallen ally with 40% HP and 100% TM (or heal team if none fallen).',
          icon: Icons.healing,
          requiredPhylacteryRank: 3,
        ),
      ],
    ),
    GeneralProfile(
      type: GeneralType.morrigan,
      id: 'morrigan_01',
      name: 'Morrigan',
      title: 'The Ashen Oracle',
      auraName: 'Temporal Threads',
      auraDescription: 'Squad gains +10% Speed; critical hits grant +5% Turn Meter.',
      themeColor: Color(0xFF7B1FA2),
      icon: Icons.hourglass_full,
      orders: [
        GeneralOrderDefinition(
          id: 'quicken',
          name: 'QUICKEN',
          focusCost: 1,
          description: 'Immediately grant target ally 100% Turn Meter so they act next.',
          icon: Icons.fast_forward,
          requiresTargetAlly: true,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'unravel_hex',
          name: 'UNRAVEL',
          focusCost: 2,
          description: 'Cleanse all debuffs from squad and strip 30% Armor from all enemies.',
          icon: Icons.auto_fix_high,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'echoing_hourglass',
          name: 'HOURGLASS',
          focusCost: 3,
          description: 'Grant all allies +40% Turn Meter and reduce skill cooldowns by 1.',
          icon: Icons.update,
          requiredPhylacteryRank: 3,
        ),
      ],
    ),
  ];

  static GeneralProfile getByType(GeneralType type) {
    return allGenerals.firstWhere(
      (g) => g.type == type,
      orElse: () => allGenerals.first,
    );
  }
}

@immutable
class OrderResult {
  final String orderId;
  final String orderName;
  final int focusSpent;
  final int remainingFocus;
  final String summary;
  final List<UnitEntity> updatedAllies;
  final List<UnitEntity> updatedEnemies;

  const OrderResult({
    required this.orderId,
    required this.orderName,
    required this.focusSpent,
    required this.remainingFocus,
    required this.summary,
    required this.updatedAllies,
    required this.updatedEnemies,
  });
}

@immutable
class RecordedAction {
  final SkillEntity skill;
  final String targetUnitId;

  const RecordedAction({required this.skill, required this.targetUnitId});
}

class GeneralCommandService extends ChangeNotifier {
  static const int maxFocusCap = 3;
  static const int defaultMaxFocusCap = 3;
  static const int grimoireMaxFocusCap = 6;
  static const int maxHandSize = 3;
  static const double focusChargeThreshold = 500.0; // Damage dealt/taken per 1 Focus point

  final InitiativeTickManager tickManager;
  GeneralType _activeGeneralType;

  int _maxFocusCap;
  int _currentFocus;
  double _accumulatedDamageProgress = 0.0;

  // Grimoire State (GDD v2.6 Sec 5 & 14.1)
  final List<GeneralOrderDefinition> _grimoireDeck = [];
  final List<GeneralOrderDefinition> _hand = [];
  final List<GeneralOrderDefinition> _discardPile = [];
  int _burnCooldownTicks = 0;
  int _focusTickAccumulator = 0;
  bool _isBulletTimeActive = false;

  final Map<GeneralType, int> _phylacteryRanks = {
    GeneralType.vladislav: 1,
    GeneralType.valeria: 1,
    GeneralType.malakor: 1,
    GeneralType.morrigan: 1,
  };

  GeneralCommandService({
    required this.tickManager,
    String? generalId,
    String? generalName,
    GeneralType generalType = GeneralType.vladislav,
    int initialFocus = 1,
    int? maxFocus,
    Map<GeneralType, int>? initialPhylacteryRanks,
  })  : _activeGeneralType = generalType,
        _maxFocusCap = maxFocus ?? defaultMaxFocusCap,
        _currentFocus = initialFocus.clamp(0, maxFocus ?? defaultMaxFocusCap) {
    if (initialPhylacteryRanks != null) {
      _phylacteryRanks.addAll(initialPhylacteryRanks);
    }
  }

  GeneralType get activeGeneralType => _activeGeneralType;
  GeneralProfile get currentProfile => GeneralProfile.getByType(_activeGeneralType);

  String get generalId => currentProfile.id;
  String get generalName => currentProfile.name;
  int get currentFocus => _currentFocus;
  int get maxFocus => _maxFocusCap;
  int get currentMaxFocus => _maxFocusCap;
  set maxFocusCapValue(int val) {
    _maxFocusCap = val;
    if (_currentFocus > _maxFocusCap) _currentFocus = _maxFocusCap;
    notifyListeners();
  }
  bool get isFocusMaxed => _currentFocus >= _maxFocusCap;
  double get focusProgressRatio =>
      (_accumulatedDamageProgress / focusChargeThreshold).clamp(0.0, 1.0);
  double get focusChargeProgress => focusProgressRatio;

  /// GDD v2.9 Section 4.1: Asymmetric Commander Deck Capacity Matrix
  int get deckLimit {
    switch (_activeGeneralType) {
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

  /// GDD v2.9 Section 4.1: Asymmetric Commander Hand Size
  int get maxHandSizeForGeneral {
    switch (_activeGeneralType) {
      case GeneralType.morrigan:
        return 4; // Rapid Sky-Chymist: 4 Slips
      case GeneralType.valeria:
      case GeneralType.vladislav:
      case GeneralType.malakor:
      default:
        return 3;
    }
  }

  /// GDD v2.9 Section 4.1: Baseline Starting Focus per Commander
  int get defaultStartingFocus {
    switch (_activeGeneralType) {
      case GeneralType.vladislav:
        return 2;
      case GeneralType.valeria:
        return 3;
      case GeneralType.morrigan:
        return 3;
      case GeneralType.malakor:
        return 1;
    }
  }

  /// GDD v2.9 Section 4.1: Maximum Focus Cap per Commander
  int get grimoireMaxFocusCapForGeneral {
    switch (_activeGeneralType) {
      case GeneralType.vladislav:
        return 6;
      case GeneralType.valeria:
        return 7;
      case GeneralType.morrigan:
        return 5;
      case GeneralType.malakor:
        return 8;
    }
  }

  /// GDD v2.9 Section 4.1: Baseline Focus Tick Interval (Ticks required to generate 1 Focus)
  int get baseFocusTickInterval {
    switch (_activeGeneralType) {
      case GeneralType.morrigan:
        return 20; // 0.66s at 30Hz
      case GeneralType.vladislav:
        return 30; // 1.0s at 30Hz
      case GeneralType.malakor:
        return 35; // Ramping
      case GeneralType.valeria:
        return 40; // 1.33s at 30Hz
    }
  }

  // Grimoire Getters (GDD v2.6 Sec 5)
  List<GeneralOrderDefinition> get hand => List.unmodifiable(_hand);
  List<GeneralOrderDefinition> get grimoireDeck => List.unmodifiable(_grimoireDeck);
  List<GeneralOrderDefinition> get discardPile => List.unmodifiable(_discardPile);
  int get burnCooldownTicks => _burnCooldownTicks;
  bool get isBulletTimeActive => _isBulletTimeActive;
  double get simulationSpeedMultiplier => _isBulletTimeActive ? 0.30 : 1.0;

  Map<GeneralType, int> get allPhylacteryRanks => Map.unmodifiable(_phylacteryRanks);

  int get activePhylacteryRank => getPhylacteryRank(_activeGeneralType);

  int get getActivePhylacteryRank => getPhylacteryRank(_activeGeneralType);

  int getPhylacteryRank(GeneralType type) => _phylacteryRanks[type] ?? 1;

  /// Last action performed by each ally (unitId -> skill + target), replayed by Echoing Hourglass.
  final Map<String, RecordedAction> _lastActions = {};

  /// Corpses already detonated by Corpse Burst; they cannot be detonated or rebound again.
  final Set<String> _consumedCorpseIds = {};

  Map<String, RecordedAction> get lastActions => Map.unmodifiable(_lastActions);
  Set<String> get consumedCorpseIds => Set.unmodifiable(_consumedCorpseIds);

  /// Called by the combat engine whenever an ally resolves a skill.
  void recordUnitAction(String unitId, SkillEntity skill, String targetUnitId) {
    _lastActions[unitId] = RecordedAction(skill: skill, targetUnitId: targetUnitId);
  }

  /// Clears per-battle memory (last actions, consumed corpses) when a new encounter begins.
  void resetBattleMemory() {
    _lastActions.clear();
    _consumedCorpseIds.clear();
  }

  /// Fallen units that remain intact (not yet detonated).
  bool _isIntactCorpse(UnitEntity u) => !u.isAlive && !_consumedCorpseIds.contains(u.id);

  double get potencyMultiplier {
    final rank = activePhylacteryRank;
    if (rank >= 3) return 1.35; // Rank 3 Mastery
    if (rank >= 2) return 1.20; // Rank 2 Potency
    return 1.0;
  }

  /// Checks if an order is unlocked under the current General's active Phylactery rank.
  bool isOrderUnlocked(GeneralOrderDefinition order) {
    return activePhylacteryRank >= order.requiredPhylacteryRank;
  }

  /// Checks if an order is unlocked for a specific general type.
  bool isOrderUnlockedForGeneral(GeneralType type, GeneralOrderDefinition order) {
    return getPhylacteryRank(type) >= order.requiredPhylacteryRank;
  }

  bool upgradePhylactery(GeneralType type) {
    final current = getPhylacteryRank(type);
    if (current >= 3) return false;
    _phylacteryRanks[type] = current + 1;
    notifyListeners();
    return true;
  }

  void setActiveGeneral(GeneralType type) {
    if (_activeGeneralType == type) return;
    _activeGeneralType = type;
    notifyListeners();
  }

  /// Accumulates damage dealt or taken across the squad and converts it to Focus points.
  void registerCombatDamage(int damage) {
    if (_currentFocus >= _maxFocusCap || damage <= 0) return;

    _accumulatedDamageProgress += damage;

    while (_accumulatedDamageProgress >= focusChargeThreshold && _currentFocus < _maxFocusCap) {
      _accumulatedDamageProgress -= focusChargeThreshold;
      _currentFocus++;
    }

    if (_currentFocus == _maxFocusCap) {
      _accumulatedDamageProgress = 0.0;
    }

    notifyListeners();
  }

  /// Manually grants flat Focus (e.g. from Altar rewards or Relic triggers).
  void grantFocus(int points) {
    _currentFocus = (_currentFocus + points).clamp(0, _maxFocusCap);
    notifyListeners();
  }

  void _validateOrderUnlocked(String orderId) {
    final order = currentProfile.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw ArgumentError('Unknown order $orderId for ${currentProfile.name}.'),
    );
    if (!isOrderUnlocked(order)) {
      throw StateError(
        'Order ${order.name} is sealed! Requires Phylactery Rank ${order.requiredPhylacteryRank}. Anoint ${currentProfile.name} in the Phylactery.',
      );
    }
  }

  /// Validates and spends focus points. Throws an error if insufficient.
  void _spendFocus(int cost) {
    if (_currentFocus < cost) {
      throw StateError(
        'Insufficient Command Focus: Attempted to spend $cost, but only have $_currentFocus.',
      );
    }
    _currentFocus -= cost;
    notifyListeners();
  }

  // ===========================================================================
  // GRIMOIRE DECK & HAND LIFECYCLE (GDD v2.6 SEC 5 & 14.1)
  // ===========================================================================

  void _onCardPlayed(String cardId) {
    final int handIdx = _hand.indexWhere((c) => c.id == cardId);
    if (handIdx != -1) {
      final card = _hand.removeAt(handIdx);
      _discardPile.add(card);
      drawCard();
      notifyListeners();
    }
  }

  /// GDD v2.9 Section 4.1 & 5.1: Builds the default asymmetric Grimoire deck per Commander.
  static List<GeneralOrderDefinition> buildDefaultGrimoireForGeneral(GeneralType type) {
    switch (type) {
      case GeneralType.valeria:
        return [
          GeneralProfile.getByType(GeneralType.valeria).orders.firstWhere((o) => o.id == 'stand_resolute'),
          GeneralProfile.getByType(GeneralType.valeria).orders.firstWhere((o) => o.id == 'stand_resolute'),
          GeneralProfile.getByType(GeneralType.valeria).orders.firstWhere((o) => o.id == 'retributive_stride'),
          GeneralProfile.getByType(GeneralType.valeria).orders.firstWhere((o) => o.id == 'retributive_stride'),
          GeneralProfile.getByType(GeneralType.valeria).orders.firstWhere((o) => o.id == 'smite_the_wicked'),
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.disruptingCleaveOrder,
          GeneralProfile.disruptingCleaveOrder,
          GeneralProfile.sanguineRevivalOrder,
        ]; // Exactly 10 cards
      case GeneralType.malakor:
        return [
          GeneralProfile.getByType(GeneralType.malakor).orders.firstWhere((o) => o.id == 'corpse_burst'),
          GeneralProfile.getByType(GeneralType.malakor).orders.firstWhere((o) => o.id == 'corpse_burst'),
          GeneralProfile.getByType(GeneralType.malakor).orders.firstWhere((o) => o.id == 'virulent_cascade'),
          GeneralProfile.getByType(GeneralType.malakor).orders.firstWhere((o) => o.id == 'virulent_cascade'),
          GeneralProfile.getByType(GeneralType.malakor).orders.firstWhere((o) => o.id == 'rebind_flesh'),
          GeneralProfile.rendFleshOrder,
          GeneralProfile.rendFleshOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.disruptingCleaveOrder,
          GeneralProfile.disruptingCleaveOrder,
          GeneralProfile.sanguineRevivalOrder,
          GeneralProfile.bloodBoilOrder,
          GeneralProfile.bloodBoilOrder,
        ]; // Exactly 14 cards
      case GeneralType.morrigan:
        return [
          GeneralProfile.getByType(GeneralType.morrigan).orders.firstWhere((o) => o.id == 'quicken'),
          GeneralProfile.getByType(GeneralType.morrigan).orders.firstWhere((o) => o.id == 'quicken'),
          GeneralProfile.getByType(GeneralType.morrigan).orders.firstWhere((o) => o.id == 'quicken'),
          GeneralProfile.getByType(GeneralType.morrigan).orders.firstWhere((o) => o.id == 'unravel_hex'),
          GeneralProfile.getByType(GeneralType.morrigan).orders.firstWhere((o) => o.id == 'unravel_hex'),
          GeneralProfile.getByType(GeneralType.morrigan).orders.firstWhere((o) => o.id == 'echoing_hourglass'),
          GeneralProfile.getByType(GeneralType.morrigan).orders.firstWhere((o) => o.id == 'echoing_hourglass'),
          GeneralProfile.rendFleshOrder,
          GeneralProfile.rendFleshOrder,
          GeneralProfile.rendFleshOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.exsanguinatingStrikeOrder,
          GeneralProfile.exsanguinatingStrikeOrder,
          GeneralProfile.disruptingCleaveOrder,
          GeneralProfile.disruptingCleaveOrder,
          GeneralProfile.disruptingCleaveOrder,
          GeneralProfile.bloodBoilOrder,
          GeneralProfile.bloodBoilOrder,
        ]; // Exactly 20 cards
      case GeneralType.vladislav:
      default:
        return [
          GeneralProfile.getByType(GeneralType.vladislav).orders.firstWhere((o) => o.id == 'siphon_vitality'),
          GeneralProfile.getByType(GeneralType.vladislav).orders.firstWhere((o) => o.id == 'siphon_vitality'),
          GeneralProfile.getByType(GeneralType.vladislav).orders.firstWhere((o) => o.id == 'sanguine_ward'),
          GeneralProfile.getByType(GeneralType.vladislav).orders.firstWhere((o) => o.id == 'feast_of_ruin'),
          GeneralProfile.rendFleshOrder,
          GeneralProfile.rendFleshOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.ironBulwarkOrder,
          GeneralProfile.exsanguinatingStrikeOrder,
          GeneralProfile.exsanguinatingStrikeOrder,
          GeneralProfile.sanguineRevivalOrder,
          GeneralProfile.bloodBoilOrder,
        ]; // Exactly 12 cards
    }
  }

  /// Initializes the asymmetric Grimoire deck and draws initial hand.
  void initializeGrimoire({List<GeneralOrderDefinition>? customDeck}) {
    _hand.clear();
    _discardPile.clear();
    _burnCooldownTicks = 0;
    _isBulletTimeActive = false;
    _maxFocusCap = grimoireMaxFocusCapForGeneral;
    if (_currentFocus < defaultStartingFocus) {
      _currentFocus = defaultStartingFocus;
    }
    if (_currentFocus > _maxFocusCap) {
      _currentFocus = _maxFocusCap;
    }

    _grimoireDeck.clear();
    if (customDeck != null && customDeck.isNotEmpty) {
      _grimoireDeck.addAll(customDeck);
    } else {
      _grimoireDeck.addAll(buildDefaultGrimoireForGeneral(_activeGeneralType));
    }

    // Draw up to maxHandSizeForGeneral cards
    while (_hand.length < maxHandSizeForGeneral && _grimoireDeck.isNotEmpty) {
      _hand.add(_grimoireDeck.removeAt(0));
    }
    notifyListeners();
  }

  /// Draws a card from the deck into hand. Reshuffles discard pile if deck is empty.
  GeneralOrderDefinition? drawCard() {
    if (_hand.length >= maxHandSizeForGeneral) return null;
    if (_grimoireDeck.isEmpty) {
      if (_discardPile.isEmpty) return null;
      // Deck Reshuffle: recycles discard pile with zero penalty
      _grimoireDeck.addAll(_discardPile);
      _discardPile.clear();
    }
    if (_grimoireDeck.isEmpty) return null;
    final card = _grimoireDeck.removeAt(0);
    _hand.add(card);
    notifyListeners();
    return card;
  }

  /// Discards a card from hand to the Burn Pit (costs 0 Focus),
  /// triggering a 6-tick safety cooldown before drawing a replacement.
  void burnCard(String cardId) {
    final int handIdx = _hand.indexWhere((c) => c.id == cardId);
    if (handIdx == -1) return;
    final card = _hand.removeAt(handIdx);
    _discardPile.add(card);
    _burnCooldownTicks = 6;
    notifyListeners();
  }

  /// Called each simulation tick to process burn cooldowns and Focus generation.
  void onSimulationTick() {
    bool stateChanged = false;

    // GDD v2.9 Sec 4.1: Asymmetric Focus generation intervals
    final commanderUnit = tickManager.allies.where((u) => u.isCommander).firstOrNull;
    final bool isCommanderDowned = commanderUnit != null && !commanderUnit.isAlive;
    final int baseTicks = baseFocusTickInterval;
    final int requiredTicks = isCommanderDowned ? (baseTicks * 2) : baseTicks;

    if (_currentFocus < _maxFocusCap) {
      _focusTickAccumulator++;
      if (_focusTickAccumulator >= requiredTicks) {
        _focusTickAccumulator = 0;
        _currentFocus++;
        stateChanged = true;
      }
    }

    if (_burnCooldownTicks > 0) {
      _burnCooldownTicks--;
      if (_burnCooldownTicks == 0) {
        drawCard();
      }
      stateChanged = true;
    }

    if (stateChanged) {
      notifyListeners();
    }
  }

  /// Toggles Bullet-Time (slows simulation to 30% speed).
  void setBulletTime(bool active) {
    if (_isBulletTimeActive == active) return;
    _isBulletTimeActive = active;
    notifyListeners();
  }

  /// GDD v2.8 Sec 3.5: Returns the effective focus cost of an order accounting for
  /// Commander leadership aura (e.g., Lord Vladislav in Arcanum reduces Bleed orders by 1 Focus).
  int getEffectiveFocusCost(GeneralOrderDefinition order) {
    int cost = order.focusCost;
    if (activeGeneralType == GeneralType.vladislav) {
      final commander = tickManager.allies.where((u) => u.isCommander).firstOrNull;
      if (commander != null && commander.isArcanum && commander.isAlive) {
        if (order.id == 'rend_flesh' || order.id == 'exsanguinating_strike') {
          cost = max(0, cost - 1);
        }
      }
    }
    return cost;
  }

  // ===========================================================================
  // 1A. LORD VLADISLAV 6-CARD GRIMOIRE ORDERS (MVP SPEC GDD v2.6 SEC 14.1)
  // ===========================================================================

  /// Rend Flesh (Cost: 1 Focus; 0 Focus if Vladislav is in Arcanum)
  /// Strike + Bleed DoT.
  OrderResult executeRendFlesh(String targetEnemyId) {
    _validateOrderUnlocked('rend_flesh');
    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    // GDD v2.8 Sec 3.5: Vladislav Backline placement reduces Bleed Tuning Slips cost by 1 (min 0)
    final vladislavUnit = tickManager.allies.where((u) => u.isCommander).firstOrNull;
    final bool isVladislavBackline = vladislavUnit != null && vladislavUnit.isArcanum && vladislavUnit.isAlive;
    final int cost = isVladislavBackline ? 0 : 1;
    _spendFocus(cost);

    final UnitEntity target = enemies[enemyIdx];
    final double prr = CombatMath.calculatePrr(target.armor);
    final int rawDmg = (160 * potencyMultiplier).round();
    final int netDmg = max(1, (rawDmg * (1.0 - prr)).round());
    final int newHp = max(0, target.currentHp - netDmg);

    final List<StatusEffect> updatedEffects = List.of(target.activeEffects);
    updatedEffects.add(const StatusEffect(
      type: StatusEffectType.bleed,
      durationTurns: 3,
      value: 40,
    ));
    updatedEffects.add(const StatusEffect(
      type: StatusEffectType.bleed,
      durationTurns: 3,
      value: 40,
    ));

    enemies[enemyIdx] = target.copyWith(
      currentHp: newHp,
      activeEffects: updatedEffects,
    );

    _applyStateToTickManager(tickManager.allies, enemies);
    _onCardPlayed('rend_flesh');

    return OrderResult(
      orderId: 'rend_flesh',
      orderName: 'Rend Flesh',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Inflicted $netDmg damage and 2 Bleed stacks on ${target.name}.',
      updatedAllies: tickManager.allies,
      updatedEnemies: enemies,
    );
  }

  /// Iron Bulwark (Cost: 2 Focus)
  /// Aegis Shield + Armor boost.
  OrderResult executeIronBulwark(String targetAllyId) {
    _validateOrderUnlocked('iron_bulwark');
    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId not found or already defeated.');
    }

    const int cost = 2;
    _spendFocus(cost);

    final UnitEntity target = allies[allyIdx];
    final int shieldValue = (250 * potencyMultiplier).round();
    final List<StatusEffect> updatedEffects = List.of(target.activeEffects);
    updatedEffects.add(StatusEffect(
      type: StatusEffectType.shield,
      durationTurns: 3,
      value: shieldValue,
    ));
    updatedEffects.add(const StatusEffect(
      type: StatusEffectType.defenseUp,
      durationTurns: 3,
      value: 25,
    ));

    allies[allyIdx] = target.copyWith(
      activeEffects: updatedEffects,
      defense: target.defense + 25,
    );

    _applyStateToTickManager(allies, tickManager.enemies);
    _onCardPlayed('iron_bulwark');

    return OrderResult(
      orderId: 'iron_bulwark',
      orderName: 'Iron Bulwark',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Fortified ${target.name} with $shieldValue Aegis Shield and +25 Armor.',
      updatedAllies: allies,
      updatedEnemies: tickManager.enemies,
    );
  }

  /// Exsanguinating Strike (Cost: 3 Focus)
  /// Execute bonus vs. Bleeding targets or targets below 25% HP.
  OrderResult executeExsanguinatingStrike(String targetEnemyId) {
    _validateOrderUnlocked('exsanguinating_strike');
    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    // GDD v2.8 Sec 3.5: Vladislav Backline placement reduces the Focus cost of all Bleed Tuning Slips by 1 (min 1).
    final vladislavUnit = tickManager.allies.where((u) => u.isCommander).firstOrNull;
    final bool isVladislavBackline = vladislavUnit != null && vladislavUnit.isArcanum && vladislavUnit.isAlive;
    final int cost = isVladislavBackline ? 2 : 3;
    _spendFocus(cost);

    final UnitEntity target = enemies[enemyIdx];
    final bool isBleeding = target.activeEffects.any((e) => e.type == StatusEffectType.bleed);
    final bool isLowHp = (target.currentHp / target.maxHp) <= 0.25;

    int damageDealt;
    String summary;

    if (isLowHp) {
      damageDealt = target.currentHp;
      enemies[enemyIdx] = target.copyWith(currentHp: 0);
      summary = 'Executed ${target.name} under 25% HP threshold!';
    } else if (isBleeding) {
      final double prr = CombatMath.calculatePrr(target.armor);
      final int rawDmg = (200 * 2.5 * potencyMultiplier).round();
      damageDealt = max(1, (rawDmg * (1.0 - prr)).round());
      final int newHp = max(0, target.currentHp - damageDealt);
      enemies[enemyIdx] = target.copyWith(currentHp: newHp);
      summary = 'Exsanguinated ${target.name} for $damageDealt amplified damage (2.5x vs Bleed)!';
    } else {
      final double prr = CombatMath.calculatePrr(target.armor);
      final int rawDmg = (200 * potencyMultiplier).round();
      damageDealt = max(1, (rawDmg * (1.0 - prr)).round());
      final int newHp = max(0, target.currentHp - damageDealt);
      enemies[enemyIdx] = target.copyWith(currentHp: newHp);
      summary = 'Struck ${target.name} for $damageDealt physical damage.';
    }

    _applyStateToTickManager(tickManager.allies, enemies);
    _onCardPlayed('exsanguinating_strike');

    return OrderResult(
      orderId: 'exsanguinating_strike',
      orderName: 'Exsanguinating Strike',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: summary,
      updatedAllies: tickManager.allies,
      updatedEnemies: enemies,
    );
  }

  /// Sanguine Revival (Cost: 4 Focus)
  /// Infused Vitae revive targeting a fallen Inert Vessel.
  OrderResult executeSanguineRevival(String targetAllyId) {
    _validateOrderUnlocked('sanguine_revival');
    if (tickManager.areRevivesDisabled) {
      throw StateError('Revives are strictly disabled during Terminal Collapse!');
    }

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && !u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId is not a fallen Inert Vessel.');
    }

    const int cost = 4;
    _spendFocus(cost);

    final UnitEntity target = allies[allyIdx];
    final int newReviveCount = target.reviveCount + 1;
    final int effectiveCap = (target.maxHp * pow(0.80, newReviveCount)).round();

    final int rawHeal = ((350 * potencyMultiplier) * tickManager.reckoningHealingMultiplier).round();
    final int finalHp = min(effectiveCap, max(1, rawHeal));
    final int overflow = max(0, rawHeal - effectiveCap);
    final int aegisShield = (overflow * 0.50).round();

    final List<StatusEffect> updatedEffects = target.activeEffects
        .where((e) => !e.isDebuff)
        .toList();

    updatedEffects.add(const StatusEffect(
      type: StatusEffectType.invulnerable,
      durationTurns: 1,
      value: 6,
    ));

    if (aegisShield > 0) {
      updatedEffects.add(StatusEffect(
        type: StatusEffectType.shield,
        durationTurns: 2,
        value: aegisShield,
      ));
    }

    allies[allyIdx] = target.copyWith(
      currentHp: finalHp,
      reviveCount: newReviveCount,
      turnMeter: 0.0,
      activeEffects: updatedEffects,
    );

    _applyStateToTickManager(allies, tickManager.enemies);
    _onCardPlayed('sanguine_revival');

    return OrderResult(
      orderId: 'sanguine_revival',
      orderName: 'Sanguine Revival',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Revived ${target.name} with $finalHp HP, 6-tick Grace, and $aegisShield Aegis Shield.',
      updatedAllies: allies,
      updatedEnemies: tickManager.enemies,
    );
  }

  /// Disrupting Cleave (Cost: 2 Focus)
  /// Staggers enemy AP gauge by 25%.
  OrderResult executeDisruptingCleave(String targetEnemyId) {
    _validateOrderUnlocked('disrupting_cleave');
    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    const int cost = 2;
    _spendFocus(cost);

    final UnitEntity target = enemies[enemyIdx];
    final double prr = CombatMath.calculatePrr(target.armor);
    final int rawDmg = (140 * potencyMultiplier).round();
    final int netDmg = max(1, (rawDmg * (1.0 - prr)).round());
    final int newHp = max(0, target.currentHp - netDmg);

    final double newTurnMeter = max(0.0, target.turnMeter - 25.0);

    enemies[enemyIdx] = target.copyWith(
      currentHp: newHp,
      turnMeter: newTurnMeter,
    );

    _applyStateToTickManager(tickManager.allies, enemies);
    _onCardPlayed('disrupting_cleave');

    return OrderResult(
      orderId: 'disrupting_cleave',
      orderName: 'Disrupting Cleave',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Dealt $netDmg damage and disrupted ${target.name}\'s AP gauge by 25%.',
      updatedAllies: tickManager.allies,
      updatedEnemies: enemies,
    );
  }

  /// Blood Boil (Cost: 2 Focus)
  /// Haste buff +35% SPD with minor recoil (5% HP).
  OrderResult executeBloodBoil(String targetAllyId) {
    _validateOrderUnlocked('blood_boil');
    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId not found or already defeated.');
    }

    const int cost = 2;
    _spendFocus(cost);

    final UnitEntity target = allies[allyIdx];
    final int recoil = max(1, (target.currentHp * 0.05).round());
    final int newHp = max(1, target.currentHp - recoil);

    final List<StatusEffect> updatedEffects = List.of(target.activeEffects);
    updatedEffects.add(const StatusEffect(
      type: StatusEffectType.speedUp,
      durationTurns: 3,
      value: 35,
    ));

    allies[allyIdx] = target.copyWith(
      currentHp: newHp,
      speed: (target.speed * 1.35).round(),
      activeEffects: updatedEffects,
    );

    _applyStateToTickManager(allies, tickManager.enemies);
    _onCardPlayed('blood_boil');

    return OrderResult(
      orderId: 'blood_boil',
      orderName: 'Blood Boil',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Granted +35% Haste to ${target.name} at cost of $recoil recoil HP.',
      updatedAllies: allies,
      updatedEnemies: tickManager.enemies,
    );
  }

  // ===========================================================================
  // 1B. LORD VLADISLAV LEGACY ORDERS
  // ===========================================================================

  /// Siphon Vitality (Cost: 1 Focus)
  OrderResult executeSiphonVitality(String targetEnemyId) {
    _validateOrderUnlocked('siphon_vitality');
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    final UnitEntity target = enemies[enemyIdx];
    final int drainAmount = max(1, ((target.currentHp * 0.15) * potencyMultiplier).round());
    final UnitEntity updatedTarget = target.copyWith(
      currentHp: max(0, target.currentHp - drainAmount),
    );
    enemies[enemyIdx] = updatedTarget;

    List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> aliveVanguard = allies.where((u) => u.isVanguard && u.isAlive).toList();

    if (aliveVanguard.isNotEmpty) {
      final int healPerVanguard = max(1, (drainAmount / aliveVanguard.length).round());
      allies = allies.map((u) {
        if (u.isVanguard && u.isAlive) {
          final int newHp = min(u.maxHp, u.currentHp + healPerVanguard);
          return u.copyWith(currentHp: newHp);
        }
        return u;
      }).toList();
    }

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('siphon_vitality');

    return OrderResult(
      orderId: 'siphon_vitality',
      orderName: 'Siphon Vitality',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Drained $drainAmount HP from ${target.name} and healed frontline.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Sanguine Ward (Cost: 2 Focus)
  OrderResult executeSanguineWard() {
    _validateOrderUnlocked('sanguine_ward');
    const int cost = 2;
    _spendFocus(cost);

    int totalSacrificedHp = 0;
    List<UnitEntity> allies = List.of(tickManager.allies);

    allies = allies.map((unit) {
      if (!unit.isAlive) return unit;
      final int sacrifice = max(1, (unit.currentHp * 0.15).round());
      final int newHp = max(1, unit.currentHp - sacrifice);
      totalSacrificedHp += (unit.currentHp - newHp);
      return unit.copyWith(currentHp: newHp);
    }).toList();

    final int defenseBuffPerUnit = max(5, (((totalSacrificedHp * 2.0) * potencyMultiplier) / allies.length).round());
    allies = allies.map((unit) {
      if (!unit.isAlive) return unit;
      return unit.copyWith(defense: unit.defense + defenseBuffPerUnit);
    }).toList();

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('sanguine_ward');

    return OrderResult(
      orderId: 'sanguine_ward',
      orderName: 'Sanguine Ward',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Sacrificed $totalSacrificedHp team HP to bolster all units with +$defenseBuffPerUnit Armor.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Feast of Ruin (Cost: 3 Focus)
  OrderResult executeFeastOfRuin(String targetEnemyId) {
    _validateOrderUnlocked('feast_of_ruin');
    const int cost = 3;
    _spendFocus(cost);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    final UnitEntity target = enemies[enemyIdx];
    final double hpRatio = target.currentHp / target.maxHp;

    List<UnitEntity> allies = List.of(tickManager.allies);
    String summary;

    if (hpRatio <= 0.20) {
      enemies[enemyIdx] = target.copyWith(currentHp: 0);
      allies = allies.map((u) {
        if (!u.isAlive) return u;
        return u.copyWith(turnMeter: u.turnMeter + 50.0);
      }).toList();
      summary = 'Executed ${target.name}! Roster surged with +50% Turn Meter.';
    } else {
      final int flatDamage = (target.maxHp * 0.15).round();
      enemies[enemyIdx] = target.copyWith(currentHp: max(0, target.currentHp - flatDamage));
      summary = '${target.name} HP above 20% threshold. Dealt $flatDamage physical damage.';
    }

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('feast_of_ruin');

    return OrderResult(
      orderId: 'feast_of_ruin',
      orderName: 'Feast of Ruin',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: summary,
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  // ===========================================================================
  // 2. LADY VALERIA (PALADIN) ORDERS
  // ===========================================================================

  /// Stand Resolute (Cost: 1 Focus)
  OrderResult executeStandResolute(String targetAllyId) {
    _validateOrderUnlocked('stand_resolute');
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId not found or already defeated.');
    }

    final UnitEntity target = allies[allyIdx];
    final int armorBoost = max(10, ((target.defense * 0.40) * potencyMultiplier).round());
    allies[allyIdx] = target.copyWith(defense: target.defense + armorBoost);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('stand_resolute');

    return OrderResult(
      orderId: 'stand_resolute',
      orderName: 'Stand Resolute',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Fortified ${target.name} with +$armorBoost Armor.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Retributive Stride (Cost: 2 Focus)
  /// All surviving Vanguard allies strike the front enemy directly for 100% of their ATK.
  OrderResult executeRetributiveStride() {
    _validateOrderUnlocked('retributive_stride');
    const int cost = 2;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> enemies = List.of(tickManager.enemies);

    final int targetIdx = enemies.indexWhere((e) => e.isAlive);
    if (targetIdx == -1) {
      throw StateError('No living enemy to counter-strike.');
    }

    final livingVanguard = allies.where((u) => u.isVanguard && u.isAlive).toList();
    int totalDamage = 0;
    for (final v in livingVanguard) {
      totalDamage += v.attack;
    }

    final target = enemies[targetIdx];
    final int newHp = max(0, target.currentHp - totalDamage);
    enemies[targetIdx] = target.copyWith(currentHp: newHp);

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('retributive_stride');

    return OrderResult(
      orderId: 'retributive_stride',
      orderName: 'Retributive Stride',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Vanguard counter-attack unleashed! Dealt $totalDamage physical damage to ${target.name}.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Smite the Wicked (Cost: 3 Focus)
  /// High-impact divine strike scaling with 80% of total brigade armor.
  OrderResult executeSmiteTheWicked(String targetEnemyId) {
    _validateOrderUnlocked('smite_the_wicked');
    const int cost = 3;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> enemies = List.of(tickManager.enemies);

    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    int totalBrigadeArmor = 0;
    for (final ally in allies) {
      if (ally.isAlive) {
        totalBrigadeArmor += ally.defense;
      }
    }

    final int radiantDamage = max(150, ((totalBrigadeArmor * 0.80) * potencyMultiplier).round());
    final target = enemies[enemyIdx];
    final int newHp = max(0, target.currentHp - radiantDamage);
    enemies[enemyIdx] = target.copyWith(currentHp: newHp);

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('smite_the_wicked');

    return OrderResult(
      orderId: 'smite_the_wicked',
      orderName: 'Smite the Wicked',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Radiant Smite channeled total armor ($totalBrigadeArmor DEF) dealing $radiantDamage holy damage to ${target.name}!',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  // ===========================================================================
  // 3. MALAKOR (THE BLIGHT FATHER) ORDERS
  // ===========================================================================

  /// Corpse Burst (Cost: 1 Focus)
  /// Spec 6.1: Detonates a fallen unit for AoE poison damage. The largest intact corpse on
  /// the field (ally or enemy) explodes for 140 + 20% of its max HP, then is consumed.
  /// With no corpse available, Malakor vents raw miasma for the base 140 damage.
  OrderResult executeCorpseBurst() {
    _validateOrderUnlocked('corpse_burst');
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    List<UnitEntity> enemies = List.of(tickManager.enemies);

    final corpses = [...allies, ...enemies].where(_isIntactCorpse).toList()
      ..sort((a, b) => b.maxHp.compareTo(a.maxHp));
    final UnitEntity? corpse = corpses.isNotEmpty ? corpses.first : null;

    final int corpseBonus = corpse != null ? (corpse.maxHp * 0.20).round() : 0;
    final int burstDamage = max(1, ((140 + corpseBonus) * potencyMultiplier).round());
    if (corpse != null) _consumedCorpseIds.add(corpse.id);

    enemies = enemies.map((enemy) {
      if (!enemy.isAlive) return enemy;
      final int newHp = max(0, enemy.currentHp - burstDamage);
      final updatedEffects = List<StatusEffect>.from(enemy.activeEffects)
        ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40));
      return enemy.copyWith(currentHp: newHp, activeEffects: updatedEffects);
    }).toList();

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('corpse_burst');

    return OrderResult(
      orderId: 'corpse_burst',
      orderName: 'Corpse Burst',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: corpse != null
          ? 'Corpse Burst detonated ${corpse.name}\'s remains! Dealt $burstDamage poison damage and blighted all enemies.'
          : 'Corpse Burst vented raw miasma! Dealt $burstDamage poison damage and blighted all enemies.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Remaining DoT a unit will suffer from its Bleed/Blight effects across their full durations.
  static int remainingDotDamage(UnitEntity unit) {
    int total = 0;
    for (final e in unit.activeEffects) {
      if (e.type == StatusEffectType.bleed) {
        final perTurn = e.value > 0 ? e.value : max(1, (unit.maxHp * 0.05).round());
        total += perTurn * e.durationTurns;
      } else if (e.type == StatusEffectType.blight) {
        final perTurn = e.value > 0 ? e.value : max(1, (unit.maxHp * 0.06).round());
        total += perTurn * e.durationTurns;
      }
    }
    return total;
  }

  /// Virulent Cascade (Cost: 2 Focus)
  /// Spec 6.1: Instantly triggers 50% of the remaining DoT on every afflicted enemy.
  /// The underlying Bleed/Blight effects keep ticking afterwards.
  OrderResult executeVirulentCascade() {
    _validateOrderUnlocked('virulent_cascade');
    const int cost = 2;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    List<UnitEntity> enemies = List.of(tickManager.enemies);

    int targetsAfflicted = 0;
    int totalBurst = 0;
    enemies = enemies.map((enemy) {
      if (!enemy.isAlive) return enemy;
      final int remaining = remainingDotDamage(enemy);
      if (remaining <= 0) return enemy;
      targetsAfflicted++;
      final int burst = max(1, (remaining * 0.50 * potencyMultiplier).round());
      totalBurst += burst;
      return enemy.copyWith(currentHp: max(0, enemy.currentHp - burst));
    }).toList();

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('virulent_cascade');

    return OrderResult(
      orderId: 'virulent_cascade',
      orderName: 'Virulent Cascade',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: targetsAfflicted > 0
          ? 'Virulent Cascade ruptured $targetsAfflicted afflicted enemies, unleashing $totalBurst festering damage!'
          : 'Virulent Cascade found no festering wounds to rupture.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Turns of action a Rebind Flesh thrall gets before collapsing (Decaying ticks at turn start).
  static const int reboundThrallTurns = 2;

  /// Rebind Flesh (Cost: 3 Focus)
  /// Spec 6.1: Resurrects a fallen ally as a decaying thrall for 2 turns (40% HP, 100% TM).
  /// The thrall collapses when its Decaying status expires. If none fallen, heals team for 35% HP.
  OrderResult executeRebindFlesh() {
    _validateOrderUnlocked('rebind_flesh');
    const int cost = 3;
    _spendFocus(cost);

    List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> enemies = List.of(tickManager.enemies);

    final deadIdx = allies.indexWhere(_isIntactCorpse);
    String summary;

    if (deadIdx != -1) {
      final deadUnit = allies[deadIdx];
      final int restoredHp = max(100, (deadUnit.maxHp * 0.40).round());
      allies[deadIdx] = deadUnit.copyWith(
        currentHp: restoredHp,
        turnMeter: 100.0,
        activeEffects: const [
          // +1 because the effect is decremented at the start of each of the thrall's turns
          StatusEffect(type: StatusEffectType.decaying, durationTurns: reboundThrallTurns + 1),
        ],
      );
      summary = 'Rebound flesh! ${deadUnit.name} rises as a decaying thrall with $restoredHp HP for $reboundThrallTurns turns.';
    } else {
      allies = allies.map((u) {
        if (!u.isAlive) return u;
        final heal = (u.maxHp * 0.35).round();
        return u.copyWith(currentHp: min(u.maxHp, u.currentHp + heal));
      }).toList();
      summary = 'Necrotic surge restored 35% vitality across all surviving allies.';
    }

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('rebind_flesh');

    return OrderResult(
      orderId: 'rebind_flesh',
      orderName: 'Rebind Flesh',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: summary,
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  // ===========================================================================
  // 4. MORRIGAN (THE ASHEN ORACLE) ORDERS
  // ===========================================================================

  /// Quicken (Cost: 1 Focus)
  /// Immediately grant target ally 100% Turn Meter.
  OrderResult executeQuicken(String targetAllyId) {
    _validateOrderUnlocked('quicken');
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId not found or already defeated.');
    }

    final UnitEntity target = allies[allyIdx];
    allies[allyIdx] = target.copyWith(turnMeter: 100.0);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('quicken');

    return OrderResult(
      orderId: 'quicken',
      orderName: 'Quicken',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Spun temporal threads! ${target.name} surged to 100% Turn Meter.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Unravel Hex (Cost: 2 Focus)
  /// Spec 6.1: Strips all enemy buffs (Armor Up, Haste) and reduces enemy Armor by 30%.
  OrderResult executeUnravelHex() {
    _validateOrderUnlocked('unravel_hex');
    const int cost = 2;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    List<UnitEntity> enemies = List.of(tickManager.enemies);

    int buffsStripped = 0;
    enemies = enemies.map((e) {
      if (!e.isAlive) return e;
      final remainingEffects = e.activeEffects.where((eff) {
        final isBuff = eff.type == StatusEffectType.defenseUp || eff.type == StatusEffectType.speedUp;
        if (isBuff) buffsStripped++;
        return !isBuff;
      }).toList();
      final int armorShred = (e.defense * 0.30).round();
      return e.copyWith(
        defense: max(10, e.defense - armorShred),
        activeEffects: remainingEffects,
      );
    }).toList();

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('unravel_hex');

    return OrderResult(
      orderId: 'unravel_hex',
      orderName: 'Unravel Hex',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Hex unravelled! Stripped $buffsStripped enemy buff(s) and 30% Armor from all enemies!',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Echoing Hourglass (Cost: 3 Focus)
  /// Spec 6.1: Every living backline Arcanum ally repeats their last action for free.
  /// Offensive echoes strike the original target (or the first living foe if it fell);
  /// support echoes re-heal their original ally. If no Arcanum ally has acted yet,
  /// the sands instead grant all allies +40% Turn Meter and -1 skill cooldowns.
  OrderResult executeEchoingHourglass() {
    _validateOrderUnlocked('echoing_hourglass');
    const int cost = 3;
    _spendFocus(cost);

    List<UnitEntity> allies = List.of(tickManager.allies);
    List<UnitEntity> enemies = List.of(tickManager.enemies);

    final echoers = allies
        .where((u) => u.isAlive && !u.isVanguard && _lastActions.containsKey(u.id))
        .toList();

    if (echoers.isEmpty) {
      allies = allies.map((u) {
        if (!u.isAlive) return u;
        final updatedSkills = u.resolvedSkills.map((s) {
          if (s.currentCooldown > 0) {
            return s.copyWith(currentCooldown: s.currentCooldown - 1);
          }
          return s;
        }).toList();
        return u.copyWith(
          turnMeter: u.turnMeter + 40.0,
          skills: updatedSkills,
        );
      }).toList();

      _applyStateToTickManager(allies, enemies);
      _onCardPlayed('echoing_hourglass');

      return OrderResult(
        orderId: 'echoing_hourglass',
        orderName: 'Echoing Hourglass',
        focusSpent: cost,
        remainingFocus: _currentFocus,
        summary: 'No Arcanum echoes to recall — time rewound! Squad gained +40% Turn Meter and reduced skill cooldowns.',
        updatedAllies: allies,
        updatedEnemies: enemies,
      );
    }

    final List<String> echoLog = [];
    for (final echoer in echoers) {
      final action = _lastActions[echoer.id]!;
      final skill = action.skill;
      final bool isSupport = skill.targetType == SkillTargetType.singleAlly || skill.damageCoefficient == 0.0;

      if (isSupport) {
        int idx = allies.indexWhere((u) => u.id == action.targetUnitId && u.isAlive);
        if (idx == -1) idx = allies.indexWhere((u) => u.id == echoer.id);
        final target = allies[idx];
        final heal = max(50, (target.maxHp * 0.25).round());
        final effects = List<StatusEffect>.from(target.activeEffects);
        if (skill.appliedStatus != null) effects.add(skill.appliedStatus!);
        allies[idx] = target.copyWith(
          currentHp: min(target.maxHp, target.currentHp + heal),
          activeEffects: effects,
        );
        echoLog.add('${echoer.name} echoed ${skill.name} (+$heal HP to ${target.name})');
      } else {
        int idx = enemies.indexWhere((u) => u.id == action.targetUnitId && u.isAlive);
        if (idx == -1) idx = enemies.indexWhere((u) => u.isAlive);
        if (idx == -1) break; // No foes left standing
        final target = enemies[idx];
        final mitigation = CombatMath.calculateMitigation(target.defense);
        final affinity = CombatMath.getAffinityMultiplier(echoer.archetype, target.archetype);
        final damage = max(1, (echoer.attack * skill.damageCoefficient * mitigation * affinity).round());
        final newHp = max(0, target.currentHp - damage);
        final effects = List<StatusEffect>.from(target.activeEffects);
        if (skill.appliedStatus != null && newHp > 0) effects.add(skill.appliedStatus!);
        enemies[idx] = target.copyWith(currentHp: newHp, activeEffects: effects);
        echoLog.add('${echoer.name} echoed ${skill.name} ($damage DMG to ${target.name})');
      }
    }

    _applyStateToTickManager(allies, enemies);
    _onCardPlayed('echoing_hourglass');

    return OrderResult(
      orderId: 'echoing_hourglass',
      orderName: 'Echoing Hourglass',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'The hourglass turns! ${echoLog.join(' • ')}',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  void _applyStateToTickManager(List<UnitEntity> allies, List<UnitEntity> enemies) {
    tickManager.updateSquads(allies: allies, enemies: enemies);
  }
}
