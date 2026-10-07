import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/ftue/ftue_service.dart';
import 'package:ashen_crucible/features/ftue/ftue_stage.dart';

void main() {
  group('FtueService & Onboarding Stage Tests', () {
    test('Default initial stage is awakening', () {
      final service = FtueService();
      expect(service.currentStage, equals(FtueStage.awakening));
      expect(service.isCompleted, isFalse);
      expect(service.isGuideBannerVisible, isTrue);
    });

    test('Advances through all 5 GDD Section 8 screens sequentially', () {
      final service = FtueService();

      expect(service.currentStage, equals(FtueStage.awakening));
      expect(service.currentStage.stepNumber, equals(1));

      // Screen 1: Awakening -> Screen 2: Encounter 1
      service.advanceStage();
      expect(service.currentStage, equals(FtueStage.encounter1));
      expect(service.currentStage.stepNumber, equals(2));
      expect(service.currentStage.title, contains('INITIATIVE TICKS'));

      // Screen 2: Encounter 1 -> Screen 3: Encounter 2
      service.advanceStage();
      expect(service.currentStage, equals(FtueStage.encounter2));
      expect(service.currentStage.stepNumber, equals(3));
      expect(service.currentStage.title, contains('HEX WHEEL'));

      // Screen 3: Encounter 2 -> Screen 4: Crucible
      service.advanceStage();
      expect(service.currentStage, equals(FtueStage.crucibleFusion));
      expect(service.currentStage.stepNumber, equals(4));
      expect(service.currentStage.title, contains('CRUCIBLE TRANSMUTATION'));

      // Screen 4: Crucible -> Screen 5: Gatekeeper
      service.advanceStage();
      expect(service.currentStage, equals(FtueStage.encounter3));
      expect(service.currentStage.stepNumber, equals(5));
      expect(service.currentStage.title, contains('GATEKEEPER PURGE'));

      // Screen 5: Gatekeeper -> Completed
      service.advanceStage();
      expect(service.currentStage, equals(FtueStage.completed));
      expect(service.isCompleted, isTrue);
    });

    test('Banner toggle and reset prologue work properly', () {
      final service = FtueService();
      expect(service.isGuideBannerVisible, isTrue);

      service.toggleGuideBanner();
      expect(service.isGuideBannerVisible, isFalse);

      service.setStage(FtueStage.encounter3);
      expect(service.currentStage, equals(FtueStage.encounter3));

      service.resetPrologue();
      expect(service.currentStage, equals(FtueStage.awakening));
      expect(service.isGuideBannerVisible, isTrue);
    });
  });
}
