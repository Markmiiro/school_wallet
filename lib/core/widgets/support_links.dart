// "Get support": WhatsApp first, email for anyone without it. Used in
// Profile and on the lock screen, where the parent cannot get in and
// most needs help. Contacts come from SupportConfig; one that is not set
// is not offered.

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/support_config.dart';
import '../support/open_link.dart';
import '../support/support_request.dart';
import '../theme/app_theme.dart';

class SupportLinks extends StatelessWidget {
  /// The screen this sits on; goes into the message.
  final String screen;

  /// The signed-in account's phone number, if any.
  final String? account;

  /// On the navy lock screen: light text instead of navy.
  final bool onDark;
  final SupportConfig config;

  const SupportLinks({
    super.key,
    required this.screen,
    required this.account,
    this.onDark = false,
    this.config = SupportConfig.current,
  });

  Future<void> _open(BuildContext context, Uri uri, String otherwise) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await openLink(uri)) {
      messenger?.showSnackBar(SnackBar(content: Text(otherwise)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!config.hasWhatsapp && !config.hasEmail) return const SizedBox.shrink();
    final request = SupportRequest(screen: screen, account: account);
    final colour = onDark ? AppColors.onPrimary : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.hasWhatsapp)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colour,
              side: BorderSide(color: colour),
            ),
            onPressed: () => _open(context, request.whatsappUri(config),
                'Could not open WhatsApp. Message us on ${config.whatsapp}.'),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Get support on WhatsApp'),
          ),
        if (config.hasEmail)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colour),
            onPressed: () => _open(context, request.emailUri(config),
                'Could not open your mail app. Write to ${config.email}.'),
            child: Text(config.hasWhatsapp ? 'No WhatsApp? Email us' : 'Email support'),
          ),
      ],
    );
  }
}

/// "Nuvora 1.4.0 (build 212)", small, at the foot of Profile.
class AppVersionLine extends StatelessWidget {
  const AppVersionLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nuvora ${AppVersion.current.label}',
      textAlign: TextAlign.center,
      style: AppTheme.bodySm.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant),
    );
  }
}
