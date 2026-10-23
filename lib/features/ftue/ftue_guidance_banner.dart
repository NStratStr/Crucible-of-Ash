import 'package:flutter/material.dart';
import 'ftue_service.dart';
import 'ftue_stage.dart';

class FtueGuidanceBanner extends StatefulWidget {
  final FtueService ftueService;
  final VoidCallback onLaunchStageAction;
  final VoidCallback? onReplayAwakening;

  const FtueGuidanceBanner({
    super.key,
    required this.ftueService,
    required this.onLaunchStageAction,
    this.onReplayAwakening,
  });

  @override
  State<FtueGuidanceBanner> createState() => _FtueGuidanceBannerState();
}

class _FtueGuidanceBannerState extends State<FtueGuidanceBanner> {
  bool _isExpanded = false;

  void _showTomeDialog(BuildContext context, FtueStage stage) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14141A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5A93C), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.menu_book, color: Color(0xFFE5A93C), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ORACLE\'S TOME: ${stage.title}',
                  style: const TextStyle(
                    color: Color(0xFFE5A93C),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stage.shortObjective,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  stage.tacticalAdvice,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE TOME', style: TextStyle(color: Color(0xFFE5A93C))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.ftueService.currentStage;
    if (stage == FtueStage.completed && !widget.ftueService.isGuideBannerVisible) {
      return const SizedBox.shrink();
    }

    final isFinished = stage == FtueStage.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF15151D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFinished ? const Color(0xFF43A047) : const Color(0xFFB3261E),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isFinished ? const Color(0xFF43A047) : const Color(0xFFB3261E)).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Icon(stage.icon, color: const Color(0xFFE5A93C), size: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF261010),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFB3261E)),
                    ),
                    child: Text(
                      isFinished ? 'PROLOGUE' : 'PROLOGUE [${stage.stepNumber}/5]',
                      style: const TextStyle(
                        color: Color(0xFFE5A93C),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stage.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isExpanded) ...[
                    InkWell(
                      onTap: () => _showTomeDialog(context, stage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.menu_book, size: 10, color: Color(0xFFE5A93C)),
                            SizedBox(width: 3),
                            Text('TOME', style: TextStyle(color: Color(0xFFE5A93C), fontSize: 8.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: isFinished
                          ? (widget.onReplayAwakening ?? widget.onLaunchStageAction)
                          : widget.onLaunchStageAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFinished ? const Color(0xFF333340) : const Color(0xFFB3261E),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB3261E).withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isFinished ? Icons.replay : Icons.play_arrow, size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              isFinished ? 'REPLAY' : 'LAUNCH',
                              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.white60),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  Text(
                    stage.shortObjective,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage.tacticalAdvice,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 10, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.menu_book, size: 13),
                        label: const Text('ORACLE TOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE5A93C),
                          side: const BorderSide(color: Color(0xFFE5A93C)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showTomeDialog(context, stage),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(
                          isFinished ? Icons.replay : Icons.play_arrow,
                          size: 14,
                        ),
                        label: Text(
                          isFinished ? 'REPLAY AWAKENING' : 'LAUNCH TRIAL',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFinished ? const Color(0xFF333340) : const Color(0xFFB3261E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: isFinished
                            ? (widget.onReplayAwakening ?? widget.onLaunchStageAction)
                            : widget.onLaunchStageAction,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
