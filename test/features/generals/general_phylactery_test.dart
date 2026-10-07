import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';

void main() {
  group('General Phylactery Tests', () {
    test('Phylactery starts at Rank 1 with baseline potency (1.0)', () {
      final tickManager = InitiativeTickManager(
        initialAllies: StarterBrigades.createPlayerSquad(),
        initialEnemies: StarterBrigades.createTutorialEnemies(),
      );

      final service = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
      );

      expect(service.activePhylacteryRank, equals(1));
      expect(service.potencyMultiplier, equals(1.0));
    });

    test('Upgrading Phylactery to Rank 2 activates +20% potency multiplier (1.20)', () {
      final tickManager = InitiativeTickManager(
        initialAllies: StarterBrigades.createPlayerSquad(),
        initialEnemies: StarterBrigades.createTutorialEnemies(),
      );

      final service = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.valeria,
      );

      final success = service.upgradePhylactery(GeneralType.valeria);
      expect(success, isTrue);
      expect(service.activePhylacteryRank, equals(2));
      expect(service.potencyMultiplier, equals(1.20));
    });

    test('Upgrading Phylactery to Rank 3 reaches maximum cap', () {
      final tickManager = InitiativeTickManager(
        initialAllies: StarterBrigades.createPlayerSquad(),
        initialEnemies: StarterBrigades.createTutorialEnemies(),
      );

      final service = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.malakor,
      );

      service.upgradePhylactery(GeneralType.malakor); // Rank 2
      service.upgradePhylactery(GeneralType.malakor); // Rank 3
      expect(service.activePhylacteryRank, equals(3));

      // Attempting to exceed rank 3 fails
      final overflowSuccess = service.upgradePhylactery(GeneralType.malakor);
      expect(overflowSuccess, isFalse);
      expect(service.activePhylacteryRank, equals(3));
    });

    test('Rank 2 potency increases damage dealt by Corpse Burst', () {
      final tickManager = InitiativeTickManager(
        initialAllies: StarterBrigades.createPlayerSquad(),
        initialEnemies: StarterBrigades.createTutorialEnemies(),
      );

      final baseService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.malakor,
        initialFocus: 1,
      );

      final resBase = baseService.executeCorpseBurst();
      // Base: 140 damage
      expect(resBase.summary, contains('140 poison damage'));

      final rank2Service = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.malakor,
        initialFocus: 1,
        initialPhylacteryRanks: {GeneralType.malakor: 2},
      );

      final resRank2 = rank2Service.executeCorpseBurst();
      // Rank 2: 140 * 1.20 = 168 damage
      expect(resRank2.summary, contains('168 poison damage'));
    });
  });
}
