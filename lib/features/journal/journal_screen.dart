import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/journal_entry.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/upgrade_prompt_sheet.dart';

// ── Journal screen ────────────────────────────────────────

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(authNotifierProvider).tier;
    final entries = ref.watch(appDataProvider).journal;
    final filtered =
        _search.isEmpty
            ? entries
            : entries.where((e) {
              final q = _search.toLowerCase();
              return (e.title?.toLowerCase().contains(q) ?? false) ||
                  e.body.toLowerCase().contains(q) ||
                  e.tags.any((t) => t.toLowerCase().contains(q));
            }).toList();

    // Sort newest first
    final sorted = [...filtered]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Journal',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${entries.length} / ${AppLimits.maxJournalEntries(tier)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  hintText: 'Search entries…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    () => ref.read(dataNotifierProvider.notifier).reload(),
                child:
                    sorted.isEmpty
                        ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: EmptyStateWidget(
                            icon: Icons.menu_book_rounded,
                            title:
                                _search.isNotEmpty
                                    ? 'No matching entries'
                                    : 'No journal entries yet',
                            subtitle:
                                _search.isNotEmpty
                                    ? 'Try a different search term.'
                                    : 'Tap the pencil button to write your first entry.',
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: sorted.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder:
                              (_, i) => _EntryTile(
                                entry: sorted[i],
                                onTap: () => _openEntry(context, sorted[i]),
                                onDelete: () => _deleteEntry(sorted[i].id),
                              ),
                        ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onNew(context, tier, entries.length),
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  void _onNew(BuildContext context, UserTier tier, int count) {
    if (count >= AppLimits.maxJournalEntries(tier)) {
      UpgradePromptSheet.show(context, feature: 'More Journal Entries');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const _JournalEntrySheet(),
      ),
    );
  }

  void _openEntry(BuildContext context, JournalEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _JournalEntrySheet(entry: entry),
      ),
    );
  }

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete entry?'),
            content: const Text('This entry will be permanently deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await ref.read(dataNotifierProvider.notifier).deleteJournalEntry(id);
    }
  }
}

// ── Entry tile ────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _fmtDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dt = DateTime.tryParse(entry.createdAt)?.toLocal();
    final dateStr = dt != null ? _fmtDate(dt) : '';
    final preview = entry.body.replaceAll(RegExp(r'\n+'), ' ').trim();
    final wordCount =
        entry.body.trim().isEmpty
            ? 0
            : entry.body.trim().split(RegExp(r'\s+')).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: context.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title?.isNotEmpty == true
                            ? entry.title!
                            : 'Untitled',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (entry.tags.isNotEmpty)
                  ...entry.tags
                      .take(3)
                      .map(
                        (t) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(fontSize: 11, color: primary),
                          ),
                        ),
                      ),
                const Spacer(),
                Text(
                  '$wordCount words',
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── New / Edit entry sheet ────────────────────────────────

class _JournalEntrySheet extends ConsumerStatefulWidget {
  final JournalEntry? entry;
  const _JournalEntrySheet({this.entry});

  @override
  ConsumerState<_JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends ConsumerState<_JournalEntrySheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _tagCtrl;
  final Set<String> _tags = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _bodyCtrl = TextEditingController(text: e?.body ?? '');
    _tagCtrl = TextEditingController();
    if (e != null) _tags.addAll(e.tags);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final existing = widget.entry;
      final entry = JournalEntry(
        id: existing?.id ?? const Uuid().v4(),
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        tags: _tags.toList(),
        linkedMoodId: existing?.linkedMoodId,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final notifier = ref.read(dataNotifierProvider.notifier);
      if (existing == null) {
        await notifier.addJournalEntry(entry);
      } else {
        await notifier.updateJournalEntry(entry);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save entry: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addTag() {
    final t = _tagCtrl.text.trim();
    if (t.isNotEmpty && _tags.length < 10) {
      setState(() {
        _tags.add(t);
        _tagCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'Edit Entry' : 'New Entry',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child:
                _saving
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: primary,
                      ),
                    ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
        children: [
          // Date display
          Text(
            _fmtFullDate(DateTime.now()),
            style: TextStyle(
              color: context.appColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Title field
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),

          // Body field
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _bodyCtrl,
            builder: (_, val, __) {
              final words =
                  val.text.trim().isEmpty
                      ? 0
                      : val.text.trim().split(RegExp(r'\s+')).length;
              return Text(
                '$words words  •  ${val.text.length} chars',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 11,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: null,
            minLines: 12,
            style: const TextStyle(fontSize: 15, height: 1.7),
            decoration: InputDecoration(
              hintText: 'Write your thoughts…',
              alignLabelWithHint: true,
              hintStyle: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 15,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const Divider(height: 32),

          // Tags
          Text(
            'TAGS',
            style: TextStyle(
              color: context.appColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ..._tags.map(
                (t) => GestureDetector(
                  onTap: () => setState(() => _tags.remove(t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 12, color: primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add tag…',
                    hintStyle: TextStyle(
                      color: context.appColors.textMuted,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              IconButton(
                onPressed: _addTag,
                icon: Icon(Icons.add_rounded, color: primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtFullDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
