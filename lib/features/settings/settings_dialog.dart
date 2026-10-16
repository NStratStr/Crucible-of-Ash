import 'package:flutter/material.dart';
import 'settings_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Dialog(
          backgroundColor: const Color(0xFF14141E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 640),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/UI/Settings Shield Icon Transparent.png',
                          width: 26,
                          height: 26,
                          errorBuilder: (_, __, ___) => const Icon(Icons.settings, color: Color(0xFFD4AF37), size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IMPERIAL ARCHIVES & SETTINGS',
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'AUDIO • GRAPHICS • TELCO & NETWORK • SIMULATION',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9.0,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFFFD54F),
                  indicatorWeight: 2.5,
                  labelColor: const Color(0xFFFFD54F),
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(icon: Icon(Icons.volume_up, size: 16), text: 'AUDIO'),
                    Tab(icon: Icon(Icons.tune, size: 16), text: 'TACTICAL'),
                    Tab(icon: Icon(Icons.cell_tower, size: 16), text: 'TELCO & DATA'),
                    Tab(icon: Icon(Icons.info_outline, size: 16), text: 'ABOUT'),
                  ],
                ),
                const SizedBox(height: 14),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAudioTab(),
                      _buildTacticalTab(),
                      _buildTelcoTab(),
                      _buildAboutTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('BACKGROUND ATMOSPHERE (BGM)'),
        SwitchListTile(
          title: const Text('Ambient Combat Score', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Chamber strings and war drum ambiance during battlefield engagement', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.bgmEnabled,
          activeColor: const Color(0xFFFFD54F),
          onChanged: (val) => _settings.setBgmEnabled(val),
        ),
        if (_settings.bgmEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.volume_mute, size: 16, color: Colors.white54),
                Expanded(
                  child: Slider(
                    value: _settings.bgmVolume,
                    activeColor: const Color(0xFFFFD54F),
                    inactiveColor: Colors.white24,
                    onChanged: (val) => _settings.setBgmVolume(val),
                  ),
                ),
                Text('${(_settings.bgmVolume * 100).toInt()}%', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
        const Divider(color: Color(0xFF262636)),

        _buildSectionHeader('SOUND EFFECTS & SPELLCASTING (SFX)'),
        SwitchListTile(
          title: const Text('Combat & Kinetic SFX', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Weapon clashing, shield block resonances, and incantation surges', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.sfxEnabled,
          activeColor: const Color(0xFFFFD54F),
          onChanged: (val) => _settings.setSfxEnabled(val),
        ),
        if (_settings.sfxEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.volume_mute, size: 16, color: Colors.white54),
                Expanded(
                  child: Slider(
                    value: _settings.sfxVolume,
                    activeColor: const Color(0xFFFFD54F),
                    inactiveColor: Colors.white24,
                    onChanged: (val) => _settings.setSfxVolume(val),
                  ),
                ),
                Text('${(_settings.sfxVolume * 100).toInt()}%', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTacticalTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('PRESENTATION & KINETIC FEEDBACK'),
        SwitchListTile(
          title: const Text('Screen Impact Shake', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Dynamic camera impulse upon critical hits and titan smites', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.screenShakeEnabled,
          activeColor: const Color(0xFFFFD54F),
          onChanged: (val) => _settings.setScreenShakeEnabled(val),
        ),
        SwitchListTile(
          title: const Text('Damage & Status Float Text', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Live floating numbers indicating Armor absorption, True DMG, and Stagger', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.damageNumbersEnabled,
          activeColor: const Color(0xFFFFD54F),
          onChanged: (val) => _settings.setDamageNumbersEnabled(val),
        ),
        SwitchListTile(
          title: const Text('High-Contrast Plinth HP Bars', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Elevated visibility health and AP turn meters on 2.5D units', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.highContrastHpBars,
          activeColor: const Color(0xFFFFD54F),
          onChanged: (val) => _settings.setHighContrastHpBars(val),
        ),
        SwitchListTile(
          title: const Text('Spell Spark & Particle FX', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Glowing magical circle conduits and trajectory lines', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.particleFXEnabled,
          activeColor: const Color(0xFFFFD54F),
          onChanged: (val) => _settings.setParticleFXEnabled(val),
        ),
        const Divider(color: Color(0xFF262636)),

        _buildSectionHeader('SIMULATION PACING'),
        SwitchListTile(
          title: const Text('Auto-Bullet Time on Boss Telegraphs', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Automatically slows simulation to 30% when boss primes a telegraphed AoE', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.autoPauseOnBossTelegraph,
          activeColor: const Color(0xFFFFD54F),
          onChanged: (val) => _settings.setAutoPauseOnBossTelegraph(val),
        ),
      ],
    );
  }

  Widget _buildTelcoTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('MOBILE TELCO & NETWORK PROFILE'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF38384E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cell_tower, color: Color(0xFF00E5FF), size: 18),
                  SizedBox(width: 8),
                  Text('Active Carrier Profile', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: _settings.networkProfile,
                dropdownColor: const Color(0xFF1E1E2C),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                underline: Container(height: 1, color: const Color(0xFF00E5FF)),
                items: const [
                  DropdownMenuItem(value: 'Auto (Adaptive 4G/5G)', child: Text('Auto (Adaptive 4G/5G)')),
                  DropdownMenuItem(value: 'High Bandwidth (Wi-Fi / 5G Ultra)', child: Text('High Bandwidth (Wi-Fi / 5G Ultra)')),
                  DropdownMenuItem(value: 'Telco Data Saver (Metered 3G/4G)', child: Text('Telco Data Saver (Metered 3G/4G)')),
                  DropdownMenuItem(value: 'Airgap Offline Mode', child: Text('Airgap Offline Mode')),
                ],
                onChanged: (val) {
                  if (val != null) _settings.setNetworkProfile(val);
                },
              ),
            ],
          ),
        ),

        SwitchListTile(
          title: const Text('Telco Low-Data Mode', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Compresses asset transfers, reduces background sync, and suspends high-res telemetry over metered cell connections', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.lowDataMode,
          activeColor: const Color(0xFF00E5FF),
          onChanged: (val) => _settings.setLowDataMode(val),
        ),

        SwitchListTile(
          title: const Text('Offline Local Storage Cache', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Persists campaign progress, rosters, and fusion pedigrees directly in local IndexedDB/SharedPrefs to prevent re-downloads', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.offlineCacheMode,
          activeColor: const Color(0xFF00E5FF),
          onChanged: (val) => _settings.setOfflineCacheMode(val),
        ),

        SwitchListTile(
          title: const Text('Anonymous Combat Analytics', style: TextStyle(color: Colors.white, fontSize: 12)),
          subtitle: const Text('Shares balance metrics (boss win rates, encounter durations) to help balance future content updates', style: TextStyle(color: Colors.white54, fontSize: 10)),
          value: _settings.analyticsTelemetry,
          activeColor: const Color(0xFF00E5FF),
          onChanged: (val) => _settings.setAnalyticsTelemetry(val),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Center(
          child: Column(
            children: [
              Image.asset(
                'assets/images/UI/Ruby Shield Icon transparent.png',
                width: 54,
                height: 54,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 48, color: Color(0xFFD4AF37)),
              ),
              const SizedBox(height: 8),
              const Text(
                'CRUCIBLE OF ASH',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Text(
                'Dark Fantasy Tabletop Strategy RPG • Version 3.2',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF38384E)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM ARCHITECTURE & GDD SPECS',
                style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              SizedBox(height: 6),
              Text(
                '• Engine: Flutter Web / Mobile High-Performance Canvas\n'
                '• 30 Hz Deterministic Spatial Simulation Plane\n'
                '• 6-Generation Pureblood Bloodline Fusion System\n'
                '• 4 Great Factions: Ash Legion, Crypt Stalkers, Mire Coven, Calx Order\n'
                '• Telco & Cross-Platform Offline Persistence Engine',
                style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
