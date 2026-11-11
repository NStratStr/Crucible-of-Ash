import 'package:flutter/material.dart';
import '../combat_spatial/models/crucible_skill_tree_models.dart';

class SculptorDisciplineData {
  final CrucibleSkillBranch branch;
  final String title;
  final String branchName;
  final String tagline;
  final String playstyle;
  final Color themeColor;
  final IconData icon;
  final String starterGenerator;
  final String starterCoreSkill;
  final String traitBonus;
  final String flavor;

  const SculptorDisciplineData({
    required this.branch,
    required this.title,
    required this.branchName,
    required this.tagline,
    required this.playstyle,
    required this.themeColor,
    required this.icon,
    required this.starterGenerator,
    required this.starterCoreSkill,
    required this.traitBonus,
    required this.flavor,
  });

  static const List<SculptorDisciplineData> allDisciplines = [
    SculptorDisciplineData(
      branch: CrucibleSkillBranch.wrath,
      title: 'FORGE BERSERKER',
      branchName: 'PATH OF WRATH',
      tagline: 'Pyre-Forged Carnage & Armor Cleave',
      playstyle: 'Aggressive frontline burst & raw physical momentum',
      themeColor: Color(0xFFFF5252),
      icon: Icons.local_fire_department,
      starterGenerator: 'Forge Cleave (Free Strike • +6 Cinders)',
      starterCoreSkill: 'Sundering Brand (30 Cinders • Armor Shred)',
      traitBonus: '+15% Direct Strike Damage & +2 Cinders on Crits',
      flavor: 'Hammer hot ore into the flesh of the fallen. Shatter enemy defenses with devastating cleaving blows.',
    ),
    SculptorDisciplineData(
      branch: CrucibleSkillBranch.bastion,
      title: 'IRONCLAD WARDEN',
      branchName: 'PATH OF BASTION',
      tagline: 'Granite Bulwarks & Squad Mitigation',
      playstyle: 'Immovable tanking, damage redirection & Aegis shielding',
      themeColor: Color(0xFF42A5F5),
      icon: Icons.shield,
      starterGenerator: 'Iron Bastion (Defensive Strike • +6 Cinders)',
      starterCoreSkill: 'Cinder Bulwark (25 Cinders • Squad Aegis Shield)',
      traitBonus: '+20% Aegis Shield Power & -15% Squad Damage Taken',
      flavor: 'Weave mineral strata into living ramparts. Turn incoming enemy volleys into harmless showers of flint sparks.',
    ),
    SculptorDisciplineData(
      branch: CrucibleSkillBranch.resonance,
      title: 'BLOOD ALCHEMIST',
      branchName: 'PATH OF RESONANCE',
      tagline: 'Sanguine Tethering & Life Leech',
      playstyle: 'Hybrid lifesteal, continuous bleed ticks & sustain',
      themeColor: Color(0xFFAB47BC),
      icon: Icons.bloodtype,
      starterGenerator: 'Siphon Rend (Vampiric Slash • +6 Cinders & Leech)',
      starterCoreSkill: 'Crimson Brand (30 Cinders • Bleed Affliction)',
      traitBonus: '+15% Sanguine Lifesteal & +3 Cinders on Bleed Ticks',
      flavor: 'Quicken cold veins with molten vitriol. Siphon the vital essence of foes across battlefield vectors.',
    ),
    SculptorDisciplineData(
      branch: CrucibleSkillBranch.vitae,
      title: 'SANCTIFIED RESTORER',
      branchName: 'PATH OF VITAE',
      tagline: 'Living Mineral Renewal & Squad Mending',
      playstyle: 'Dynamic squad healing, overshield conversion & cleanse',
      themeColor: Color(0xFF66BB6A),
      icon: Icons.healing,
      starterGenerator: 'Mending Ash (Restorative Strike • +6 Cinders & Mends Ally)',
      starterCoreSkill: 'Sanctified Bloom (25 Cinders • Frontline Renewal)',
      traitBonus: '+20% Healing Power & +5% Max HP Regen Per Turn',
      flavor: 'Purify calcified organs with soothing white fire. Keep your companion retinue fighting through impossible odds.',
    ),
    SculptorDisciplineData(
      branch: CrucibleSkillBranch.calamity,
      title: 'PYRE ARCANIST',
      branchName: 'PATH OF CALAMITY',
      tagline: 'Battlefield Devastation & Ash Whirlwinds',
      playstyle: 'Wide-area annihilation, vortex displacement & AoE pyres',
      themeColor: Color(0xFFFF7043),
      icon: Icons.whatshot,
      starterGenerator: 'Ash Whirlwind (Spinning Strike • +6 Cinders & Cleave)',
      starterCoreSkill: 'Sanguine Vortex (40 Cinders • Gravitational Pull & Pyre)',
      traitBonus: '+25% AoE Damage & +1 AoE Splash Radius',
      flavor: 'Unleash the suffocating heat of the caldera. Drag enemies into burning gravitational vortexes.',
    ),
  ];
}

class AwakeningDialog extends StatefulWidget {
  final CrucibleSkillBranch initialSelected;

  const AwakeningDialog({
    super.key,
    this.initialSelected = CrucibleSkillBranch.wrath,
  });

  static Future<CrucibleSkillBranch?> show(
    BuildContext context, {
    CrucibleSkillBranch initialSelected = CrucibleSkillBranch.wrath,
  }) {
    return showDialog<CrucibleSkillBranch>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AwakeningDialog(initialSelected: initialSelected),
    );
  }

  @override
  State<AwakeningDialog> createState() => _AwakeningDialogState();
}

class _AwakeningDialogState extends State<AwakeningDialog> with SingleTickerProviderStateMixin {
  late CrucibleSkillBranch _selected;
  int _currentStep = 0; // 0 = Prologue Lore Slides, 1 = Sculptor Discipline Selection
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
          'Dying legionnaires, deserting knights, and infected witches followed your workbench trail across the wasteland. Together, you claimed a geothermal volcanic basin where subterranean Vitae springs hold back the ash: The Citadel Sanctuary. Now, as the Ash Sculptor, choose your initial martial discipline to forge your first Grimoire rites.',
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
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [
                        Color(0xFF161624),
                        Color(0xFF08080E),
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

                    // Main Content (Prologue or Sculptor Discipline Selection)
                    Expanded(
                      child: _currentStep == 0
                          ? _buildPrologueView(isCompact)
                          : _buildDisciplineSelectionView(isCompact),
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
                    : 'SCULPTOR INITIATION • CHOOSE YOUR STARTING DISCIPLINE',
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
                    : 'Select Your Initial Combat Pathway to Forge Your First Grimoire Rites',
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
                            color: Colors.white,
                            fontSize: isCompact ? 18 : 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slide['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: isCompact ? 12 : 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['body'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: isCompact ? 12 : 14,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            slide['quote'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.95),
                              fontSize: isCompact ? 11 : 12.5,
                              fontStyle: FontStyle.italic,
                              height: 1.35,
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

  Widget _buildDisciplineSelectionView(bool isCompact) {
    final disciplines = SculptorDisciplineData.allDisciplines;

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
                  'As the Ash Sculptor, you command the battlefield with your Grimoire rites. Choose your starting discipline: you begin with core fundamentals (Slot 1 primary generator + Slot 2 tactical core) and 5 Skill Points to build up your rites in the Crucible Skill Tree.',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5-Discipline List / Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 720 ? 1 : (constraints.maxWidth < 900 ? 2 : 3);

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.5,
                ),
                itemCount: disciplines.length,
                itemBuilder: (context, index) {
                  return _buildDisciplineCard(disciplines[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDisciplineCard(SculptorDisciplineData discipline) {
    final bool isSelected = _selected == discipline.branch;

    return InkWell(
      onTap: () => setState(() => _selected = discipline.branch),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? discipline.themeColor.withValues(alpha: 0.18)
              : const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? discipline.themeColor : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: discipline.themeColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon, Name, Branch Badge & Radio
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: discipline.themeColor.withValues(alpha: 0.22),
                    border: Border.all(color: discipline.themeColor, width: 1.5),
                  ),
                  child: Icon(discipline.icon, color: discipline.themeColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: discipline.themeColor.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: discipline.themeColor, width: 0.8),
                            ),
                            child: Text(
                              discipline.branchName,
                              style: TextStyle(
                                color: discipline.themeColor,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        discipline.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        discipline.tagline,
                        style: TextStyle(
                          color: discipline.themeColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Radio<CrucibleSkillBranch>(
                  value: discipline.branch,
                  groupValue: _selected,
                  activeColor: discipline.themeColor,
                  onChanged: (val) {
                    if (val != null) setState(() => _selected = val);
                  },
                ),
              ],
            ),

            // Starter Skills Box
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: discipline.themeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, size: 11, color: discipline.themeColor),
                      const SizedBox(width: 4),
                      Text(
                        'STARTER SKILLS (SLOTS 1 & 2):',
                        style: TextStyle(
                          color: discipline.themeColor,
                          fontSize: 8.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '• ${discipline.starterGenerator}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 8.0),
                  ),
                  Text(
                    '• ${discipline.starterCoreSkill}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 8.0),
                  ),
                ],
              ),
            ),

            // Trait bonus
            Row(
              children: [
                const Text(
                  'TRAIT: ',
                  style: TextStyle(color: Colors.white38, fontSize: 8.0, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    discipline.traitBonus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: discipline.themeColor, fontSize: 8.5, fontWeight: FontWeight.w600),
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
              isLastSlide ? 'CHOOSE SCULPTOR DISCIPLINE' : 'NEXT CHAPTER',
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

    final chosen = SculptorDisciplineData.allDisciplines.firstWhere((d) => d.branch == _selected);

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
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              'INITIATE AS ${chosen.title}',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: chosen.themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              shadowColor: chosen.themeColor.withValues(alpha: 0.6),
              elevation: 4,
            ),
            onPressed: () => Navigator.pop(context, _selected),
          ),
        ),
      ],
    );
  }
}
