import 'package:flutter/material.dart';
import '../generals/general_command_service.dart';

class AwakeningDialog extends StatefulWidget {
  final GeneralType initialSelected;

  const AwakeningDialog({
    super.key,
    this.initialSelected = GeneralType.vladislav,
  });

  static Future<GeneralType?> show(
    BuildContext context, {
    GeneralType initialSelected = GeneralType.vladislav,
  }) {
    return showDialog<GeneralType>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AwakeningDialog(initialSelected: initialSelected),
    );
  }

  @override
  State<AwakeningDialog> createState() => _AwakeningDialogState();
}

class _AwakeningDialogState extends State<AwakeningDialog> {
  late GeneralType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    final vladislav = GeneralProfile.getByType(GeneralType.vladislav);
    final valeria = GeneralProfile.getByType(GeneralType.valeria);

    return Dialog(
      backgroundColor: const Color(0xFF101015),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFE5A93C), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCREEN 1: THE AWAKENING',
                          style: TextStyle(
                            color: Color(0xFFE5A93C),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Choose Your Progenitor General',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Dark souls gather around the Ashen Altar. Two legendary commanders offer their eternal covenant to lead your brigade. Choose your progenitor:',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Commander Options
              Expanded(
                child: ListView(
                  children: [
                    _buildGeneralOptionCard(vladislav),
                    const SizedBox(height: 14),
                    _buildGeneralOptionCard(valeria),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'SEAL COVENANT & BIND SQUAD',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selected == GeneralType.vladislav
                      ? const Color(0xFFB3261E)
                      : const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, _selected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralOptionCard(GeneralProfile profile) {
    final bool isSelected = _selected == profile.type;

    return InkWell(
      onTap: () => setState(() => _selected = profile.type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? profile.themeColor.withValues(alpha: 0.15)
              : const Color(0xFF181820),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? profile.themeColor : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: profile.themeColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: profile.themeColor),
                  ),
                  child: Icon(profile.icon, color: profile.themeColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        profile.title,
                        style: TextStyle(
                          color: profile.themeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<GeneralType>(
                  value: profile.type,
                  groupValue: _selected,
                  activeColor: profile.themeColor,
                  onChanged: (val) {
                    if (val != null) setState(() => _selected = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Aura Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: profile.themeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, size: 13, color: profile.themeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AURA: ${profile.auraName} — ${profile.auraDescription}',
                      style: TextStyle(
                        color: profile.themeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Orders preview
            const Text(
              'COMMAND FOCUS ORDERS:',
              style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 9, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...profile.orders.map(
              (order) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${order.focusCost}F',
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${order.name}: ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
