import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';

/// Shown once after the first Google Sign-In (at the end of Onboarding).
/// The user picks the folder where their data file will be stored.
class FileSetupScreen extends ConsumerStatefulWidget {
  const FileSetupScreen({super.key});

  @override
  ConsumerState<FileSetupScreen> createState() => _FileSetupScreenState();
}

class _FileSetupScreenState extends ConsumerState<FileSetupScreen> {
  String? _selectedPath;
  bool _isLoading = false;

  /// Shows the rationale dialog, opens the system folder picker, then
  /// validates that the selected folder is actually writable.
  Future<void> _pickFolder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Choose a data folder'),
            content: const Text(
              'HabitGenius stores all your habits, journal, moods, focus sessions, '
              'and expenses in a single JSON file.\n\n'
              'Pick any folder on your device. '
              'The app only reads and writes this one file — it does not access '
              'any other files or photos on your device.\n\n'
              'Tip: Use the app\'s default location if you are unsure — it always works.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Choose folder'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose folder for HabitGenius data',
    );
    if (dir == null || !mounted) return;

    // Validate write access BEFORE accepting the path.
    // On Android 11+ (scoped storage), user-picked external paths may look
    // like valid file paths but are NOT writable via dart:io's File API.
    final svc = ref.read(dataServiceProvider);
    final canWrite = await svc.testWriteAccess(dir);
    if (!mounted) return;

    if (!canWrite) {
      // Offer the user a choice: pick again or use internal storage.
      final useDefault = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Folder not accessible'),
              content: const Text(
                'HabitGenius cannot write to that folder on this device.\n\n'
                'This is a known Android limitation for certain storage locations.\n\n'
                'Would you like to use the default location inside the app instead? '
                'Your data will be safe there — you can always move the file later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Pick another'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Use default'),
                ),
              ],
            ),
      );
      if (!mounted) return;
      if (useDefault == true) {
        await _useDefaultLocation();
      }
      return;
    }

    setState(() => _selectedPath = dir);
  }

  /// Sets the data path to the internal app documents directory — always
  /// accessible on all Android versions, no permissions needed.
  Future<void> _useDefaultLocation() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) setState(() => _selectedPath = dir.path);
  }

  Future<void> _continue() async {
    if (_selectedPath == null) return;
    setState(() => _isLoading = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(PrefKeys.dataFilePath, _selectedPath!);
      await prefs.setBool(PrefKeys.hasSeenOnboarding, true);

      await ref
          .read(dataNotifierProvider.notifier)
          .load(isGuest: false, customDir: _selectedPath);

      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not access the selected folder: $e\n'
              'Please choose a different location or use the default.',
            ),
            backgroundColor: const Color(0xFFE17055),
            duration: const Duration(seconds: 6),
          ),
        );
        // Reset selection so the user can pick again.
        setState(() => _selectedPath = null);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Icon(Icons.folder_open_rounded, size: 56, color: primary),
              const SizedBox(height: 24),
              Text(
                'Choose Data Location',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'HabitGenius stores all your data in a single file. Pick where to save it — local storage or a cloud-synced folder (e.g. Google Drive).',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 40),
              // Selected path display
              if (_selectedPath != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedPath!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_rounded),
                label: Text(
                  _selectedPath == null ? 'Choose Folder' : 'Change Folder',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: primary),
                  foregroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Default location shortcut.
              TextButton(
                onPressed: _useDefaultLocation,
                child: Text(
                  'Use default location',
                  style: TextStyle(color: primary.withValues(alpha: 0.7)),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed:
                    _selectedPath != null && !_isLoading ? _continue : null,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Continue'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
