import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose folder for HabitGenius data',
    );
    if (dir != null && mounted) {
      setState(() => _selectedPath = dir);
    }
  }

  Future<void> _continue() async {
    if (_selectedPath == null) return;
    setState(() => _isLoading = true);

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefKeys.dataFilePath, _selectedPath!);
    await prefs.setBool(PrefKeys.hasSeenOnboarding, true);

    await ref
        .read(dataNotifierProvider.notifier)
        .load(isGuest: false, customDir: _selectedPath);

    if (mounted) context.go(AppRoutes.home);
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
                      Icon(
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
