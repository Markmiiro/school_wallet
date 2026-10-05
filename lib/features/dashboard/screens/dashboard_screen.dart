// Home. Greeting header, then one of four things:
//   - still loading: grey blocks;
//   - could not load: what failed and "Try again" (never "no children",
//     which would be a wrong answer rather than no answer);
//   - nothing on the account yet: only the "Get started" panel, which
//     names the next thing to do. No balance, no shortcuts, no empty
//     "Your Children" box;
//   - children: total family balance, quick actions (Buy a Card /
//     History), a card per child, then what is left of "Get started".
//
// Parents do not create children here, and do not link cards. The school
// registers each child with the guardian's phone number and links their
// card at handout. When children wait on this parent's number, the first
// step (or a banner, once there are children) leads to
// ClaimChildrenScreen, which proves the number by SMS code once.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/brand_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/student.dart';
import '../../../data/models/wallet_balance.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/card_service.dart';
import '../../../data/services/family_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../family/screens/claim_children_screen.dart';
import '../../wallet/screens/child_wallet_detail_screen.dart';
import '../get_started.dart';

class DashboardScreen extends StatefulWidget {
  /// Switches the shell to the Transactions tab.
  final VoidCallback? onOpenTransactions;

  final FamilyService? familyService;
  final CardService? cardService;

  const DashboardScreen({
    super.key,
    this.onOpenTransactions,
    this.familyService,
    this.cardService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final _family = widget.familyService ?? FamilyService();
  late final _cards = widget.cardService ?? CardService();
  FamilyClaimable? _claimable;

  // Children whose card is bought and waiting at the school.
  Set<int> _cardPaidFor = {};
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();
    final parentId = authProvider.currentUser?.id;
    if (parentId != null) {
      await walletProvider.loadForParent(parentId);
    }
    try {
      final claimable = await _family.claimable();
      if (mounted) setState(() => _claimable = claimable);
    } catch (_) {
      // The dashboard works without it: the first step then says to ask
      // the school, and "Check again" asks once more.
    }
    await _loadSetup(walletProvider);
  }

  // What "Get started" needs beyond children and balances, and only
  // when a step depends on it.
  Future<void> _loadSetup(WalletProvider wallet) async {
    if (wallet.students.isEmpty) return;
    // The history says whether money ever went in (a zero balance may
    // be money already spent), and keeps the Transactions tab in step
    // with a top-up just made from here.
    await wallet.loadFamilyTransactions();
    final without = [
      for (final s in wallet.students)
        if (s.neverHadCard) s.id,
    ];
    try {
      final paid = without.isEmpty ? <int>{} : await _cards.paidFor(without);
      if (mounted) setState(() => _cardPaidFor = paid);
    } on SessionExpiredException {
      // The router is already on its way back to the login screen.
    }
  }

  Future<void> _openClaim() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ClaimChildrenScreen(claimable: _claimable!),
    ));
    if (added == true) await _load();
  }

  // "Check again" on the first step: the parent has just asked the
  // school, so say plainly when there is still nothing.
  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    await _load();
    if (!mounted) return;
    setState(() => _checking = false);
    final wallet = context.read<WalletProvider>();
    final nothing = wallet.hasLoaded &&
        wallet.students.isEmpty &&
        (_claimable?.count ?? 0) == 0;
    if (nothing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nothing yet. The school has not added your number.'),
      ));
    }
  }

  Future<void> _buyCard() async {
    await context.push('/buy-card');
    // A card may have been paid for in there: the step then says to
    // collect it.
    if (mounted) _load();
  }

  // A top-up is always for one child. With one child, go straight to
  // their wallet; otherwise ask which.
  void _topUp(WalletProvider wallet) {
    if (wallet.students.length == 1) {
      _openChild(wallet.students.first);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choose a child below to top up their wallet.'),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  double get _totalBalance {
    final wallet = context.read<WalletProvider>();
    double sum = 0;
    for (final s in wallet.students) {
      final b = wallet.balanceFor(s.id);
      if (b != null) sum += b.balance;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final user = authProvider.currentUser;
    final hasChildren = walletProvider.students.isNotEmpty;
    // Until the first load has come back there is no telling an empty
    // account from one that has not loaded.
    final loaded = walletProvider.hasLoaded;
    final failed = !loaded && walletProvider.errorMessage != null;
    final steps = setupStepsLeft(
      students: walletProvider.students,
      toppedUp: walletProvider.hasToppedUp,
    );

    final getStarted = GetStartedPanel(
      steps: steps,
      students: walletProvider.students,
      waiting: _claimable?.count ?? 0,
      phone: user?.phone,
      paidFor: _cardPaidFor,
      busy: _checking,
      onAddChildren: _openClaim,
      onCheckAgain: _checkAgain,
      onBuyCard: _buyCard,
      onTopUp: () => _topUp(walletProvider),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.marginMobile, AppTheme.spaceLg,
              AppTheme.marginMobile, AppTheme.spaceXl,
            ),
            children: [
              // Header
              Row(
                children: [
                  SvgPicture.asset(BrandAssets.mark,
                      height: 22, excludeFromSemantics: true),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text('Nuvora', style: AppTheme.headlineMd),
                  const Spacer(),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryContainer.withOpacity(0.2),
                    child: Text(
                      _initials(user?.name),
                      style: AppTheme.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppTheme.spaceLg),

              // Someone with nothing on the account has not been here
              // before in any way that matters.
              Text(loaded && !hasChildren ? 'Welcome,' : 'Welcome back,',
                  style: AppTheme.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant)),
              Text(user?.name ?? 'there', style: AppTheme.headlineLgMobile)
                  .animate()
                  .fadeIn(delay: 80.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: AppTheme.spaceLg),

              if (failed)
                LoadFailed(
                  title: 'Could not load your account',
                  message: walletProvider.errorMessage!,
                  onRetry: _load,
                )
              else if (!loaded)
                const LoadingBlocks(height: 88)
              else if (!hasChildren)
                getStarted.animate().fadeIn(duration: 300.ms)
              else ...[
                // A refresh failed; what is shown is from the last one
                // that worked.
                if (walletProvider.errorMessage != null) ...[
                  _staleNote(),
                  const SizedBox(height: AppTheme.spaceMd),
                ],

                if ((_claimable?.count ?? 0) > 0) ...[
                  _claimBanner(_claimable!.count),
                  const SizedBox(height: AppTheme.spaceLg),
                ],

                _totalBalanceCard(walletProvider),
                const SizedBox(height: AppTheme.spaceLg),

                _quickActions(),
                const SizedBox(height: AppTheme.spaceLg),

                Text('Your Children', style: AppTheme.headlineMd),
                const SizedBox(height: AppTheme.spaceMd),

                ...walletProvider.students.asMap().entries.map((entry) {
                  final index = entry.key;
                  final student = entry.value;
                  final balance = walletProvider.balanceFor(student.id);
                  return _childCard(student, balance, index);
                }),

                // What is still missing comes after the children, so the
                // balance and the children stay where they always are.
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  getStarted,
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _staleNote() {
    return Row(
      children: [
        Expanded(
          child: Text('Could not refresh. This is what loaded last time.',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        ),
        TextButton(onPressed: _load, child: const Text('Try again')),
      ],
    );
  }

  Widget _totalBalanceCard(WalletProvider wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.balanceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [AppColors.level2Shadow],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0, top: 0,
            child: Icon(Icons.shield_rounded,
                color: AppColors.onBalanceCard.withOpacity(0.15), size: 28),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total family balance',
                  style: AppTheme.bodySm.copyWith(
                      color: AppColors.onBalanceCard, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppTheme.spaceXs),
              AnimatedBalanceCounter(
                balance: _totalBalance,
                style: AppTheme.displayCurrency.copyWith(color: AppColors.onBalanceCard),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              // The one teal fill on Home: blue and teal sit together
              // here, and teal is the smaller of the two.
              ElevatedButton(
                style: AppTheme.signalButton.copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
                ),
                onPressed: () => _topUp(wallet),
                child: const Text('Top Up Wallet'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _claimBanner(int count) {
    final noun = count == 1 ? 'child is' : 'children are';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count $noun waiting for you', style: AppTheme.headlineMd),
          const SizedBox(height: AppTheme.spaceXs),
          Text('Your school registered them under your phone number.',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppTheme.spaceMd),
          ElevatedButton(
            onPressed: _openClaim,
            child: const Text('Add them'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _quickActions() {
    return Row(
      children: [
        _actionTile(Icons.credit_card_rounded, 'Buy a Card', _buyCard),
        const SizedBox(width: AppTheme.spaceMd),
        _actionTile(Icons.receipt_long_rounded, 'History',
            () => widget.onOpenTransactions?.call()),
      ],
    ).animate().fadeIn(delay: 160.ms);
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.level1CardBorder),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChild(Student student) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChildWalletDetailScreen(student: student),
      ),
    );
    // A top-up, a new limit or a blocked card may have happened in there.
    if (mounted) _load();
  }

  Widget _childCard(Student student, WalletBalance? balance, int index) {
    final schoolLine = [
      if (student.schoolName != null) student.schoolName!,
      if (student.accountNumber != null) 'Acc ${student.accountNumber}',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => _openChild(student),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.level1CardBorder),
            boxShadow: [AppColors.level2Shadow],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryContainer.withOpacity(0.15),
                child: Icon(Icons.school_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: AppTheme.headlineMd.copyWith(fontSize: 17)),
                    if (schoolLine.isNotEmpty)
                      Text(
                        schoolLine,
                        style: AppTheme.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    if (balance == null)
                      Text('Balance unavailable',
                          style: AppTheme.bodySm
                              .copyWith(color: AppColors.onSurfaceVariant))
                    else
                      AnimatedBalanceCounter(
                        balance: balance.balance,
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 20, color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }
}