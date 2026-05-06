import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/account.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/utils/app_toast.dart';
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
    _tabs = TabController(length: 3, vsync: this);
    // Rebuild when the active tab changes so the FAB updates.
    _tabs.addListener(() => setState(() {}));
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'expenses_fab',
        onPressed:
            _tabs.index == 0
                ? () => _onAddTransaction(context, tier, transactions, accounts)
                : () => _onAddAccount(context, tier, accounts),
        child: const Icon(Icons.add_rounded),
      ),
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
                  color: context.appColors.bgCard,
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
                    Tab(text: 'Timeline'),
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
                    _TimelineTab(transactions: transactions),
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
      AppToast.show(context, 'Add an account first.');
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
    final monthExpenseTxs = transactions.where(
      (t) => t.date.startsWith(monthStr) && t.type == TransactionType.expense,
    );
    final monthIncomeTxs = transactions.where(
      (t) => t.date.startsWith(monthStr) && t.type == TransactionType.income,
    );
    final monthExpenses =
        monthExpenseTxs.isEmpty
            ? 0.0
            : monthExpenseTxs.map((t) => t.amount).reduce((a, b) => a + b);
    final monthIncome =
        monthIncomeTxs.isEmpty
            ? 0.0
            : monthIncomeTxs.map((t) => t.amount).reduce((a, b) => a + b);
    // Use the currency from this month's expenses (or first transaction).
    final summaryCurrency =
        monthExpenseTxs.isNotEmpty
            ? monthExpenseTxs.first.currency
            : (transactions.isNotEmpty ? transactions.first.currency : 'USD');

    return Column(
      children: [
        if (transactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SummaryCard(
              monthExpenses: monthExpenses,
              monthIncome: monthIncome,
              currency: summaryCurrency,
            ),
          ),
        if (monthExpenseTxs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _CategoryBreakdown(
              transactions: monthExpenseTxs.toList(),
              currency: summaryCurrency,
            ),
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
                    ],
                  ),
        ),
      ],
    );
  }
}

// ── Accounts tab ──────────────────────────────────────────

class _AccountsTab extends ConsumerWidget {
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
        if (tx.type == TransactionType.income) {
          bal += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          bal -= tx.amount;
        } else if (tx.type == TransactionType.transfer) {
          // Deduct from source account; credit handled by toAccountId check.
          bal -= tx.amount;
        }
      }
      // Credit the destination account only for transfers, and only if it is
      // a different account (guards against same-account transfers which would
      // otherwise double-count the amount).
      if (tx.type == TransactionType.transfer &&
          tx.toAccountId == a.id &&
          tx.toAccountId != tx.accountId) {
        bal += tx.amount;
      }
    }
    return bal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              return GestureDetector(
                onLongPress: () => _confirmDeleteAccount(context, ref, a),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: context.cardDecoration,
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
                        '${bal >= 0 ? '+' : ''}${a.currency} ${bal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color:
                              bal > 0
                                  ? AppColors.success
                                  : bal < 0
                                  ? AppColors.danger
                                  : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account a,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Delete "${a.name}"?'),
            content: const Text(
              'The account will be removed. Its transactions remain in history.',
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
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(dataNotifierProvider.notifier).deleteAccount(a.id);
    }
  }
}

// ── Summary card ──────────────────────────────────────────

// ── Category breakdown donut ──────────────────────────────

const _kCategoryColors = <String, Color>{
  'Food & Drink': Color(0xFFFF6B00),
  'Transport': Color(0xFF3498DB),
  'Housing': Color(0xFF9B59B6),
  'Shopping': Color(0xFFE74C3C),
  'Health': Color(0xFF2ECC71),
  'Entertainment': Color(0xFFF39C12),
  'Education': Color(0xFF1ABC9C),
  'Travel': Color(0xFF0984E3),
  'Other': Color(0xFF636E72),
};

// ── Timeline tab ──────────────────────────────────────────

enum _Period { week, month, quarter, year }

class _TimelineTab extends StatefulWidget {
  final List<Transaction> transactions;
  const _TimelineTab({required this.transactions});

  @override
  State<_TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<_TimelineTab> {
  _Period _period = _Period.month;

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

  String _smartMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  /// Returns (labels, expValues, incValues) for the current period.
  ({List<String> labels, List<double> exp, List<double> inc}) _chartData() {
    final txs = widget.transactions;
    final now = DateTime.now();

    switch (_period) {
      case _Period.week:
        // Last 7 days
        final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final labels = <String>[];
        final exp = <double>[];
        final inc = <double>[];
        for (int i = 6; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          final ds =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          labels.add(dayNames[(d.weekday - 1) % 7]);
          exp.add(
            txs
                .where((t) => t.date == ds && t.type == TransactionType.expense)
                .fold(0.0, (s, t) => s + t.amount),
          );
          inc.add(
            txs
                .where((t) => t.date == ds && t.type == TransactionType.income)
                .fold(0.0, (s, t) => s + t.amount),
          );
        }
        return (labels: labels, exp: exp, inc: inc);

      case _Period.month:
        // Current month by week (W1–W5)
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
        final labels = <String>[];
        final exp = <double>[];
        final inc = <double>[];
        int weekNum = 1;
        int day = 1;
        while (day <= daysInMonth) {
          final weekEnd = (day + 6).clamp(1, daysInMonth);
          labels.add('W$weekNum');
          double e = 0, i2 = 0;
          for (int d = day; d <= weekEnd; d++) {
            final ds =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
            e += txs
                .where((t) => t.date == ds && t.type == TransactionType.expense)
                .fold(0.0, (s, t) => s + t.amount);
            i2 += txs
                .where((t) => t.date == ds && t.type == TransactionType.income)
                .fold(0.0, (s, t) => s + t.amount);
          }
          exp.add(e);
          inc.add(i2);
          day += 7;
          weekNum++;
        }
        return (labels: labels, exp: exp, inc: inc);

      case _Period.quarter:
        // Last 3 months
        final labels = <String>[];
        final exp = <double>[];
        final inc = <double>[];
        for (int i = 2; i >= 0; i--) {
          final m = DateTime(now.year, now.month - i, 1);
          final ym = '${m.year}-${m.month.toString().padLeft(2, '0')}';
          labels.add(_months[m.month - 1]);
          exp.add(
            txs
                .where(
                  (t) =>
                      t.date.startsWith(ym) &&
                      t.type == TransactionType.expense,
                )
                .fold(0.0, (s, t) => s + t.amount),
          );
          inc.add(
            txs
                .where(
                  (t) =>
                      t.date.startsWith(ym) && t.type == TransactionType.income,
                )
                .fold(0.0, (s, t) => s + t.amount),
          );
        }
        return (labels: labels, exp: exp, inc: inc);

      case _Period.year:
        // Last 12 months
        final labels = <String>[];
        final exp = <double>[];
        final inc = <double>[];
        for (int i = 11; i >= 0; i--) {
          final m = DateTime(now.year, now.month - i, 1);
          final ym = '${m.year}-${m.month.toString().padLeft(2, '0')}';
          labels.add(_months[m.month - 1]);
          exp.add(
            txs
                .where(
                  (t) =>
                      t.date.startsWith(ym) &&
                      t.type == TransactionType.expense,
                )
                .fold(0.0, (s, t) => s + t.amount),
          );
          inc.add(
            txs
                .where(
                  (t) =>
                      t.date.startsWith(ym) && t.type == TransactionType.income,
                )
                .fold(0.0, (s, t) => s + t.amount),
          );
        }
        return (labels: labels, exp: exp, inc: inc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = widget.transactions;
    if (txs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.bar_chart_rounded,
        title: 'No transactions yet',
        subtitle: 'Add transactions to see your monthly spending over time.',
      );
    }

    const expenseColor = Color(0xFFE74C3C);
    const incomeColor = Color(0xFF2ECC71);

    final Map<String, double> monthExpense = {};
    final Map<String, double> monthIncome = {};
    String? currency;
    for (final tx in txs) {
      final month = tx.date.substring(0, 7);
      if (tx.type == TransactionType.expense) {
        monthExpense[month] = (monthExpense[month] ?? 0) + tx.amount;
        currency ??= tx.currency;
      } else {
        monthIncome[month] = (monthIncome[month] ?? 0) + tx.amount;
        currency ??= tx.currency;
      }
    }

    final allMonths =
        {...monthExpense.keys, ...monthIncome.keys}.toList()..sort();

    if (allMonths.isEmpty) return const SizedBox.shrink();

    final maxVal = allMonths
        .map(
          (m) => [
            monthExpense[m] ?? 0,
            monthIncome[m] ?? 0,
          ].reduce((a, b) => a > b ? a : b),
        )
        .reduce((a, b) => a > b ? a : b);

    final chart = _chartData();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // ── Period filter chips ────────────────────────────
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                _Period.values.map((p) {
                  final label = switch (p) {
                    _Period.week => 'Week',
                    _Period.month => 'Month',
                    _Period.quarter => 'Quarter',
                    _Period.year => 'Year',
                  };
                  final sel = _period == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: sel,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // ── Bar chart ──────────────────────────────────────
        Builder(
          builder: (context) {
            final allZero =
                chart.exp.every((v) => v == 0) &&
                chart.inc.every((v) => v == 0);
            if (allZero) {
              return Container(
                height: 180,
                padding: const EdgeInsets.all(24),
                decoration: context.cardDecoration,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 36,
                        color: context.appColors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No transactions this period',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add a transaction to see your chart.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              decoration: context.cardDecoration,
              child: _SpendBarChart(
                labels: chart.labels,
                expValues: chart.exp,
                incValues: chart.inc,
                expColor: expenseColor,
                incColor: incomeColor,
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // ── Legend ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _LegendDot(color: expenseColor, label: 'Expense'),
              const SizedBox(width: 16),
              _LegendDot(color: incomeColor, label: 'Income'),
              const Spacer(),
              Text(
                currency ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: context.appColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // ── Month cards ────────────────────────────────────
        ...allMonths.reversed.map((m) {
          final exp = monthExpense[m] ?? 0;
          final inc = monthIncome[m] ?? 0;
          final expRatio = maxVal > 0 ? (exp / maxVal).clamp(0.0, 1.0) : 0.0;
          final incRatio = maxVal > 0 ? (inc / maxVal).clamp(0.0, 1.0) : 0.0;
          final parts = m.split('-');
          final monthIdx = (int.tryParse(parts[1]) ?? 1).clamp(1, 12);
          final label = '${_months[monthIdx - 1]} ${parts[0]}';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: context.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (inc > 0)
                      Text(
                        '+${_smartMoney(inc)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: incomeColor,
                        ),
                      ),
                    if (inc > 0 && exp > 0) const SizedBox(width: 8),
                    if (exp > 0)
                      Text(
                        '-${_smartMoney(exp)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: expenseColor,
                        ),
                      ),
                  ],
                ),
                if (exp > 0) ...[
                  const SizedBox(height: 8),
                  _MonthBar(
                    label: 'Exp',
                    ratio: expRatio,
                    color: expenseColor,
                    ctx: context,
                  ),
                ],
                if (inc > 0) ...[
                  const SizedBox(height: 6),
                  _MonthBar(
                    label: 'Inc',
                    ratio: incRatio,
                    color: incomeColor,
                    ctx: context,
                  ),
                ],
                if (inc > 0 && exp > 0) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      'Net: ${inc >= exp ? '+' : ''}${_smartMoney(inc - exp)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: inc >= exp ? incomeColor : expenseColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SpendBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> expValues;
  final List<double> incValues;
  final Color expColor;
  final Color incColor;

  const _SpendBarChart({
    required this.labels,
    required this.expValues,
    required this.incValues,
    required this.expColor,
    required this.incColor,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final allVals = [...expValues, ...incValues];
    final maxVal =
        allVals.isEmpty
            ? 1.0
            : allVals
                .reduce((a, b) => a > b ? a : b)
                .clamp(1.0, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight - 24),
                painter: _LineChartPainter(
                  labels: labels,
                  expValues: expValues,
                  incValues: incValues,
                  maxVal: maxVal,
                  expColor: expColor,
                  incColor: incColor,
                  textColor: context.appColors.textMuted,
                ),
              ),
            ),
            SizedBox(
              height: 24,
              child: Row(
                children:
                    labels.map((l) {
                      return Expanded(
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 9,
                            color: context.appColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> expValues;
  final List<double> incValues;
  final double maxVal;
  final Color expColor;
  final Color incColor;
  final Color textColor;

  const _LineChartPainter({
    required this.labels,
    required this.expValues,
    required this.incValues,
    required this.maxVal,
    required this.expColor,
    required this.incColor,
    required this.textColor,
  });

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n == 0) return;
    const topPad = 18.0;
    const bottomPad = 4.0;
    final drawH = size.height - topPad - bottomPad;
    final groupW = size.width / (n == 1 ? 2 : n - 1);

    Offset pt(int i, double val) {
      final x = n == 1 ? size.width / 2 : i * groupW;
      final y = topPad + drawH - (maxVal > 0 ? (val / maxVal) * drawH : 0.0);
      return Offset(x, y);
    }

    // Grid line at 50%
    final gridPaint =
        Paint()
          ..color = textColor.withAlpha(30)
          ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, topPad + drawH / 2),
      Offset(size.width, topPad + drawH / 2),
      gridPaint,
    );
    // Baseline
    canvas.drawLine(
      Offset(0, topPad + drawH),
      Offset(size.width, topPad + drawH),
      gridPaint..color = textColor.withAlpha(50),
    );

    void drawLine(List<double> values, Color color) {
      if (values.every((v) => v == 0)) return;
      final linePaint =
          Paint()
            ..color = color.withAlpha(210)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
      final fillPaint =
          Paint()
            ..color = color.withAlpha(25)
            ..style = PaintingStyle.fill;

      final path = Path();
      final fillPath = Path();
      final pts = List.generate(n, (i) => pt(i, values[i]));

      fillPath.moveTo(pts.first.dx, topPad + drawH);
      fillPath.lineTo(pts.first.dx, pts.first.dy);
      path.moveTo(pts.first.dx, pts.first.dy);

      for (int i = 1; i < n; i++) {
        // Smooth cubic curve
        final cp1x = pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * 0.5;
        path.cubicTo(
          cp1x,
          pts[i - 1].dy,
          cp1x,
          pts[i].dy,
          pts[i].dx,
          pts[i].dy,
        );
        fillPath.cubicTo(
          cp1x,
          pts[i - 1].dy,
          cp1x,
          pts[i].dy,
          pts[i].dx,
          pts[i].dy,
        );
      }
      fillPath.lineTo(pts.last.dx, topPad + drawH);
      fillPath.close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);

      // Data points + labels
      final dotPaint = Paint()..color = color.withAlpha(230);
      final bgPaint = Paint()..color = color.withAlpha(40);
      for (int i = 0; i < n; i++) {
        if (values[i] == 0) continue;
        canvas.drawCircle(pts[i], 4, bgPaint);
        canvas.drawCircle(pts[i], 2.5, dotPaint);

        // Data label above point
        final label = _fmt(values[i]);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color.withAlpha(220),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lx = (pts[i].dx - tp.width / 2).clamp(0.0, size.width - tp.width);
        final ly = (pts[i].dy - tp.height - 4).clamp(
          0.0,
          size.height.toDouble(),
        );
        tp.paint(canvas, Offset(lx, ly));
      }
    }

    drawLine(expValues, expColor);
    drawLine(incValues, incColor);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.expValues != expValues ||
      old.incValues != incValues ||
      old.maxVal != maxVal;
}

class _MonthBar extends StatelessWidget {
  final String label;
  final double ratio;
  final Color color;
  final BuildContext ctx;
  const _MonthBar({
    required this.label,
    required this.ratio,
    required this.color,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: ctx.appColors.textMuted),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatefulWidget {
  final List<Transaction> transactions;
  final String currency;

  const _CategoryBreakdown({
    required this.transactions,
    required this.currency,
  });

  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Aggregate by category
    final Map<String, double> totals = {};
    for (final tx in widget.transactions) {
      totals[tx.category] = (totals[tx.category] ?? 0) + tx.amount;
    }
    final sorted =
        totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(0.0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox();

    final donutAndLegend = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut chart
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _DonutPainter(
              segments:
                  sorted
                      .map(
                        (e) => _DonutSegment(
                          value: e.value,
                          color:
                              _kCategoryColors[e.key] ??
                              const Color(0xFF636E72),
                        ),
                      )
                      .toList(),
              total: total,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.currency,
                    style: TextStyle(
                      color: context.appColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                sorted.take(5).map((e) {
                  final color =
                      _kCategoryColors[e.key] ?? const Color(0xFF636E72);
                  final pct = (e.value / total * 100).toStringAsFixed(0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );

    final expandedDetail = Column(
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),
        ...sorted.map((e) {
          final color = _kCategoryColors[e.key] ?? const Color(0xFF636E72);
          final ratio = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.currency} ${e.value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SPENDING BY CATEGORY',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _expanded = !_expanded);
                },
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 250),
                  turns: _expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: context.appColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          donutAndLegend,
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: expandedDetail,
          ),
        ],
      ),
    );
  }
}

class _DonutSegment {
  final double value;
  final Color color;
  const _DonutSegment({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;

  const _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 18.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const gapAngle = 0.03; // radians gap between segments
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

    double startAngle = -3.14159 / 2; // start at top

    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * 3.14159 - gapAngle;
      paint.color = seg.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.total != total;
}

// ── Summary card ──────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double monthExpenses;
  final double monthIncome;
  final String currency;

  const _SummaryCard({
    required this.monthExpenses,
    required this.monthIncome,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final net = monthIncome - monthExpenses;
    final now = DateTime.now();
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
    final monthLabel = '${months[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MonthMetric(
                  label: 'Expenses',
                  amount: monthExpenses,
                  currency: currency,
                  color: AppColors.danger,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MonthMetric(
                  label: 'Income',
                  amount: monthIncome,
                  currency: currency,
                  color: AppColors.success,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MonthMetric(
                  label: 'Net',
                  amount: net,
                  currency: currency,
                  color: net >= 0 ? AppColors.success : AppColors.danger,
                  icon:
                      net >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthMetric extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final IconData icon;

  const _MonthMetric({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount.abs().toStringAsFixed(2),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          currency,
          style: TextStyle(color: context.appColors.textMuted, fontSize: 10),
        ),
      ],
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
    final color =
        isIncome
            ? AppColors.success
            : isTransfer
            ? AppColors.textSecondary
            : AppColors.danger;

    return GestureDetector(
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: context.cardDecorationR(14),
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
                  '${isIncome
                      ? '+'
                      : isTransfer
                      ? ''
                      : '-'}${tx.currency} ${tx.amount.toStringAsFixed(2)}',
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
          (ctx) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: const Text('This cannot be undone.'),
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
  Account? _toAccount; // destination account for transfers
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
          : _kExpenseCategories; // expense + transfer both use expense categories

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || amount > 1e9 || _account == null) {
      return;
    }
    if (_type == TransactionType.transfer && _toAccount == null) {
      AppToast.show(context, 'Please select a destination account.');
      return;
    }
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
        toAccountId: _type == TransactionType.transfer ? _toAccount?.id : null,
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
        AppToast.show(
          context,
          'Could not save transaction. Please try again.',
          type: ToastType.error,
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
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
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
                      // Type toggle — Expense / Income / Transfer
                      Row(
                        children:
                            [
                              TransactionType.expense,
                              TransactionType.income,
                              TransactionType.transfer,
                            ].map((t) {
                              final sel = _type == t;
                              final c =
                                  t == TransactionType.income
                                      ? AppColors.success
                                      : t == TransactionType.transfer
                                      ? AppColors.accent
                                      : AppColors.danger;
                              final label =
                                  t == TransactionType.expense
                                      ? 'Expense'
                                      : t == TransactionType.income
                                      ? 'Income'
                                      : 'Transfer';
                              return Expanded(
                                child: GestureDetector(
                                  onTap:
                                      () => setState(() {
                                        _type = t;
                                        _category = _categories.first;
                                        _toAccount = null;
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
                                              : context.appColors.bgCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            sel ? c : context.appColors.border,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color:
                                              sel ? c : AppColors.textSecondary,
                                          fontWeight:
                                              sel
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Destination account (only for transfers)
                      if (_type == TransactionType.transfer) ...[
                        DropdownButtonFormField<Account>(
                          value: _toAccount,
                          decoration: const InputDecoration(
                            labelText: 'To Account',
                          ),
                          items:
                              widget.accounts
                                  .where((a) => a.id != _account?.id)
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (a) => setState(() => _toAccount = a),
                        ),
                        const SizedBox(height: 16),
                      ],

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
                                            : context.appColors.bgCard,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          sel
                                              ? primary
                                              : context.appColors.border,
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
  void initState() {
    super.initState();
    // Pre-fill the default currency from Settings
    final prefs = ref.read(sharedPreferencesProvider);
    _currency = prefs.getString(PrefKeys.defaultCurrency) ?? 'USD';
  }

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
        AppToast.show(
          context,
          'Could not save account. Please try again.',
          type: ToastType.error,
        );
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
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
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
