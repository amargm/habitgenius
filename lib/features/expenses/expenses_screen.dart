import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/account.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/upgrade_prompt_sheet.dart';

// ── Category constants ────────────────────────────────────

const _kExpenseCategories = [
  'Food & Drink',
  'Transport',
  'Housing',
  'Shopping',
  'Health',
  'Entertainment',
  'Education',
  'Travel',
  'Other',
];

const _kIncomeCategories = [
  'Salary',
  'Freelance',
  'Gift',
  'Investment',
  'Other',
];

const _kAccountTypeIcons = {
  AccountType.checking: '🏦',
  AccountType.savings: '💰',
  AccountType.credit: '💳',
  AccountType.cash: '💵',
};

// ── Expenses screen ───────────────────────────────────────

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(authNotifierProvider).tier;
    final appData = ref.watch(appDataProvider);
    final accounts = appData.accounts;
    final transactions = appData.transactions;

    if (tier == UserTier.guest) {
      return const Scaffold(
        body: EmptyStateWidget(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Expenses is for registered users',
          subtitle:
              'Sign in with Google to track your transactions and accounts.',
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Expenses',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Transactions'),
                    Tab(text: 'Accounts'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    () => ref.read(dataNotifierProvider.notifier).reload(),
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _TransactionsTab(
                      transactions: transactions,
                      accounts: accounts,
                      tier: tier,
                      onAdd:
                          () => _onAddTransaction(
                            context,
                            tier,
                            transactions,
                            accounts,
                          ),
                    ),
                    _AccountsTab(
                      accounts: accounts,
                      transactions: transactions,
                      tier: tier,
                      onAdd: () => _onAddAccount(context, tier, accounts),
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

  // ── FAB actions ───────────────────────────────────────────

  void _onAddTransaction(
    BuildContext context,
    UserTier tier,
    List<Transaction> txs,
    List<Account> accounts,
  ) {
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add an account first')));
      return;
    }
    final today = _todayStr();
    final txToday = txs.where((t) => t.date == today).length;
    if (txToday >= AppLimits.maxTransactionsPerDay(tier)) {
      UpgradePromptSheet.show(context, feature: 'More daily transactions');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionSheet(accounts: accounts),
    );
  }

  void _onAddAccount(
    BuildContext context,
    UserTier tier,
    List<Account> accounts,
  ) {
    if (accounts.length >= AppLimits.maxAccounts(tier)) {
      UpgradePromptSheet.show(context, feature: 'More Accounts');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AccountSheet(),
    );
  }

  static String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}

// ── Transactions tab ──────────────────────────────────────

class _TransactionsTab extends StatelessWidget {
  final List<Transaction> transactions;
  final List<Account> accounts;
  final UserTier tier;
  final VoidCallback onAdd;

  const _TransactionsTab({
    required this.transactions,
    required this.accounts,
    required this.tier,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));

    // Group by date
    final Map<String, List<Transaction>> grouped = {};
    for (final tx in sorted) {
      grouped.putIfAbsent(tx.date, () => []).add(tx);
    }

    // Total this month
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthTxs = transactions.where(
      (t) => t.date.startsWith(monthStr) && t.type == TransactionType.expense,
    );
    final monthTotal =
        monthTxs.isEmpty
            ? 0.0
            : monthTxs.map((t) => t.amount).reduce((a, b) => a + b);

    return Column(
      children: [
        if (transactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SummaryCard(monthTotal: monthTotal),
          ),
        Expanded(
          child:
              transactions.isEmpty
                  ? _EmptyState(
                    icon: '💸',
                    label: 'No transactions yet',
                    sub: 'Tap + to log your first transaction.',
                    onAdd: onAdd,
                  )
                  : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: [
                      ...grouped.entries.map(
                        (e) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DateHeader(dateStr: e.key),
                            ...e.value.map(
                              (tx) => _TxTile(
                                tx: tx,
                                account:
                                    accounts
                                        .where((a) => a.id == tx.accountId)
                                        .firstOrNull,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                      Align(
                        alignment: Alignment.center,
                        child: FloatingActionButton(
                          heroTag: 'add_tx',
                          onPressed: onAdd,
                          child: const Icon(Icons.add_rounded),
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }
}

// ── Accounts tab ──────────────────────────────────────────

class _AccountsTab extends StatelessWidget {
  final List<Account> accounts;
  final List<Transaction> transactions;
  final UserTier tier;
  final VoidCallback onAdd;

  const _AccountsTab({
    required this.accounts,
    required this.transactions,
    required this.tier,
    required this.onAdd,
  });

  double _balance(Account a) {
    double bal = a.startingBalance;
    for (final tx in transactions) {
      if (tx.accountId == a.id) {
        bal += tx.type == TransactionType.income ? tx.amount : -tx.amount;
      }
      if (tx.toAccountId == a.id) {
        bal += tx.amount;
      }
    }
    return bal;
  }

  @override
  Widget build(BuildContext context) {
    return accounts.isEmpty
        ? _EmptyState(
          icon: '🏦',
          label: 'No accounts yet',
          sub: 'Tap + to add your first account.',
          onAdd: onAdd,
        )
        : ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            ...accounts.map((a) {
              final bal = _balance(a);
              final icon = _kAccountTypeIcons[a.type] ?? '🏦';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            a.type.name.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${a.currency} ${bal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: bal >= 0 ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Center(
              child: FloatingActionButton(
                heroTag: 'add_acc',
                onPressed: onAdd,
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        );
  }
}

// ── Summary card ──────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double monthTotal;
  const _SummaryCard({required this.monthTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text('💸', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This month',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                monthTotal.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Date header ───────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String dateStr;
  const _DateHeader({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(dateStr);
    final label = d != null ? _fmt(d) : dateStr;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    const months = [
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Transaction tile ──────────────────────────────────────

class _TxTile extends ConsumerWidget {
  final Transaction tx;
  final Account? account;
  const _TxTile({required this.tx, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = tx.type == TransactionType.income;
    final isTransfer = tx.type == TransactionType.transfer;
    final color = isIncome
        ? AppColors.success
        : isTransfer
            ? AppColors.textSecondary
            : AppColors.danger;

    return GestureDetector(
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  isIncome
                      ? '↑'
                      : isTransfer
                      ? '⇄'
                      : '↓',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (account != null)
                    Text(
                      account!.name,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : isTransfer ? '' : '-'}${tx.currency} ${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (tx.note != null)
                  Text(
                    tx.note!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete transaction?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(dataNotifierProvider.notifier).deleteTransaction(tx.id);
    }
  }
}

// ── Add transaction sheet ─────────────────────────────────

class _TransactionSheet extends ConsumerStatefulWidget {
  final List<Account> accounts;
  const _TransactionSheet({required this.accounts});

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  TransactionType _type = TransactionType.expense;
  String _category = _kExpenseCategories.first;
  Account? _account;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _account = widget.accounts.firstOrNull;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _type == TransactionType.income
          ? _kIncomeCategories
          : _kExpenseCategories;

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _account == null) return;
    setState(() => _saving = true);
    try {
      final dateStr =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

      final tx = Transaction(
        id: const Uuid().v4(),
        type: _type,
        amount: amount,
        currency: _account!.currency,
        category: _category,
        accountId: _account!.id,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        recurring: false,
        date: dateStr,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      await ref.read(dataNotifierProvider.notifier).addTransaction(tx);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save transaction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder:
          (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        'New Transaction',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child:
                            _saving
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Save'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      // Type toggle
                      Row(
                        children:
                            [
                              TransactionType.expense,
                              TransactionType.income,
                            ].map((t) {
                              final sel = _type == t;
                              final c =
                                  t == TransactionType.income
                                      ? AppColors.success
                                      : AppColors.danger;
                              return Expanded(
                                child: GestureDetector(
                                  onTap:
                                      () => setState(() {
                                        _type = t;
                                        _category = _categories.first;
                                      }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          sel
                                              ? c.withValues(alpha: 0.15)
                                              : AppColors.bgElevated,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: sel ? c : AppColors.border,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        t == TransactionType.expense
                                            ? 'Expense'
                                            : 'Income',
                                        style: TextStyle(
                                          color:
                                              sel ? c : AppColors.textSecondary,
                                          fontWeight:
                                              sel
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '${_account?.currency ?? ''} ',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),

                      // Account picker
                      DropdownButtonFormField<Account>(
                        value: _account,
                        decoration: const InputDecoration(labelText: 'Account'),
                        items:
                            widget.accounts
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (a) => setState(() => _account = a),
                      ),
                      const SizedBox(height: 16),

                      // Category
                      const Text(
                        'CATEGORY',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _categories.map((c) {
                              final sel = _category == c;
                              return GestureDetector(
                                onTap: () => setState(() => _category = c),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        sel
                                            ? primary.withValues(alpha: 0.15)
                                            : AppColors.bgElevated,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sel ? primary : AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    c,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          sel
                                              ? primary
                                              : AppColors.textSecondary,
                                      fontWeight:
                                          sel
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Date
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded),
                        title: Text(_fmtDate(_date)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _date = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 8),

                      // Note
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Add account sheet ─────────────────────────────────────

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _nameCtrl = TextEditingController();
  final _balCtrl = TextEditingController(text: '0');
  AccountType _type = AccountType.checking;
  String _currency = 'USD';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final bal = double.tryParse(_balCtrl.text) ?? 0;
    setState(() => _saving = true);
    try {
      final account = Account(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        type: _type,
        startingBalance: bal,
        currency: _currency,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      await ref.read(dataNotifierProvider.notifier).addAccount(account);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save account: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder:
          (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        'New Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Account name',
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),

                      // Account type
                      DropdownButtonFormField<AccountType>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items:
                            AccountType.values
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      '${_kAccountTypeIcons[t]} ${t.name}',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _type = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Currency
                      DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        items:
                            [
                                  'USD',
                                  'EUR',
                                  'GBP',
                                  'JPY',
                                  'CAD',
                                  'AUD',
                                  'INR',
                                  'CHF',
                                  'CNY',
                                  'BRL',
                                ]
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _currency = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _balCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Starting balance',
                        ),
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

// ── Empty state ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String icon;
  final String label;
  final String sub;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        FloatingActionButton(
          heroTag: 'empty_add',
          onPressed: onAdd,
          child: const Icon(Icons.add_rounded),
        ),
      ],
    ),
  );
}
