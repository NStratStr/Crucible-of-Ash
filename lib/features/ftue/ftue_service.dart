import 'package:flutter/foundation.dart';
import 'ftue_stage.dart';

class FtueService extends ChangeNotifier {
  FtueStage _currentStage;
  bool _isGuideBannerVisible;

  FtueService({
    FtueStage initialStage = FtueStage.awakening,
    bool isGuideBannerVisible = true,
  })  : _currentStage = initialStage,
        _isGuideBannerVisible = isGuideBannerVisible;

  FtueStage get currentStage => _currentStage;
  bool get isGuideBannerVisible => _isGuideBannerVisible;
  bool get isCompleted => _currentStage == FtueStage.completed;

  void advanceStage() {
    switch (_currentStage) {
      case FtueStage.awakening:
        _currentStage = FtueStage.encounter1;
        break;
      case FtueStage.encounter1:
        _currentStage = FtueStage.encounter2;
        break;
      case FtueStage.encounter2:
        _currentStage = FtueStage.crucibleFusion;
        break;
      case FtueStage.crucibleFusion:
        _currentStage = FtueStage.encounter3;
        break;
      case FtueStage.encounter3:
        _currentStage = FtueStage.completed;
        break;
      case FtueStage.completed:
        break;
    }
    notifyListeners();
  }

  void setStage(FtueStage stage) {
    if (_currentStage == stage) return;
    _currentStage = stage;
    notifyListeners();
  }

  void toggleGuideBanner() {
    _isGuideBannerVisible = !_isGuideBannerVisible;
    notifyListeners();
  }

  void setBannerVisibility(bool visible) {
    if (_isGuideBannerVisible == visible) return;
    _isGuideBannerVisible = visible;
    notifyListeners();
  }

  void resetPrologue() {
    _currentStage = FtueStage.awakening;
    _isGuideBannerVisible = true;
    notifyListeners();
  }
}
