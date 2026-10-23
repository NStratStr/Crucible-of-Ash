import 'package:flutter/material.dart';
import '../generals/general_command_service.dart';
import 'cloud_auth_service.dart';
import 'game_state_persistence_service.dart';

class CloudAccountDialog extends StatefulWidget {
  final VoidCallback? onCloudDataRestored;

  const CloudAccountDialog({super.key, this.onCloudDataRestored});

  static Future<void> show(BuildContext context, {VoidCallback? onCloudDataRestored}) {
    return showDialog(
      context: context,
      builder: (_) => CloudAccountDialog(onCloudDataRestored: onCloudDataRestored),
    );
  }

  @override
  State<CloudAccountDialog> createState() => _CloudAccountDialogState();
}

class _CloudAccountDialogState extends State<CloudAccountDialog> {
  final CloudAuthService _auth = CloudAuthService();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  bool _isEditingName = false;
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _auth.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please provide both email and password.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    String? error;
    if (_isSignUp) {
      error = await _auth.linkOrSignUpWithEmail(email, password);
    } else {
      error = await _auth.signInWithEmail(email, password);
    }

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = _isSignUp
            ? 'Account registered & linked to Cloud Firestore!'
            : 'Signed in successfully!';
      });
      widget.onCloudDataRestored?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAnon = _auth.isAnonymous;

    return Dialog(
      backgroundColor: const Color(0xFF101018),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      border: Border.all(color: const Color(0xFFD4AF37)),
                    ),
                    child: const Icon(Icons.cloud_sync, color: Color(0xFFFFD54F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLOUDFIRE SANCTUARY VAULT',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Cloud Save & Playtester Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Account Status Pill
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161624),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAnon ? Icons.person_outline : Icons.verified_user,
                      color: isAnon ? const Color(0xFFE5A93C) : const Color(0xFF81C784),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAnon ? 'GUEST PLAYTESTER' : 'REGISTERED CITADEL COMMANDER',
                            style: TextStyle(
                              color: isAnon ? const Color(0xFFE5A93C) : const Color(0xFF81C784),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            _auth.userIdentifier,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_auth.currentUser?.email != null)
                            Text(
                              'Email: ${_auth.currentUser!.email}',
                              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 9.5),
                            ),
                          if (user != null)
                            Text(
                              'Firestore UID: ${user.uid}',
                              style: const TextStyle(color: Colors.white38, fontSize: 8.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isEditingName ? Icons.check : Icons.edit,
                        color: const Color(0xFFFFD54F),
                        size: 18,
                      ),
                      tooltip: _isEditingName ? 'Save Name' : 'Edit Alchemist Name',
                      onPressed: () async {
                        if (_isEditingName) {
                          final newName = _nameCtrl.text.trim();
                          if (newName.isNotEmpty) {
                            await _auth.updateDisplayName(newName);
                          }
                          setState(() => _isEditingName = false);
                        } else {
                          setState(() => _isEditingName = true);
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (_isEditingName) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Enter Alchemist Name...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFF1B1B2A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        final newName = _nameCtrl.text.trim();
                        if (newName.isNotEmpty) {
                          await _auth.updateDisplayName(newName);
                        }
                        setState(() => _isEditingName = false);
                      },
                      child: const Text('SAVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Error or Status messages
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x33B3261E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFB3261E)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
                  ),
                ),
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x332E7D32),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Color(0xFFA5D6A7), fontSize: 11),
                  ),
                ),

              // Inputs for binding / switching account
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Alchemical Email Address',
                  labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFFFD54F), size: 18),
                  filled: true,
                  fillColor: const Color(0xFF14141F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Secret Oath (Password)',
                  labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFFD54F), size: 18),
                  filled: true,
                  fillColor: const Color(0xFF14141F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        _isSignUp ? 'CREATE ACCOUNT & SYNC SAVE' : 'SIGN IN & LOAD CLOUD SAVE',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                        _statusMessage = null;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In' : 'Need an account? Register',
                      style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11),
                    ),
                  ),
                  if (!isAnon)
                    TextButton(
                      onPressed: () async {
                        await _auth.signOut();
                        setState(() {});
                      },
                      child: const Text('Sign Out', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),

              // Reset / New Journey Option for testing pacing from scratch
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, color: Color(0xFFEF5350), size: 16),
                label: const Text(
                  'START FRESH PROLOGUE JOURNEY (RESET SAVE)',
                  style: TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFB3261E)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF14141E),
                      title: const Text('Reset to Day Zero?', style: TextStyle(color: Color(0xFFFFD54F))),
                      content: const Text(
                        'This will clear local & cloud progress and trigger the Awakening Prologue from the very beginning with baseline starter units and zero currencies.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('CANCEL'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('CONFIRM RESET'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await GameStatePersistenceService.clear();
                    // Also clear cloud Firestore save document so it doesn't reload prior progress
                    final u = _auth.currentUser;
                    if (u != null) {
                      await _auth.syncSaveToCloud(
                        GameSaveData(
                          totalIchor: 0,
                          cursedOre: 0,
                          bloodlineSigils: 0,
                          activeGeneralType: GeneralType.vladislav,
                          phylacteryRanks: {},
                          currentChapter: 1,
                          maxUnlockedChapter: 1,
                          allies: [],
                          reserveInventory: [],
                          relics: [],
                          clearedGauntletTrials: {},
                          lastSavedTimestamp: DateTime.now().millisecondsSinceEpoch,
                        ),
                      );
                    }
                    Navigator.pop(context);
                    widget.onCloudDataRestored?.call();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
