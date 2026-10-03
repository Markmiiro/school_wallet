// Terms and privacy acceptance. A full screen, not a checkbox: a plain
// summary of what the parent is agreeing to, links to the full Terms of
// Use and Privacy Policy, and one "I accept" button.
//
// Shown in two places:
//   - signup, BEFORE the account form — no account without acceptance;
//   - login, when the backend says the version this parent accepted is
//     no longer the current one.
//
// The text and its version come from GET /auth/terms, so what is shown
// is exactly what the accepted version refers to. This screen records
// nothing itself; it hands the accepted version back to the caller,
// which sends it with the signup or login request.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/terms.dart';
import '../../../data/services/auth_service.dart';

class TermsAcceptanceView extends StatefulWidget {
  /// Called with the version the parent accepted.
  final ValueChanged<String> onAccept;
  final VoidCallback onDecline;

  /// True when someone who already has an account is being asked at
  /// login: the terms changed since they accepted, or they never have.
  final bool isUpdate;

  const TermsAcceptanceView({
    super.key,
    required this.onAccept,
    required this.onDecline,
    this.isUpdate = false,
  });

  @override
  State<TermsAcceptanceView> createState() => _TermsAcceptanceViewState();
}

class _TermsAcceptanceViewState extends State<TermsAcceptanceView> {
  final AuthService _authService = AuthService();
  late Future<Terms> _terms;

  @override
  void initState() {
    super.initState();
    _terms = _authService.fetchTerms();
  }

  void _retry() => setState(() => _terms = _authService.fetchTerms());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onDecline,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<Terms>(
          future: _terms,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _loadFailed();
            }
            return _loaded(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _loadFailed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Could not load the terms', style: AppTheme.headlineMd),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Check your connection and try again. You need to read them '
              'before you can continue.',
              textAlign: TextAlign.center,
              style:
                  AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loaded(Terms terms) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.marginMobile),
            children: [
              Text(
                widget.isUpdate
                    ? 'Please review our terms'
                    : 'Before you continue',
                style: AppTheme.headlineLgMobile,
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                widget.isUpdate
                    ? 'These are the current terms. You need to accept them '
                        'to keep using Nuvora.'
                    : 'Here is what you are agreeing to, in plain words.',
                style:
                    AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              for (final point in terms.summary) ...[
                _summaryCard(point),
                const SizedBox(height: AppTheme.spaceSm),
              ],

              const SizedBox(height: AppTheme.spaceMd),
              Text('The full text',
                  style:
                      AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppTheme.spaceSm),
              for (final doc in terms.documents) ...[
                _documentLink(doc),
                const SizedBox(height: AppTheme.spaceSm),
              ],

              const SizedBox(height: AppTheme.spaceSm),
              Text(
                'Version ${terms.version}',
                style: AppTheme.labelMono.copyWith(
                    color: AppColors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),

        // Pinned, so accepting never depends on scrolling to find it.
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.marginMobile,
            AppTheme.spaceMd,
            AppTheme.marginMobile,
            AppTheme.spaceSm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(top: BorderSide(color: AppColors.level1CardBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'By tapping "I accept" you agree to the Terms of Use and '
                'the Privacy Policy above.',
                textAlign: TextAlign.center,
                style:
                    AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onAccept(terms.version),
                  child: const Text('I accept'),
                ),
              ),
              TextButton(
                onPressed: widget.onDecline,
                child: Text(
                  'Not now',
                  style: AppTheme.bodySm.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(TermsPoint point) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.level1CardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(point.title,
              style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTheme.spaceXs),
          Text(point.body,
              style:
                  AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _documentLink(TermsDocument doc) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TermsDocumentScreen(document: doc)),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  'Read the full ${doc.title}',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One full document (Terms of Use, or Privacy Policy), section by
/// section. Read-only; going back returns to the acceptance screen.
class TermsDocumentScreen extends StatelessWidget {
  final TermsDocument document;

  const TermsDocumentScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.marginMobile),
          children: [
            for (final section in document.sections) ...[
              Text(section.heading,
                  style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppTheme.spaceXs),
              Text(section.body,
                  style: AppTheme.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppTheme.spaceLg),
            ],
          ],
        ),
      ),
    );
  }
}
