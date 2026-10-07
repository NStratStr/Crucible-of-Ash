import 'package:flutter/material.dart';
import 'general_command_service.dart';

/// Modal dialog allowing the player to awaken and appoint their General Commander.
class GeneralSelectionDialog extends StatelessWidget {
  final GeneralType currentGeneralType;
  final ValueChanged<GeneralType> onGeneralSelected;

  const GeneralSelectionDialog({
    super.key,
    required this.currentGeneralType,
    required this.onGeneralSelected,
  });

  static Future<GeneralType?> show(
    BuildContext context, {
    required GeneralType currentGeneralType,
  }) {
    return showModalBottomSheet<GeneralType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GeneralSelectionDialog(
        currentGeneralType: currentGeneralType,
        onGeneralSelected: (type) => Navigator.pop(ctx, type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                  child: const Icon(Icons.military_tech, color: Color(0xFFE5A93C), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PHYLACTERY OF COMMANDERS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Appoint the General overseeing your brigade',
                        style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF2B2B36), height: 1),

          // General list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: GeneralProfile.allGenerals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final gen = GeneralProfile.allGenerals[index];
                final isSelected = gen.type == currentGeneralType;

                return _buildGeneralCard(context, gen, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralCard(BuildContext context, GeneralProfile gen, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? gen.themeColor.withValues(alpha: 0.12)
            : const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? gen.themeColor : const Color(0xFF2B2B36),
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar icon + Name + Select Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: gen.themeColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gen.themeColor),
                  ),
                  child: Icon(gen.icon, color: gen.themeColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              gen.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE5A93C), width: 1),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Color(0xFFE5A93C),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        gen.title,
                        style: TextStyle(
                          color: gen.themeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? const Color(0xFF2B2B36)
                        : gen.themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSelected ? null : () => onGeneralSelected(gen.type),
                  child: Text(
                    isSelected ? 'APPOINTED' : 'APPOINT',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Passive Aura
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFE5A93C), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11, height: 1.3),
                        children: [
                          TextSpan(
                            text: '${gen.auraName}: ',
                            style: const TextStyle(
                              color: Color(0xFFE5A93C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: gen.auraDescription,
                            style: const TextStyle(color: Color(0xFFB0B0C0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Orders list
            const Text(
              'BATTLEFIELD ORDERS (FOCUS):',
              style: TextStyle(
                color: Color(0xFF8E8EA0),
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: gen.orders.map((ord) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C26),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ord.icon, size: 12, color: gen.themeColor),
                      const SizedBox(width: 5),
                      Text(
                        '${ord.name} (${ord.focusCost}F)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
