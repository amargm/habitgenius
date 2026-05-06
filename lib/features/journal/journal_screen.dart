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
import '../../core/utils/app_toast.dart';
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
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _bodyCtrl = TextEditingController(text: e?.body ?? '');
    _tagCtrl = TextEditingController();
    if (e != null) _tags.addAll(e.tags);
    // Open existing entries (with content) in preview mode.
    if (e != null && (e.body.trim().isNotEmpty || e.title?.trim().isNotEmpty == true)) {
      _preview = true;
    }
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
      AppToast.show(context, 'Write something before saving.');
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
        AppToast.show(
          context,
          'Could not save entry. Please try again.',
          type: ToastType.error,
        );
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
      resizeToAvoidBottomInset: true,
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
          // Preview / edit toggle
          IconButton(
            tooltip: _preview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _preview = !_preview),
            icon: Icon(
              _preview ? Icons.edit_rounded : Icons.visibility_rounded,
              size: 20,
            ),
          ),
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
      body: Column(
        children: [
          Expanded(
            child:
                _preview
                    ? _MarkdownPreview(
                      title: _titleCtrl.text,
                      body: _bodyCtrl.text,
                    )
                    : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                        Container(
                          decoration: BoxDecoration(
                            color: context.appColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.appColors.border),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: TextField(
                            controller: _titleCtrl,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Title',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),

                        // Body field
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _bodyCtrl,
                          builder: (_, val, __) {
                            final words =
                                val.text.trim().isEmpty
                                    ? 0
                                    : val.text
                                        .trim()
                                        .split(RegExp(r'\s+'))
                                        .length;
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
                        Container(
                          decoration: BoxDecoration(
                            color: context.appColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.appColors.border),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: TextField(
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
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
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
                                      Icon(
                                        Icons.close,
                                        size: 12,
                                        color: primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: context.appColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.appColors.border),
                          ),
                          padding: const EdgeInsets.only(left: 14),
                          child: Row(
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
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
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
                        ),
                      ],
                    ),
          ),
          if (!_preview) _JournalToolbar(bodyCtrl: _bodyCtrl),
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

// ── Markdown preview ──────────────────────────────────────

class _MarkdownPreview extends StatelessWidget {
  final String title;
  final String body;
  const _MarkdownPreview({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty) ...[
            Text(
              title.trim(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (body.trim().isEmpty)
            Text(
              'Nothing to preview yet.',
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ..._parseMarkdown(body, context, primary),
        ],
      ),
    );
  }

  List<Widget> _parseMarkdown(
    String text,
    BuildContext context,
    Color primary,
  ) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.startsWith('### ')) {
        widgets.add(
          _styledLine(line.substring(4), 16, FontWeight.w700, context),
        );
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('## ')) {
        widgets.add(
          _styledLine(line.substring(3), 18, FontWeight.w700, context),
        );
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('# ')) {
        widgets.add(
          _styledLine(line.substring(2), 22, FontWeight.w800, context),
        );
        widgets.add(const SizedBox(height: 10));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: TextStyle(
                    fontSize: 15,
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(child: _inlineSpans(line.substring(2), context)),
              ],
            ),
          ),
        );
      } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        final num = line.indexOf('. ');
        final numStr = line.substring(0, num + 1);
        final content = line.substring(num + 2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numStr  ',
                  style: TextStyle(
                    fontSize: 15,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(child: _inlineSpans(content, context)),
              ],
            ),
          ),
        );
      } else if (line.startsWith('> ')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.07),
              border: Border(left: BorderSide(color: primary, width: 3)),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: _inlineSpans(line.substring(2), context),
          ),
        );
      } else if (line.trim() == '---' || line.trim() == '***') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: context.appColors.border),
          ),
        );
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _inlineSpans(line, context),
          ),
        );
      }
      i++;
    }
    return widgets;
  }

  Widget _styledLine(
    String text,
    double size,
    FontWeight weight,
    BuildContext context,
  ) {
    return _inlineSpansStyled(
      text,
      context,
      fontSize: size,
      fontWeight: weight,
    );
  }

  Widget _inlineSpans(String text, BuildContext context) =>
      _inlineSpansStyled(text, context);

  Widget _inlineSpansStyled(
    String text,
    BuildContext context, {
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    // Parse inline: **bold**, *italic*, `code`, ~~strikethrough~~
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`|~~(.+?)~~)');
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(
          TextSpan(
            text: text.substring(last, m.start),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1.6,
              color: context.appColors.textPrimary,
            ),
          ),
        );
      }
      if (m.group(2) != null) {
        // **bold**
        spans.add(
          TextSpan(
            text: m.group(2),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.6,
              color: context.appColors.textPrimary,
            ),
          ),
        );
      } else if (m.group(3) != null) {
        // *italic*
        spans.add(
          TextSpan(
            text: m.group(3),
            style: TextStyle(
              fontSize: fontSize,
              fontStyle: FontStyle.italic,
              height: 1.6,
              color: context.appColors.textPrimary,
            ),
          ),
        );
      } else if (m.group(4) != null) {
        // `code`
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.appColors.bgElevated,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                m.group(4)!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: fontSize - 1,
                  color: context.appColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      } else if (m.group(5) != null) {
        // ~~strikethrough~~
        spans.add(
          TextSpan(
            text: m.group(5),
            style: TextStyle(
              fontSize: fontSize,
              decoration: TextDecoration.lineThrough,
              height: 1.6,
              color: context.appColors.textSecondary,
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(last),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1.6,
            color: context.appColors.textPrimary,
          ),
        ),
      );
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ── Journal formatting toolbar ────────────────────────────

class _JournalToolbar extends StatelessWidget {
  final TextEditingController bodyCtrl;

  const _JournalToolbar({required this.bodyCtrl});

  void _insert(String prefix, String suffix) {
    final text = bodyCtrl.text;
    final sel = bodyCtrl.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final selected = text.substring(start, end);
    final replacement = '$prefix$selected$suffix';
    final newText =
        text.substring(0, start) + replacement + text.substring(end);
    bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _insertLine(String prefix) {
    final text = bodyCtrl.text;
    final sel = bodyCtrl.selection;
    final pos = sel.start < 0 ? text.length : sel.start;
    // Find start of current line
    final lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    final newText =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToolbarBtn(
              label: 'B',
              bold: true,
              onTap: () => _insert('**', '**'),
            ),
            _ToolbarBtn(
              label: 'I',
              italic: true,
              onTap: () => _insert('_', '_'),
            ),
            _ToolbarBtn(
              icon: Icons.format_list_bulleted_rounded,
              onTap: () => _insertLine('• '),
            ),
            _ToolbarBtn(
              label: 'H',
              bold: true,
              onTap: () => _insertLine('## '),
            ),
            _ToolbarBtn(
              icon: Icons.format_quote_rounded,
              onTap: () => _insertLine('> '),
            ),
            _ToolbarBtn(
              icon: Icons.keyboard_hide_rounded,
              onTap: () => FocusScope.of(context).unfocus(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool bold;
  final bool italic;
  final VoidCallback onTap;

  const _ToolbarBtn({
    this.label,
    this.icon,
    this.bold = false,
    this.italic = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child:
            icon != null
                ? Icon(icon, size: 20, color: context.appColors.textSecondary)
                : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                    color: context.appColors.textSecondary,
                  ),
                ),
      ),
    );
  }
}
