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

class _AwakeningDialogState extends State<AwakeningDialog> with SingleTickerProviderStateMixin {
  late GeneralType _selected;
  int _currentStep = 0; // 0 = Prologue Lore Slides, 1 = Commander Faction Selection
  int _prologuePage = 0;
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _prologueSlides = [
    {
      'scene': 'SCENE 1: THE WHITE PLAIN',
      'title': 'THE WHITE RAIN CATACLYSM',
      'subtitle': 'The Petrification of the Known World',
      'icon': Icons.terrain_outlined,
      'color': const Color(0xFFCFD8DC),
      'body':
          'A suffocating white ash drifts from the shattered firmament—the fallout of an artificial sun drilling through the planetary mantle. Millions stand frozen mid-scream along crumbling roads: brittle chalk statues whose souls drift like hollow embers through the storm.',
      'quote': '"We did not pray for salvation. We prayed that our knuckles would bend for one more hour."',
    },
    {
      'scene': 'SCENE 2: THE MOBILE WORKBENCH',
      'title': 'THE ITINERANT PHYSICIAN',
      'subtitle': 'The Lone Wanderer with Pack Mule & Scalpel',
      'icon': Icons.auto_fix_high,
      'color': const Color(0xFFE5A93C),
      'body':
          'You were no prophesied king or warlord. You were an itinerant doctor pulling a lone pack mule strapped with bubbling copper retorts, iron needles, and glowing Vitae vials. Where imperial hospitals slammed their gates, your needles pierced calcifying chests to discover the impossible.',
      'quote': '"They called it an incurable plague. We called it living stone."',
    },
    {
      'scene': 'SCENE 3: THE TRANSMUTATION',
      'title': 'MINERAL SINEW & THE CRUCIBLE',
      'subtitle': 'Flesh of Stone, Capillaries of Quicksilver',
      'icon': Icons.colorize,
      'color': const Color(0xFFEF5350),
      'body':
          'Injecting hot, pressurized Ichor directly into calcifying heart muscle triggers a violent phase change: the ash does not leave, but weaves with muscle fibers into mineral sinew—possessing the density of granite, but the lightning elasticity of living muscle. Your patients rise as immortal Thralls.',
      'quote': '"The White Ash took their mortal breath. The Crucible gave them an eternal vanguard."',
    },
    {
      'scene': 'SCENE 4: THE ASHEN SANCTUARY',
      'title': 'FOUNDING THE CITADEL',
      'subtitle': 'The Caldera of the Living Flame',
      'icon': Icons.fort,
      'color': const Color(0xFFFFD54F),
      'body':
          'Dying legionnaires, deserting knights, and infected witches followed your workbench trail across the wasteland. Together, you claimed a geothermal volcanic basin where subterranean Vitae springs hold back the ash: The Citadel Sanctuary. Now, bind covenant with your first Progenitor Champion to lead your vanguard.',
      'quote': '"They called it an extinction. We called it a harvest. Welcome to the Crucible."',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 760;

    return Dialog(
      backgroundColor: const Color(0xFF0C0C14),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 32,
        vertical: isCompact ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: isCompact ? 720 : 660,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Subtle background vignette
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [
                        const Color(0xFF161624),
                        const Color(0xFF08080E),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(isCompact ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    _buildHeader(isCompact),
                    const SizedBox(height: 12),

                    // Main Content (Prologue or 4-Faction Selection)
                    Expanded(
                      child: _currentStep == 0
                          ? _buildPrologueView(isCompact)
                          : _buildFactionSelectionView(isCompact),
                    ),

                    const SizedBox(height: 14),

                    // Footer Navigation & Confirmation Button
                    _buildFooter(isCompact),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          ),
          child: const Icon(Icons.shield, color: Color(0xFFFFD54F), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStep == 0
                    ? 'PROLOGUE • THE CALCIFIED CONTINENT'
                    : 'FIRST TIME AWAKENING • CHOOSE YOUR PROGENITOR',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              Text(
                _currentStep == 0
                    ? 'The Genesis of the Itinerant Alchemist'
                    : 'Rescue 1 of 4 Faction Champions to Lead Your Sanctuary',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        if (_currentStep == 0)
          TextButton.icon(
            icon: const Icon(Icons.fast_forward, size: 16, color: Color(0xFFFFD54F)),
            label: const Text(
              'SKIP INTRO',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
          )
        else
          TextButton.icon(
            icon: const Icon(Icons.menu_book, size: 16, color: Colors.white70),
            label: const Text(
              'LORE ARCHIVE',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            onPressed: () {
              setState(() {
                _currentStep = 0;
              });
            },
          ),
      ],
    );
  }

  Widget _buildPrologueView(bool isCompact) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _prologuePage = idx),
            itemCount: _prologueSlides.length,
            itemBuilder: (context, index) {
              final slide = _prologueSlides[index];
              final Color accent = slide['color'] as Color;

              return Center(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 16 : 28),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12121E).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.2),
                            border: Border.all(color: accent, width: 2),
                          ),
                          child: Icon(slide['icon'] as IconData, color: accent, size: 34),
                        ),
                        const SizedBox(height: 16),
                        if (slide['scene'] != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.0),
                            ),
                            child: Text(
                              slide['scene'] as String,
                              style: TextStyle(
                                color: accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            color: accent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            fontSize: isCompact ? 16 : 19,
                          ),
                        ),
                        Text(
                          slide['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['body'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: isCompact ? 12 : 13.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            slide['quote'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontStyle: FontStyle.italic,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _prologueSlides.length,
            (idx) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _prologuePage == idx ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _prologuePage == idx
                    ? const Color(0xFFFFD54F)
                    : Colors.white24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFactionSelectionView(bool isCompact) {
    final generals = GeneralProfile.allGenerals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141422),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Four half-calcified champions lie stranded at the perimeter. You have enough raw catalyst to stabilize ONE immediate Progenitor General to lead your starter brigade:',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4-Faction Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 680 ? 1 : 2;

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.75,
                ),
                itemCount: generals.length,
                itemBuilder: (context, index) {
                  return _buildFactionCard(generals[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFactionCard(GeneralProfile profile) {
    final bool isSelected = _selected == profile.type;

    // Faction metadata labels
    final factionMap = {
      GeneralType.vladislav: {'faction': 'SANGUINE COURT', 'playstyle': 'Lifesteal & Execution'},
      GeneralType.valeria: {'faction': 'ASH LEGION', 'playstyle': 'Heavy Armor & Counter-Strikes'},
      GeneralType.malakor: {'faction': 'MIRE COVEN', 'playstyle': 'Blight Stacks & Necrotic Rebirth'},
      GeneralType.morrigan: {'faction': 'CALX ORDER', 'playstyle': 'Haste, Turn Meter & Criticals'},
    };
    final meta = factionMap[profile.type] ?? {'faction': 'INDEPENDENT', 'playstyle': 'Tactical'};

    return InkWell(
      onTap: () => setState(() => _selected = profile.type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? profile.themeColor.withValues(alpha: 0.18)
              : const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? profile.themeColor : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: profile.themeColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon, Name, Faction & Radio
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: profile.themeColor.withValues(alpha: 0.22),
                    border: Border.all(color: profile.themeColor, width: 1.5),
                  ),
                  child: Icon(profile.icon, color: profile.themeColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: profile.themeColor.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: profile.themeColor, width: 0.8),
                            ),
                            child: Text(
                              meta['faction']!,
                              style: TextStyle(
                                color: profile.themeColor,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            meta['playstyle']!,
                            style: const TextStyle(color: Colors.white54, fontSize: 8.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        profile.title,
                        style: TextStyle(
                          color: profile.themeColor,
                          fontSize: 10,
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

            // Aura Description
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: profile.themeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, size: 12, color: profile.themeColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'AURA: ${profile.auraName} — ${profile.auraDescription}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: profile.themeColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Orders list
            Row(
              children: [
                const Text(
                  'FOCUS ORDERS: ',
                  style: TextStyle(color: Colors.white38, fontSize: 8.0, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    profile.orders.take(3).map((o) => '${o.name} (${o.focusCost}F)').join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 8.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isCompact) {
    if (_currentStep == 0) {
      final isLastSlide = _prologuePage == _prologueSlides.length - 1;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _prologuePage > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            child: const Text('PREVIOUS', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            icon: Icon(
              isLastSlide ? Icons.check_circle : Icons.arrow_forward,
              size: 16,
            ),
            label: Text(
              isLastSlide ? 'CHOOSE PROGENITOR GENERAL' : 'NEXT CHAPTER',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (isLastSlide) {
                setState(() => _currentStep = 1);
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ],
      );
    }

    final chosenProfile = GeneralProfile.getByType(_selected);

    return Row(
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () => setState(() => _currentStep = 0),
          child: const Text('BACK TO LORE'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shield, size: 18),
            label: Text(
              'SEAL COVENANT WITH ${chosenProfile.name.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: chosenProfile.themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              shadowColor: chosenProfile.themeColor.withValues(alpha: 0.6),
              elevation: 4,
            ),
            onPressed: () => Navigator.pop(context, _selected),
          ),
        ),
      ],
    );
  }
}
