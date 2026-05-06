import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cloud_sync_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/purchase_service.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/app_toast.dart';
import 'package:go_router/go_router.dart';

// ── Settings screen ───────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final themeState = ref.watch(themeProvider);
    final tier = authState.tier;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Profile card ──────────────────────────────
            _ProfileCard(authState: authState, tier: tier),
            const SizedBox(height: 24),

            // ── Pro upgrade ───────────────────────────────
            if (tier != UserTier.pro) ...[
              _ProCard(tier: tier),
              const SizedBox(height: 24),
            ],

            // ── Appearance ────────────────────────────────
            _SectionHeader(label: 'Appearance'),
            const SizedBox(height: 12),
            _ThemeModeRow(themeState: themeState),
            const SizedBox(height: 12),
            _ThemeColorGrid(themeState: themeState, tier: tier),
            const SizedBox(height: 24),

            // ── Notifications ─────────────────────────────
            _SectionHeader(label: 'Notifications'),
            const SizedBox(height: 12),
            const _NotificationsSection(),
            const SizedBox(height: 24),

            // ── General ───────────────────────────────────
            _SectionHeader(label: 'General'),
            const SizedBox(height: 12),
            const _GeneralSection(),
            const SizedBox(height: 24),

            // ── Data ──────────────────────────────────────
            _SectionHeader(label: 'Data'),
            const SizedBox(height: 12),
            _DataSection(tier: tier),
            const SizedBox(height: 24),

            // ── Cloud Backup ──────────────────────────────
            _SectionHeader(label: 'Cloud Backup'),
            const SizedBox(height: 12),
            _CloudSyncSection(authState: authState),
            const SizedBox(height: 24),

            // ── About & Support ───────────────────────────
            _SectionHeader(label: 'About & Support'),
            const SizedBox(height: 12),
            const _AboutSection(),
            const SizedBox(height: 24),

            // ── Account ───────────────────────────────────
            _SectionHeader(label: 'Account'),
            const SizedBox(height: 12),
            _AccountSection(authState: authState),
            const SizedBox(height: 32),

            // ── Version footer ────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    'HabitGenius',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Version 1.0.0 (1)',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '© 2026 HabitGenius. All rights reserved.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────

class _ProfileCard extends ConsumerStatefulWidget {
  final AuthState authState;
  final UserTier tier;

  const _ProfileCard({required this.authState, required this.tier});

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  Future<void> _editName(BuildContext context) async {
    if (widget.authState.isGuest) return;
    final user = widget.authState.user;
    final ctrl = TextEditingController(text: user?.displayName ?? '');
    // Capture before any await.
    final scaffoldMsg = ScaffoldMessenger.of(context);
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit display name'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(result);
      // Also save locally in app settings
      final settings = ref.read(appDataProvider).settings;
      await ref
          .read(dataNotifierProvider.notifier)
          .updateSettings(settings.copyWith(displayName: result));
      if (!mounted) return;
      scaffoldMsg.showSnackBar(const SnackBar(content: Text('Name updated')));
    } catch (_) {
      if (!mounted) return;
      scaffoldMsg.showSnackBar(
        const SnackBar(content: Text('Could not update name.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = widget.authState;
    final tier = widget.tier;
    final user = authState.user;
    final displayName =
        user?.displayName ?? ref.watch(appDataProvider).settings.displayName;
    final initials =
        displayName != null
            ? displayName
                .split(' ')
                .map((w) => w.isNotEmpty ? w[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : '?';

    final tierLabel = switch (tier) {
      UserTier.guest => 'Guest',
      UserTier.registered => 'Free',
      UserTier.pro => 'Pro ⭐',
    };

    final tierColor = switch (tier) {
      UserTier.pro => const Color(0xFFFDCB6E),
      UserTier.registered => Theme.of(context).colorScheme.primary,
      UserTier.guest => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDecorationR(20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: authState.isGuest ? null : () => _editName(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName ??
                            (authState.isGuest ? 'Guest User' : 'User'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (!authState.isGuest) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: context.appColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user!.email!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pro upgrade card ──────────────────────────────────────

class _ProCard extends ConsumerStatefulWidget {
  final UserTier tier;
  const _ProCard({required this.tier});

  @override
  ConsumerState<_ProCard> createState() => _ProCardState();
}

class _ProCardState extends ConsumerState<_ProCard> {
  bool _loading = false;
  String? _error;

  Future<void> _onUpgrade() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final svc = ref.read(purchaseServiceProvider);
    final result = await svc.buyPro();
    if (!mounted) return;

    switch (result) {
      case PurchaseResult.success:
      case PurchaseResult.alreadyOwned:
        ref.read(authNotifierProvider.notifier).upgradeToPro();
        HapticFeedback.heavyImpact();
        AppToast.show(context, 'Welcome to Pro! ⭐', type: ToastType.success);
      case PurchaseResult.cancelled:
        break;
      case PurchaseResult.error:
        setState(() => _error = svc.error ?? 'Purchase failed');
    }
    setState(() => _loading = false);
  }

  Future<void> _onRestore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // restore() now resets _loading internally once the request is submitted;
    // results will arrive via the purchase stream asynchronously.
    await ref.read(purchaseServiceProvider).restore();
    if (!mounted) return;
    final svc = ref.read(purchaseServiceProvider);
    if (svc.error != null) {
      setState(() => _error = svc.error);
    } else if (svc.isPro) {
      ref.read(authNotifierProvider.notifier).upgradeToPro();
      AppToast.show(context, 'Pro restored! ⭐', type: ToastType.success);
    } else {
      setState(() => _error = 'No previous Pro purchase found');
    }
    if (mounted) setState(() => _loading = false);
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppToast.show(context, 'Could not open link.', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const gold = Color(0xFFFDCB6E);
    final svc = ref.watch(purchaseServiceProvider);
    final price = svc.formattedPrice;
    final priceLabel = price.isNotEmpty ? price : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gold.withValues(alpha: 0.12),
            primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Upgrade to Pro',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              if (priceLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    priceLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFDCB6E),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            '✓ Unlimited habits',
            '✓ Unlimited journal entries',
            '✓ Unlimited transactions & accounts',
            '✓ Custom focus durations',
            '✓ One-time payment, no subscription',
          ].map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                b,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _onUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _loading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                          : Text(
                            priceLabel != null
                                ? 'Buy Pro · $priceLabel'
                                : 'Upgrade to Pro',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _loading ? null : _onRestore,
                child: const Text(
                  'Restore',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          // ── Billing disclosure (required by Google Play billing policy) ─────
          const SizedBox(height: 12),
          Wrap(
            children: [
              Text(
                'One-time purchase. Payment charged to your Google Play account on confirmation. '
                'By purchasing you agree to our ',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () => _openUrl(context, 'https://habitgenius.app/terms'),
                child: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                ' and ',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              GestureDetector(
                onTap:
                    () => _openUrl(context, 'https://habitgenius.app/privacy'),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                '.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Theme mode row ────────────────────────────────────────

class _ThemeModeRow extends ConsumerWidget {
  final ThemeState themeState;
  const _ThemeModeRow({required this.themeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const modes = [
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
    ];
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children:
          modes.map((m) {
            final sel = themeState.themeMode == m.$1;
            return Expanded(
              child: GestureDetector(
                onTap:
                    () => ref.read(themeProvider.notifier).setThemeMode(m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        sel
                            ? primary.withValues(alpha: 0.15)
                            : context.appColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? primary : context.appColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        m.$2,
                        size: 20,
                        color: sel ? primary : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.$3,
                        style: TextStyle(
                          fontSize: 11,
                          color: sel ? primary : AppColors.textSecondary,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ── Theme color grid ──────────────────────────────────────

class _ThemeColorGrid extends ConsumerWidget {
  final ThemeState themeState;
  final UserTier tier;

  const _ThemeColorGrid({required this.themeState, required this.tier});

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    Color picked =
        themeState.customAccentColor ?? themeState.themeColor.primary;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.borderLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Pick accent color',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose any color as your accent. This overrides the preset selection.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Color picker
                      ColorPicker(
                        pickerColor: picked,
                        onColorChanged: (c) => setSheetState(() => picked = c),
                        enableAlpha: false,
                        labelTypes: const [],
                        pickerAreaHeightPercent: 0.55,
                        hexInputBar: true,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(color: AppColors.borderLight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(themeProvider.notifier)
                                    .setCustomAccentColor(picked);
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: picked,
                                foregroundColor:
                                    ThemeData.estimateBrightnessForColor(
                                              picked,
                                            ) ==
                                            Brightness.light
                                        ? Colors.black
                                        : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Apply',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCustomActive = themeState.themeColor.id == 'custom';
    final customColor = themeState.customAccentColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accent color',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // ── Preset swatches ─────────────────────────
              ...AppColors.themeColors.map((tc) {
                final locked =
                    tc.requiredTier == UserTier.pro && tier != UserTier.pro;
                final sel =
                    themeState.themeColor.id == tc.id && !isCustomActive;

                return GestureDetector(
                  onTap: () {
                    if (locked) {
                      AppToast.show(
                        context,
                        'Upgrade to Pro to unlock this colour',
                      );
                      return;
                    }
                    ref.read(themeProvider.notifier).setThemeColor(tc);
                  },
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              locked
                                  ? tc.primary.withValues(alpha: 0.3)
                                  : tc.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow:
                              sel
                                  ? [
                                    BoxShadow(
                                      color: tc.primary.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                  : null,
                        ),
                      ),
                      if (locked)
                        const Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      if (sel && !locked)
                        const Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              // ── Custom (free-pick) swatch ─────────────
              GestureDetector(
                onTap: () => _showColorPicker(context, ref),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isCustomActive ? Colors.white : AppColors.border,
                          width: isCustomActive ? 3 : 1.5,
                        ),
                        boxShadow:
                            isCustomActive && customColor != null
                                ? [
                                  BoxShadow(
                                    color: customColor.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                                : null,
                      ),
                      child: ClipOval(
                        child:
                            isCustomActive && customColor != null
                                ? ColoredBox(color: customColor)
                                : DecoratedBox(
                                  decoration: const BoxDecoration(
                                    gradient: SweepGradient(
                                      colors: [
                                        Color(0xFFFF0000),
                                        Color(0xFFFFFF00),
                                        Color(0xFF00FF00),
                                        Color(0xFF00FFFF),
                                        Color(0xFF0000FF),
                                        Color(0xFFFF00FF),
                                        Color(0xFFFF0000),
                                      ],
                                    ),
                                  ),
                                ),
                      ),
                    ),
                    if (isCustomActive)
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.colorize_rounded,
                            size: 18,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Data section ──────────────────────────────────────────

class _DataSection extends ConsumerWidget {
  final UserTier tier;
  const _DataSection({required this.tier});

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(dataNotifierProvider.notifier);
    final path = notifier.filePath;
    if (path == null) {
      AppToast.show(context, 'Data file not found.', type: ToastType.error);
      return;
    }
    try {
      await Share.shareXFiles([
        XFile(path, mimeType: 'application/json'),
      ], subject: 'HabitGenius backup');
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Could not share backup.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appData = ref.watch(appDataProvider);
    final habitCount = appData.habits.where((h) => h.archivedAt == null).length;
    final entryCount = appData.journal.length;
    final txCount = appData.transactions.length;
    final moodCount = appData.moods.length;

    return Container(
      decoration: context.cardDecoration,
      child: Column(
        children: [
          _DataRow(label: 'Habits', value: '$habitCount'),
          _DataRow(label: 'Journal entries', value: '$entryCount'),
          _DataRow(label: 'Transactions', value: '$txCount'),
          _DataRow(label: 'Mood logs', value: '$moodCount'),
          const _DataRow(label: 'Storage', value: 'Local (on-device)'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _ActionRow(
            icon: Icons.download_rounded,
            label: 'Export backup (JSON)',
            onTap: () => _exportBackup(context, ref),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );
}

// ── Cloud Sync section ────────────────────────────────────

class _CloudSyncSection extends ConsumerStatefulWidget {
  final AuthState authState;
  const _CloudSyncSection({required this.authState});

  @override
  ConsumerState<_CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<_CloudSyncSection> {
  bool _toggling = false;

  Future<void> _onToggle(bool value, CloudSyncState syncState) async {
    // Guest users cannot use Cloud Backup — they have no Google account.
    if (widget.authState.isGuest) {
      AppToast.show(
        context,
        'Sign in with Google to use Cloud Backup',
        type: ToastType.error,
      );
      return;
    }

    if (value) {
      setState(() => _toggling = true);
      final authService = ref.read(authServiceProvider);
      final granted = await authService.requestDriveScope();
      if (!mounted) return;
      if (!granted) {
        AppToast.show(
          context,
          'Drive permission denied — Cloud Backup not enabled',
          type: ToastType.error,
        );
        setState(() => _toggling = false);
        return;
      }
      await ref
          .read(cloudSyncProvider.notifier)
          .enableSync(
            dataNotifier: ref.read(dataNotifierProvider.notifier),
            googleSignIn: authService.googleSignIn,
          );
      setState(() => _toggling = false);
    } else {
      await ref.read(cloudSyncProvider.notifier).disableSync();
    }
  }

  Future<void> _onSyncNow() async {
    final authService = ref.read(authServiceProvider);
    await ref
        .read(cloudSyncProvider.notifier)
        .syncNow(
          dataNotifier: ref.read(dataNotifierProvider.notifier),
          googleSignIn: authService.googleSignIn,
        );
  }

  String _lastSyncedLabel(DateTime? lastSynced) {
    if (lastSynced == null) return 'Not yet synced';
    final now = DateTime.now();
    final local = lastSynced.toLocal();
    final diff = now.difference(local);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      final hm =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      return 'Today, $hm';
    }
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(cloudSyncProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final isSyncing = syncState.status == SyncStatus.syncing;

    return Container(
      decoration: context.cardDecoration,
      child: Column(
        children: [
          // ── Toggle row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_sync_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sync to Google Drive',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                _toggling
                    ? const SizedBox(
                      width: 36,
                      height: 20,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                    : Switch(
                      value: syncState.isEnabled,
                      onChanged:
                          _toggling ? null : (v) => _onToggle(v, syncState),
                      activeColor: primary,
                    ),
              ],
            ),
          ),

          if (syncState.isEnabled) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),

            // ── Status row ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (isSyncing) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Syncing…',
                      style: TextStyle(fontSize: 13, color: primary),
                    ),
                  ] else if (syncState.status == SyncStatus.error) ...[
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        syncState.errorMessage ?? 'Sync error',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _lastSyncedLabel(syncState.lastSynced),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Sync Now button
                  if (!isSyncing)
                    TextButton(
                      onPressed: _onSyncNow,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Sync Now',
                        style: TextStyle(fontSize: 12, color: primary),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Disclosure ─────────────────────────────────
          const Divider(height: 1, indent: 16, endIndent: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Text(
              'Your data is stored in Google Drive\'s hidden App Data folder — '
              'it is only accessible by this app and is not visible in your Drive.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account section ───────────────────────────────────────

class _AccountSection extends ConsumerWidget {
  final AuthState authState;
  const _AccountSection({required this.authState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: context.cardDecoration,
      child: Column(
        children: [
          if (authState.isGuest) ...[
            _ActionRow(
              icon: Icons.login_rounded,
              label: 'Sign in with Google',
              onTap: () => context.go(AppRoutes.welcome),
            ),
          ] else ...[
            _ActionRow(
              icon: Icons.delete_sweep_rounded,
              label: 'Clear all data',
              color: AppColors.danger,
              onTap: () => _confirmClearData(context, ref),
            ),
            _ActionRow(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              color: AppColors.danger,
              onTap: () => _confirmSignOut(context, ref),
            ),
            _ActionRow(
              icon: Icons.person_remove_rounded,
              label: 'Delete account',
              color: AppColors.danger,
              onTap: () => _confirmDeleteAccount(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear all data?'),
            content: const Text(
              'All habits, journal entries, mood logs, focus sessions, '
              'transactions and accounts will be permanently deleted. '
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clear all'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(dataNotifierProvider.notifier).clearAllData();
      if (context.mounted) {
        AppToast.show(context, 'All data cleared.');
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'Your data will remain intact. You can sign back in any time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      // Clear in-memory data BEFORE signing out so the previous user's
      // habits, journal entries and transactions are not accessible to
      // the next session while the sign-out completes.
      ref.read(dataNotifierProvider.notifier).reset();
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) context.go(AppRoutes.welcome);
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete your account?'),
            content: const Text(
              'This will permanently delete your account and ALL your data — '
              'habits, journal entries, mood logs, focus sessions, and transactions.\n\n'
              'This action cannot be undone. Your Google account itself will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete account'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;

    // Cancel all scheduled notifications first.
    await NotificationService.cancelAll();
    // Wipe local data.
    await ref.read(dataNotifierProvider.notifier).clearAllData();
    ref.read(dataNotifierProvider.notifier).reset();
    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'requires-recent-login') {
        AppToast.show(
          context,
          'Please sign out and sign in again, then try deleting your account.',
          type: ToastType.error,
        );
        return;
      }
      AppToast.show(
        context,
        'Could not delete account: ${e.message}',
        type: ToastType.error,
      );
      return;
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        'Could not delete account. Please try again.',
        type: ToastType.error,
      );
      return;
    }
    if (context.mounted) context.go(AppRoutes.welcome);
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color, size: 22),
    title: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 15),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textMuted,
      size: 20,
    ),
    onTap: onTap,
  );
}

// ── Section header ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),
  );
}

// ── Notifications section ─────────────────────────────────

class _NotificationsSection extends ConsumerStatefulWidget {
  const _NotificationsSection();

  @override
  ConsumerState<_NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<_NotificationsSection> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _loaded = false;
  // Tracks OS-level permission status so we can show actionable UI.
  PermissionStatus _permStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final permStatus = await PermissionService.instance.notificationStatus;
    if (!mounted) return;
    setState(() {
      _enabled =
          (prefs.getBool(PrefKeys.notificationsEnabled) ?? false) &&
          permStatus.isGranted;
      _time = TimeOfDay(
        hour: prefs.getInt(PrefKeys.reminderHour) ?? 8,
        minute: prefs.getInt(PrefKeys.reminderMinute) ?? 0,
      );
      _permStatus = permStatus;
      _loaded = true;
    });
  }

  /// Called when the user flips the toggle.
  Future<void> _setEnabled(bool val) async {
    final prefs = ref.read(sharedPreferencesProvider);

    if (val) {
      // 1. Request POST_NOTIFICATIONS (no-op if already granted).
      if (!_permStatus.isGranted) {
        final granted = await PermissionService.instance.requestNotifications(
          context,
        );
        if (!mounted) return;
        final newStatus = await PermissionService.instance.notificationStatus;
        setState(() => _permStatus = newStatus);
        if (!granted) return; // stay off if user denied
      }
      if (!mounted) return;
      // 2. Request exact alarm permission (needed on Android 12).
      await PermissionService.instance.requestExactAlarm(context);
      if (!mounted) return;
      // 3. Schedule the global daily reminder.
      await NotificationService.scheduleGlobalReminder(_time);
    } else {
      // Cancel the global daily reminder.
      await NotificationService.cancelGlobalReminder();
    }

    await prefs.setBool(PrefKeys.notificationsEnabled, val);
    if (mounted) setState(() => _enabled = val);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(PrefKeys.reminderHour, picked.hour);
    await prefs.setInt(PrefKeys.reminderMinute, picked.minute);
    setState(() => _time = picked);
    // Reschedule the global reminder at the new time (if the toggle is on).
    if (_enabled) {
      await NotificationService.scheduleGlobalReminder(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    final isPermanentlyDenied = _permStatus.isPermanentlyDenied;

    return Container(
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color:
                      isPermanentlyDenied
                          ? AppColors.textMuted
                          : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Daily habit reminders',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: isPermanentlyDenied ? null : _setEnabled,
                  activeColor: primary,
                ),
              ],
            ),
          ),
          // ── Permanently denied banner ─────────────────────
          if (isPermanentlyDenied) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            InkWell(
              onTap: openAppSettings,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Notification permission denied. Tap to open Settings and enable it.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.warning,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
          // ── Time picker row (only when enabled) ───────────
          if (_enabled && !isPermanentlyDenied) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            InkWell(
              onTap: _pickTime,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Reminder time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _time.format(context),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── General section ───────────────────────────────────────

class _GeneralSection extends ConsumerStatefulWidget {
  const _GeneralSection();

  @override
  ConsumerState<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends ConsumerState<_GeneralSection> {
  int _firstDayOfWeek = 1; // 0=Sun, 1=Mon
  String _currency = 'USD';
  bool _celebrationHaptic = true;
  bool _celebrationVibration = true;
  bool _celebrationSound = true;
  bool _celebrationVisual = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _firstDayOfWeek = prefs.getInt(PrefKeys.firstDayOfWeek) ?? 1;
      _currency = prefs.getString(PrefKeys.defaultCurrency) ?? 'USD';
      _celebrationHaptic = prefs.getBool(PrefKeys.celebrationHaptic) ?? true;
      _celebrationVibration =
          prefs.getBool(PrefKeys.celebrationVibration) ?? true;
      _celebrationSound = prefs.getBool(PrefKeys.celebrationSound) ?? true;
      _celebrationVisual = prefs.getBool(PrefKeys.celebrationVisual) ?? true;
      _loaded = true;
    });
  }

  Future<void> _pickFirstDay() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final picked = await showDialog<int>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('First day of week'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 0),
                child: const Text('Sunday'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 1),
                child: const Text('Monday'),
              ),
            ],
          ),
    );
    if (picked == null) return;
    await prefs.setInt(PrefKeys.firstDayOfWeek, picked);
    setState(() => _firstDayOfWeek = picked);
  }

  Future<void> _pickCurrency() async {
    final prefs = ref.read(sharedPreferencesProvider);
    const currencies = <(String, String)>[
      ('USD', 'US Dollar'),
      ('EUR', 'Euro'),
      ('GBP', 'British Pound'),
      ('INR', 'Indian Rupee'),
      ('JPY', 'Japanese Yen'),
      ('CAD', 'Canadian Dollar'),
      ('AUD', 'Australian Dollar'),
      ('CHF', 'Swiss Franc'),
      ('CNY', 'Chinese Yuan'),
      ('BRL', 'Brazilian Real'),
      ('MXN', 'Mexican Peso'),
      ('SGD', 'Singapore Dollar'),
      ('AED', 'UAE Dirham'),
      ('KRW', 'South Korean Won'),
      ('SAR', 'Saudi Riyal'),
      ('HKD', 'Hong Kong Dollar'),
      ('SEK', 'Swedish Krona'),
      ('NOK', 'Norwegian Krone'),
      ('DKK', 'Danish Krone'),
      ('PLN', 'Polish Zloty'),
      ('TRY', 'Turkish Lira'),
      ('ZAR', 'South African Rand'),
      ('IDR', 'Indonesian Rupiah'),
      ('MYR', 'Malaysian Ringgit'),
      ('THB', 'Thai Baht'),
      ('PHP', 'Philippine Peso'),
      ('VND', 'Vietnamese Dong'),
      ('NGN', 'Nigerian Naira'),
      ('PKR', 'Pakistani Rupee'),
      ('BDT', 'Bangladeshi Taka'),
      ('EGP', 'Egyptian Pound'),
      ('NZD', 'New Zealand Dollar'),
      ('ILS', 'Israeli Shekel'),
      ('ARS', 'Argentine Peso'),
      ('CLP', 'Chilean Peso'),
      ('COP', 'Colombian Peso'),
      ('UAH', 'Ukrainian Hryvnia'),
      ('CZK', 'Czech Koruna'),
      ('HUF', 'Hungarian Forint'),
      ('RUB', 'Russian Ruble'),
    ];
    final picked = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Default currency'),
            contentPadding: const EdgeInsets.only(top: 12, bottom: 0),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currencies.length,
                itemBuilder: (_, i) {
                  final (code, name) = currencies[i];
                  final sel = _currency == code;
                  return ListTile(
                    dense: true,
                    title: Text(
                      code,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(name),
                    trailing:
                        sel
                            ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                            : null,
                    onTap: () => Navigator.pop(ctx, code),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
    if (picked == null) return;
    await prefs.setString(PrefKeys.defaultCurrency, picked);
    setState(() => _currency = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    final dayLabel = _firstDayOfWeek == 1 ? 'Monday' : 'Sunday';

    return Container(
      decoration: context.cardDecoration,
      child: Column(
        children: [
          InkWell(
            onTap: _pickFirstDay,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'First day of week',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          InkWell(
            onTap: _pickCurrency,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_money_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Default currency',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _currency,
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // ── Celebration feedback ─────────────────────────
          // Master toggle
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            secondary: const Icon(
              Icons.celebration_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            title: const Text(
              'Celebration feedback',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Show effects when a habit is completed',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            value: _celebrationHaptic,
            onChanged: (v) async {
              final prefs = ref.read(sharedPreferencesProvider);
              await prefs.setBool(PrefKeys.celebrationHaptic, v);
              setState(() => _celebrationHaptic = v);
            },
          ),
          // Sub-toggles (only visible when master is on)
          if (_celebrationHaptic) ...[
            const Divider(height: 1, indent: 52, endIndent: 16),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.only(
                left: 52,
                right: 16,
                top: 2,
                bottom: 2,
              ),
              title: const Text(
                'Vibration',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
              value: _celebrationVibration,
              onChanged: (v) async {
                final prefs = ref.read(sharedPreferencesProvider);
                await prefs.setBool(PrefKeys.celebrationVibration, v);
                setState(() => _celebrationVibration = v);
              },
            ),
            const Divider(height: 1, indent: 52, endIndent: 16),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.only(
                left: 52,
                right: 16,
                top: 2,
                bottom: 2,
              ),
              title: const Text(
                'Sound',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
              value: _celebrationSound,
              onChanged: (v) async {
                final prefs = ref.read(sharedPreferencesProvider);
                await prefs.setBool(PrefKeys.celebrationSound, v);
                setState(() => _celebrationSound = v);
              },
            ),
            const Divider(height: 1, indent: 52, endIndent: 16),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.only(
                left: 52,
                right: 16,
                top: 2,
                bottom: 2,
              ),
              title: const Text(
                'Visual (confetti)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
              value: _celebrationVisual,
              onChanged: (v) async {
                final prefs = ref.read(sharedPreferencesProvider);
                await prefs.setBool(PrefKeys.celebrationVisual, v);
                setState(() => _celebrationVisual = v);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── About & Support section ───────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  static Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppToast.show(context, 'Could not open link.', type: ToastType.error);
      }
    }
  }

  static Future<void> _share(BuildContext context) async {
    // Copy link to clipboard since share_plus is not installed.
    const link =
        'https://play.google.com/store/apps/details?id=com.habitgenius';
    await Clipboard.setData(const ClipboardData(text: link));
    if (context.mounted) {
      AppToast.show(
        context,
        'App link copied to clipboard',
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: context.cardDecoration,
      child: Column(
        children: [
          _AboutRow(
            icon: Icons.star_rounded,
            label: 'Rate on Google Play',
            color: const Color(0xFFFDCB6E),
            onTap: () => _open(context, 'market://details?id=com.habitgenius'),
            isFirst: true,
          ),
          _AboutRow(
            icon: Icons.share_rounded,
            label: 'Share HabitGenius',
            onTap: () => _share(context),
          ),
          _AboutRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _open(context, 'https://habitgenius.app/privacy'),
          ),
          _AboutRow(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            onTap: () => _open(context, 'https://habitgenius.app/terms'),
          ),
          _AboutRow(
            icon: Icons.mail_outline_rounded,
            label: 'Contact Support',
            onTap:
                () => _open(
                  context,
                  'mailto:support@habitgenius.app?subject=HabitGenius%20Support',
                ),
          ),
          _AboutRow(
            icon: Icons.info_outline_rounded,
            label: 'Open Source Licenses',
            isLast: true,
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isFirst;
  final bool isLast;

  const _AboutRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.textSecondary;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(16) : Radius.zero,
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
